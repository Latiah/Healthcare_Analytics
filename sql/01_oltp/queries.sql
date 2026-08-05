-- ============================================================
-- Healthcare Analytics Lab
-- Part 2: Business questions answered against the normalized OLTP schema
-- ============================================================
USE healthcare_analytics;

-- ------------------------------------------------------------
-- Question 1: Monthly Encounters by Specialty
-- ------------------------------------------------------------
SELECT
    DATE_FORMAT(e.encounter_date, '%Y-%m') AS month,
    s.specialty_name,
    e.encounter_type,
    COUNT(e.encounter_id)          AS total_encounters,
    COUNT(DISTINCT e.patient_id)   AS unique_patients
FROM encounters e
JOIN providers p    ON e.provider_id = p.provider_id
JOIN specialties s  ON p.specialty_id = s.specialty_id
GROUP BY month, s.specialty_name, e.encounter_type
ORDER BY month, s.specialty_name;


-- ------------------------------------------------------------
-- Question 2: Top Diagnosis-Procedure Pairs
-- ------------------------------------------------------------
SELECT
    d.icd10_code,
    p.cpt_code,
    COUNT(*) AS frequency
FROM encounter_diagnoses ed
JOIN diagnoses d            ON ed.diagnosis_id = d.diagnosis_id
JOIN encounter_procedures ep ON ed.encounter_id = ep.encounter_id
JOIN procedures p           ON ep.procedure_id = p.procedure_id
GROUP BY d.icd10_code, p.cpt_code
ORDER BY frequency DESC;


-- ------------------------------------------------------------
-- Question 3: 30-Day Readmission Rate by Specialty
-- ------------------------------------------------------------

SELECT
    s.specialty_name,
    COUNT(DISTINCT e1.encounter_id) AS inpatient_discharges,
    COUNT(DISTINCT CASE WHEN e2.encounter_id IS NOT NULL
                         THEN e1.encounter_id END)   AS readmitted_within_30d,
    ROUND(
        COUNT(DISTINCT CASE WHEN e2.encounter_id IS NOT NULL
                             THEN e1.encounter_id END) * 1.0
        / COUNT(DISTINCT e1.encounter_id),
    4) AS readmission_rate
FROM encounters e1
JOIN providers pr   ON e1.provider_id = pr.provider_id
JOIN specialties s  ON pr.specialty_id = s.specialty_id
LEFT JOIN encounters e2
    ON e2.patient_id = e1.patient_id
    AND e2.encounter_date > e1.discharge_date
    AND e2.encounter_date <= DATE_ADD(e1.discharge_date, INTERVAL 30 DAY)
WHERE e1.encounter_type = 'Inpatient'
GROUP BY s.specialty_name
ORDER BY readmission_rate DESC;


-- ------------------------------------------------------------
-- Question 4: Revenue by Specialty & Month
-- ------------------------------------------------------------
SELECT
    YEAR(b.claim_date)  AS year,
    MONTH(b.claim_date) AS month,
    s.specialty_name,
    SUM(b.allowed_amount) AS total_revenue
FROM billing b
JOIN encounters e   ON b.encounter_id = e.encounter_id
JOIN providers p    ON e.provider_id = p.provider_id
JOIN specialties s  ON p.specialty_id = s.specialty_id
GROUP BY YEAR(b.claim_date), MONTH(b.claim_date), s.specialty_name
ORDER BY total_revenue DESC;
