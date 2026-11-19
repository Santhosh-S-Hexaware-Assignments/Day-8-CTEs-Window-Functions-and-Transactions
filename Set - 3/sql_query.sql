-- Set 3 (Retail Inventory Reservation)


-- Creating Database
IF DB_ID('RetailDB') IS NULL
    CREATE DATABASE RetailDB;
GO

USE RetailDB;
GO

-- Creating Tables

CREATE TABLE Categories (
    CategoryID      INT PRIMARY KEY,
    CategoryName    VARCHAR(50) NOT NULL
);


CREATE TABLE Products (
    ProductID       INT PRIMARY KEY,
    ProductName     VARCHAR(100) NOT NULL,
    CategoryID      INT NOT NULL REFERENCES Categories(CategoryID),,
    StockQuantity   INT NOT NULL CHECK (StockQuantity >= 0),
    UnitPrice       DECIMAL(10, 2) NOT NULL CHECK (UnitPrice >= 0),
);


CREATE TABLE Orders (
    OrderID         INT IDENTITY(1, 1) PRIMARY KEY,
    CustomerName    VARCHAR(100) NOT NULL,
    OrderDate       DATE NOT NULL DEFAULT GETDATE(),
    OrderStatus     VARCHAR(20) NOT NULL DEFAULT 'Placed'
);


CREATE TABLE OrderItems (
    OrderItemID     INT IDENTITY(1, 1) PRIMARY KEY,
    OrderID         INT NOT NULL REFERENCES Orders(OrderID),,
    ProductID       INT NOT NULL REFERENCES Products(ProductID),,
    Quantity        INT NOT NULL CHECK (Quantity > 0),
    UnitPrice       DECIMAL(10, 2) NOT NULL CHECK (UnitPrice >= 0),
);



-- Inserting Sample Data


-- Categories
INSERT INTO Categories VALUES
    (1, 'Electronics'),
    (2, 'Accessories'),
    (3, 'Furniture');


-- Products
INSERT INTO Products VALUES
    (101, 'Laptop', 1, 20, 55000),
    (102, 'Smartphone', 1, 35, 25000),
    (103, 'Tablet', 1, 8, 18000),
    (104, 'Headphones', 2, 50, 2500),
    (105, 'Keyboard', 2, 15, 1200),
    (106, 'Mouse', 2, 40, 800),
    (107, 'Office Chair', 3, 12, 7500),
    (108, 'Study Table', 3, 6, 9000);


-- Historical Orders
INSERT INTO Orders (CustomerName, OrderDate, OrderStatus) VALUES
    ('Alice', '2026-01-10', 'Completed'),
    ('Bob', '2026-01-15', 'Completed'),
    ('Charlie', '2026-02-05', 'Completed'),
    ('David', '2026-02-18', 'Completed'),
    ('Emma', '2026-03-08', 'Completed'),
    ('Frank', '2026-03-20', 'Completed'),
    ('Grace', '2026-04-12', 'Completed'),
    ('Henry', '2026-04-25', 'Completed');


-- Historical Order Items
INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice) VALUES
    (1, 101, 2, 55000),
    (1, 104, 5, 2500),
    (2, 102, 3, 25000),
    (2, 105, 4, 1200),
    (3, 101, 1, 55000),
    (3, 103, 2, 18000),
    (4, 106, 8, 800),
    (4, 107, 2, 7500),
    (5, 102, 4, 25000),
    (5, 104, 6, 2500),
    (6, 108, 3, 9000),
    (6, 105, 5, 1200),
    (7, 101, 3, 55000),
    (7, 106, 10, 800),
    (8, 103, 4, 18000),
    (8, 107, 3, 7500);



-- Assignment Tasks


-- Task 1


-- Stock Reservation Transaction


DECLARE
    @CustomerName VARCHAR(100) = 'John',
    @OrderID INT;


-- Products to be Reserved
DECLARE @OrderItems TABLE (ProductID INT, Quantity INT,UnitPrice DECIMAL(10, 2));


INSERT INTO @OrderItems VALUES
    (101, 2, 55000),
    (104, 3, 2500);


BEGIN TRY

    BEGIN TRANSACTION;


    -- Checking Product Availability
    IF EXISTS (
        SELECT 1
            FROM @OrderItems OI
            LEFT JOIN Products P ON OI.ProductID = P.ProductID
            WHERE P.ProductID IS NULL
                OR P.StockQuantity < OI.Quantity
    )
        THROW 51001, 'Insufficient stock or invalid product.', 1;


    -- Decrementing Stock
    UPDATE P
        SET P.StockQuantity = P.StockQuantity - OI.Quantity
        FROM Products P
        JOIN @OrderItems OI ON P.ProductID = OI.ProductID
        WHERE P.StockQuantity >= OI.Quantity;


    IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @OrderItems)
        THROW 51002, 'Stock reservation failed.', 1;


    -- Inserting Order
    INSERT INTO Orders (CustomerName, OrderDate, OrderStatus) VALUES
        (@CustomerName, GETDATE(), 'Placed');


    SET @OrderID = SCOPE_IDENTITY();


    -- Inserting Order Items
    INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice)
        SELECT @OrderID, ProductID, Quantity, UnitPrice
            FROM @OrderItems;

    COMMIT TRANSACTION;
    PRINT 'Order placed and stock reserved successfully.';

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    PRINT ERROR_MESSAGE();
END CATCH;


