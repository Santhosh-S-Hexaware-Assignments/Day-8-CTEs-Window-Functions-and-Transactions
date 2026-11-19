-- Set 1

-- 1. DATABASE TABLES AND SAMPLE DATA

-- Create Database
CREATE DATABASE TransactionDB; GO;
USE TransactionDB;

-- Create Bank Accounts Table
CREATE TABLE BankAccounts (
    AccountID       INT PRIMARY KEY,
    AccountHolder   NVARCHAR(100) NOT NULL,
    Balance         DECIMAL(12, 2) NOT NULL CHECK (Balance >= 0),
    AccountStatus   VARCHAR(20) NOT NULL CHECK (AccountStatus IN ('Active', 'Blocked'))
);

-- Create Bank Transactions Table
CREATE TABLE BankTransactions (
    TransactionID   INT IDENTITY(1, 1) PRIMARY KEY,
    AccountID       INT NOT NULL REFERENCES BankAccounts(AccountID),
    TransactionDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    TransactionType VARCHAR(20) NOT NULL,
    Amount          DECIMAL(12, 2) NOT NULL CHECK (Amount > 0),
    BalanceAfter    DECIMAL(12, 2) NOT NULL CHECK (BalanceAfter >= 0),
    Description     NVARCHAR(200)
);

-- Insert Sample Accounts
INSERT INTO BankAccounts (AccountID, AccountHolder, Balance, AccountStatus) VALUES
    (1001, 'Alice', 5000.00, 'Active'),
    (1002, 'Bob', 2500.00, 'Active'),
    (1003, 'Charlie', 1000.00, 'Blocked');

-- Display Initial Accounts
SELECT * FROM BankAccounts;


-- 2. FUNDS TRANSFER WITH TRANSACTION HANDLING

DECLARE @FromAccount INT = 1001;
DECLARE @ToAccount INT = 1002;
DECLARE @TransferAmount DECIMAL(12, 2) = 500.00;

DECLARE @FromBalance DECIMAL(12, 2);
DECLARE @ToBalance DECIMAL(12, 2);

DECLARE @FromStatus VARCHAR(20);
DECLARE @ToStatus VARCHAR(20);

BEGIN TRY
    BEGIN TRANSACTION;

    -- Lock both accounts while validating and transferring
    SELECT @FromBalance = Balance, @FromStatus = AccountStatus
        FROM BankAccounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @FromAccount;

    SELECT @ToBalance = Balance, @ToStatus = AccountStatus
        FROM BankAccounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @ToAccount;

    -- Validate account existence
    IF @FromBalance IS NULL OR @ToBalance IS NULL
        THROW 51001, 'One or both accounts do not exist.', 1;

    -- Validate account status
    IF @FromStatus <> 'Active' OR @ToStatus <> 'Active'
        THROW 51002, 'Both accounts must be active.', 1;

    -- Validate transfer amount
    IF @TransferAmount <= 0
        THROW 51003, 'Transfer amount must be greater than zero.', 1;

    -- Validate available balance
    IF @FromBalance < @TransferAmount
        THROW 51004, 'Insufficient account balance.', 1;

    -- Debit Source Account
    UPDATE BankAccounts
        SET Balance = Balance - @TransferAmount
        WHERE AccountID = @FromAccount;

    -- Credit Destination Account
    UPDATE BankAccounts
        SET Balance = Balance + @TransferAmount
        WHERE AccountID = @ToAccount;

    -- Retrieve Updated Balances
    SELECT @FromBalance = Balance
        FROM BankAccounts
        WHERE AccountID = @FromAccount;

    SELECT @ToBalance = Balance
        FROM BankAccounts
        WHERE AccountID = @ToAccount;

    -- Record Debit Transaction
    INSERT INTO BankTransactions (AccountID, TransactionType, Amount, BalanceAfter, Description) VALUES
        (@FromAccount, 'Debit', @TransferAmount, @FromBalance, 'Funds transferred to another account');

    -- Record Credit Transaction
    INSERT INTO BankTransactions (AccountID, TransactionType, Amount, BalanceAfter, Description) VALUES
        (@ToAccount, 'Credit', @TransferAmount, @ToBalance, 'Funds received from another account');

    COMMIT TRANSACTION;
    PRINT 'Funds transfer completed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'Transfer failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH;

