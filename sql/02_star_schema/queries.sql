-- Healthcare Analytics Lab
-- Part 3.3: The same 4 business questions, answered from the star schema

USE healthcare_analytics;

-- ------------------------------------------------------------
-- Question 1: Monthly Encounters by Specialty
-- ------------------------------------------------------------
SELECT
    d.year,
    d.month,
    s.specialty_name,
    et.encounter_type,
    COUNT(*)                     AS total_encounters,
    COUNT(DISTINCT f.patient_key) AS unique_patients
FROM fact_encounters f
JOIN dim_date d           ON f.date_key = d.date_key
JOIN dim_specialty s      ON f.specialty_key = s.specialty_key
JOIN dim_encounter_type et ON f.encounter_type_key = et.encounter_type_key
GROUP BY d.year, d.month, s.specialty_name, et.encounter_type
ORDER BY d.year, d.month;


-- ------------------------------------------------------------
-- Question 2: Top Diagnosis-Procedure Pairs
-- ------------------------------------------------------------
SELECT
    dd.icd10_code,
    dp.cpt_code,
    COUNT(*) AS encounter_count
FROM bridge_encounter_diagnoses bd
JOIN dim_diagnosis dd            ON bd.diagnosis_key = dd.diagnosis_key
JOIN bridge_encounter_procedures bp ON bd.encounter_key = bp.encounter_key
JOIN dim_procedure dp            ON bp.procedure_key = dp.procedure_key
GROUP BY dd.icd10_code, dp.cpt_code
ORDER BY encounter_count DESC;


-- ------------------------------------------------------------
-- Question 3: 30-Day Readmission Rate by Specialty
-- ------------------------------------------------------------

SELECT
    s.specialty_name,
    COUNT(*)                          AS inpatient_discharges,
    SUM(f.readmission_flag)           AS readmitted_within_30d,
    ROUND(AVG(f.readmission_flag), 4) AS readmission_rate
FROM fact_encounters f
JOIN dim_encounter_type et ON f.encounter_type_key = et.encounter_type_key
JOIN dim_specialty s       ON f.specialty_key = s.specialty_key
WHERE et.encounter_type = 'Inpatient'
GROUP BY s.specialty_name
ORDER BY readmission_rate DESC;


-- ------------------------------------------------------------
-- Question 4: Revenue by Specialty & Month
-- ------------------------------------------------------------
SELECT
    d.year,
    d.month,
    s.specialty_name,
    SUM(f.total_allowed_amount) AS total_revenue
FROM fact_encounters f
JOIN dim_date d      ON f.date_key = d.date_key
JOIN dim_specialty s ON f.specialty_key = s.specialty_key
GROUP BY d.year, d.month, s.specialty_name
ORDER BY total_revenue DESC;
