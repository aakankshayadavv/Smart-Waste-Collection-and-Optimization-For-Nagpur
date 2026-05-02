/* CREATING TABLES FOR NAGPUR_SMARTWASTE_DB*/


-- 1. Bins
CREATE TABLE Bins (
BinID VARCHAR(10) PRIMARY KEY,
Ward VARCHAR(50),
AreaType VARCHAR(30),
PopulationDensity VARCHAR(10),
WasteType VARCHAR(20),
Capacity_Ltrs INT,
Latitude FLOAT,
Longitude FLOAT);

-- 2. Trucks
CREATE TABLE Trucks (
TruckID VARCHAR(10) PRIMARY KEY,
Model VARCHAR(50),
FuelType VARCHAR(20),
Specialization VARCHAR(20),
FuelPerKm FLOAT);

-- 3. Routes
CREATE TABLE Routes (
RouteID VARCHAR(10),
BinID VARCHAR(10) PRIMARY KEY,
TruckID VARCHAR(10),
Sequence INT,
Distance_KM FLOAT,
CONSTRAINT fk_bin FOREIGN KEY (BinID) REFERENCES Bins(BinID),
CONSTRAINT fk_truck FOREIGN KEY (TruckID) REFERENCES Trucks(TruckID)
);

-- 4. WasteReadings (Changed DATETIME to TIMESTAMP)
CREATE TABLE WasteReadings (
ReadingID VARCHAR(15) PRIMARY KEY,
BinID VARCHAR(10),
FillLevel_Percent INT,
Timestamp TIMESTAMP, 
CONSTRAINT fk_bin_read FOREIGN KEY (BinID) REFERENCES Bins(BinID));

-- 5. HistoricalCollections
CREATE TABLE HistoricalCollections (
CollectionID VARCHAR(15) PRIMARY KEY,
BinID VARCHAR(10),
CollectionDate DATE,
WasteCollected_KG INT,
CONSTRAINT fk_bin_hist FOREIGN KEY (BinID) REFERENCES Bins(BinID));

------------------------------------------------------------------------------------------------
------------------------------ IMPORTED DATA TO THE TABLES -------------------------------------


----------- Data Querying --------------------
 
SELECT COUNT(*) FROM Bins;
SELECT COUNT(*) FROM Trucks;
SELECT COUNT(*) FROM WasteReadings;
SELECT COUNT(*) FROM HistoricalCollections;






---------------------- query oriented solutions --------------------------------------------

----------------------  The "Live" Emergency List ------------------------------------------

/*  Find all bins in Nagpur that are currently over 90% full */

SELECT b.BinID, b.Ward, b.AreaType, w.FillLevel_Percent, w.Timestamp
FROM Bins b
INNER JOIN WasteReadings w ON b.BinID = w.BinID
WHERE w.FillLevel_Percent >= 90
AND w.Timestamp::date = '2026-04-28' -- This is today's date because we're checking for todays levels
ORDER BY w.FillLevel_Percent DESC;

----------------------------------------------------------------------------------------------------
--------------------------- The "Smart Priority" Engine --------------------------------------------

/* A priority list that'll give extra priority to Markets and Hospitals */

SELECT b.BinID, b.Ward, b.AreaType,w.FillLevel_Percent,
/*Formula I used here: Hospital (1.5x) > Market (1.3x) > Residential (1.0x) because 
it's important to keep the hospitals clean so as soon as it hit's the threshold it gives an alert */
ROUND(w.FillLevel_Percent * (CASE 
        WHEN b.AreaType = 'Hospital' THEN 1.5 
        WHEN b.AreaType = 'Market' THEN 1.3 
        ELSE 1.0 END), 2) AS Priority_Score
FROM Bins b
INNER JOIN WasteReadings w ON b.BinID = w.BinID
WHERE w.Timestamp::date = '2026-04-28'
ORDER BY Priority_Score DESC
LIMIT 10;

----------------------------------------------------------------------------------------------------
------------------------------ Automated Dispatch Mapping -----------------------------------------

/*  This query connects three critical entities: the WasteReadings (detecting a full bin), 
the Routes (determining the travel sequence), and the Trucks (identifying the specific vehicle). 
By filtering for bins above 85% capacity, it generates a precise "Morning Manifest" that ensures 
drivers know exactly which bins to target in the most fuel-efficient order  */

SELECT r.RouteID,r.TruckID,t.Model as Truck_Model,b.BinID,b.Ward,w.FillLevel_Percent,r.Sequence
FROM Routes r
INNER JOIN Trucks t ON 
r.TruckID = t.TruckID
INNER JOIN Bins b ON 
r.BinID = b.BinID
INNER JOIN WasteReadings w ON 
b.BinID = w.BinID
WHERE w.FillLevel_Percent >= 85 AND w.Timestamp::date = '2026-04-28'
ORDER BY r.RouteID, r.Sequence;

----------------------------------------------------------------------------------------------------
------------------------------ Efficiency Metric (Waste per Ward) ----------------------------------

/*  I used the HistoricalCollections table to see which part of Nagpur produces the most waste. 
This will help in long-term planning */

