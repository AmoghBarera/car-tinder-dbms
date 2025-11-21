	-- =====================================================
-- Car Tinder Project - Full SQL Schema (with all entities)
-- =====================================================

CREATE DATABASE CarTinderDB;
USE CarTinderDB;

-- 1️⃣ USER PROFILE TABLE
CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    age INT,
    gender ENUM('Male', 'Female', 'Other', 'Prefer not to say'),
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2️⃣ DEALER TABLE
CREATE TABLE Dealers (
    dealer_id INT PRIMARY KEY AUTO_INCREMENT,
    dealer_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    city VARCHAR(100),
    rating DECIMAL(2,1) DEFAULT 4.0
);

-- 3️⃣ CAR PROFILE TABLE
CREATE TABLE Cars (
    car_id INT PRIMARY KEY AUTO_INCREMENT,
    dealer_id INT,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    fuel_type ENUM('Petrol', 'Diesel', 'Electric', 'CNG', 'Hybrid') NOT NULL,
    transmission ENUM('Manual', 'Automatic') NOT NULL,
    seating_capacity INT,
    image_url VARCHAR(255),
    FOREIGN KEY (dealer_id) REFERENCES Dealers(dealer_id) ON DELETE SET NULL
);

-- 4️⃣ LIKED CARS (User-Car Relationship)
CREATE TABLE LikedCars (
    like_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    car_id INT,
    liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES Cars(car_id) ON DELETE CASCADE,
    UNIQUE(user_id, car_id)
);

-- 5️⃣ REVIEW TABLE
CREATE TABLE Reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    car_id INT,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES Cars(car_id) ON DELETE CASCADE
);