-- Verify Transfer
SELECT * FROM BankAccounts;
SELECT * FROM BankTransactions;


-- 3. DELIBERATE FAILURE AFTER DEBIT - ROLLBACK DEMONSTRATION

DECLARE @FailureAccount INT = 1001;
DECLARE @FailureAmount DECIMAL(12, 2) = 300.00;
DECLARE @BalanceBeforeFailure DECIMAL(12, 2);

SELECT @BalanceBeforeFailure = Balance
    FROM BankAccounts
    WHERE AccountID = @FailureAccount;

PRINT 'Balance before deliberate failure: ' + CAST(@BalanceBeforeFailure AS VARCHAR(30));

BEGIN TRY
    BEGIN TRANSACTION;

    -- Perform Debit
    UPDATE BankAccounts
    SET Balance = Balance - @FailureAmount
        WHERE AccountID = @FailureAccount
            AND AccountStatus = 'Active'
            AND Balance >= @FailureAmount;

    IF @@ROWCOUNT = 0
        THROW 51005, 'Debit could not be completed.', 1;

    PRINT 'Debit completed inside transaction.';

    -- Deliberately generate an error after the debit
    THROW 51006, 'Simulated failure after debit.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'Expected failure: ' + ERROR_MESSAGE();
    PRINT 'Transaction rolled back.';
END CATCH;

-- Verify that the balance remains unchanged
SELECT @BalanceBeforeFailure AS BalanceBeforeFailure, Balance AS BalanceAfterRollback
    FROM BankAccounts
    WHERE AccountID = @FailureAccount;


-- 4. SAVEPOINT - ROLLBACK ONLY THE FEE-POSTING STEP

DECLARE @FeeFromAccount INT = 1001;
DECLARE @FeeToAccount INT = 1002;

DECLARE @FeeTransferAmount DECIMAL(12, 2) = 200.00;
DECLARE @TransferFee DECIMAL(12, 2) = 25.00;

DECLARE @FeeFromBalance DECIMAL(12, 2);
DECLARE @FeeToBalance DECIMAL(12, 2);
DECLARE @FeeFromStatus VARCHAR(20);
DECLARE @FeeToStatus VARCHAR(20);

