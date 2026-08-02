# Healthcare Analytics Lab: OLTP to Star Schema

## Project Overview

This project demonstrates how to transform a normalized healthcare database (OLTP) into a star schema optimized for analytical reporting.

The objective is to identify performance issues in the normalized database, design a dimensional model, and show how a star schema improves query performance for business intelligence and analytics.

---

## Objectives

- Analyze the normalized OLTP database.
- Write analytical SQL queries.
- Identify query performance bottlenecks.
- Design a star schema.
- Create optimized analytical queries.
- Design an ETL process for loading the data warehouse.
- Compare the OLTP and star schema approaches.


## Deliverables

### 1. query_analysis.txt
Contains the four analytical SQL queries written against the normalized database, including performance analysis and identified bottlenecks.

### 2. design_decisions.txt
Documents the star schema design decisions, including:
- Fact table grain
- Dimension tables
- Pre-aggregated metrics
- Bridge tables

### 3. star_schema.sql
Contains the SQL script used to create the dimensional model, including:
- Dimension tables
- Fact table
- Bridge tables
- Primary keys
- Foreign keys
- Indexes

### 4. star_schema_queries.txt
Contains the optimized versions of the analytical queries using the star schema and explains the expected performance improvements.

### 5. etl_design.txt
Describes the ETL process used to populate the data warehouse, including:
- Dimension loading
- Fact loading
- Bridge table loading
- Refresh strategy

### 6. reflection.md
Summarizes the lessons learned from the project, compares OLTP and star schema designs, and discusses the advantages and trade-offs of dimensional modeling.

---

## Star Schema Design

The warehouse consists of:

### Fact Table

- fact_encounters

### Dimension Tables

- dim_date
- dim_patient
- dim_provider
- dim_specialty
- dim_department
- dim_encounter_type
- dim_diagnosis
- dim_procedure

### Bridge Tables

- bridge_encounter_diagnoses
- bridge_encounter_procedures

---


## Expected Outcome

After completing this project, the analytical queries become easier to write and require fewer joins compared to the normalized OLTP schema. Pre-computed metrics and dimensional modeling improve query performance and simplify business reporting.
