# Call Center Analytics Portfolio

An end-to-end analytics portfolio built around a single operational dataset —
a simulated UAE telecom contact centre with 12,000 call records spanning 15 months
(January 2024 – March 2025).

The same database underpins three separate projects, each demonstrating a different
layer of the analytics workflow. Built by someone with 7+ years working inside BPO
and contact centre operations in Cairo and Dubai — the schema, KPI definitions, and
target benchmarks reflect real reporting requirements, not textbook examples.

---

## Projects

| # | Folder | Tool | Status | What It Covers |
|---|--------|------|--------|----------------|
| 1 | `sql/` | SQL Server | Complete | Star schema design, 12,000-row dataset, 8 analysis queries, target variance report, stored procedure |
| 2 | `power_bi/` | Power BI | In Progress | Interactive operational dashboard — KPIs, SLA tracking, agent scorecard |
| 3 | `excel/` | Excel | In Progress | Data cleaning on a dirty extract of the dataset, pivot analysis, charts |

Each folder contains its own README with setup instructions and detail.
Run the SQL project first — the Power BI and Excel projects are built on top of the same database.

---

## The Dataset

**Star schema — 1 fact table, 7 dimension tables**

| Table | Description |
|-------|-------------|
| `fact_calls` | One row per call — timestamps, scores, disposition, SLA flag |
| `dim_agent` | 15 agents handling all queue types |
| `dim_queue` | 6 queues: Billing, Cancellations, Customer Service, Sales, Technical Support, Upgrade & Retention |
| `dim_channel` | Phone, Chat, Email, WhatsApp |
| `dim_product` | 6 telecom products: Mobile Plan, Broadband, TV Package, Business Line, IoT Service, Roaming Add-on |
| `dim_location` | 7 UAE cities: Abu Dhabi, Ajman, Al Ain, Dubai, Fujairah, Ras Al Khaimah, Sharjah |
| `dim_date` | Date dimension with UAE weekend flag (Saturday–Sunday, post January 2022) |
| `dim_targets` | Contracted KPI targets per queue for variance analysis |

**Date range (calls):** 01 January 2024 – 31 March 2025
**Date range (dim_date):** 01 January 2024 – 31 December 2025 (extended for Power BI time intelligence)
**Volume:** 12,000 calls

---

## KPI Definitions

| KPI | Definition |
|-----|------------|
| SLA | Wait time ≤ 20 seconds = Met |
| AHT | Talk time + Hold time + After Call Work |
| CSAT | Post-call IVR score (1–5). Not recorded for abandoned and voicemail calls — excluded from the calculation automatically via NULL |
| NPS | Net Promoter Score (0–10) recorded per connected call |
| FCR | First call resolution flag. Not recorded for abandoned and voicemail calls — excluded from the calculation automatically via NULL |
| Abandon | Calls where handle, talk, hold, and ACW = 0 and agent = NULL |

---

## Tools

- SQL Server 2019+ / T-SQL
- Power BI Desktop
- Microsoft Excel (with Power Query)
