-- Healthcare Analytics Lab
-- OLTP schema (normalized, 3NF) — source system of record

DROP DATABASE IF EXISTS healthcare_analytics;
CREATE DATABASE healthcare_analytics;
USE healthcare_analytics;

CREATE TABLE patients (
    patient_id      INT PRIMARY KEY,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    date_of_birth   DATE,
    gender          CHAR(1),
    mrn             VARCHAR(20) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE specialties (
    specialty_id    INT PRIMARY KEY,
    specialty_name  VARCHAR(100),
    specialty_code  VARCHAR(10)
) ENGINE=InnoDB;

CREATE TABLE departments (
    department_id    INT PRIMARY KEY,
    department_name  VARCHAR(100),
    floor             INT,
    capacity          INT
) ENGINE=InnoDB;

CREATE TABLE providers (
    provider_id     INT PRIMARY KEY,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    credential      VARCHAR(20),
    specialty_id    INT,
    department_id   INT,
    FOREIGN KEY (specialty_id)  REFERENCES specialties(specialty_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    INDEX idx_providers_specialty (specialty_id),
    INDEX idx_providers_department (department_id)
) ENGINE=InnoDB;

CREATE TABLE encounters (
    encounter_id     INT PRIMARY KEY,
    patient_id       INT,
    provider_id      INT,
    encounter_type   VARCHAR(50), -- 'Outpatient', 'Inpatient', 'ER'
    encounter_date   DATETIME,
    discharge_date   DATETIME,
    department_id    INT,
    FOREIGN KEY (patient_id)     REFERENCES patients(patient_id),
    FOREIGN KEY (provider_id)    REFERENCES providers(provider_id),
    FOREIGN KEY (department_id)  REFERENCES departments(department_id),
    INDEX idx_encounter_date (encounter_date),
    INDEX idx_encounters_patient (patient_id),
    INDEX idx_encounters_provider (provider_id),
    INDEX idx_encounters_discharge (discharge_date)
) ENGINE=InnoDB;

CREATE TABLE diagnoses (
    diagnosis_id        INT PRIMARY KEY,
    icd10_code          VARCHAR(10),
    icd10_description   VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE encounter_diagnoses (
    encounter_diagnosis_id  INT PRIMARY KEY,
    encounter_id            INT,
    diagnosis_id            INT,
    diagnosis_sequence      INT,
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id),
    FOREIGN KEY (diagnosis_id) REFERENCES diagnoses(diagnosis_id),
    INDEX idx_ed_encounter (encounter_id),
    INDEX idx_ed_diagnosis (diagnosis_id)
) ENGINE=InnoDB;

CREATE TABLE procedures (
    procedure_id     INT PRIMARY KEY,
    cpt_code         VARCHAR(10),
    cpt_description  VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE encounter_procedures (
    encounter_procedure_id  INT PRIMARY KEY,
    encounter_id            INT,
    procedure_id            INT,
    procedure_date          DATE,
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id),
    FOREIGN KEY (procedure_id) REFERENCES procedures(procedure_id),
    INDEX idx_ep_encounter (encounter_id),
    INDEX idx_ep_procedure (procedure_id)
) ENGINE=InnoDB;

CREATE TABLE billing (
    billing_id       INT PRIMARY KEY,
    encounter_id     INT,
    claim_amount     DECIMAL(12, 2),
    allowed_amount   DECIMAL(12, 2),
    claim_date       DATE,
    claim_status     VARCHAR(50),
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id),
    INDEX idx_claim_date (claim_date),
    INDEX idx_billing_encounter (encounter_id)
) ENGINE=InnoDB;
