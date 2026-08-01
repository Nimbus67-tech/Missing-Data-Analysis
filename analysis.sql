/* ============================================================
   Missing Data Analysis — SQL version
   Reproduces the Excel COUNTIFS-based coverage check using
   standard SQL (GROUP BY + LEFT JOIN / anti-join).

   Tables (loaded from the CSVs in this repo):
     ideal_data     <- Hackathon_Ideal_Data.csv
     working_data   <- Hackathon_Working_Data.csv

   Goal: for each STORECODE x MONTH, count how many of the 80
   expected GRP categories (from ideal_data) have zero recorded
   sales rows in working_data.
   ============================================================ */

-- 1. Reference set: the 80 categories every store is expected to report
DROP TABLE IF EXISTS expected_categories;
CREATE TEMP TABLE expected_categories AS
SELECT DISTINCT grp
FROM ideal_data;

-- 2. Every store x month x expected-category combination we SHOULD see
DROP TABLE IF EXISTS expected_combinations;
CREATE TEMP TABLE expected_combinations AS
SELECT DISTINCT
    w.storecode,
    w.month,
    e.grp
FROM (SELECT DISTINCT storecode, month FROM working_data) w
CROSS JOIN expected_categories e;

-- 3. What actually showed up in the raw transaction data
DROP TABLE IF EXISTS present_combinations;
CREATE TEMP TABLE present_combinations AS
SELECT DISTINCT storecode, month, grp
FROM working_data;

-- 4. Anti-join: expected combinations with no matching recorded sale = missing
DROP TABLE IF EXISTS missing_combinations;
CREATE TEMP TABLE missing_combinations AS
SELECT ec.storecode, ec.month, ec.grp
FROM expected_combinations ec
LEFT JOIN present_combinations pc
    ON ec.storecode = pc.storecode
   AND ec.month     = pc.month
   AND ec.grp       = pc.grp
WHERE pc.grp IS NULL;

-- 5a. Store-level summary (mirrors the Store_Summary sheet in the workbook)
SELECT
    ec.storecode,
    COUNT(*)                                   AS expected,
    COUNT(*) - COALESCE(mc.missing_count, 0)   AS present,
    COALESCE(mc.missing_count, 0)              AS missing,
    ROUND(100.0 * COALESCE(mc.missing_count, 0) / COUNT(*), 1) AS missing_pct
FROM expected_combinations ec
LEFT JOIN (
    SELECT storecode, COUNT(*) AS missing_count
    FROM missing_combinations
    GROUP BY storecode
) mc ON ec.storecode = mc.storecode
GROUP BY ec.storecode, mc.missing_count
ORDER BY missing_pct DESC;

-- 5b. Month-level summary (mirrors the Month_Summary sheet)
SELECT
    ec.month,
    COUNT(*)                                   AS expected,
    COUNT(*) - COALESCE(mc.missing_count, 0)   AS present,
    COALESCE(mc.missing_count, 0)              AS missing,
    ROUND(100.0 * COALESCE(mc.missing_count, 0) / COUNT(*), 1) AS missing_pct
FROM expected_combinations ec
LEFT JOIN (
    SELECT month, COUNT(*) AS missing_count
    FROM missing_combinations
    GROUP BY month
) mc ON ec.month = mc.month
GROUP BY ec.month, mc.missing_count
ORDER BY ec.month;

-- 5c. Overall missing rate (single headline number, matches README)
SELECT
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM expected_combinations), 1) AS overall_missing_pct
FROM missing_combinations;
