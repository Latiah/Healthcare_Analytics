-- ============================================================
-- Healthcare Analytics Lab
-- ============================================================

USE healthcare_analytics;

-- ------------------------------------------------------------
-- Fixed reference data
-- ------------------------------------------------------------
INSERT INTO specialties (specialty_id, specialty_name, specialty_code) VALUES
    (1, 'Cardiology', 'CARD'),
    (2, 'Internal Medicine', 'IM'),
    (3, 'Emergency', 'ER'),
    (4, 'Orthopedics', 'ORTHO'),
    (5, 'Pediatrics', 'PEDS');

INSERT INTO departments (department_id, department_name, floor, capacity) VALUES
    (1, 'Cardiology Unit', 3, 20),
    (2, 'Internal Medicine', 2, 30),
    (3, 'Emergency', 1, 45),
    (4, 'Orthopedics Unit', 4, 15),
    (5, 'Pediatrics Unit', 2, 25);

INSERT INTO diagnoses (diagnosis_id, icd10_code, icd10_description) VALUES
    (1, 'I10', 'Essential (primary) hypertension'),
    (2, 'E11.9', 'Type 2 diabetes mellitus without complications'),
    (3, 'I50.9', 'Heart failure, unspecified'),
    (4, 'J45.909', 'Unspecified asthma, uncomplicated'),
    (5, 'J44.9', 'Chronic obstructive pulmonary disease, unspecified'),
    (6, 'F32.9', 'Major depressive disorder, single episode, unspecified'),
    (7, 'F41.9', 'Anxiety disorder, unspecified'),
    (8, 'E66.9', 'Obesity, unspecified'),
    (9, 'M19.90', 'Osteoarthritis, unspecified site'),
    (10, 'K21.9', 'Gastro-esophageal reflux disease without esophagitis'),
    (11, 'E78.5', 'Hyperlipidemia, unspecified'),
    (12, 'N18.9', 'Chronic kidney disease, unspecified'),
    (13, 'I48.91', 'Unspecified atrial fibrillation'),
    (14, 'J18.9', 'Pneumonia, unspecified organism'),
    (15, 'N39.0', 'Urinary tract infection, site not specified'),
    (16, 'G43.909', 'Migraine, unspecified, not intractable'),
    (17, 'E03.9', 'Hypothyroidism, unspecified'),
    (18, 'D64.9', 'Anemia, unspecified'),
    (19, 'G47.33', 'Obstructive sleep apnea'),
    (20, 'J30.9', 'Allergic rhinitis, unspecified');

INSERT INTO procedures (procedure_id, cpt_code, cpt_description) VALUES
    (1, '99213', 'Office visit, established patient'),
    (2, '93000', 'Electrocardiogram, complete'),
    (3, '71020', 'Chest X-ray, 2 views'),
    (4, '85025', 'Complete blood count with differential'),
    (5, '70551', 'MRI brain without contrast'),
    (6, '74176', 'CT scan abdomen and pelvis without contrast'),
    (7, '45378', 'Colonoscopy, diagnostic'),
    (8, '93306', 'Echocardiogram, complete'),
    (9, '97110', 'Therapeutic exercise, physical therapy'),
    (10, '90471', 'Immunization administration'),
    (11, '99000', 'Specimen handling'),
    (12, '81003', 'Urinalysis, automated'),
    (13, '88305', 'Tissue biopsy examination'),
    (14, '76700', 'Abdominal ultrasound, complete'),
    (15, '93017', 'Cardiovascular stress test');

-- ------------------------------------------------------------
-- Providers: 10, cycling through the 5 specialties/departments.
-- 10 rows is well under the 1000-row default cap MySQL/MariaDB put
-- on recursive CTEs, so a single flat CTE is all that's needed here
-- — no cross-join tricks required at this scale.
-- ------------------------------------------------------------
INSERT INTO providers (provider_id, first_name, last_name, credential, specialty_id, department_id)
WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 10
)
SELECT n, CONCAT('Provider', n), 'Smith', 'MD', ((n - 1) % 5) + 1, ((n - 1) % 5) + 1
FROM seq;

-- ------------------------------------------------------------
-- Patients: 100.
-- ------------------------------------------------------------
INSERT INTO patients (patient_id, first_name, last_name, date_of_birth, gender, mrn)
WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 100
)
SELECT
    n,
    CONCAT('Patient', n),
    CONCAT('Lastname', n),
    DATE_ADD('1935-01-01', INTERVAL FLOOR(RAND() * 32000) DAY),
    ELT(1 + FLOOR(RAND() * 2), 'M', 'F'),
    CONCAT('MRN', LPAD(n, 6, '0'))
FROM seq;

