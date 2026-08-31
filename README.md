# Analytics Engineering Fellowship — Capstone Submissions

Four end-to-end analytics engineering consulting engagements, each built as
a layered dbt project (staging → intermediate → marts) against a
deliberately imperfect dataset, with a full documentation suite defending
every definitional decision made along the way.

## Engagements

| # | Engagement | Domain |
|---|---|---|
| [01](./01-ecommerce-revenue-leakage) | E-Commerce Revenue Leakage | Retail / Finance 
| [04](./04-fintech-loan-portfolio) | Fintech Loan Portfolio | Lending 
| [05](./05-healthcare-appointment-analytics) | Healthcare Appointment Analytics | Healthcare 
| [08](./08-hr-workforce-analytics) | HR Workforce Analytics | People Ops 

## What's in each engagement folder

```
NN-engagement-name/
├── README.md            ← how to run the generator + dbt build to validate
├── dbt/                 ← the full dbt project (staging/intermediate/marts, tests)
└── docs/                ← assumptions log, source-to-target map, architecture
                            diagram, business metric definitions, data quality
                            framework, orchestration design, exec summary,
                            deck outline
```

Every engagement follows the same architecture: staging views (light
casting only) → ephemeral intermediate models (dedup + joins) → materialized
table marts (business definitions applied), with a named reconciliation
bridge walking from the "naive"/reported number to the ledger-true number,
and at least 4 business-rule tests enforcing it never silently regresses.

## Validation

Each engagement's own `README.md` has exact commands to run the data
generator against a Snowflake sandbox and `dbt build` the project.