-- Verifying Stock
SELECT ProductID, ProductName, StockQuantity
    FROM Products;


-- Verifying Orders
SELECT *
    FROM Orders;


SELECT *
    FROM OrderItems;


-- Demonstrating Rollback When Stock Is Insufficient


-- Capturing Original Stock
DECLARE @OriginalStock INT;

SELECT @OriginalStock = StockQuantity
    FROM Products
    WHERE ProductID = 103;


-- Attempting an Invalid Reservation
DECLARE @FailedOrderItems TABLE (ProductID INT, Quantity INT, UnitPrice DECIMAL(10, 2));


INSERT INTO @FailedOrderItems VALUES
    (103, 100, 18000);


BEGIN TRY

    BEGIN TRANSACTION;


    -- Checking Stock
    IF EXISTS (
        SELECT 1
            FROM @FailedOrderItems OI
            JOIN Products P ON OI.ProductID = P.ProductID
            WHERE P.StockQuantity < OI.Quantity
    )
        THROW 51003, 'Insufficient stock for reservation.', 1;


    -- This Section Will Not Execute
    UPDATE P
        SET P.StockQuantity = P.StockQuantity - OI.Quantity
        FROM Products P
        JOIN @FailedOrderItems OI ON P.ProductID = OI.ProductID;


    INSERT INTO Orders (CustomerName, OrderStatus) VALUES
        ('Failed Customer', 'Placed');

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    PRINT ERROR_MESSAGE();
END CATCH;


-- Verifying Rollback
DECLARE @FinalStock INT;

SELECT @FinalStock = StockQuantity
    FROM Products
    WHERE ProductID = 103;


PRINT 'Original Stock: ' + CAST(@OriginalStock AS VARCHAR(10));
PRINT 'Final Stock: ' + CAST(@FinalStock AS VARCHAR(10));

IF @OriginalStock = @FinalStock
    PRINT 'Rollback Successful: Stock remains unchanged.';
ELSE
    PRINT 'Rollback Failed: Stock has changed.';



-- Task 2


-- Products with Stock Below Category Average

SELECT P.ProductID, P.ProductName, C.CategoryName, P.StockQuantity
    FROM Products P
    JOIN Categories C ON P.CategoryID = C.CategoryID
    WHERE P.StockQuantity < (
        SELECT AVG(CAST(P2.StockQuantity AS DECIMAL(10, 2)))
            FROM Products P2
            WHERE P2.CategoryID = P.CategoryID
    )
    ORDER BY C.CategoryName, P.StockQuantity;



-- Task 3


-- Top 3 Products by Sales Within Each Category

WITH ProductSales AS (
    SELECT P.ProductID, P.ProductName, C.CategoryName, SUM(OI.Quantity) AS TotalUnitsSold
        FROM Products P
        JOIN Categories C ON P.CategoryID = C.CategoryID
        JOIN OrderItems OI ON P.ProductID = OI.ProductID
        JOIN Orders O ON OI.OrderID = O.OrderID
        WHERE O.OrderStatus = 'Completed'
        GROUP BY P.ProductID, P.ProductName, C.CategoryName
), RankedProducts AS (
    SELECT ProductID, ProductName, CategoryName, TotalUnitsSold,
    ROW_NUMBER() OVER (PARTITION BY CategoryName ORDER BY TotalUnitsSold DESC, ProductID) AS SalesRank
        FROM ProductSales
)
SELECT ProductID, ProductName, CategoryName, TotalUnitsSold, SalesRank
    FROM RankedProducts
    WHERE SalesRank <= 3
    ORDER BY CategoryName, SalesRank;



-- Task 4


-- Month-on-Month Sales Using LAG and LEAD

WITH MonthlySales AS (
    SELECT OI.ProductID, P.ProductName,
    DATEFROMPARTS(YEAR(O.OrderDate),MONTH(O.OrderDate), 1) AS SalesMonth,
    SUM(OI.Quantity) AS TotalUnitsSold
        FROM OrderItems OI
        JOIN Orders O ON OI.OrderID = O.OrderID
        JOIN Products P ON OI.ProductID = P.ProductID
        WHERE O.OrderStatus = 'Completed'
        GROUP BY OI.ProductID, P.ProductName, YEAR(O.OrderDate), MONTH(O.OrderDate)
), SalesComparison AS (
    SELECT ProductID, ProductName, SalesMonth, TotalUnitsSold,
    LAG(TotalUnitsSold) OVER (PARTITION BY ProductID ORDER BY SalesMonth) AS PreviousMonthSales,
    LEAD(TotalUnitsSold) OVER (PARTITION BY ProductID ORDER BY SalesMonth) AS NextMonthSales
        FROM MonthlySales
)
SELECT ProductID, ProductName, SalesMonth, TotalUnitsSold, PreviousMonthSales, NextMonthSales, TotalUnitsSold - PreviousMonthSales AS MonthOnMonthChange
    FROM SalesComparison
    ORDER BY ProductID, SalesMonth;
