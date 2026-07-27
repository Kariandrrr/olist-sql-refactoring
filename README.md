# Olist E-Commerce Database Refactoring & Analysis

## 📌 Project Overview
This project takes a raw, unconstrained e-commerce dataset from **Olist** (Brazilian marketplace, 100k+ orders from 2016-2018) and treats it as a legacy database migration task. 

The goal of this project is to simulate a real-world data engineering/backend scenario: taking a messy database with missing constraints and `NULL` anomalies, cleaning its architecture, establishing proper relational integrity, and writing advanced analytical queries.

- **Source Dataset:** [Kaggle - Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Database Management System:** PostgreSQL
- **Tools Used:** DBeaver, Git, SQL

---

## 🏗️ Database Architecture Evolution

### 1. Initial State (As-Is / Legacy Mess)
* Lack of explicit `PRIMARY KEY` and `FOREIGN KEY` constraints.
* Intentional data corruption.
* Disconnected tables causing data integrity issues.

> *[ER Diagram Before Cleanup]*

### 2. Target State (To-Be / Refactored)
* Enforced entity integrity via `PRIMARY KEY` constraints.
* Enforced referential integrity via `FOREIGN KEY` constraints with cascading rules.
* Cleaned up core attributes and handled anomaly records.

> *[ER Diagram After Cleanup]*

---

## 🚀 Repository Structure
- `scripts/`: DDL and DML scripts for data seeding, schema cleanup, and constraint enforcement.
- `analysis/`: Complex SQL queries (joins, aggregations, window functions).