-- 6️⃣ TEST DRIVE TABLE
CREATE TABLE TestDrives (
    testdrive_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    car_id INT,
    scheduled_date DATE NOT NULL,
    status ENUM('Pending', 'Completed', 'Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES Cars(car_id) ON DELETE CASCADE
);

-- 7️⃣ PRICE HISTORY TABLE
CREATE TABLE PriceHistory (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    car_id INT,
    old_price DECIMAL(10, 2),
    new_price DECIMAL(10, 2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (car_id) REFERENCES Cars(car_id) ON DELETE CASCADE
);

-- =====================================================
-- 🔧 TRIGGERS
-- =====================================================

-- Trigger: Record price change in PriceHistory
DELIMITER //
CREATE TRIGGER after_car_price_update
AFTER UPDATE ON Cars
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO PriceHistory (car_id, old_price, new_price)
        VALUES (OLD.car_id, OLD.price, NEW.price);
    END IF;
END;
//
DELIMITER ;

-- Auto-delete Related Data When User is Deleted
DELIMITER //
CREATE TRIGGER after_user_delete
AFTER DELETE ON Users
FOR EACH ROW
BEGIN
    DELETE FROM Reviews WHERE user_id = OLD.user_id;
    DELETE FROM LikedCars WHERE user_id = OLD.user_id;
    DELETE FROM TestDrives WHERE user_id = OLD.user_id;
END;
//
DELIMITER ;

-- Log Dealer’s New Car Addition
CREATE TABLE DealerActivityLog (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    dealer_id INT,
    car_id INT,
    action VARCHAR(50),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
DELIMITER //
CREATE TRIGGER after_car_insert
AFTER INSERT ON Cars
FOR EACH ROW
BEGIN
    INSERT INTO DealerActivityLog (dealer_id, car_id, action)
    VALUES (NEW.dealer_id, NEW.car_id, 'New Car Added');
END;
//
DELIMITER ;

-- Prevent Duplicate Test Drive Bookings
DELIMITER //
CREATE TRIGGER before_testdrive_insert
BEFORE INSERT ON TestDrives
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM TestDrives
        WHERE user_id = NEW.user_id AND car_id = NEW.car_id AND scheduled_date = NEW.scheduled_date
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Duplicate test drive booking detected.';
    END IF;
END;
//
DELIMITER ;




-- =====================================================
-- 🧠 FUNCTIONS
-- =====================================================

-- Function: Get average rating for a car
DELIMITER //
CREATE FUNCTION get_avg_rating(carId INT)
RETURNS DECIMAL(3,2)
DETERMINISTIC
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    SELECT AVG(rating) INTO avg_rating FROM Reviews WHERE car_id = carId;
    RETURN IFNULL(avg_rating, 0.0);
END;
//
DELIMITER ;


-- Get User Test Drive Count
DELIMITER //
CREATE FUNCTION get_testdrive_count(userId INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total_drives INT;
    SELECT COUNT(*) INTO total_drives FROM TestDrives WHERE user_id = userId;
    RETURN total_drives;
END;
//
DELIMITER ;

-- Total Likes for the car
DELIMITER //
CREATE FUNCTION get_total_likes(carId INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE like_count INT;
    SELECT COUNT(*) INTO like_count FROM LikedCars WHERE car_id = carId;
    RETURN like_count;
END;
//
DELIMITER ;



-- =====================================================
-- ⚙️ STORED PROCEDURES
-- =====================================================

-- Procedure 1: Add a new test drive booking
DELIMITER //
CREATE PROCEDURE book_test_drive(IN userId INT, IN carId INT, IN driveDate DATE)
BEGIN
    INSERT INTO TestDrives (user_id, car_id, scheduled_date)
    VALUES (userId, carId, driveDate);
END;
//
DELIMITER ;

-- Procedure 2: Get all liked cars for a user
DELIMITER //
CREATE PROCEDURE get_liked_cars(IN userId INT)
BEGIN
    SELECT c.car_id, c.brand, c.model, c.price, c.image_url
    FROM Cars c
    JOIN LikedCars l ON c.car_id = l.car_id
    WHERE l.user_id = userId;
END;
//
DELIMITER ;

-- Procedure 3: Get cars available from a specific dealer
DELIMITER //
CREATE PROCEDURE get_cars_by_dealer(IN dealerName VARCHAR(100))
BEGIN
    SELECT c.car_id, c.brand, c.model, c.price, d.dealer_name
    FROM Cars c
    JOIN Dealers d ON c.dealer_id = d.dealer_id
    WHERE d.dealer_name = dealerName;
END;
//
DELIMITER ;

-- =====================================================
-- 🌱 SAMPLE DATA
-- =====================================================

INSERT INTO Dealers (dealer_name, phone, email, city, rating)
VALUES 
('AutoWorld Mumbai', '9876543210', 'autoworld@mumbai.com', 'Mumbai', 4.5),
('SpeedMotors Delhi', '9988776655', 'speedmotors@delhi.com', 'Delhi', 4.2);

INSERT INTO Users (first_name, last_name, email, password_hash, age, gender, city)
VALUES
('Arjun', 'Mehta', 'arjun.mehta@example.com', 'hashed_password_1', 28, 'Male', 'Mumbai'),
('Priya', 'Sharma', 'priya.sharma@example.com', 'hashed_password_2', 25, 'Female', 'Delhi');

INSERT INTO Cars (dealer_id, brand, model, year, price, fuel_type, transmission, seating_capacity, image_url)
VALUES
(1, 'Maruti Suzuki', 'Swift', 2023, 850000.00, 'Petrol', 'Manual', 5, 'https://placehold.co/600x400/333/FFF?text=Maruti+Swift'),
(1, 'Tata', 'Nexon EV', 2023, 1700000.00, 'Electric', 'Automatic', 5, 'https://placehold.co/600x400/777/FFF?text=Tata+Nexon+EV'),
(2, 'Hyundai', 'Creta', 2022, 1400000.00, 'Diesel', 'Automatic', 5, 'https://placehold.co/600x400/555/FFF?text=Hyundai+Creta');

INSERT INTO Reviews (user_id, car_id, rating, comment)
VALUES
(1, 1, 5, 'Excellent car! Smooth drive.'),
(2, 2, 4, 'Very good EV, good range.');

CALL book_test_drive(1, 1, '2025-11-10');
CALL get_liked_cars(1);
show tables;
select * from cars;


-- Functions
SELECT car_id, brand, model, get_avg_rating(car_id) AS avg_rating FROM Cars;
SELECT get_total_likes(1) AS LikesForCar1;
SELECT get_testdrive_count(1) AS TestDrivesForUser1;

-- Procedures
CALL book_test_drive(1, 2, '2025-12-02');
CALL get_liked_cars(1);
CALL get_cars_by_dealer('SpeedMotors Delhi');

-- Triggers
UPDATE Cars SET price = 1900000 WHERE car_id = 2;  -- check PriceHistory
SELECT * FROM PriceHistory;

-- Trigger violation
CALL book_test_drive(1, 2, '2025-12-01'); -- should throw duplicate error

-- Dealer activity log
INSERT INTO Cars (dealer_id, brand, model, year, price, fuel_type, transmission, seating_capacity, image_url)
VALUES (2, 'Kia', 'Seltos', 2023, 1550000.00, 'Petrol', 'Automatic', 5, 'https://placehold.co/600x400/AAA/FFF?text=Kia+Seltos');
SELECT * FROM DealerActivityLog;

select * from TestDrives;
