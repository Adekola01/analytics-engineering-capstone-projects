# Architecture Diagram — Engagement 08

```mermaid
flowchart LR
    subgraph SRC["Source systems (Snowflake RAW schema)"]
        RD[(RAW_DEPARTMENTS)]
        RE[(RAW_EMPLOYEES)]
        RR[(RAW_PERFORMANCE_REVIEWS)]
        RP[(RAW_PAYROLL)]
    end

    subgraph STG["Staging — views, 1:1 with source, no business logic"]
        SD[stg_departments]
        SE[stg_employees]
        SR[stg_performance_reviews]
        SP[stg_payroll]
    end

    subgraph INT["Intermediate — ephemeral, the person-stitching pipeline"]
        IED[int_employees_deduped\n dedupe 2021 migration double-loads]
        IERR[int_employment_records_resolved\n date-authoritative status resolution]
        IECC[int_employment_chain_classified\n transfer vs rehire successor]
        IPES[int_person_employment_summary\n collapse to PERSON grain,\n 3 tenure definitions]
        IPD[int_payroll_deduped]
        IRD[int_reviews_deduped]
    end

    subgraph MART["Marts — tables, business definitions applied"]
        FW[fct_workforce\n person grain\n THE shared mart]
        FDW[fct_department_workforce\n transfers net to zero]
        FRB[fct_attrition_tenure_reconciliation_bridge\n record-based to person-based]
    end

    RD --> SD
    RE --> SE
    RR --> SR
    RP --> SP

    SE --> IED
    IED --> IERR
    IERR --> IECC
    IECC --> IPES
    SP --> IPD
    IED -.orphan check.-> IPD
    SR --> IRD
    IED -.orphan check.-> IRD

    IPES --> FW
    SD --> FW

    FW --> FDW
    IECC --> FDW
    IED --> FRB
    IERR --> FRB
    FW --> FRB

    FW -.tests: headcount reconciles\nto distinct active people.-> DQ1[["dbt tests"]]
    FDW -.business-rule: transfers net to zero,\nsums to company total.-> DQ1
    FRB -.business-rule: ties to true exits.-> DQ1
```

**Layering rules (enforced, see RUBRIC.md "Architecture & modeling"):**
- Staging: `materialized: view`, pure rename/cast, zero business logic —
  status/date reconciliation and duplicate detection are NOT done here.
- Intermediate: `materialized: ephemeral`. Strict internal order: dedupe →
  resolve status/date conflicts → classify transfer/rehire → collapse to
  person grain, each stage depending on the previous being correct first.
- Marts: `materialized: table`. Person-grain choice (A1), the attrition
  window, and department attribution rules are applied here.
- `int_payroll_deduped`/`int_reviews_deduped` are parallel branches that
  never feed the person-stitching pipeline — they only need to know which
  `employee_id`s survived dedup, checked against `int_employees_deduped`
  directly.
