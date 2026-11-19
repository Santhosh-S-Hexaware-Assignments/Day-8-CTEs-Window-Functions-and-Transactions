-- Set 2 (Airline Seat Booking)

-- Creating Database
IF DB_ID('AirlineDB') IS NULL
    CREATE DATABASE AirlineDB;
GO

USE AirlineDB;
GO


-- Creating Tables
CREATE TABLE Flights (
    FlightID        INT PRIMARY KEY,
    FlightNumber    VARCHAR(10) NOT NULL,
    Source          VARCHAR(50) NOT NULL,
    Destination     VARCHAR(50) NOT NULL
);


CREATE TABLE Passengers (
    PassengerID     INT PRIMARY KEY,
    PassengerName   VARCHAR(50) NOT NULL
);


CREATE TABLE Seats (
    FlightID        INT NOT NULL REFERENCES Flights(FlightID),
    SeatNumber      VARCHAR(5) NOT NULL,
    SeatStatus      VARCHAR(15) NOT NULL DEFAULT 'Available' CHECK (SeatStatus IN ('Available', 'Booked')),
    PRIMARY KEY (FlightID, SeatNumber),
);


CREATE TABLE Bookings (
    BookingID       INT IDENTITY(1, 1) PRIMARY KEY,
    FlightID        INT NOT NULL,
    SeatNumber      VARCHAR(5) NOT NULL,
    PassengerID     INT NOT NULL REFERENCES Passengers(PassengerID),
    Fare            DECIMAL(10, 2) NOT NULL CHECK (Fare >= 0),
    BookingDate     DATETIME2 DEFAULT GETDATE(),

    FOREIGN KEY (FlightID, SeatNumber) REFERENCES Seats(FlightID, SeatNumber),
    UNIQUE (FlightID, SeatNumber),
);


-- Inserting Sample Data
INSERT INTO Flights VALUES
    (101, 'AI101', 'Chennai', 'Delhi'),
    (102, 'AI202', 'Mumbai', 'Bangalore');


INSERT INTO Passengers VALUES
    (1, 'Alice'),
    (2, 'Bob'),
    (3, 'Charlie'),
    (4, 'David'),
    (5, 'Emma');


INSERT INTO Seats (FlightID, SeatNumber) VALUES
    (101, '1A'),
    (101, '1B'),
    (101, '1C'),
    (101, '2A'),
    (102, '1A'),
    (102, '1B');


INSERT INTO Bookings (FlightID, SeatNumber, PassengerID, Fare) VALUES
    (101, '1B', 3, 7500),
    (101, '1C', 4, 9000),
    (102, '1A', 5, 6500);


UPDATE Seats
    SET SeatStatus = 'Booked'
    WHERE (FlightID = 101 AND SeatNumber IN ('1B', '1C'))
        OR (FlightID = 102 AND SeatNumber = '1A');


-- Assignment Tasks


-- Task 1


-- Booking Transaction
DECLARE
    @FlightID INT = 101,
    @SeatNumber VARCHAR(5) = '1A',
    @PassengerID INT = 1,
    @Fare DECIMAL(10, 2) = 8000,
    @SeatStatus VARCHAR(15);


BEGIN TRY

    BEGIN TRANSACTION;

    -- Checking Seat Availability
    SELECT @SeatStatus = SeatStatus
        FROM Seats WITH (UPDLOCK, HOLDLOCK)
        WHERE FlightID = @FlightID
            AND SeatNumber = @SeatNumber;


    IF @SeatStatus IS NULL
        THROW 51001, 'Seat does not exist.', 1;


    IF @SeatStatus <> 'Available'
        THROW 51002, 'Seat is already booked.', 1;


    -- Checking Passenger
    IF NOT EXISTS (
        SELECT 1
            FROM Passengers
            WHERE PassengerID = @PassengerID
    )
        THROW 51003, 'Passenger does not exist.', 1;


    -- Updating Seat Status
    UPDATE Seats
        SET SeatStatus = 'Booked'
        WHERE FlightID = @FlightID
            AND SeatNumber = @SeatNumber
            AND SeatStatus = 'Available';


    IF @@ROWCOUNT <> 1
        THROW 51004, 'Seat booking failed.', 1;


    -- Inserting Booking
    INSERT INTO Bookings (FlightID, SeatNumber, PassengerID, Fare) VALUES
        (@FlightID, @SeatNumber, @PassengerID, @Fare);


    COMMIT TRANSACTION;
    PRINT 'Seat booked successfully.';

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    PRINT ERROR_MESSAGE();
END CATCH;


