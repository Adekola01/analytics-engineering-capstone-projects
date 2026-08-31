# Architecture Diagram — Engagement 05

```mermaid
flowchart LR
    subgraph SRC["Source systems (Snowflake RAW schema)"]
        RP[(RAW_PATIENTS)]
        RDoc[(RAW_DOCTORS)]
        RA[(RAW_APPOINTMENTS)]
        RB[(RAW_BILLING)]
    end

    subgraph STG["Staging — views, 1:1 with source, no business logic"]
        SP[stg_patients]
        SD[stg_doctors]
        SA[stg_appointments]
        SB[stg_billing]
    end

    subgraph INT["Intermediate — ephemeral, the canonicalization + chain pipeline"]
        IAD[int_appointments_deduped\n dedupe double-submitted bookings]
        IAC[int_appointments_canonical\n cancel/reschedule-misflag priority logic]
        IACh[int_appointment_chains\n recursive walk -> logical visit]
        IBA[int_billing_agg\n corroborating signal only]
    end

    subgraph MART["Marts — tables, business definitions applied"]
        FA[fct_appointments\n logical-visit grain\n THE shared mart]
        FPE[fct_patient_engagement\n patient grain,\n no-show risk segment]
        FRB[fct_noshow_reconciliation_bridge\n naive 22% to true 13%]
    end

    RP --> SP
    RDoc --> SD
    RA --> SA
    RB --> SB

    SA --> IAD
    IAD --> IAC
    IAC --> IACh
    SB --> IBA

    IACh --> FA
    IAC --> FA
    IBA --> FA

    FA --> FPE
    IAC --> FRB
    FA --> FRB

    FA -.tests: one canonical status per row,\nno double-counted intent.-> DQ1[["dbt tests"]]
    FRB -.business-rule: ties to fct_appointments.-> DQ1
    FA -.business-rule: billing never contradicts status.-> DQ1
```

**Layering rules (enforced, see RUBRIC.md "Architecture & modeling"):**
- Staging: `materialized: view`, pure rename/cast, zero business logic —
  notably, raw status synonyms (`no_show`/`missed`/`no-show`) are **not**
  collapsed here; that's canonicalization, a business decision.
- Intermediate: `materialized: ephemeral`. This is where the actual
  engagement lives — dedup, then canonicalize (dedup must run first, see
  assumptions_log.md A4), then resolve chains, in that dependency order.
- Marts: `materialized: table`. Grain-defining decisions (logical visit,
  patient) and denominator choices are applied here.
- `int_billing_agg` is a parallel branch that never feeds
  `int_appointments_canonical`/`int_appointment_chains` — billing joins in
  only at the very end, in `fct_appointments`, strictly as a corroborating
  column set (assumptions_log.md A6).
