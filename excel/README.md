# Excel Project — Data Cleaning & Analysis

> **Status: In Progress**
> This project is currently being built. The SQL database is complete and serves as the data source.
> This README will be updated with full documentation once the project is complete.

---

## Planned Scope

An Excel-based data cleaning and analysis project using a deliberately dirtied extract
of the call center database created in the `sql/` project.

**Planned deliverables:**

| File | Description |
|------|-------------|
| `CallCenter_Raw_Dirty.xlsx` | Extracted dataset with intentional data quality issues introduced |
| `CallCenter_Cleaned.xlsx` | Cleaned and analysed output with pivot tables and charts |

**Planned data quality issues to introduce and resolve:**

- Duplicate call records
- Missing values in key columns
- Inconsistent formatting — date formats, text case, whitespace
- Out-of-range scores (CSAT, NPS)
- Incorrect disposition labels

**Planned analysis:**

- Pivot table summaries by queue, channel, and agent
- Monthly KPI trend charts
- CSAT and FCR distribution

---

## Data Source

Data extracted from `CallCenterDB` on SQL Server via export.
Run `sql/01_database_build.sql` first to create and populate the database.

---

## Tools

- Microsoft Excel
- Power Query (data cleaning steps)
- Pivot Tables and Charts
