# Architecture Diagram — Engagement 01

```mermaid
flowchart LR
    subgraph SRC["Source systems (Snowflake RAW schema)"]
        RO[(RAW_ORDERS)]
        RP[(RAW_PAYMENTS)]
        RR[(RAW_REFUNDS)]
        RS[(RAW_SHIPPING)]
    end

    subgraph STG["Staging — views, 1:1 with source, no business logic"]
        SO[stg_orders]
        SP[stg_payments]
        SR[stg_refunds]
        SS[stg_shipping]
    end

    subgraph INT["Intermediate — ephemeral, dedup + joins"]
        IPD[int_payments_deduped\n dedupe gateway double-logs]
        IOF[int_order_financials\n one row per order,\n payments+refunds+shipping joined]
    end

    subgraph MART["Marts — tables, business definitions applied"]
        FR[fct_revenue\n order grain\n THE shared mart]
        FRM[fct_revenue_monthly\n Finance board metrics]
        FRB[fct_revenue_reconciliation_bridge\n Ops number to Finance number]
    end

    RO --> SO
    RP --> SP
    RR --> SR
    RS --> SS

    SP --> IPD
    SO --> IOF
    IPD --> IOF
    SR --> IOF
    SS --> IOF

    IOF --> FR
    FR --> FRM
    FR --> FRB

    FR -.tests: uniqueness, ranges.-> DQ1[["dbt tests"]]
    FRB -.business-rule: ties to fct_revenue.-> DQ1
    FRM -.business-rule: ties to raw ledger.-> DQ1
```

**Layering rules (enforced, see RUBRIC.md "Architecture & modeling"):**
- Staging: `materialized: view`, pure rename/cast, zero business logic, always `select * from {{ source(...) }}` as the first CTE.
- Intermediate: `materialized: ephemeral`, dedup + joins only — no metric definitions yet.
- Marts: `materialized: table`, this is where "what counts as revenue" decisions get applied.
- Every model reaches its sources exclusively through `ref()`/`source()` — never a hardcoded table name.