BEGIN TRY
    BEGIN TRANSACTION;

    -- Lock and validate accounts
    SELECT @FeeFromBalance = Balance, @FeeFromStatus = AccountStatus
        FROM BankAccounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @FeeFromAccount;

    SELECT @FeeToBalance = Balance, @FeeToStatus = AccountStatus
        FROM BankAccounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @FeeToAccount;

    IF @FeeFromBalance IS NULL OR @FeeToBalance IS NULL
        THROW 51007, 'One or both accounts do not exist.', 1;

    IF @FeeFromStatus <> 'Active' OR @FeeToStatus <> 'Active'
        THROW 51008, 'Both accounts must be active.', 1;

    IF @FeeTransferAmount <= 0 OR @TransferFee < 0
        THROW 51009, 'Invalid transfer amount or fee.', 1;

    IF @FeeFromBalance < @FeeTransferAmount
        THROW 51010, 'Insufficient balance for transfer.', 1;

    -- Perform the actual transfer
    UPDATE BankAccounts
        SET Balance = Balance - @FeeTransferAmount
        WHERE AccountID = @FeeFromAccount;

    UPDATE BankAccounts
        SET Balance = Balance + @FeeTransferAmount
        WHERE AccountID = @FeeToAccount;

    -- Retrieve updated balances
    SELECT @FeeFromBalance = Balance
        FROM BankAccounts
        WHERE AccountID = @FeeFromAccount;

    SELECT @FeeToBalance = Balance
        FROM BankAccounts
        WHERE AccountID = @FeeToAccount;

    -- Record transfer transactions
    INSERT INTO BankTransactions (AccountID, TransactionType, Amount, BalanceAfter, Description) VALUES
        (@FeeFromAccount, 'Debit', @FeeTransferAmount, @FeeFromBalance, 'Funds transfer');

    INSERT INTO BankTransactions (AccountID, TransactionType, Amount, BalanceAfter, Description) VALUES
        (@FeeToAccount, 'Credit', @FeeTransferAmount, @FeeToBalance, 'Funds received');

    -- Create a savepoint after the transfer
    SAVE TRANSACTION FeePosting;
    PRINT 'Transfer completed inside transaction.';

    -- Attempt fee posting
    UPDATE BankAccounts
        SET Balance = Balance - @TransferFee
        WHERE AccountID = @FeeFromAccount
            AND Balance >= @TransferFee;

    IF @@ROWCOUNT = 0
        THROW 51011, 'Fee posting failed.', 1;

    SELECT @FeeFromBalance = Balance
        FROM BankAccounts
        WHERE AccountID = @FeeFromAccount;

    INSERT INTO BankTransactions (AccountID, TransactionType, Amount, BalanceAfter, Description) VALUES
        (@FeeFromAccount, 'Fee', @TransferFee, @FeeFromBalance, 'Transfer processing fee');

    PRINT 'Fee posted temporarily.';

    -- Roll back only the fee-posting operations
    ROLLBACK TRANSACTION FeePosting;
    PRINT 'Fee posting rolled back. Transfer retained.';

    -- Commit the remaining transaction
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = 1
        ROLLBACK TRANSACTION;

    ELSE IF XACT_STATE() = -1
        ROLLBACK TRANSACTION;

    PRINT 'Transaction failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH;

-- Verify transfer was retained and fee was not posted
SELECT * FROM BankAccounts;
SELECT * FROM BankTransactions
ORDER BY TransactionID;


-- 5. MONTHLY STATEMENT USING CTE AND WINDOW FUNCTIONS

DECLARE @StatementAccount INT = 1001;

;WITH StatementCTE AS (
    SELECT TransactionID, AccountID, TransactionDate, TransactionType, Amount, BalanceAfter, Description,
    ROW_NUMBER() OVER (
        PARTITION BY AccountID
        ORDER BY TransactionDate, TransactionID
    ) AS TransactionNumber,
    LAG(BalanceAfter) OVER (
        PARTITION BY AccountID
        ORDER BY TransactionDate, TransactionID
    ) AS PreviousBalance
        FROM BankTransactions
        WHERE AccountID = @StatementAccount
)
SELECT TransactionNumber, TransactionID, TransactionDate, TransactionType, Amount, PreviousBalance, BalanceAfter, Description
    FROM StatementCTE
    ORDER BY TransactionNumber;


-- 6. TRANSACTION ISOLATION LEVELS - TWO SESSION EXAMPLE


-- READ COMMITTED ISOLATION

-- Session 1:
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE BankAccounts
    SET Balance = Balance - 100
    WHERE AccountID = 1001;

WAITFOR DELAY '00:00:10';

COMMIT TRANSACTION;


-- Session 2:
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT Balance
    FROM BankAccounts
    WHERE AccountID = 1001;


-- SNAPSHOT ISOLATION

-- Enable snapshot isolation once for the database:
ALTER DATABASE CurrentDB
    SET ALLOW_SNAPSHOT_ISOLATION ON;


-- Session 1:
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

BEGIN TRANSACTION;

SELECT Balance
    FROM BankAccounts
    WHERE AccountID = 1001;

WAITFOR DELAY '00:00:10';

SELECT Balance
    FROM BankAccounts
    WHERE AccountID = 1001;

COMMIT TRANSACTION;


-- Session 2:
UPDATE BankAccounts
    SET Balance = Balance - 100
    WHERE AccountID = 1001;