-- ------------------------------------------------------------
-- Encounters: 300, spread across 2024. Date range capped through
-- September (270 days) so a readmission added below — up to ~38
-- days after a late discharge — still lands within 2024.
-- ------------------------------------------------------------
INSERT INTO encounters (encounter_id, patient_id, provider_id, encounter_type, encounter_date, department_id)
WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 300
)
SELECT
    n,
    1 + FLOOR(RAND() * 100),
    1 + FLOOR(RAND() * 10),
    ELT(1 + FLOOR(RAND() * 3), 'Outpatient', 'Inpatient', 'ER'),
    DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 270) DAY),
    1 + FLOOR(RAND() * 5)
FROM seq;

-- discharge_date filled in as a separate UPDATE (not in the same
-- SELECT as encounter_type) so each RAND() call does exactly one job
-- with nothing to reuse or get miscounted.
UPDATE encounters
SET discharge_date = CASE
    WHEN encounter_type = 'Inpatient' THEN DATE_ADD(encounter_date, INTERVAL (24 + FLOOR(RAND() * 216)) HOUR)
    ELSE DATE_ADD(encounter_date, INTERVAL (15 + FLOOR(RAND() * 225)) MINUTE)
END;

-- ------------------------------------------------------------
-- Readmissions: ~15% of inpatient discharges get a follow-up ER
-- visit 1-28 days later, so the readmission-rate query later has
-- something real to detect.
-- ------------------------------------------------------------
INSERT INTO encounters (encounter_id, patient_id, provider_id, encounter_type, encounter_date, discharge_date, department_id)
SELECT
    encounter_id + 1000,
    patient_id,
    1 + FLOOR(RAND() * 10),
    'ER',
    DATE_ADD(discharge_date, INTERVAL days_later DAY),
    DATE_ADD(discharge_date, INTERVAL days_later DAY) + INTERVAL 4 HOUR,
    department_id
FROM (
    SELECT encounter_id, patient_id, department_id, discharge_date,
           1 + FLOOR(RAND() * 28) AS days_later
    FROM encounters
    WHERE encounter_type = 'Inpatient' AND RAND() < 0.15
) readmit_candidates;

-- ------------------------------------------------------------
-- Encounter diagnoses: every encounter gets 1; about a third get a 2nd.
-- Plain WHERE filters, no joins — avoids the "RAND() inside a JOIN's
-- ON clause doesn't re-evaluate per row" trap.
-- ------------------------------------------------------------
INSERT INTO encounter_diagnoses (encounter_diagnosis_id, encounter_id, diagnosis_id, diagnosis_sequence)
SELECT encounter_id, encounter_id, 1 + FLOOR(RAND() * 20), 1
FROM encounters;

INSERT INTO encounter_diagnoses (encounter_diagnosis_id, encounter_id, diagnosis_id, diagnosis_sequence)
SELECT encounter_id + 10000, encounter_id, 1 + FLOOR(RAND() * 20), 2
FROM encounters
WHERE RAND() < 0.35;

-- ------------------------------------------------------------
-- Encounter procedures: same pattern.
-- ------------------------------------------------------------
INSERT INTO encounter_procedures (encounter_procedure_id, encounter_id, procedure_id, procedure_date)
SELECT encounter_id, encounter_id, 1 + FLOOR(RAND() * 15), DATE(encounter_date)
FROM encounters;

INSERT INTO encounter_procedures (encounter_procedure_id, encounter_id, procedure_id, procedure_date)
SELECT encounter_id + 10000, encounter_id, 1 + FLOOR(RAND() * 15), DATE(encounter_date)
FROM encounters
WHERE RAND() < 0.35;

-- ------------------------------------------------------------
-- Billing: one claim per encounter.
-- ------------------------------------------------------------
INSERT INTO billing (billing_id, encounter_id, claim_amount, allowed_amount, claim_date, claim_status)
SELECT
    encounter_id,
    encounter_id,
    claim_amount,
    ROUND(claim_amount * (0.6 + RAND() * 0.3), 2),
    DATE_ADD(discharge_date, INTERVAL (1 + FLOOR(RAND() * 9)) DAY),
    ELT(1 + FLOOR(RAND() * 3), 'Paid', 'Pending', 'Denied')
FROM (
    SELECT encounter_id, discharge_date, ROUND(150 + RAND() * 14850, 2) AS claim_amount
    FROM encounters
) with_claim;

-- ------------------------------------------------------------
-- Tables check.
-- ------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM patients) AS patients,
    (SELECT COUNT(*) FROM providers) AS providers,
    (SELECT COUNT(*) FROM encounters) AS encounters,
    (SELECT COUNT(*) FROM encounter_diagnoses) AS encounter_diagnoses,
    (SELECT COUNT(*) FROM encounter_procedures) AS encounter_procedures,
    (SELECT COUNT(*) FROM billing) AS billing_rows,
    (SELECT COUNT(*) FROM encounters WHERE encounter_type = 'Inpatient') AS inpatient_encounters;