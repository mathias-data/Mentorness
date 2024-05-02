---1. Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0.

SELECT LD.P_ID, LD.Dev_ID, PD.PName, LD.Difficulty, LD.level 
FROM level_details AS LD
INNER JOIN player_details AS PD
ON LD.P_ID = PD.P_ID
WHERE LD.level = 0

---2. Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and at least 3 stages are crossed
SELECT PD.L1_code, AVG(LD.kill_count) AS Avg_Kill_Count
FROM Level_Details AS LD
INNER JOIN Player_Details PD ON LD.P_ID = PD.P_ID
WHERE LD.lives_earned = 2 
AND LD.stages_crossed >= 3
GROUP BY PD.L1_code;

---3. Find the total number of stages crossed at each difficulty level for Level 2 with players using `zm_series` devices. Arrange the result in decreasing order of the total number of stages crossed.
SELECT LD.difficulty AS Difficulty_level, 
SUM(LD.stages_crossed) AS Total_Stages_Crossed
FROM Level_Details AS LD
INNER JOIN Player_Details PD ON LD.P_ID = PD.P_ID
WHERE LD.level = 2
AND PD.P_ID IN (SELECT P_ID FROM Level_Details WHERE Dev_ID LIKE 'zm%')
GROUP BY LD.difficulty
ORDER BY Total_Stages_Crossed DESC;


---4. Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days

SELECT LD.P_ID, COUNT(DISTINCT CONVERT(DATE, LD.timestamp)) AS Unique_Date_Count
FROM Level_Details LD
GROUP BY LD.P_ID
HAVING COUNT(DISTINCT CONVERT(DATE, LD.timestamp)) > 1;


---5. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty

WITH MediumAvgKill AS (
    SELECT AVG(LD.kill_count) AS AvgKill
    FROM Level_Details LD
    WHERE LD.difficulty = 'Medium'
)
SELECT LD.P_ID, LD.level, SUM(LD.kill_count) AS Sum_Kill_Count
FROM Level_Details LD
JOIN MediumAvgKill MAK ON LD.kill_count > MAK.AvgKill
GROUP BY LD.P_ID, LD.level;


---6. Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level 0. Arrange in ascending order of level.

SELECT LD.level, PD.L1_code AS Level_code, SUM(LD.lives_Earned) AS Total_Lives_Earned
FROM Level_Details AS LD
INNER JOIN Player_Details AS PD ON LD.P_ID = PD.P_ID
WHERE LD.level > 0
GROUP BY LD.level, PD.L1_code
ORDER BY LD.level ASC;


---7. Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using Row_Number`. Display the difficulty as well.

WITH TopScores AS (
    SELECT LD.Dev_ID, LD.score, LD.difficulty,
           ROW_NUMBER() OVER (PARTITION BY LD.Dev_ID ORDER BY LD.score DESC) AS RowNum
    FROM Level_Details LD
)
SELECT Dev_ID, score, difficulty
FROM TopScores
WHERE RowNum <= 3
ORDER BY Dev_ID, RowNum;


---8. Find the `first_login` datetime for each device ID.

SELECT DISTINCT Dev_ID, MIN(TimeStamp) AS first_login
FROM Level_Details
GROUP BY Dev_ID;


---9. Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well.

WITH TopScores AS (
    SELECT Dev_ID, score, difficulty,
           RANK() OVER (PARTITION BY difficulty ORDER BY score DESC) AS Rank
    FROM Level_Details
)
SELECT Dev_ID, score, difficulty, Rank
FROM TopScores
WHERE Rank <= 5
ORDER BY difficulty, Rank;


---10. Find the device ID that is first logged in (based on `start_datetime`) for each player (`P_ID`). Output should contain player ID, device ID, and first login datetime.

WITH FirstLogin AS (
    SELECT P_ID, Dev_ID, TimeStamp,
           ROW_NUMBER() OVER (PARTITION BY P_ID ORDER BY TimeStamp) AS RowNum
    FROM Level_Details
)
SELECT P_ID, Dev_ID, TimeStamp AS first_login_datetime
FROM FirstLogin
WHERE RowNum = 1;

---11. For each player and date, determine how many `kill_counts` were played by the player so far
---Using Window Functions
SELECT P_ID, CONVERT(DATE, TimeStamp) AS start_date, 
       SUM(kill_count) OVER (PARTITION BY P_ID, CONVERT(DATE, TimeStamp) ORDER BY TimeStamp) AS cumulative_kill_counts
FROM Level_Details;

---Without Window Functions
SELECT LD.P_ID, CONVERT(DATE, LD.TimeStamp) AS start_date,
       SUM(LD2.kill_count) AS cumulative_kill_counts
FROM Level_Details AS LD
INNER JOIN Level_Details AS LD2 ON LD.P_ID = LD2.P_ID AND LD.TimeStamp >= LD2.TimeStamp
GROUP BY LD.P_ID, CONVERT(DATE, LD.TimeStamp);


---12. Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, excluding the most recent `start_datetime

WITH ExcludingRecent AS (
    SELECT P_ID, TIMESTAMP, stages_crossed,
           ROW_NUMBER() OVER (PARTITION BY P_ID ORDER BY TIMESTAMP DESC) AS RowNum
    FROM Level_Details
)
SELECT P_ID, TIMESTAMP, stages_crossed,
       SUM(stages_crossed) OVER (PARTITION BY P_ID ORDER BY TIMESTAMP) - stages_crossed AS cumulative_stages_crossed
FROM ExcludingRecent
WHERE RowNum > 1;


---13. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`

WITH TopScores AS (
    SELECT Dev_ID, P_ID, SUM(score) AS total_score,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY SUM(score) DESC) AS Rank
    FROM Level_Details
    GROUP BY Dev_ID, P_ID
)
SELECT Dev_ID, P_ID, total_score
FROM TopScores
WHERE Rank <= 3;


---14. Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`

WITH PlayerAverage AS (
    SELECT P_ID, AVG(score) AS avg_score
    FROM Level_Details
    GROUP BY P_ID
)
SELECT LD.P_ID, LD.score, PA.avg_score
FROM Level_Details LD
JOIN PlayerAverage PA ON LD.P_ID = PA.P_ID
WHERE LD.score > 0.5 * PA.avg_score;


15. --Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well

CREATE PROCEDURE FindTopNHeadshotsCounts
    @n INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH TopHeadshots AS (
        SELECT Dev_ID, difficulty, headshots_count,
               ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count DESC) AS Rank
        FROM Level_Details
    )
    SELECT Dev_ID, difficulty, headshots_count, Rank
    FROM TopHeadshots
    WHERE Rank <= @n
    ORDER BY Dev_ID, Rank;
END;
