// Set 3 (Retail Inventory Reservation)


// Creating Database
use RetailDB


// Creating Collections
db.createCollection("Categories")
db.createCollection("Products")
db.createCollection("Orders")
db.createCollection("OrderItems")


// Clearing Existing Data
db.Categories.deleteMany({})
db.Products.deleteMany({})
db.Orders.deleteMany({})
db.OrderItems.deleteMany({})


// Inserting Sample Data


// Categories
db.Categories.insertMany([
    { CategoryID: 1, CategoryName: "Electronics" },
    { CategoryID: 2, CategoryName: "Accessories" },
    { CategoryID: 3, CategoryName: "Furniture" }
])


// Products
db.Products.insertMany([
    { ProductID: 101, ProductName: "Laptop", CategoryID: 1, StockQuantity: 20, UnitPrice: 55000 },
    { ProductID: 102, ProductName: "Smartphone", CategoryID: 1, StockQuantity: 35, UnitPrice: 25000 },
    { ProductID: 103, ProductName: "Tablet", CategoryID: 1, StockQuantity: 8, UnitPrice: 18000 },
    { ProductID: 104, ProductName: "Headphones", CategoryID: 2, StockQuantity: 50, UnitPrice: 2500 },
    { ProductID: 105, ProductName: "Keyboard", CategoryID: 2, StockQuantity: 15, UnitPrice: 1200 },
    { ProductID: 106, ProductName: "Mouse", CategoryID: 2, StockQuantity: 40, UnitPrice: 800 },
    { ProductID: 107, ProductName: "Office Chair", CategoryID: 3, StockQuantity: 12, UnitPrice: 7500 },
    { ProductID: 108, ProductName: "Study Table", CategoryID: 3, StockQuantity: 6, UnitPrice: 9000 }
])


// Existing Orders
db.Orders.insertMany([
    { OrderID: 1, CustomerName: "Alice", OrderStatus: "Completed" },
    { OrderID: 2, CustomerName: "Bob", OrderStatus: "Completed" },
    { OrderID: 3, CustomerName: "Charlie", OrderStatus: "Completed" }
])


// Existing Order Items
db.OrderItems.insertMany([
    { OrderID: 1, ProductID: 101, Quantity: 2, UnitPrice: 55000 },
    { OrderID: 1, ProductID: 104, Quantity: 5, UnitPrice: 2500 },
    { OrderID: 2, ProductID: 102, Quantity: 3, UnitPrice: 25000 },
    { OrderID: 2, ProductID: 105, Quantity: 4, UnitPrice: 1200 },
    { OrderID: 3, ProductID: 103, Quantity: 2, UnitPrice: 18000 }
])



// Assignment Tasks


// Task 5


// Single-document Atomic Stock Update


// Reservation Details
var productID = 101
var quantity = 3


// Checking Product Availability
db.Products.findOne({
    ProductID: productID
})


// Decrementing Stock Atomically
db.Products.updateOne(
    {
        ProductID: productID,
        StockQuantity: { $gte: quantity }
    },
    {
        $inc: { StockQuantity: -quantity }
    }
)


// Verifying Updated Stock
db.Products.findOne(
    { ProductID: productID },
    { _id: 0 }
)


// Demonstrating Insufficient Stock


// Attempting to Reserve More Stock Than Available
db.Products.updateOne(
    {
        ProductID: 103,
        StockQuantity: { $gte: 100 }
    },
    {
        $inc: { StockQuantity: -100 }
    }
)


// Verifying Stock Remains Unchanged
db.Products.findOne(
    { ProductID: 103 },
    { _id: 0 }
)