-- Verifying Booking
SELECT *
    FROM Bookings;

SELECT *
    FROM Seats;



-- Task 2


-- Simulating Concurrent Bookings


-- READ COMMITTED Isolation Level


-- SESSION A

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;

SELECT SeatStatus
    FROM Seats
    WHERE FlightID = 101 AND SeatNumber = '2A';

UPDATE Seats
    SET SeatStatus = 'Booked'
    WHERE FlightID = 101
        AND SeatNumber = '2A'
        AND SeatStatus = 'Available';

INSERT INTO Bookings (FlightID, SeatNumber, PassengerID, Fare) VALUES
    (101, '2A', 1, 8500);

COMMIT TRANSACTION;


-- SESSION B

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;

UPDATE Seats
    SET SeatStatus = 'Booked'
    WHERE FlightID = 101
        AND SeatNumber = '2A'
        AND SeatStatus = 'Available';

IF @@ROWCOUNT = 1
    BEGIN
        INSERT INTO Bookings (FlightID, SeatNumber, PassengerID, Fare) VALUES
            (101, '2A', 2, 8500);

        COMMIT TRANSACTION;
        PRINT 'Booking successful.';
    END
ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Seat is already booked.';
    END;


-- SERIALIZABLE Isolation Level


-- SESSION A

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;

SELECT SeatStatus
    FROM Seats
    WHERE FlightID = 101 AND SeatNumber = '2A';

WAITFOR DELAY '00:00:10';

UPDATE Seats
    SET SeatStatus = 'Booked'
    WHERE FlightID = 101
        AND SeatNumber = '2A'
        AND SeatStatus = 'Available';

IF @@ROWCOUNT = 1
    INSERT INTO Bookings (FlightID, SeatNumber, PassengerID, Fare) VALUES
        (101, '2A', 1, 8500);

COMMIT TRANSACTION;


-- SESSION B

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;

SELECT SeatStatus
    FROM Seats
    WHERE FlightID = 101 AND SeatNumber = '2A';

COMMIT TRANSACTION;


-- Task 3


-- Ranking Passengers by Fare per Flight

SELECT F.FlightNumber, P.PassengerName, B.Fare,
RANK() OVER (PARTITION BY B.FlightID ORDER BY B.Fare DESC) AS FareRank,
DENSE_RANK() OVER (PARTITION BY B.FlightID ORDER BY B.Fare DESC) AS DenseFareRank

    FROM Bookings B
    JOIN Passengers P ON B.PassengerID = P.PassengerID
    JOIN Flights F ON B.FlightID = F.FlightID
    ORDER BY F.FlightNumber, B.Fare DESC;



-- Task 4


-- CTE with Ranking and Running Revenue

WITH PassengerRanking AS (
    SELECT B.FlightID, F.FlightNumber, P.PassengerName, B.Fare,
    RANK() OVER (PARTITION BY B.FlightID ORDER BY B.Fare DESC) AS FareRank,
    DENSE_RANK() OVER (PARTITION BY B.FlightID ORDER BY B.Fare DESC) AS DenseFareRank,
    SUM(B.Fare) OVER (PARTITION BY B.FlightID ORDER BY B.Fare DESC, B.BookingID ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningRevenue

        FROM Bookings B
        JOIN Passengers P ON B.PassengerID = P.PassengerID
        JOIN Flights F ON B.FlightID = F.FlightID
)
SELECT FlightNumber, PassengerName, Fare, FareRank, DenseFareRank, RunningRevenue
    FROM PassengerRanking
    ORDER BY FlightNumber, Fare DESC;
