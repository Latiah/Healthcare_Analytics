-- =====================================================
-- STAR SCHEMA FOR HEALTHCARE ANALYTICS
-- =====================================================

-- ==========================
-- Date Dimension
-- ==========================
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY AUTO_INCREMENT,
    calendar_date DATE NOT NULL,
    day INT,
    month INT,
    month_name VARCHAR(20),
    quarter INT,
    year INT
);

-- ==========================
-- Patient Dimension
-- ==========================
CREATE TABLE dim_patient (
    patient_key INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    gender CHAR(1),
    date_of_birth DATE,
    age_group VARCHAR(20),
    mrn VARCHAR(20)
);

-- ==========================
-- Specialty Dimension
-- ==========================
CREATE TABLE dim_specialty (
    specialty_key INT PRIMARY KEY AUTO_INCREMENT,
    specialty_id INT,
    specialty_name VARCHAR(100),
    specialty_code VARCHAR(10)
);

-- ==========================
-- Department Dimension
-- ==========================
CREATE TABLE dim_department (
    department_key INT PRIMARY KEY AUTO_INCREMENT,
    department_id INT,
    department_name VARCHAR(100),
    floor INT,
    capacity INT
);

-- ==========================
-- Provider Dimension
-- ==========================
CREATE TABLE dim_provider (
    provider_key INT PRIMARY KEY AUTO_INCREMENT,
    provider_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    credential VARCHAR(20),
    specialty_key INT,
    department_key INT,
    FOREIGN KEY (specialty_key) REFERENCES dim_specialty(specialty_key),
    FOREIGN KEY (department_key) REFERENCES dim_department(department_key)
);

-- ==========================
-- Encounter Type Dimension
-- ==========================
CREATE TABLE dim_encounter_type (
    encounter_type_key INT PRIMARY KEY AUTO_INCREMENT,
    encounter_type VARCHAR(50)
);

-- ==========================
-- Diagnosis Dimension
-- ==========================
CREATE TABLE dim_diagnosis (
    diagnosis_key INT PRIMARY KEY AUTO_INCREMENT,
    diagnosis_id INT,
    icd10_code VARCHAR(10),
    icd10_description VARCHAR(200)
);

-- ==========================
-- Procedure Dimension
-- ==========================
CREATE TABLE dim_procedure (
    procedure_key INT PRIMARY KEY AUTO_INCREMENT,
    procedure_id INT,
    cpt_code VARCHAR(10),
    cpt_description VARCHAR(200)
);



-- ==========================
-- Fact Table
-- ==========================
CREATE TABLE fact_encounters (

    encounter_key INT PRIMARY KEY AUTO_INCREMENT,

    encounter_id INT,

    date_key INT,
    patient_key INT,
    provider_key INT,
    specialty_key INT,
    department_key INT,
    encounter_type_key INT,

    diagnosis_count INT,
    procedure_count INT,

    total_claim_amount DECIMAL(12,2),
    total_allowed_amount DECIMAL(12,2),

    FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY (patient_key)
        REFERENCES dim_patient(patient_key),

    FOREIGN KEY (provider_key)
        REFERENCES dim_provider(provider_key),

    FOREIGN KEY (specialty_key)
        REFERENCES dim_specialty(specialty_key),

    FOREIGN KEY (department_key)
        REFERENCES dim_department(department_key),

    FOREIGN KEY (encounter_type_key)
        REFERENCES dim_encounter_type(encounter_type_key)
);



-- ==========================
-- Bridge: Encounter - Diagnosis
-- ==========================
CREATE TABLE bridge_encounter_diagnoses (

    encounter_key INT,
    diagnosis_key INT,

    PRIMARY KEY (encounter_key, diagnosis_key),

    FOREIGN KEY (encounter_key)
        REFERENCES fact_encounters(encounter_key),

    FOREIGN KEY (diagnosis_key)
        REFERENCES dim_diagnosis(diagnosis_key)
);

-- ==========================
-- Bridge: Encounter - Procedure
-- ==========================
CREATE TABLE bridge_encounter_procedures (

    encounter_key INT,
    procedure_key INT,

    PRIMARY KEY (encounter_key, procedure_key),

    FOREIGN KEY (encounter_key)
        REFERENCES fact_encounters(encounter_key),

    FOREIGN KEY (procedure_key)
        REFERENCES dim_procedure(procedure_key)
);


CREATE INDEX idx_fact_date
ON fact_encounters(date_key);

CREATE INDEX idx_fact_patient
ON fact_encounters(patient_key);

CREATE INDEX idx_fact_provider
ON fact_encounters(provider_key);

CREATE INDEX idx_fact_specialty
ON fact_encounters(specialty_key);

CREATE INDEX idx_fact_department
ON fact_encounters(department_key);

CREATE INDEX idx_fact_encounter_type
ON fact_encounters(encounter_type_key);