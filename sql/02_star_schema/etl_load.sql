-- Healthcare Analytics Lab
-- ETL: OLTP (healthcare_analytics) -> Star Schema 


-- ------------------------------------------------------------
-- 1. Dimension Load Logic
-- ------------------------------------------------------------

USE healthcare_analytics;

INSERT INTO dim_date
    (date_key, calendar_date, day, month, month_name, quarter, year)
WITH RECURSIVE seq AS (
    SELECT DATE('2024-01-01') AS d
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM seq WHERE d < '2024-12-31'
)
SELECT
    CAST(DATE_FORMAT(d, '%Y%m%d') AS UNSIGNED) AS date_key,
    d,
    DAY(d),
    MONTH(d),
    MONTHNAME(d),
    QUARTER(d),
    YEAR(d)
FROM seq
ON DUPLICATE KEY UPDATE calendar_date = calendar_date;

-- dim_patient: age_group is computed as of the ETL run date.
-- For a slowly changing dimension in production you'd snapshot
-- this at a fixed "as_of" date rather than recomputing on every
-- run; kept simple here since the lab only needs one load.
INSERT INTO dim_patient
    (patient_id, first_name, last_name, gender, date_of_birth, age_group, mrn)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.gender,
    p.date_of_birth,
    CASE
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) < 18 THEN 'Under 18'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 18 AND 34 THEN '18-34'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 35 AND 49 THEN '35-49'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 50 AND 64 THEN '50-64'
        ELSE '65+'
    END AS age_group,
    p.mrn
FROM patients p
ON DUPLICATE KEY UPDATE
    first_name = VALUES(first_name),
    last_name  = VALUES(last_name),
    gender     = VALUES(gender),
    age_group  = VALUES(age_group),
    mrn        = VALUES(mrn);

-- dim_specialty: direct load.
INSERT INTO dim_specialty
    (specialty_id, specialty_name, specialty_code)
SELECT specialty_id, specialty_name, specialty_code
FROM specialties
ON DUPLICATE KEY UPDATE
    specialty_name = VALUES(specialty_name),
    specialty_code = VALUES(specialty_code);

-- dim_department: direct load.
INSERT INTO dim_department
    (department_id, department_name, floor, capacity)
SELECT department_id, department_name, floor, capacity
FROM departments
ON DUPLICATE KEY UPDATE
    department_name = VALUES(department_name),
    floor            = VALUES(floor),
    capacity         = VALUES(capacity);

-- dim_provider: resolves specialty_key / department_key by joining
-- back to the dimensions loaded above.
INSERT INTO dim_provider
    (provider_id, first_name, last_name, credential, specialty_key, department_key)
SELECT
    pr.provider_id,
    pr.first_name,
    pr.last_name,
    pr.credential,
    ds.specialty_key,
    dd.department_key
FROM providers pr
JOIN dim_specialty  ds ON pr.specialty_id  = ds.specialty_id
JOIN dim_department dd ON pr.department_id = dd.department_id
ON DUPLICATE KEY UPDATE
    first_name     = VALUES(first_name),
    last_name      = VALUES(last_name),
    credential     = VALUES(credential),
    specialty_key  = VALUES(specialty_key),
    department_key = VALUES(department_key);

-- dim_encounter_type: distinct values straight from the source,
-- not a hardcoded list — so a new encounter type added upstream
-- shows up automatically on the next ETL run.
INSERT INTO dim_encounter_type (encounter_type)
SELECT DISTINCT encounter_type
FROM encounters
ON DUPLICATE KEY UPDATE encounter_type = VALUES(encounter_type);

-- dim_diagnosis: direct load.
INSERT INTO dim_diagnosis
    (diagnosis_id, icd10_code, icd10_description)
SELECT diagnosis_id, icd10_code, icd10_description
FROM diagnoses
ON DUPLICATE KEY UPDATE
    icd10_code        = VALUES(icd10_code),
    icd10_description = VALUES(icd10_description);

-- dim_procedure: direct load.
INSERT INTO dim_procedure
    (procedure_id, cpt_code, cpt_description)
SELECT procedure_id, cpt_code, cpt_description
FROM procedures
ON DUPLICATE KEY UPDATE
    cpt_code        = VALUES(cpt_code),
    cpt_description = VALUES(cpt_description);


