/*
=================================================================
  CALL CENTER DATABASE  —  Analysis & Reporting
  Author     : Mahmoud Metawea

  Query-based analysis and operational reporting built on top
  of the call center database (01_database_build.sql).
  Covers descriptive KPI analysis, target variance reporting,
  and a parameterised stored procedure for monthly reporting.

  Prerequisite : 01_database_build.sql must be executed first.
-----------------------------------------------------------------
  SECTIONS
  1  Analysis queries (Q1–Q8)
  2  Target vs actual variance
  3  Stored procedure — parameterised monthly report
=================================================================
*/

USE CallCenterDB;
GO

-- =================================================================
-- SECTION 1: ANALYSIS QUERIES  (Q1–Q8)
-- =================================================================

-- -----------------------------------------------------------------
-- Q1.  Monthly call volume, SLA % and AHT
-- -----------------------------------------------------------------
SELECT
    d.[year]                                                              AS [Year],
    d.month_name                                                          AS [Month Name],
    COUNT(f.call_id)                                                      AS [Offered Calls],
    SUM(CASE WHEN f.disposition != 'Abandoned' THEN 1 ELSE 0 END)        AS [Answered Calls],
    SUM(CASE WHEN f.disposition  = 'Abandoned' THEN 1 ELSE 0 END)        AS [Abandoned Calls],
    -- SLA: COPC standard — answered within 20 sec vs total offered calls (incl. abandoned)
    CAST(ROUND(
        100.0 * SUM(CASE WHEN f.sla_met = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(f.call_id), 0), 1) AS DECIMAL(5,1))               AS [SLA %],
    -- AHT: abandoned excluded (0 handle time); voicemail included — ACW is real agent time
    CAST(ROUND(
        AVG(CASE WHEN f.disposition != 'Abandoned'
                 THEN CAST(f.handle_time_sec AS FLOAT) END) / 60, 1)
        AS DECIMAL(5,1))                                                  AS [Avg AHT (min)],
    CAST(ROUND(AVG(CAST(f.wait_time_sec AS FLOAT)), 0) AS INT)           AS [Avg Wait (sec)]
FROM dbo.fact_calls f
JOIN dbo.dim_date d ON f.call_date = d.date_key
GROUP BY d.[year], d.[month], d.month_name
ORDER BY d.[year], d.[month];
GO

-- -----------------------------------------------------------------
-- Q2.  Agent performance scorecard with RANK
-- -----------------------------------------------------------------
SELECT
    a.agent_name                                                          AS [Agent],
    COUNT(f.call_id)                                                      AS [Calls],

    -- CSAT and NPS: AVG ignores NULLs — calls without a score are excluded automatically
    -- FCR: denominator counts only calls where FCR was recorded (IS NOT NULL)
    -- AHT: voicemail included — talk/hold = 0 but ACW is real agent work time
    CAST(ROUND(AVG(CAST(f.csat_score AS FLOAT)), 2)
        AS DECIMAL(4,2))                                                  AS [Avg CSAT],
    CAST(ROUND(AVG(CAST(f.nps_score  AS FLOAT)), 1)
        AS DECIMAL(4,1))                                                  AS [Avg NPS],

    CAST(ROUND(AVG(CAST(f.handle_time_sec AS FLOAT)) / 60, 1)
        AS DECIMAL(5,1))                                                  AS [Avg AHT (min)],

    CAST(ROUND(
        100.0 * SUM(CASE WHEN f.first_call_resolution = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN f.first_call_resolution IS NOT NULL
                          THEN 1 ELSE 0 END), 0), 1) AS DECIMAL(5,1))    AS [FCR %],

    RANK() OVER (ORDER BY AVG(CAST(f.csat_score AS FLOAT)) DESC)         AS [CSAT Rank]
FROM dbo.fact_calls f
JOIN dbo.dim_agent a ON f.agent_id = a.agent_id
WHERE f.disposition != 'Abandoned'
GROUP BY a.agent_id, a.agent_name
ORDER BY [CSAT Rank];
GO

