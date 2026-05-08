# Power BI Project — Call Center Dashboard

> **Status: In Progress**
> This project is currently being built. The SQL database is complete and serves as the data source.
> This README will be updated with full documentation once the dashboard is published.

---

## Planned Scope

An interactive operational dashboard built on top of the call center database
(`CallCenterDB`) created in the `sql/` project.

**Planned pages:**

| Page | Focus |
|------|-------|
| Overview | Monthly KPI summary — volume, SLA, AHT, CSAT, FCR, abandon rate |
| Queue Performance | SLA and AHT breakdown by queue vs contracted targets |
| Agent Scorecard | CSAT, FCR, and AHT ranking across all 15 agents |
| Channel & Location | Contact mix by channel, city, and customer segment |
| Trend Analysis | Month-over-month volume and KPI movement |

---

## Data Source

The dashboard connects directly to `CallCenterDB` on SQL Server.
Run `sql/01_database_build.sql` first to create and populate the database.

Note: `dim_date` extends to 31 December 2025 to support Power BI time intelligence
functions across the full calendar year.

---

## Tools

- Power BI Desktop
- DAX (measures and calculated columns)
- SQL Server live connection / import mode
