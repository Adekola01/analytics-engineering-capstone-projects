# Architecture Diagram — Engagement 04

```mermaid
flowchart LR
    subgraph SRC["Source systems (Snowflake RAW schema)"]
        RA[(RAW_APPLICATIONS)]
        RL[(RAW_LOANS)]
        RR[(RAW_REPAYMENTS)]
        RD[(RAW_DEFAULTS)]
    end

    subgraph STG["Staging — views, 1:1 with source, no business logic"]
        SA[stg_applications]
        SL[stg_loans]
        SR[stg_repayments]
        SD[stg_defaults]
    end

    subgraph INT["Intermediate — ephemeral, dedup + the repayment pipeline"]
        IRD[int_repayments_deduped\n dedupe gateway double-posts]
        ILD[int_loan_delinquency\n oldest missed instalment -> true_dpd]
        ILR[int_loan_register_status\n collapse register to 1 row/loan]
    end

    subgraph MART["Marts — tables, business definitions applied"]
        FLP[fct_loan_performance\n loan grain, active book\n THE shared mart]
        FPM[fct_portfolio_metrics\n PAR30/90, restructure rate,\n partial-payment rate by product]
        FRB[fct_par_reconciliation_bridge\n reported PAR to true PAR]
    end

    RA --> SA
    RL --> SL
    RR --> SR
    RD --> SD

    SR --> IRD
    IRD --> ILD
    SD --> ILR

    SL --> FLP
    ILD --> FLP
    ILR --> FLP

    FLP --> FPM
    FLP --> FRB

    FLP -.tests: DPD/outstanding ranges.-> DQ1[["dbt tests"]]
    FRB -.business-rule: ties to true PAR.-> DQ1
    FRB -.business-rule: true PAR >= reported PAR.-> DQ1
```

**Layering rules (enforced, see RUBRIC.md "Architecture & modeling"):**
- Staging: `materialized: view`, pure rename/cast, zero business logic.
- Intermediate: `materialized: ephemeral`, dedup + the repayment-ledger-to-
  delinquency-state pipeline — this is where "what counts as missed" logic
  lives, but not yet "what counts as at-risk."
- Marts: `materialized: table`, DPD thresholds and the active-book filter
  are applied here.
- `stg_applications` is intentionally NOT wired into the loan-performance
  pipeline — loans, not applications, are the entry point for PAR. It's
  modeled and tested (per the source data being provided) but not a
  dependency of any downstream risk mart, and that's a deliberate scoping
  choice, not an oversight.