-- -----------------------------------------------------------------
-- Q3.  Abandon rate by hour of day
-- -----------------------------------------------------------------
SELECT
    hour_of_day                                                           AS [Hour],
    COUNT(*)                                                              AS [Total Calls],
    SUM(CASE WHEN disposition = 'Abandoned' THEN 1 ELSE 0 END)           AS [Abandoned],
    CAST(ROUND(
        100.0 * SUM(CASE WHEN disposition = 'Abandoned' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 1) AS DECIMAL(5,1))                       AS [Abandon Rate %]
FROM dbo.fact_calls
GROUP BY hour_of_day
ORDER BY hour_of_day;
GO

-- -----------------------------------------------------------------
-- Q4.  NPS segmentation — Detractors / Passives / Promoters
-- -----------------------------------------------------------------
WITH cte_nps AS (
    SELECT
        CASE
            WHEN nps_score BETWEEN 0  AND 6  THEN 'Detractor'
            WHEN nps_score BETWEEN 7  AND 8  THEN 'Passive'
            WHEN nps_score BETWEEN 9  AND 10 THEN 'Promoter'
        END AS nps_segment,
        COUNT(*) AS respondents
    FROM dbo.fact_calls
    WHERE nps_score IS NOT NULL
    GROUP BY
        CASE
            WHEN nps_score BETWEEN 0  AND 6  THEN 'Detractor'
            WHEN nps_score BETWEEN 7  AND 8  THEN 'Passive'
            WHEN nps_score BETWEEN 9  AND 10 THEN 'Promoter'
        END
)
SELECT
    nps_segment                                                           AS [Segment],
    respondents                                                           AS [Count],
    CAST(ROUND(100.0 * respondents / SUM(respondents) OVER (), 1)
        AS DECIMAL(5,1))                                                  AS [Share %],
    CAST(ROUND(
        (SUM(CASE WHEN nps_segment = 'Promoter'  THEN respondents ELSE 0 END) OVER()
       - SUM(CASE WHEN nps_segment = 'Detractor' THEN respondents ELSE 0 END) OVER()) * 100.0
       / NULLIF(SUM(respondents) OVER(), 0), 1) AS DECIMAL(5,1))         AS [Net NPS]
FROM cte_nps
ORDER BY CASE nps_segment WHEN 'Detractor' THEN 1 WHEN 'Passive' THEN 2 ELSE 3 END;
GO

-- -----------------------------------------------------------------
-- Q5.  Queue performance comparison
-- -----------------------------------------------------------------
SELECT
    q.queue_name                                                          AS [Queue],
    COUNT(f.call_id)                                                      AS [Total Calls],
    SUM(CASE WHEN f.disposition = 'Abandoned' THEN 1 ELSE 0 END)         AS [Abandoned],
    CAST(ROUND(AVG(CAST(f.wait_time_sec   AS FLOAT)), 0) AS INT)         AS [Avg Wait (sec)],
    -- AHT: abandoned excluded (0 handle time); voicemail included — ACW is real agent time
    CAST(ROUND(AVG(CASE WHEN f.disposition != 'Abandoned'
                        THEN CAST(f.handle_time_sec AS FLOAT) END) / 60, 1)
        AS DECIMAL(5,1))                                                  AS [Avg AHT (min)],
    CAST(ROUND(AVG(CAST(f.csat_score AS FLOAT)), 2) AS DECIMAL(4,2))    AS [Avg CSAT],
    CAST(ROUND(
        100.0 * SUM(CASE WHEN f.first_call_resolution = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN f.first_call_resolution IS NOT NULL
                          THEN 1 ELSE 0 END), 0), 1) AS DECIMAL(5,1))    AS [FCR %]
FROM dbo.fact_calls f
JOIN dbo.dim_queue q ON f.queue_id = q.queue_id
GROUP BY q.queue_name
ORDER BY [Total Calls] DESC;
GO

-- -----------------------------------------------------------------
-- Q6.  Month-over-month volume change  (LAG window function)
-- -----------------------------------------------------------------
WITH cte_monthly AS (
    SELECT d.[year], d.[month], d.month_name,
           COUNT(f.call_id)                                               AS total_calls,
           SUM(CASE WHEN f.disposition != 'Abandoned' THEN 1 ELSE 0 END) AS answered_calls,
           SUM(CASE WHEN f.disposition  = 'Abandoned' THEN 1 ELSE 0 END) AS abandoned_calls
    FROM dbo.fact_calls f
    JOIN dbo.dim_date d ON f.call_date = d.date_key
    GROUP BY d.[year], d.[month], d.month_name
)
SELECT
    [year]                                                                AS [Year],
    month_name                                                            AS [Month Name],
    total_calls                                                           AS [Offered Calls],
    answered_calls                                                        AS [Answered Calls],
    abandoned_calls                                                       AS [Abandoned Calls],
    LAG(total_calls) OVER (ORDER BY [year],[month])                       AS [Prev Month],
    total_calls - LAG(total_calls) OVER (ORDER BY [year],[month])         AS [MoM Change],
    CAST(ROUND(
        100.0*(total_calls - LAG(total_calls) OVER (ORDER BY [year],[month]))
        / NULLIF(LAG(total_calls) OVER (ORDER BY [year],[month]),0),1)
    AS DECIMAL(5,1))                                                      AS [MoM %]
