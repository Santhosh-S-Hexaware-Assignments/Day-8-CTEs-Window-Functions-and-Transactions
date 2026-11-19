// Creating Database
use AirlineDB


// Creating Collections
db.createCollection("Flights")
db.createCollection("Passengers")
db.createCollection("Seats")
db.createCollection("Bookings")


// Clearing Existing Data
db.Flights.deleteMany({})
db.Passengers.deleteMany({})
db.Seats.deleteMany({})
db.Bookings.deleteMany({})


// Inserting Sample Data


// Flights
db.Flights.insertMany([
    { FlightID: 101, FlightNumber: "AI101", Source: "Chennai", Destination: "Delhi" },
    { FlightID: 102, FlightNumber: "AI202", Source: "Mumbai", Destination: "Bangalore" }
])


// Passengers
db.Passengers.insertMany([
    { PassengerID: 1, PassengerName: "Alice" },
    { PassengerID: 2, PassengerName: "Bob" },
    { PassengerID: 3, PassengerName: "Charlie" },
    { PassengerID: 4, PassengerName: "David" },
    { PassengerID: 5, PassengerName: "Emma" }
])


// Seats
db.Seats.insertMany([
    { FlightID: 101, SeatNumber: "1A", SeatStatus: "Available" },
    { FlightID: 101, SeatNumber: "1B", SeatStatus: "Booked" },
    { FlightID: 101, SeatNumber: "1C", SeatStatus: "Booked" },
    { FlightID: 101, SeatNumber: "2A", SeatStatus: "Available" },
    { FlightID: 102, SeatNumber: "1A", SeatStatus: "Booked" },
    { FlightID: 102, SeatNumber: "1B", SeatStatus: "Booked" }
])


// Existing Bookings
db.Bookings.insertMany([
    { BookingID: 1, FlightID: 101, SeatNumber: "1B", PassengerID: 3, Fare: 7500 },
    { BookingID: 2, FlightID: 101, SeatNumber: "1C", PassengerID: 4, Fare: 9000 },
    { BookingID: 3, FlightID: 102, SeatNumber: "1A", PassengerID: 5, Fare: 6500 },
    { BookingID: 4, FlightID: 102, SeatNumber: "1B", PassengerID: 2, Fare: 6500 }
])



// Assignment Tasks


// Task 5


// Multi-document Transaction: Seat Booking


// Booking Details
var flightID = 101
var seatNumber = "1A"
var passengerID = 1
var fare = 8000


// Starting Session
session = db.getMongo().startSession()

// Accessing Collections Through Session
airlineDB = session.getDatabase("AirlineDB")


// Starting Transaction
session.startTransaction()


// Updating Seat Status
bookingResult = airlineDB.Seats.updateOne(
    {
        FlightID: flightID,
        SeatNumber: seatNumber,
        SeatStatus: "Available"
    },
    {
        $set: { SeatStatus: "Booked" }
    }
)


// Checking Seat Availability
if (bookingResult.modifiedCount == 1) {

    // Inserting Booking
    airlineDB.Bookings.insertOne({
        BookingID: 5,
        FlightID: flightID,
        SeatNumber: seatNumber,
        PassengerID: passengerID,
        Fare: fare,
        BookingDate: new Date()
    })

    // Committing Transaction
    session.commitTransaction()

    print("Seat booked successfully.")

}
else {

    // Rolling Back Transaction
    session.abortTransaction()

    print("Seat is unavailable. Booking cancelled.")

}


// Ending Session
session.endSession()


// Verifying Seat Status
db.Seats.find(
    { FlightID: flightID, SeatNumber: seatNumber },
    { _id: 0 }
)


// Verifying Booking
db.Bookings.find(
    { FlightID: flightID, SeatNumber: seatNumber },
    { _id: 0 }
)