# Business Metric Definitions — Engagement 08

Each metric below is a contract: one definition, one owner model, one column.

| Metric | Definition | Model.column | Grain |
|---|---|---|---|
| **Active headcount** | Distinct persons whose most recent employment record is open as of the as-of date. | `fct_workforce.is_currently_active` (row) / `fct_department_workforce.active_headcount` (dept) | person / department / ALL |
| **Attrition rate (true, annualized)** | Genuine exits (excludes transfers and duplicates) in the trailing window ÷ average headcount (beginning + ending over 2). | `fct_attrition_tenure_reconciliation_bridge.true_attrition_rate` | company, trailing window |
| **Attrition rate (naive, Finance's)** | Every closed employment record (duplicates and transfers included) in the window ÷ average headcount. Reported for comparison only — never for decisions. | `fct_attrition_tenure_reconciliation_bridge.naive_finance_attrition_rate` | company, trailing window |
| **Average tenure — time-in-seat (RECOMMENDED)** | Sum of every record's own active span, per person, averaged over active headcount. Excludes rehire gaps, continuous across transfers. | `fct_workforce.tenure_time_in_seat_years` (row) / `fct_attrition_tenure_reconciliation_bridge.avg_tenure_time_in_seat_years` (company) | person / company |
| **Average tenure — since first hire (Talent's naive claim)** | Calendar span from first-ever hire to now/exit. Includes any rehire gap as if continuously employed. | `fct_workforce.tenure_since_first_hire_years` | person / company |
| **Average tenure — current stint (Finance's naive claim)** | Latest employment record's own span only. Resets on either a transfer or a rehire. | `fct_workforce.current_stint_span_years` | person / company |
| **Rehire rate** | Share of people whose employment history includes at least one rehire successor. | `fct_workforce.had_rehire` | person |
| **Internal-mobility rate** | Share of people whose employment history includes at least one transfer. | `fct_workforce.had_transfer` | person |
| **Transfers in / out** | Count of transfer successions opening in / employment records closing as `transferred_out` in a department, within the window. Must net to zero company-wide. | `fct_department_workforce.transfers_in` / `.transfers_out` | department |
| **The gap (bridge)** | `naive_record_closures` − duplicate closures − transfer closures = `true_genuine_exits`. | `fct_attrition_tenure_reconciliation_bridge.bridged_true_genuine_exits` | company, trailing window |

## What each stakeholder should query

- **CPO / board deck:** `fct_attrition_tenure_reconciliation_bridge` — the single walked number for both attrition and tenure, plus the bridge that explains each.
- **VP of Talent:** `fct_workforce.tenure_time_in_seat_years`, `had_rehire`, `had_transfer` — the person-based view that doesn't punish someone for a transfer or erase their prior stint on rehire.
- **Head of Finance / FP&A:** `fct_department_workforce` — headcount and attrition correctly attributed by cost center, with transfers shown as movement (not exits) so cost-center totals still tie to payroll headcount.
- **Data Lead:** `is_status_date_conflict` (int layer), `is_missing_review_date`, `is_duplicate_record`/`is_duplicate_period`/`is_duplicate_review` — the exact source-system issues that need fixing upstream.
