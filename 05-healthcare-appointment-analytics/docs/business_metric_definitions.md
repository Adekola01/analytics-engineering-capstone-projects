# Business Metric Definitions — Engagement 05

Each metric below is a contract: one definition, one owner model, one column.

| Metric | Definition | Model.column | Grain |
|---|---|---|---|
| **Naive no-show rate** | Every row whose raw `STATUS` says `no_show`/`missed`/`no-show`, duplicates included, over every raw booked slot. This is the ~22% "ops dashboard" number — reported for comparison, never used for decisions. | `fct_noshow_reconciliation_bridge.naive_no_show_rate` | location / ALL |
| **True no-show rate** | Kept-intent visits (canonical final outcome `attended` or `no_show`, reschedule chains collapsed) where the final outcome is `no_show`, over kept-intent visits. This is the ~13% number — the one to run the initiative against. | `fct_appointments.is_true_no_show` (row) / `fct_patient_engagement.true_no_show_rate` (patient) / `fct_noshow_reconciliation_bridge.true_no_show_rate` (location) | visit / patient / location |
| **Reschedule rate** | Share of logical visits with `reschedule_count > 0`, over all logical visits. | `fct_patient_engagement.reschedule_rate` | patient |
| **Cancellation rate** | Share of logical visits whose final outcome is `cancelled`, over all logical visits. | `fct_patient_engagement.cancellation_rate` | patient |
| **Attended rate** | Share of kept-intent visits whose final outcome is `attended`. | `fct_patient_engagement.attended_rate` | patient |
| **No-show risk segment** | `high_risk` (2+ true no-shows, or a true no-show rate ≥34%), `moderate_risk` (exactly 1), `low_risk` (0), `no_kept_intent_history` (only cancellations/no data). The COO's actionable segment for the reduction initiative. | `fct_patient_engagement.no_show_risk_segment` | patient |
| **Reschedule misflags** | Rows with a validated forward reschedule link that were still keyed `no_show`/`missed` — the largest single component of the gap. | `fct_noshow_reconciliation_bridge.reschedule_misflags` | location / ALL |
| **Cancel misflags** | Rows with a `CANCEL_REASON` that were still keyed `no_show`/`missed`. | `fct_noshow_reconciliation_bridge.cancel_misflags` | location / ALL |
| **The gap (bridge)** | `naive_no_show_count` − duplicates − reschedule misflags − cancel misflags = `true_no_show_count`. | `fct_noshow_reconciliation_bridge.bridged_true_no_show_count` | location / ALL |

## What each stakeholder should query

- **COO / board deck:** `fct_noshow_reconciliation_bridge` where `location = 'ALL'` — the single walked number, plus the bridge that explains it.
- **VP of Clinical Operations:** `fct_appointments` filtered to `is_true_no_show = true`, or the per-location rows in the bridge — "which locations, which providers, which appointment types."
- **Patient Access Manager:** `reschedule_misflags`/`cancel_misflags` by location in the bridge — the direct, quantified front-desk-keying finding to take back to each site.
- **Director of Revenue Cycle:** `fct_appointments.has_no_show_fee_charge`/`has_office_visit_charge` alongside `final_canonical_status` — billing as corroboration, never as the attendance answer.
