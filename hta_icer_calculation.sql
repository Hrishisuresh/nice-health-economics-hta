/* =============================================================================
PROJECT 1: HEALTH TECHNOLOGY ASSESSMENT & COST-EFFECTIVENESS
This query simulates patient outcomes to evaluate if a new treatment 
falls within the standard £20,000 - £30,000 NICE willingness-to-pay threshold.
============================================================================= */

WITH RawMockData AS (
  -- Creating a dummy dataset of patients inside the query
  SELECT 101 AS patient_id, 'Standard Care' AS treatment, 4500 AS drug_cost, 1200 AS management_cost, 2.5 AS life_years, 0.70 AS health_utility UNION ALL
  SELECT 102 AS patient_id, 'Standard Care' AS treatment, 4200 AS drug_cost, 1500 AS management_cost, 3.0 AS life_years, 0.65 AS health_utility UNION ALL
  SELECT 103 AS patient_id, 'Standard Care' AS treatment, 4800 AS drug_cost, 900 AS management_cost, 2.0 AS life_years, 0.80 AS health_utility UNION ALL
  SELECT 104 AS patient_id, 'Standard Care' AS treatment, 4600 AS drug_cost, 1100 AS management_cost, 2.8 AS life_years, 0.72 AS health_utility UNION ALL
  SELECT 201 AS patient_id, 'New Intervention' AS treatment, 12500 AS drug_cost, 400 AS management_cost, 4.0 AS life_years, 0.85 AS health_utility UNION ALL
  SELECT 202 AS patient_id, 'New Intervention' AS treatment, 13000 AS drug_cost, 300 AS management_cost, 4.5 AS life_years, 0.90 AS health_utility UNION ALL
  SELECT 203 AS patient_id, 'New Intervention' AS treatment, 12000 AS drug_cost, 500 AS management_cost, 3.8 AS life_years, 0.88 AS health_utility UNION ALL
  SELECT 204 AS patient_id, 'New Intervention' AS treatment, 12800 AS drug_cost, 350 AS management_cost, 4.2 AS life_years, 0.87 AS health_utility
),

PatientCalculations AS (
  -- Step 1: Calculate total cost and QALY for every individual patient
  SELECT 
    patient_id,
    treatment,
    (drug_cost + management_cost) AS total_cost,
    (life_years * health_utility) AS qaly_earned
  FROM RawMockData
),

CohortSummary AS (
  -- Step 2: Get averages for the two competing treatment groups
  SELECT 
    treatment,
    AVG(total_cost) AS avg_cost,
    AVG(qaly_earned) AS avg_qaly
  FROM PatientCalculations
  GROUP BY treatment
)

-- Step 3: Compare groups to find the incremental differences and ICER value
SELECT 
  new_int.avg_cost AS new_treatment_cost,
  std_care.avg_cost AS standard_care_cost,
  (new_int.avg_cost - std_care.avg_cost) AS incremental_cost,
  
  new_int.avg_qaly AS new_treatment_qaly,
  std_care.avg_qaly AS standard_care_qaly,
  (new_int.avg_qaly - std_care.avg_qaly) AS incremental_qaly,
  
  -- ICER = Incremental Cost / Incremental QALY
  SAFE_DIVIDE(
    (new_int.avg_cost - std_care.avg_cost), 
    (new_int.avg_qaly - std_care.avg_qaly)
  ) AS icer_per_qaly,
  
  -- NICE Decision logic rule
  CASE 
    WHEN SAFE_DIVIDE((new_int.avg_cost - std_care.avg_cost), (new_int.avg_qaly - std_care.avg_qaly)) <= 20000 
      THEN 'Highly Cost-Effective (Approve)'
    WHEN SAFE_DIVIDE((new_int.avg_cost - std_care.avg_cost), (new_int.avg_qaly - std_care.avg_qaly)) <= 30000 
      THEN 'Conditionally Cost-Effective (Review Case)'
    ELSE 'Not Cost-Effective (Reject Funding)'
  -- Using CROSS JOIN to bring the separate group metrics into a single calculation row
  END AS nice_recommendation
FROM 
  (SELECT avg_cost, avg_qaly FROM CohortSummary WHERE treatment = 'New Intervention') new_int
CROSS JOIN 
  (SELECT avg_cost, avg_qaly FROM CohortSummary WHERE treatment = 'Standard Care') std_care;