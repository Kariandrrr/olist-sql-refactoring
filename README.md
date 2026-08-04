# Olist E-Commerce Database Refactoring & Analysis
---
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18%2B-blue?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![SQL Refactoring](https://img.shields.io/badge/Data-Engineering-orange?style=flat)](https://github.com/)

A data engineering project focused on transforming raw, unstructured e-commerce CSV dumps into a clean, constrained, and fully normalized relational database using **PostgreSQL** and **DBeaver**.

---

## 📌 Project overview
The project utilizes the public **Brazilian E-Commerce Dataset by Olist**. The original dataset is provided as flat CSV files containing massive amounts of transactional data, lacking relational integrity, proper data types, and constraints.

The goal of this refactoring process was to:
* Cleanse raw data and eliminate physical duplicates.
* Standardize date-time formats from raw text to strict `timestamp` types.
* Establish robust **Primary Keys (PK)** and **Foreign Keys (FK)** with cascade rules.
* Build a reliable architectural foundation for complex analytical queries.

- **Source Dataset:** [Kaggle - Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Database Management System:** PostgreSQL
- **Tools Used:** DBeaver, Git, SQL

**Initial state (Baseline problems):**
* **Data type issues:** critical date/timestamp columns (e.g., order purchase times) were originally imported as text strings (`varchar`), preventing proper time-series analysis.
* **Missing constraints:** the raw dataset lacked Primary Keys (`PK`) and Foreign Keys (`FK`), leaving tables logically disconnected at the database schema level.
* **Data integrity:** absence of strict constraints allowed null values and orphan records in key relations.
---
## 🗄️ Database Entity-Relationship (ER) Diagram

The normalized relational structure of the database:

![ER Diagram](docs/e-commerce%20-%20public.png) 
---

## ⚙️ Refactoring Steps & Implementation

The refactoring pipeline is split into sequential SQL migration scripts inside the `scripts/` directory:

1. **Type safety & Data casts (`01_fix_types.sql`)**: 
   * Converted raw string timestamp columns (e.g., order purchase timestamps, delivery dates) into actual PostgreSQL `timestamp` data types.
2. **Primary & Foreign Key Constraints (`02_add_constraints.sql` & `03_add_remaining_pk.sql`)**:
   * Resolved data duplication issues using system `ctid` optimizations.
   * Defined strict **Primary Keys** (including composite keys for `order_items` and `order_payments`).
   * Enforced **Foreign Key** relationships across orders, items, products, sellers, and customers with `on delete cascade` rules to maintain referential integrity.

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
│   └── queries/                   # Complex queries using window functions and CTEs
│
└── docs/                          # ER diagrams and documentation assets
```
