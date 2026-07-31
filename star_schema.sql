USE healthcare_analytics;

-- Dimensions
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    calendar_date DATE,
    month_name VARCHAR(20),
    month_num INT,
    year INT,
    quarter INT
);

CREATE TABLE dim_patient (
    patient_key INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    gender CHAR(8),
    age_group VARCHAR(20),
    weight INT(10)
);

CREATE TABLE dim_provider (
    provider_key INT PRIMARY KEY AUTO_INCREMENT,
    provider_id INT,
    provider_name VARCHAR(200),
    specialty_name VARCHAR(100),
    department_name VARCHAR(100)
);


CREATE TABLE dim_speciality (
    specialty_key INT PRIMARY KEY AUTO_INCREMENT,
    specialty_id INT,
    specialty_name VARCHAR(100)
);

CREATE TABLE dim_department (
    department_key INT PRIMARY KEY AUTO_INCREMENT,
    department_id INT,
    department_name VARCHAR(100)
);

CREATE TABLE dim_encounters (
    encounter_type_key INT PRIMARY KEY AUTO_INCREMENT,
    encounter_type_name VARCHAR(50)
);


-- Fact Table
CREATE TABLE fact_encounters (
    encounter_key INT PRIMARY KEY AUTO_INCREMENT,
    encounter_id INT,
    patient_key INT,
    provider_key INT,
    date_key INT,
    encounter_type VARCHAR(50),
    -- Metrics
    total_allowed DECIMAL(12,2),
    diag_count INT,
    proc_count INT,
    length_of_stay_days INT,
    is_readmission TINYINT, -- Pre-calculated logic
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (provider_key) REFERENCES dim_provider(provider_key),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
);

-- Bridge Tables
CREATE TABLE bridge_diagnoses (
    encounter_key INT,
    icd10_code VARCHAR(10),
    description VARCHAR(200),
    is_primary TINYINT
);