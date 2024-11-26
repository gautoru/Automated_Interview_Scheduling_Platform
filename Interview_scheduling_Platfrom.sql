-- Create database
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Interview;
DROP TABLE IF EXISTS Schedule;
DROP TABLE IF EXISTS Calender;
DROP TABLE IF EXISTS Feedback;
DROP TABLE IF EXISTS Notification;
DROP TABLE IF EXISTS Report;


-- Drop the database if it exists and recreate it
DROP DATABASE IF EXISTS InterviewSchedulingPlatform;
CREATE DATABASE InterviewSchedulingPlatform;
USE InterviewSchedulingPlatform;

-- Create Tables
CREATE TABLE User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Role ENUM('recruiter', 'interviewer', 'candidate') NOT NULL,
    Password VARCHAR(255) NOT NULL,
    ContactInfo VARCHAR(255)
);

CREATE TABLE Interview (
    InterviewID INT AUTO_INCREMENT PRIMARY KEY,
    InterviewType ENUM('technical', 'HR', 'panel') NOT NULL,
    Status ENUM('scheduled', 'completed', 'canceled') NOT NULL
);

CREATE TABLE Schedule (
    ScheduleID INT AUTO_INCREMENT PRIMARY KEY,
    Date DATE NOT NULL,
    Time TIME NOT NULL,
    InterviewID INT NOT NULL,
    UserID INT NOT NULL,
    FOREIGN KEY (InterviewID) REFERENCES Interview(InterviewID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Calendar (
    CalendarID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    AvailableFrom DATETIME NOT NULL,
    AvailableTo DATETIME NOT NULL,
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Feedback (
    FeedbackID INT AUTO_INCREMENT PRIMARY KEY,
    InterviewID INT NOT NULL,
    UserID INT NOT NULL,
    Comments TEXT,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    FOREIGN KEY (InterviewID) REFERENCES Interview(InterviewID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Notification (
    NotificationID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    Message TEXT NOT NULL,
    SentTime DATETIME NOT NULL,
    Status ENUM('sent', 'delivered', 'failed') NOT NULL,
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Report (
    ReportID INT AUTO_INCREMENT PRIMARY KEY,
    GeneratedOn DATETIME NOT NULL,
    Type ENUM('scheduling_efficiency', 'feedback_summary') NOT NULL,
    Data JSON NOT NULL
);

-- Function to calculate average rating for an interview
DELIMITER //

CREATE FUNCTION avg_rating_for_interview(interview_id INT) 
RETURNS DECIMAL(3,2)
DETERMINISTIC
BEGIN
    DECLARE avgRating DECIMAL(3,2);
    SELECT AVG(Rating) INTO avgRating 
    FROM Feedback 
    WHERE InterviewID = interview_id;
    
    RETURN avgRating;
END //
DELIMITER //
-- Function to generate a scheduling efficiency report
CREATE FUNCTION scheduling_efficiency_report(month INT, year INT) 
RETURNS JSON
DETERMINISTIC
BEGIN
    DECLARE scheduled INT;
    DECLARE completed INT;
    DECLARE report JSON;

    SELECT COUNT(*) INTO scheduled
    FROM Interview
    WHERE Status = 'scheduled'
      AND MONTH(Schedule.Date) = month
      AND YEAR(Schedule.Date) = year;
      
    SELECT COUNT(*) INTO completed
    FROM Interview
    WHERE Status = 'completed'
      AND MONTH(Schedule.Date) = month
      AND YEAR(Schedule.Date) = year;
      
    SET report = JSON_OBJECT(
        'Month', month,
        'Year', year,
        'Scheduled', scheduled,
        'Completed', completed
    );
    
    RETURN report;
END //

DELIMITER //
-- Trigger to auto-update interview status when scheduled time passes
CREATE TRIGGER update_interview_status
AFTER UPDATE ON Schedule
FOR EACH ROW
BEGIN
    DECLARE currentTime DATETIME;
    SET currentTime = NOW();
    
    IF NEW.Date < CURDATE() OR (NEW.Date = CURDATE() AND NEW.Time <= CURTIME()) THEN
        UPDATE Interview
        SET Status = 'completed'
        WHERE InterviewID = NEW.InterviewID;
    END IF;
END //

DELIMITER //
-- Trigger to notify user on scheduling an interview
CREATE TRIGGER notify_user_on_schedule
AFTER INSERT ON Schedule
FOR EACH ROW
BEGIN
    DECLARE message TEXT;
    SET message = CONCAT('Your interview has been scheduled on ', NEW.Date, ' at ', NEW.Time);
    
    INSERT INTO Notification (UserID, Message, SentTime, Status)
    VALUES (NEW.UserID, message, NOW(), 'sent');
END //

DELIMITER //
-- Trigger to prevent deletion of users with scheduled interviews
CREATE TRIGGER prevent_user_deletion_with_interviews
BEFORE DELETE ON User
FOR EACH ROW
BEGIN
    DECLARE interviewCount INT;
    
    SELECT COUNT(*) INTO interviewCount
    FROM Schedule
    WHERE UserID = OLD.UserID;
    
    IF interviewCount > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete user with scheduled interviews.';
    END IF;
END //

DELIMITER //
-- Trigger to update calendar availability after scheduling interview
CREATE TRIGGER update_calendar_on_schedule
AFTER INSERT ON Schedule
FOR EACH ROW
BEGIN
    DECLARE interviewEndTime DATETIME;
    SET interviewEndTime = ADDTIME(CONCAT(NEW.Date, ' ', NEW.Time), '01:00:00');
    
    UPDATE Calendar
    SET AvailableFrom = interviewEndTime
    WHERE UserID = NEW.UserID AND AvailableFrom <= CONCAT(NEW.Date, ' ', NEW.Time) AND AvailableTo >= interviewEndTime;
END //
DELIMITER //
CREATE PROCEDURE GetUserInterviews(IN userId INT)
BEGIN
    SELECT u.Name, u.Email, i.InterviewType, s.Date, s.Time, i.Status
    FROM User u
    JOIN Schedule s ON u.UserID = s.UserID
    JOIN Interview i ON s.InterviewID = i.InterviewID
    WHERE u.UserID = userId;
END //
DELIMITER ;
CALL GetUserInterviews(1);


SHOW TABLES;
SELECT * FROM user;
SELECT * FROM interview;
SELECT * FROM Schedule;

