// Select Database
use BankingDB


// Create Collections
db.createCollection("BankAccounts")
db.createCollection("BankTransactions")


// Insert Sample Data
db.BankAccounts.insertMany([
    { AccountID: 1001, AccountHolder: "Alice", Balance: 5000, AccountStatus: "Active" },
    { AccountID: 1002, AccountHolder: "Bob", Balance: 2500, AccountStatus: "Active" },
    { AccountID: 1003, AccountHolder: "Charlie", Balance: 1000, AccountStatus: "Blocked" }
])


// Task 5: Multi-document Transaction


// Start Session and Transaction
session = db.getMongo().startSession()
session.startTransaction()

// Access Collections Through Session
bankDB = session.getDatabase("BankingDB")

// Validate Accounts
sender = bankDB.BankAccounts.findOne({ AccountID: 1001, AccountStatus: "Active" })
receiver = bankDB.BankAccounts.findOne({ AccountID: 1002, AccountStatus: "Active" })

// Debit Sender
bankDB.BankAccounts.updateOne(
    { AccountID: 1001, Balance: { $gte: 500 } },
    { $inc: { Balance: -500 } }
)

// Credit Receiver
bankDB.BankAccounts.updateOne(
    { AccountID: 1002, AccountStatus: "Active" },
    { $inc: { Balance: 500 } }
)

// Record Transactions
bankDB.BankTransactions.insertMany([
    { TransactionID: 1, AccountID: 1001, Type: "Debit", Amount: 500, Date: new Date() },
    { TransactionID: 2, AccountID: 1002, Type: "Credit", Amount: 500, Date: new Date() }
])

// Commit Transaction
session.commitTransaction()
session.endSession()


// Verify Updated Balances
db.BankAccounts.find({}, { _id: 0 })

// Verify Transactions
db.BankTransactions.find({}, { _id: 0 })


// Demonstrate Rollback


// Start Another Transaction
session = db.getMongo().startSession()
session.startTransaction()

bankDB = session.getDatabase("BankingDB")

// Perform Debit
bankDB.BankAccounts.updateOne(
    { AccountID: 1001 },
    { $inc: { Balance: -300 } }
)

// Abort Transaction
session.abortTransaction()
session.endSession()


// Verify Rollback
db.BankAccounts.find({ AccountID: 1001 }, { _id: 0 })