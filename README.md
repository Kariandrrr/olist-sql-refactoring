# Olist E-Commerce Database Refactoring & Analysis

## 📌 Project overview
This project takes a raw, unconstrained e-commerce dataset from **Olist** (Brazilian marketplace, 100k+ orders from 2016-2018) and treats it as a legacy database migration task. 

The goal of this project is to simulate a real-world data engineering/backend scenario: taking a messy database with missing constraints and `NULL` anomalies, cleaning its architecture, establishing proper relational integrity, and writing advanced analytical queries.

- **Source dataset:** [Kaggle - Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Database Management System:** PostgreSQL
- **Tools Used:** DBeaver, Git, SQL

---

## 🏗️ Database architecture evolution

### 1. Initial state (As-Is / Legacy Mess)
* Lack of explicit `PRIMARY KEY` and `FOREIGN KEY` constraints.
* Intentional data corruption.
* Disconnected tables causing data integrity issues.

> *[ER Diagram Before Cleanup]*

### 2. Target state (To-Be / Refactored)
* Enforced entity integrity via `PRIMARY KEY` constraints.
* Enforced referential integrity via `FOREIGN KEY` constraints with cascading rules.
* Cleaned up core attributes and handled anomaly records.

> *[ER Diagram After Cleanup]*

---

## 🚀 Repository structure
```text
olist-sql-refactoring/
│
├── README.md                      # Project documentation and architecture overview
├── data/                          # Placeholders for raw/cleaned datasets
│
├── scripts/                       # Database evolution scripts
│   ├── messy/                     # Scripts simulating legacy data corruption (NULLs, missing keys)
│   └── cleanup/                   # DDL scripts for constraint enforcement and refactoring
│
├── analysis/                      # Analytical and audit queries
│   ├── audit/                     # Data quality checks, anomaly detection, and orphan record search
│   ├── reports/                   # Business intelligence, aggregations, and performance reports
│   └── advanced/                  # Complex queries using window functions and CTEs
│
└── docs/                          # Visual documentation (ER diagrams before/after)
```
