-- Healthcare Analytics Lab
-- Star schema (dimensional model) for analytical reporting

USE healthcare_analytics;

-- ------------------------------------------------------------
-- Date Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_date (
    date_key        INT PRIMARY KEY,        -- YYYYMMDD, not AUTO_INCREMENT:
                                             -- lets ETL "look up or insert"
                                             -- a date deterministically.
    calendar_date   DATE NOT NULL UNIQUE,
    day             INT,
    month           INT,
    month_name      VARCHAR(20),
    quarter         INT,
    year            INT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Patient Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_patient (
    patient_key     INT PRIMARY KEY AUTO_INCREMENT,
    patient_id      INT NOT NULL UNIQUE,     -- natural key from OLTP
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    gender          CHAR(1),
    date_of_birth   DATE,
    age_group       VARCHAR(20),
    mrn             VARCHAR(20)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Specialty Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_specialty (
    specialty_key    INT PRIMARY KEY AUTO_INCREMENT,
    specialty_id     INT NOT NULL UNIQUE,
    specialty_name   VARCHAR(100),
    specialty_code   VARCHAR(10)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Department Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_department (
    department_key    INT PRIMARY KEY AUTO_INCREMENT,
    department_id     INT NOT NULL UNIQUE,
    department_name   VARCHAR(100),
    floor             INT,
    capacity          INT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Provider Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_provider (
    provider_key     INT PRIMARY KEY AUTO_INCREMENT,
    provider_id      INT NOT NULL UNIQUE,
    first_name       VARCHAR(100),
    last_name        VARCHAR(100),
    credential       VARCHAR(20),
    specialty_key    INT,
    department_key   INT,
    FOREIGN KEY (specialty_key)  REFERENCES dim_specialty(specialty_key),
    FOREIGN KEY (department_key) REFERENCES dim_department(department_key)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Encounter Type Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_encounter_type (
    encounter_type_key   INT PRIMARY KEY AUTO_INCREMENT,
    encounter_type       VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Diagnosis Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_diagnosis (
    diagnosis_key       INT PRIMARY KEY AUTO_INCREMENT,
    diagnosis_id        INT NOT NULL UNIQUE,
    icd10_code          VARCHAR(10),
    icd10_description   VARCHAR(200)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Procedure Dimension
-- ------------------------------------------------------------
CREATE TABLE dim_procedure (
    procedure_key     INT PRIMARY KEY AUTO_INCREMENT,
    procedure_id      INT NOT NULL UNIQUE,
    cpt_code          VARCHAR(10),
    cpt_description   VARCHAR(200)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Fact Table — grain: one row per encounter
-- ------------------------------------------------------------
CREATE TABLE fact_encounters (
    encounter_key         INT PRIMARY KEY AUTO_INCREMENT,
    encounter_id          INT NOT NULL UNIQUE,   -- natural key; keeps re-runs idempotent
    date_key              INT,   -- admission date, day grain (join to dim_date)
    patient_key           INT NOT NULL,
    provider_key          INT NOT NULL,
    specialty_key         INT NOT NULL,
    department_key        INT NOT NULL,
    encounter_type_key    INT NOT NULL,
    -- Degenerate raw timestamps: needed for readmission-window and
    -- length-of-stay math that a day-grain dimension can't express
    -- cleanly (see header note above).
    admit_date            DATETIME,
    discharge_date        DATETIME,
    -- Pre-aggregated metrics (Decision 3) — computed once at ETL time.
    diagnosis_count       INT DEFAULT 0,
    procedure_count       INT DEFAULT 0,
    total_claim_amount    DECIMAL(12,2) DEFAULT 0,
    total_allowed_amount  DECIMAL(12,2) DEFAULT 0,
    length_of_stay_hours  DECIMAL(10,2),          -- NULL for outpatient/ER visits with no stay
    readmission_flag      TINYINT(1) DEFAULT 0,   -- 1 = patient returned within 30 days of THIS discharge

    FOREIGN KEY (date_key)           REFERENCES dim_date(date_key),
    FOREIGN KEY (patient_key)        REFERENCES dim_patient(patient_key),
    FOREIGN KEY (provider_key)       REFERENCES dim_provider(provider_key),
    FOREIGN KEY (specialty_key)      REFERENCES dim_specialty(specialty_key),
    FOREIGN KEY (department_key)     REFERENCES dim_department(department_key),
    FOREIGN KEY (encounter_type_key) REFERENCES dim_encounter_type(encounter_type_key)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Bridge: Encounter <-> Diagnosis  (many-to-many)
-- ------------------------------------------------------------
CREATE TABLE bridge_encounter_diagnoses (
    encounter_key   INT,
    diagnosis_key   INT,
    PRIMARY KEY (encounter_key, diagnosis_key),
    FOREIGN KEY (encounter_key) REFERENCES fact_encounters(encounter_key),
    FOREIGN KEY (diagnosis_key) REFERENCES dim_diagnosis(diagnosis_key)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Bridge: Encounter <-> Procedure  (many-to-many)
-- ------------------------------------------------------------
CREATE TABLE bridge_encounter_procedures (
    encounter_key   INT,
    procedure_key   INT,
    PRIMARY KEY (encounter_key, procedure_key),
    FOREIGN KEY (encounter_key) REFERENCES fact_encounters(encounter_key),
    FOREIGN KEY (procedure_key) REFERENCES dim_procedure(procedure_key)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Fact table indexes — one per FK used in GROUP BY / JOIN
-- ------------------------------------------------------------
CREATE INDEX idx_fact_date            ON fact_encounters(date_key);
CREATE INDEX idx_fact_patient         ON fact_encounters(patient_key);
CREATE INDEX idx_fact_provider        ON fact_encounters(provider_key);
CREATE INDEX idx_fact_specialty       ON fact_encounters(specialty_key);
CREATE INDEX idx_fact_department      ON fact_encounters(department_key);
CREATE INDEX idx_fact_encounter_type  ON fact_encounters(encounter_type_key);
CREATE INDEX idx_fact_discharge       ON fact_encounters(discharge_date);
CREATE INDEX idx_fact_readmission     ON fact_encounters(readmission_flag);

CREATE INDEX idx_bridge_diag_diagnosis ON bridge_encounter_diagnoses(diagnosis_key);
CREATE INDEX idx_bridge_proc_procedure ON bridge_encounter_procedures(procedure_key);
