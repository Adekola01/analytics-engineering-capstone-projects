# Deck Outline — Engagement 05 (10 slides)

**Audience:** COO, VP Clinical Operations, Director of Revenue Cycle,
Patient Access Manager — three of whom actively disagree going in.

---

**1. Title & framing**
"One No-Show Number, Traced Line by Line." Direct answer to the COO's
own words: "I can't run an initiative against a number I don't trust."

**2. The situation as stated to us**
COO's, VP Clinical Ops', Patient Access Manager's, and Director of Revenue
Cycle's quotes, side by side. Establishes we heard all four — and that they
genuinely conflict — before we modeled.

**3. The real question**
Five definitional questions from BRIEF.md §3, framed as decisions the room
gets to see.

**4. What we found in the raw data**
Plainly stated: inconsistent status keying across locations, the
reschedule-misflag pattern, the duplicate-booking bug, and why the link
columns looked untrustworthy (and why they actually aren't, once
sequenced correctly).

**5. One mart, two views**
`fct_appointments` in the middle: raw/naive status branching one way,
canonical status + resolved chains branching the other.

**6. The bridge — 22% to 13%**
The reconciliation bridge, walked live for the whole portfolio: start at
the naive count, subtract duplicates, subtract reschedule misflags,
subtract cancel misflags, land exactly on the true count.

**7. The headline finding: reschedule misflags**
Count, rate, and the by-location breakdown — this is the one the Patient
Access Manager can act on directly, site by site.

**8. "Rescheduled twice then attended — how many no-shows?"**
Walk one real chain from the data, end to end, landing on zero. Answers
the rubric's own defense question directly, in the room.

**9. Data quality & what happens if this breaks**
The four business-rule tests in plain language — especially the
no-double-counting guard and the billing-never-contradicts-status check.

**10. What's fixed vs. what needs a front-desk fix**
Two-column list from `exec_summary.md`. Ends with a clear ask: a
consistent close-out rule at the front desk, not just "trust this new
number instead."

*(Optional 11th slide: known limitation — reschedule-to-no-show
conversion as a follow-on metric — framed as "next phase.")*