FROM cte_monthly
ORDER BY [year],[month];
GO

-- -----------------------------------------------------------------
-- Q7.  Top 3 agents per queue by CSAT  (RANK with PARTITION)
-- -----------------------------------------------------------------
WITH cte_ranked AS (
    SELECT
        q.queue_name, a.agent_name,
        COUNT(f.call_id)                                                  AS calls_handled,
        CAST(ROUND(AVG(CAST(f.csat_score AS FLOAT)),2) AS DECIMAL(4,2)) AS avg_csat,
        RANK() OVER (
            PARTITION BY q.queue_name
            ORDER BY AVG(CAST(f.csat_score AS FLOAT)) DESC
        )                                                                 AS rnk
    FROM dbo.fact_calls f
    JOIN dbo.dim_agent a ON f.agent_id = a.agent_id
    JOIN dbo.dim_queue q ON f.queue_id = q.queue_id
    WHERE f.csat_score IS NOT NULL
    GROUP BY q.queue_name, a.agent_name
)
SELECT queue_name AS [Queue], agent_name AS [Agent],
       calls_handled AS [Calls], avg_csat AS [Avg CSAT], rnk AS [Rank]
FROM cte_ranked
WHERE rnk <= 3
ORDER BY queue_name, rnk;
GO

-- -----------------------------------------------------------------
-- Q8.  Running YTD calls by channel  (cumulative window function)
-- -----------------------------------------------------------------
SELECT
    d.[year]                                                              AS [Year],
    d.month_name                                                          AS [Month Name],
    ch.channel_name                                                       AS [Channel],
    COUNT(f.call_id)                                                      AS [Offered Calls],
    SUM(CASE WHEN f.disposition != 'Abandoned' THEN 1 ELSE 0 END)        AS [Answered Calls],
    SUM(CASE WHEN f.disposition  = 'Abandoned' THEN 1 ELSE 0 END)        AS [Abandoned Calls],
    SUM(COUNT(f.call_id)) OVER (
        PARTITION BY d.[year], ch.channel_name
        ORDER BY d.[month]
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                                     AS [YTD Offered]
FROM dbo.fact_calls f
JOIN dbo.dim_date    d  ON f.call_date  = d.date_key
JOIN dbo.dim_channel ch ON f.channel_id = ch.channel_id
GROUP BY d.[year], d.[month], d.month_name, ch.channel_name
ORDER BY d.[year], ch.channel_name, d.[month];
GO

-- =================================================================
-- SECTION 2: TARGET VS ACTUAL VARIANCE ANALYSIS
-- Compares actual queue performance against contracted targets.
-- Status flags: Met / Missed — variance column shows exact gap
-- AHT targets set to reflect actual data avg of ~8 min per queue.
-- =================================================================

WITH cte_actuals AS (
    SELECT
        q.queue_name,
        COUNT(f.call_id)                                                  AS total_calls,
        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.sla_met = 'Yes' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(f.call_id), 0), 1) AS DECIMAL(5,1))           AS actual_sla_pct,

        -- AHT: abandoned excluded (0 handle time); voicemail included — ACW is real agent time
        CAST(ROUND(
            AVG(CASE WHEN f.disposition != 'Abandoned'
                     THEN CAST(f.handle_time_sec AS FLOAT) END), 0) AS INT) AS actual_aht_sec,

        -- CSAT and NPS: AVG ignores NULLs — calls without a score are excluded automatically
        CAST(ROUND(
            AVG(CAST(f.csat_score AS FLOAT)), 2)
        AS DECIMAL(4,2))                                                  AS actual_csat,

        -- FCR: only calculated where first_call_resolution was recorded (not NULL)
        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.first_call_resolution = 'Yes' THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN f.first_call_resolution IS NOT NULL
                              THEN 1 ELSE 0 END), 0), 1) AS DECIMAL(5,1)) AS actual_fcr_pct,

        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.disposition = 'Abandoned' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(f.call_id), 0), 1) AS DECIMAL(5,1))           AS actual_abandon_pct
    FROM dbo.fact_calls f
    JOIN dbo.dim_queue q ON f.queue_id = q.queue_id
    GROUP BY q.queue_name
)
SELECT
    a.queue_name                                                          AS [Queue],
    a.total_calls                                                         AS [Total Calls],

    -- SLA
    a.actual_sla_pct                                                      AS [SLA Actual %],
    t.sla_target_pct                                                      AS [SLA Target %],
    a.actual_sla_pct - t.sla_target_pct                                   AS [SLA Variance],
    CASE
        WHEN a.actual_sla_pct >= t.sla_target_pct                        THEN 'Met'
        ELSE                                                                   'Missed'
    END                                                                   AS [SLA Status],

    -- AHT
    a.actual_aht_sec                                                      AS [AHT Actual (sec)],
    t.aht_target_sec                                                      AS [AHT Target (sec)],
    a.actual_aht_sec - t.aht_target_sec                                   AS [AHT Variance],
    CASE
        WHEN a.actual_aht_sec <= t.aht_target_sec                        THEN 'Met'
        ELSE                                                                   'Missed'
    END                                                                   AS [AHT Status],

    -- CSAT
    a.actual_csat                                                         AS [CSAT Actual],
    t.csat_target                                                         AS [CSAT Target],
    CAST(a.actual_csat - t.csat_target AS DECIMAL(4,2))                  AS [CSAT Variance],
    CASE
        WHEN a.actual_csat >= t.csat_target                              THEN 'Met'
        ELSE                                                                   'Missed'
    END                                                                   AS [CSAT Status],

    -- FCR
    a.actual_fcr_pct                                                      AS [FCR Actual %],
    t.fcr_target_pct                                                      AS [FCR Target %],
    a.actual_fcr_pct - t.fcr_target_pct                                   AS [FCR Variance],
    CASE
        WHEN a.actual_fcr_pct >= t.fcr_target_pct                       THEN 'Met'
        ELSE                                                                   'Missed'
    END                                                                   AS [FCR Status],

    -- Abandon Rate (lower is better — logic inverted)
    a.actual_abandon_pct                                                  AS [Abandon Actual %],
    t.abandon_target_pct                                                  AS [Abandon Target %],
    a.actual_abandon_pct - t.abandon_target_pct                           AS [Abandon Variance],
    CASE
        WHEN a.actual_abandon_pct <= t.abandon_target_pct                THEN 'Met'
        ELSE                                                                   'Missed'
    END                                                                   AS [Abandon Status]

