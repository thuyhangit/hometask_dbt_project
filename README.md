Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test


# Task 1 - Issues in the Original SP — Analysis & Disposition

## Quick Summary

| # | Issue | Severity | Disposition |
|---|---|---|---|
| 1 | `NOLOCK` dirty reads | 🔴 High | **Fixed** |
| 2 | Non-atomic DELETE + INSERT | 🔴 High | **Fixed** |
| 3 | `GETDATE()` makes "3-month" window non-deterministic | 🔴 High | **Fixed** |
| 4 | No input validation on `@SnapshotMonth` | 🟡 Medium | **Fixed** |
| 5 | `BudgetUSD / 12.0` assumes flat annual budget | 🟡 Medium | **Preserved** (flagged below) |
---

## Detailed Analysis

### 1. `WITH (NOLOCK)` on all source reads — 🔴 **Fixed**

**Original** ([lines 20, 35, 47](/hometask_dbt_project/tests/sources/ssis_sp.sql#L20)):
```sql
FROM dbo.Projects p WITH (NOLOCK)
FROM dbo.TimesheetEntries ts WITH (NOLOCK)
FROM dbo.Employees e WITH (NOLOCK)
```

**Problem**: `NOLOCK`
In Postgres, when you run a SELECT query, it simply takes a snapshot of the database at that exact millisecond. If another transaction is in the middle of updating a row, Postgres just reads the older, committed version of that row.
Because of this, you get the performance benefits of NOLOCK (no blocking) automatically,

**Disposition — Fixed**: dbt models use standard reads at the database's default isolation level (typically `read committed` in PostgreSQL). No dirty-read risk.

---

### 2. Non-atomic DELETE + INSERT — 🔴 **Fixed**

**Original** ([lines 7–8](hometask_dbt_project/tests/sources/ssis_sp.sql#L7-L8)):
```sql
DELETE FROM dbo.FactProjectMonthly WHERE SnapshotMonth = @SnapshotMonth;
-- ... (many operations) ...
INSERT INTO dbo.FactProjectMonthly ...
```

**Problem**: There is no explicit transaction wrapping. If the SP fails partway through (e.g., after the DELETE but before the INSERT), the snapshot month's data is gone with no rollback. Consumers querying the fact table during execution will see partial/empty data.

**Disposition — Fixed**: dbt's `table` materialization creates the new table in a temporary location and atomically swaps it in via `ALTER TABLE ... RENAME`. There is no window where data is missing.

---

### 3. `GETDATE()` makes "closed within 3 months" non-deterministic — 🔴 **Fixed**

**Original** ([line 22](hometask_dbt_project/tests/sources/ssis_sp.sql#L22)):
```sql
WHERE ... p.ClosedDate >= DATEADD(MONTH, -3, GETDATE())
```

**Problem**: The "3-month lookback" is relative to _when the SP runs_, not relative to the snapshot month. If you backfill October 2024 data in January 2025, the filter uses January's date, meaning a project closed in August 2024 would be excluded even though it was active during October.

**Disposition — Preserved**: The dbt model [int_active_projects.sql](hometask_dbt_project/models/intermediate/int_active_projects.sql) get from snapshot_month instead of GETDATE():
{% set snapshot_month = var('snapshot_month') %}
{% set year_part  = snapshot_month // 100 %}
{% set month_part = snapshot_month % 100 %}
...
`closed_date >= make_date({{ year_part }}, {{ month_part }}, 1) - interval '3 months'`


### 4. No input validation on `@SnapshotMonth` — 🟡 **Fixed**

**Original** ([lines 24–25](/hometask_dbt_project/tests/sources/ssis_sp.sql#L24-L25)):
```sql
DECLARE @MonthStart DATE = DATEFROMPARTS(@SnapshotMonth / 100, @SnapshotMonth % 100, 1);
```

**Problem**: Passing an invalid value like `999999`, `202413`, or `0` would cause a runtime error in `DATEFROMPARTS`. There's no guard clause.

**Disposition — Fixed**: In [int_monthly_hours.sql](/hometask_dbt_project/models/intermediate/int_monthly_hours.sql), the Jinja `{% set %}` logic runs at compile time. `make_date()` in PostgreSQL will raise a clear error for invalid month values, and dbt's `--vars` mechanism makes the input explicit and auditable in CI/CD.

---

### 5. `BudgetUSD / 12.0` assumes uniform monthly budget — 🟡 **Preserved**

**Original** ([line 65](/hometask_dbt_project/tests/sources/ssis_sp.sql#L65)):
```sql
ap.BudgetUSD / 12.0
```

**Problem**: This assumes every project spans exactly 12 months with equal monthly allocation. For a 6-month project with a $600K budget, this produces $50K/month instead of $100K/month. Projects with variable monthly allocations are also misrepresented.

**Disposition — Preserved**: The dbt model [fct_project_monthly.sql](/hometask_dbt_project/models/marts/fct_project_monthly.sql) replicates `budget_usd / 12.0`.

**Note**: Consider replacing this with actual project duration:
> ```sql
> budget_usd / nullif(project_duration_months, 0)
> ```
> or pulling from a dedicated budget-allocation table if monthly budgets vary.

---

# Task 1: Model Decomposition Rationale

To refactor the legacy T-SQL stored procedure into a clean, maintainable dbt architecture, we adopted a standard layered design. We mapped each step of the original procedure to a distinct layer based on functional responsibility:

*   **Staging Layer (`stg_projects`, `stg_timesheet_entries`, `stg_employees`):** 
    Acts as thin, 1:1 views over raw sources. This layer handles foundational data cleanup, including field renaming to `snake_case`, null handling, and type casting.
*   **Intermediate Layer (`int_active_projects`, `int_monthly_hours`, `int_employee_snapshot`):** 
    Directly mirrors the procedure’s temporary tables (`#ActiveProjects`, `#MonthlyHours`, `#EmployeeSnapshot`). This isolates complex business logic—such as project lifecycle filtering, snapshot-month time boundaries, and timesheet aggregation—into modular, highly testable components.
*   **Marts Layer (`fct_project_monthly`):** 
    Serves as the clean, published table. It performs the final multi-way join across the intermediate models and executes the monthly budget calculations.

**Architectural Benefits:** 
This separation of concerns decouples raw data ingestion from transformation logic and eliminates the side effects common in monolithic stored procedures. Ultimately, it ensures that every business rule can be independently tested, version-controlled, and reused across the wider project.
---

# Task 2: Star Schema Design — Project Profitability

## Schema Overview

```
dim_client ──┐
dim_office ──┤
dim_project ─┼── fct_timesheet_monthly ──┬── dim_employee (SCD2)
dim_date ────┘                           │
                                         └── report_month
```

| Model | Grain | PK | Type |
|---|---|---|---|
| `dim_project` | 1 row/project | `project_key` | Type 1 |
| `dim_employee` | 1 row/employee version | `employee_key` | SCD Type 2 |
| `dim_client` | 1 row/client | `client_key` | Type 1 (stub) |
| `dim_office` | 1 row/office | `office_key` | Type 1 (stub) |
| `dim_date` | 1 row/month | `date_key` | Generated spine |
| `fct_timesheet_monthly` | project × employee_version × month | composite | Fact |

## Design Rationale

**Why this grain?** The fact grain is `(project, employee_version, month)`. Monthly aggregation balances query performance for dashboard-level reporting against 5M rows/year, while preserving the ability to slice by client, PM, office, and month. The employee_version dimension—not just employee_id—is part of the grain so mid-month role changes produce separate rows with accurate attributes.

**Role-at-time-of-work:** Each timesheet entry is joined to `dim_employee` using `entry_date BETWEEN valid_from AND valid_to`. Since the source already provides SCD Type 2 history, we consume it directly rather than capturing snapshots ourselves. This guarantees the dashboard shows the employee's role and team as they were when the work was performed.

**Trade-off:** We denormalize `client_key` and `office_key` onto the fact (from `dim_project`) for direct slicing without multi-hop joins. This duplicates data but eliminates a join in every dashboard query—a worthwhile trade for a PMO audience that filters heavily by client and office.

---

# AI Collaboration & Usage

This project was built with the assistance of an AI coding assistant (Antigravity) as an interactive pair-programming partner. Key areas where AI was leveraged include:

1. **Legacy Code Analysis & Refactoring (Task 1)**:
   - Audited the legacy T-SQL stored procedure (`sp_LoadFactProjectMonthly`) to identify anti-patterns (such as `NOLOCK` dirty reads, non-atomic `DELETE`+`INSERT`, and `GETDATE()` non-determinism).
   - Structured the procedural logic into a clean, 3-tier dbt model architecture (`staging`, `intermediate`, `marts`).

2. **Star Schema Data Modeling (Task 2)**:
   - Co-designed the Project Profitability star schema (`dim_project`, `dim_employee` SCD Type 2, `dim_client`, `dim_office`, `dim_date`, and `fct_timesheet_monthly`).
   - Formulated the point-in-time join logic (`entry_date BETWEEN valid_from AND valid_to`) to preserve employee role and team attributes at the exact time work was performed.

3. **Automated Testing & Quality Control**:
   - Generated dbt YAML schema test definitions covering uniqueness, not-null constraints, and referential integrity relationships across dimensions and facts.
   - Designed and implemented custom singular tests (e.g., enforcing `hours per employee per day ≤ 24`).

4. **Environment Setup & Troubleshooting**:
   - Diagnosed and corrected database adapter configuration issues in `~/.dbt/profiles.yml`.
   - Verified pipeline execution via `dbt compile`, `dbt build`, and `dbt test` against PostgreSQL.

