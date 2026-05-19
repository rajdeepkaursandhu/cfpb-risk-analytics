-- ============================================================
-- CFPB Consumer Complaint Risk Analytics
-- Supplementary SQL Analysis
-- Author: Rajdeep Kaur Sandhu
-- 
-- These queries demonstrate how the CFPB complaint dataset
-- can be explored and analyzed using SQL before Python modeling.
-- The original analysis pipeline was built in Python (scikit-learn).
-- Written as a supplementary SQL exploration exercise to show
-- how a BI or compliance analyst would query this data in a
-- SQL environment such as BigQuery or Snowflake.
--
-- Dataset: CFPB Consumer Complaint Database (2018-2025)
-- Source: https://www.consumerfinance.gov/data-research/consumer-complaints/
-- ============================================================


-- ============================================================
-- QUERY 1: Complaint Volume by Product Category
-- Business Question: Which financial products generate the 
-- most complaints? Where should monitoring be focused?
-- ============================================================

SELECT 
    product,
    COUNT(*) AS total_complaints,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM cfpb_complaints
WHERE date_received BETWEEN '2018-01-01' AND '2025-12-31'
    AND consumer_consent_provided = 'Consent provided'
GROUP BY product
ORDER BY total_complaints DESC;


-- ============================================================
-- QUERY 2: Year-over-Year Complaint Volume Trend
-- Business Question: Is complaint volume growing over time?
-- Are there spikes that indicate systemic issues?
-- ============================================================

SELECT 
    EXTRACT(YEAR FROM date_received) AS complaint_year,
    COUNT(*) AS total_complaints,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY EXTRACT(YEAR FROM date_received)) AS yoy_change,
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY EXTRACT(YEAR FROM date_received))) * 100.0 /
        LAG(COUNT(*)) OVER (ORDER BY EXTRACT(YEAR FROM date_received)), 2
    ) AS yoy_pct_change
FROM cfpb_complaints
WHERE consumer_consent_provided = 'Consent provided'
GROUP BY complaint_year
ORDER BY complaint_year;


-- ============================================================
-- QUERY 3: Top 10 Companies by Complaint Count
-- Business Question: Which companies have the highest complaint 
-- concentration? Who carries the most regulatory risk exposure?
-- ============================================================

SELECT 
    company,
    COUNT(*) AS total_complaints,
    ROUND(AVG(CASE WHEN timely_response = 'Yes' THEN 1.0 ELSE 0.0 END) * 100, 2) AS timely_response_rate_pct,
    COUNT(DISTINCT issue) AS unique_issue_types
FROM cfpb_complaints
WHERE consumer_consent_provided = 'Consent provided'
    AND date_received >= '2020-01-01'
GROUP BY company
ORDER BY total_complaints DESC
LIMIT 10;


-- ============================================================
-- QUERY 4: Failure Type Distribution by Product
-- Business Question: Which products are most associated with 
-- high-severity failure types like Escalation Failures?
-- ============================================================

SELECT 
    product,
    failure_type,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY product), 2) AS pct_within_product
FROM cfpb_complaints_classified
WHERE failure_type IS NOT NULL
GROUP BY product, failure_type
ORDER BY product, complaint_count DESC;


-- ============================================================
-- QUERY 5: High Risk Complaint Identification
-- Business Question: Which complaints should be flagged for 
-- immediate compliance review based on risk indicators?
-- ============================================================

SELECT 
    complaint_id,
    date_received,
    product,
    company,
    issue,
    narrative_word_count,
    failure_type,
    risk_score,
    CASE 
        WHEN risk_score >= 0.8 THEN 'High Risk'
        WHEN risk_score >= 0.5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_tier
FROM cfpb_complaints_scored
WHERE risk_score >= 0.8
    AND failure_type = 'Escalation Failure'
ORDER BY risk_score DESC, date_received DESC
LIMIT 100;


-- ============================================================
-- QUERY 6: Timely Response Rate by Risk Tier
-- Business Question: Are high-risk complaints being resolved 
-- on time? What is the compliance gap by severity level?
-- ============================================================

SELECT 
    CASE 
        WHEN risk_score >= 0.8 THEN 'High Risk'
        WHEN risk_score >= 0.5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_tier,
    COUNT(*) AS total_complaints,
    SUM(CASE WHEN timely_response = 'Yes' THEN 1 ELSE 0 END) AS timely_responses,
    ROUND(
        SUM(CASE WHEN timely_response = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS timely_response_rate_pct,
    ROUND(AVG(narrative_word_count), 0) AS avg_narrative_length
FROM cfpb_complaints_scored
GROUP BY risk_tier
ORDER BY 
    CASE risk_tier 
        WHEN 'High Risk' THEN 1 
        WHEN 'Medium Risk' THEN 2 
        ELSE 3 
    END;