FROM cte_actuals a
JOIN dbo.dim_targets t ON a.queue_name = t.queue_name
ORDER BY a.queue_name;
GO

-- =================================================================
-- SECTION 3: STORED PROCEDURE — PARAMETERISED MONTHLY REPORT
-- =================================================================
-- Returns 3 result sets for a given year and month:
--   1. Monthly summary header (overall KPIs)
--   2. Queue breakdown with SLA variance vs target
--   3. Top 10 agents by CSAT
--
-- Usage: EXEC dbo.usp_MonthlyPerformanceReport @Year=2024, @Month=6
-- =================================================================

CREATE OR ALTER PROCEDURE dbo.usp_MonthlyPerformanceReport
    @Year  SMALLINT,
    @Month TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Input validation
    IF @Month NOT BETWEEN 1 AND 12
    BEGIN
        RAISERROR('Invalid month. Enter a value between 1 and 12.', 16, 1);
        RETURN;
    END;

    IF @Year NOT BETWEEN 2020 AND 2030
    BEGIN
        RAISERROR('Invalid year. Enter a value between 2020 and 2030.', 16, 1);
        RETURN;
    END;

    -- ── Result Set 1: Monthly Summary ─────────────────────────
    SELECT
        @Year                                                             AS [Year],
        DATENAME(MONTH, DATEFROMPARTS(@Year, @Month, 1))                 AS [Month],
        COUNT(f.call_id)                                                  AS [Total Calls],
        SUM(CASE WHEN f.disposition = 'Abandoned' THEN 1 ELSE 0 END)     AS [Abandoned Calls],
        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.disposition = 'Abandoned' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(f.call_id), 0), 1) AS DECIMAL(5,1))           AS [Abandon Rate %],
        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.sla_met = 'Yes' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(f.call_id), 0), 1) AS DECIMAL(5,1))           AS [SLA %],
        -- AHT: abandoned excluded (0 handle time); voicemail included — ACW is real agent time
        CAST(ROUND(
            AVG(CASE WHEN f.disposition != 'Abandoned'
                     THEN CAST(f.handle_time_sec AS FLOAT) END) / 60, 1)
            AS DECIMAL(5,1))                                              AS [Avg AHT (min)],
        CAST(ROUND(
            AVG(CAST(f.csat_score AS FLOAT)), 2)
            AS DECIMAL(4,2))                                              AS [Avg CSAT],
        CAST(ROUND(
            AVG(CAST(f.nps_score AS FLOAT)), 1)
            AS DECIMAL(4,1))                                              AS [Avg NPS],
        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.first_call_resolution = 'Yes' THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN f.first_call_resolution IS NOT NULL
                               THEN 1 ELSE 0 END), 0), 1)
            AS DECIMAL(5,1))                                              AS [FCR %]
    FROM dbo.fact_calls f
    JOIN dbo.dim_date d ON f.call_date = d.date_key
    WHERE d.[year] = @Year AND d.[month] = @Month;

    -- ── Result Set 2: Queue Breakdown vs Target ────────────────
    ;WITH cte_queue_month AS (
        SELECT
            q.queue_name,
            t.sla_target_pct,
            COUNT(f.call_id)                                              AS total_calls,
            CAST(ROUND(
                100.0 * SUM(CASE WHEN f.sla_met = 'Yes' THEN 1 ELSE 0 END)
                / NULLIF(COUNT(f.call_id), 0), 1) AS DECIMAL(5,1))       AS sla_actual_pct,
            -- AHT: abandoned excluded; voicemail included — ACW is real agent time
            CAST(ROUND(
                AVG(CASE WHEN f.disposition != 'Abandoned'
                         THEN CAST(f.handle_time_sec AS FLOAT) END) / 60, 1)
                AS DECIMAL(5,1))                                          AS avg_aht_min,
            CAST(ROUND(
                AVG(CAST(f.csat_score AS FLOAT)), 2)
                AS DECIMAL(4,2))                                          AS avg_csat
        FROM dbo.fact_calls  f
        JOIN dbo.dim_queue   q ON f.queue_id   = q.queue_id
        JOIN dbo.dim_targets t ON q.queue_name = t.queue_name
        JOIN dbo.dim_date    d ON f.call_date  = d.date_key
        WHERE d.[year] = @Year AND d.[month] = @Month
        GROUP BY q.queue_name, t.sla_target_pct
    )
    SELECT
        queue_name                                                        AS [Queue],
        total_calls                                                       AS [Calls],
        sla_actual_pct                                                    AS [SLA Actual %],
        sla_target_pct                                                    AS [SLA Target %],
        sla_actual_pct - sla_target_pct                                   AS [SLA Variance],
        avg_aht_min                                                       AS [Avg AHT (min)],
        avg_csat                                                          AS [Avg CSAT],
        CASE
            WHEN sla_actual_pct >= sla_target_pct                        THEN 'Met'
            ELSE                                                               'Missed'
        END                                                               AS [SLA Status]
    FROM cte_queue_month
    ORDER BY total_calls DESC;

    -- ── Result Set 3: Top 10 Agents by CSAT ───────────────────
    SELECT TOP 10
        a.agent_name                                                      AS [Agent],
        COUNT(f.call_id)                                                  AS [Calls],
        CAST(ROUND(AVG(CAST(f.csat_score AS FLOAT)), 2)
            AS DECIMAL(4,2))                                              AS [Avg CSAT],
        CAST(ROUND(AVG(CAST(f.handle_time_sec AS FLOAT)) / 60, 1)
            AS DECIMAL(5,1))                                              AS [Avg AHT (min)],
        CAST(ROUND(
            100.0 * SUM(CASE WHEN f.first_call_resolution = 'Yes' THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN f.first_call_resolution IS NOT NULL
                              THEN 1 ELSE 0 END), 0), 1) AS DECIMAL(5,1)) AS [FCR %],
        RANK() OVER (ORDER BY AVG(CAST(f.csat_score AS FLOAT)) DESC)     AS [CSAT Rank]
    FROM dbo.fact_calls f
    JOIN dbo.dim_agent a ON f.agent_id  = a.agent_id
    JOIN dbo.dim_date  d ON f.call_date = d.date_key
    WHERE d.[year]  = @Year
      AND d.[month] = @Month
      AND f.disposition NOT IN ('Abandoned','Voicemail')
      AND f.csat_score IS NOT NULL
    GROUP BY a.agent_id, a.agent_name
    ORDER BY [CSAT Rank];

END;
GO

-- Example usage:
-- EXEC dbo.usp_MonthlyPerformanceReport @Year = 2024, @Month = 6;
-- EXEC dbo.usp_MonthlyPerformanceReport @Year = 2025, @Month = 1;