-- ------------------------------------------------------------
-- 2. Fact Table Load Logic
-- ------------------------------------------------------------
-- For each encounter: look up every dimension key, count linked
-- diagnoses/procedures, pull billing totals, compute length of
-- stay, and compute the 30-day readmission flag — all once here
-- so no analytical query has to redo this work.
INSERT INTO fact_encounters (
    encounter_id, date_key, patient_key, provider_key, specialty_key,
    department_key, encounter_type_key, admit_date, discharge_date,
    diagnosis_count, procedure_count, total_claim_amount,
    total_allowed_amount, length_of_stay_hours, readmission_flag
)
SELECT
    e.encounter_id,
    dt.date_key,
    dp.patient_key,
    dpr.provider_key,
    dpr.specialty_key,
    dpr.department_key,
    det.encounter_type_key,
    e.encounter_date,
    e.discharge_date,
    -- Diagnosis / procedure counts, pre-aggregated once here
    -- instead of being recomputed by every downstream query.
    (SELECT COUNT(*) FROM encounter_diagnoses ed
      WHERE ed.encounter_id = e.encounter_id)  AS diagnosis_count,
    (SELECT COUNT(*) FROM encounter_procedures ep
      WHERE ep.encounter_id = e.encounter_id)  AS procedure_count,
    -- Billing totals. SUM(), not a bare column, because an
    -- encounter could in principle have more than one claim line.
    (SELECT COALESCE(SUM(b.claim_amount), 0) FROM billing b
      WHERE b.encounter_id = e.encounter_id)   AS total_claim_amount,
    (SELECT COALESCE(SUM(b.allowed_amount), 0) FROM billing b
      WHERE b.encounter_id = e.encounter_id)   AS total_allowed_amount,
    -- Length of stay, in hours, wherever a discharge time exists.
    CASE WHEN e.discharge_date IS NOT NULL
         THEN TIMESTAMPDIFF(HOUR, e.encounter_date, e.discharge_date)
         ELSE NULL END AS length_of_stay_hours,
    -- Readmission flag lives on the INDEX (inpatient) encounter:
    -- 1 if this patient had any later encounter that started after
    -- this discharge and within the following 30 days.
    CASE WHEN e.encounter_type = 'Inpatient'
              AND EXISTS (
                  SELECT 1 FROM encounters e2
                  WHERE e2.patient_id = e.patient_id
                    AND e2.encounter_date > e.discharge_date
                    AND e2.encounter_date <= DATE_ADD(e.discharge_date, INTERVAL 30 DAY)
              )
         THEN 1 ELSE 0 END AS readmission_flag

FROM encounters e
JOIN dim_date dt
    ON dt.calendar_date = DATE(e.encounter_date)
JOIN dim_patient dp
    ON dp.patient_id = e.patient_id
JOIN dim_provider dpr
    ON dpr.provider_id = e.provider_id
JOIN dim_encounter_type det
    ON det.encounter_type = e.encounter_type

ON DUPLICATE KEY UPDATE
    date_key              = VALUES(date_key),
    patient_key            = VALUES(patient_key),
    provider_key           = VALUES(provider_key),
    specialty_key           = VALUES(specialty_key),
    department_key          = VALUES(department_key),
    encounter_type_key      = VALUES(encounter_type_key),
    admit_date               = VALUES(admit_date),
    discharge_date            = VALUES(discharge_date),
    diagnosis_count            = VALUES(diagnosis_count),
    procedure_count             = VALUES(procedure_count),
    total_claim_amount           = VALUES(total_claim_amount),
    total_allowed_amount          = VALUES(total_allowed_amount),
    length_of_stay_hours            = VALUES(length_of_stay_hours),
    readmission_flag                 = VALUES(readmission_flag);


-- ------------------------------------------------------------
-- 3. Bridge Table Load Logic
-- ------------------------------------------------------------

-- bridge_encounter_diagnoses: resolve encounter_id/diagnosis_id
-- to the surrogate keys already loaded above.
INSERT INTO bridge_encounter_diagnoses
    (encounter_key, diagnosis_key)
SELECT DISTINCT f.encounter_key, dd.diagnosis_key
FROM encounter_diagnoses ed
JOIN fact_encounters f
    ON f.encounter_id = ed.encounter_id
JOIN dim_diagnosis dd
    ON dd.diagnosis_id = ed.diagnosis_id
ON DUPLICATE KEY UPDATE encounter_key = VALUES(encounter_key);

-- bridge_encounter_procedures: same pattern for procedures.
INSERT INTO bridge_encounter_procedures
    (encounter_key, procedure_key)
SELECT DISTINCT f.encounter_key, dp.procedure_key
FROM encounter_procedures ep
JOIN fact_encounters f
    ON f.encounter_id = ep.encounter_id
JOIN dim_procedure dp
    ON dp.procedure_id = ep.procedure_id
ON DUPLICATE KEY UPDATE encounter_key = VALUES(encounter_key);