SELECT b.Ward, COUNT(h.CollectionID) as Total_Collections,
SUM(h.WasteCollected_KG) as Total_KG,
ROUND(AVG(h.WasteCollected_KG), 2) as Avg_KG_Per_Trip
FROM Bins b
INNER JOIN HistoricalCollections h ON
b.BinID = h.BinID
GROUP BY b.Ward
ORDER BY Total_KG DESC;

---------------------------------------------------------------------------------------------------
------------------------------ Fleet Fuel Efficiency & Cost Analysis ------------------------------

/* This will calculate how much money each truck is spending based on its fuel efficiency and 
the distance it travels. It will help identify which trucks are the most expensive to run */

SELECT t.TruckID, t.Model, t.FuelType,
ROUND(SUM(r.Distance_KM)::numeric, 2) as Total_Distance,
ROUND(SUM(r.Distance_KM * t.FuelPerKm)::numeric, 2) as Estimated_Fuel_Consumed_Ltrs
FROM Trucks t
INNER JOIN Routes r ON
t.TruckID = r.TruckID
GROUP BY t.TruckID, t.Model, t.FuelType
ORDER BY Estimated_Fuel_Consumed_Ltrs DESC;

----------------------------------------------------------------------------------------------------
----------------------------- Ward-Wise Hygiene Risk Assessment ------------------------------------

/* This query ill help find wards that have the highest number of bins sitting at over 70% capacity. 
This helps the Municipal Corporation decide if a specific ward (like Lakadganj) needs more 
trucks assigned to it */

SELECT b.Ward, COUNT(w.ReadingID) as High_Fill_Readings,
ROUND(AVG(w.FillLevel_Percent), 2) as Avg_Fill_Level
FROM Bins b
INNER JOIN WasteReadings w ON b.BinID = w.BinID
WHERE w.FillLevel_Percent > 70
GROUP BY b.Ward
ORDER BY High_Fill_Readings DESC;

---------------------------------------------------------------------------------------------------
----------------------------The "Ghost Bin" Finder (Underutilized Assets)--------------------------

/* This query will identify the bins that rarely get full (average fill below 20%). In a real city, 
we can move these bins to busier areas to save money */

SELECT b.BinID, b.Ward, b.AreaType, 
ROUND(AVG(w.FillLevel_Percent), 2) as Avg_Usage
FROM Bins b
INNER JOIN WasteReadings w ON b.BinID = w.BinID
GROUP BY b.BinID, b.Ward, b.AreaType
HAVING AVG(w.FillLevel_Percent) < 30
ORDER BY Avg_Usage ASC;

---------------------------------------------------------------------------------------------------
-------------------------------- Daily Collection Performance (SLA Tracker)------------------------
/* This query will help us compare how much waste was expected to be collected vs. what is actually 
in the history. It calculates the "Collection Success Rate" for each day */

SELECT h.CollectionDate, COUNT(h.CollectionID) as Total_Collections,
SUM(h.WasteCollected_KG) as Total_Waste_KG,
ROUND(AVG(h.WasteCollected_KG), 2) as Efficiency_Per_Bin
FROM HistoricalCollections h
GROUP BY h.CollectionDate
ORDER BY h.CollectionDate DESC;

----------------------------------------------------------------------------------------------------

-------------------------------------------- CREATING VIEWS ----------------------------------------
/* Live dashboard view */

CREATE VIEW View_Live_Status AS
SELECT b.BinID, b.Ward, b.AreaType, b.Latitude, b.Longitude,w.FillLevel_Percent,
    CASE 
        WHEN w.FillLevel_Percent >= 90 THEN 'Critical'
        WHEN w.FillLevel_Percent >= 70 THEN 'Warning'
        ELSE 'Normal'
    END as Status_Category
FROM Bins b
INNER JOIN WasteReadings w ON 
b.BinID = w.BinID
WHERE w.Timestamp::date = (SELECT MAX(Timestamp::date) FROM WasteReadings);

--------------------------------------------------------------------------------------------------
  /* Fleet efficienct view*/

CREATE VIEW View_Fleet_Efficiency AS
SELECT t.TruckID, t.Model, t.FuelType,
COUNT(r.BinID) as Total_Bins_Assigned,
ROUND(SUM(r.Distance_KM)::numeric, 2) as Total_KM,
ROUND(SUM(r.Distance_KM * t.FuelPerKm)::numeric, 2) as Est_Fuel_Ltrs
FROM Trucks t
INNER JOIN Routes r ON 
t.TruckID = r.TruckID
GROUP BY t.TruckID, t.Model, t.FuelType;

-------------------------------------------------------------------------------------------------
/* Final check */

SELECT 
    'Bins' as Table_Name, COUNT(*) FROM Bins
UNION ALL
SELECT 'Trucks', COUNT(*) FROM Trucks
UNION ALL
SELECT 'Routes', COUNT(*) FROM Routes
UNION ALL
SELECT 'WasteReadings', COUNT(*) FROM WasteReadings
UNION ALL
SELECT 'HistoricalCollections', COUNT(*) FROM HistoricalCollections;

-------------------------------------------------------------------------------------------------
















