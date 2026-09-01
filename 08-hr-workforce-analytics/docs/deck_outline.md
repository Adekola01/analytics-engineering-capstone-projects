# Deck Outline — Engagement 08 (10 slides)

**Audience:** CPO, VP of Talent, Head of Finance / FP&A — the CPO is caught
between the other two, and needs to leave the room able to tell the board
one number, not referee a dispute live.

---

**1. Title & framing**
"One Workforce Number, Two Teams Can Both Sign." Direct answer to the
CPO's own words: "I genuinely cannot tell them, and that is not
acceptable."

**2. The situation as stated to us**
CPO's, VP Talent's, and Head of Finance's quotes, side by side. Establishes
we heard both sides — and that both are partly right — before we modeled.

**3. The real question**
Six definitional questions from BRIEF.md §3, framed as decisions the room
gets to see.

**4. What we found in the raw data**
Plainly stated: the HRIS closes a record on both a transfer AND a genuine
exit, status/date conflicts, duplicate records from the 2021 migration.
No jargon.

**5. One mart, two views**
`fct_workforce` in the middle: Finance's record-based instincts (current
stint, closed records) branching one way, Talent's person-based view
(time-in-seat, transfer history) branching the other.

**6. The bridge — Finance's number to Talent's number**
The reconciliation bridge, walked live: start at the naive record-closure
count, subtract duplicates, subtract transfer closures, land exactly on
the true, person-based exit count.

**7. The headline finding: transfers miscounted as exits**
Size it. This is the single largest driver of the 22–33% spread, and it's
the one both Talent and the CPO can act on immediately once it's visible.

**8. "Walk me from Finance's number to Talent's number" — live**
Pick one real person from the data: an original hire, a transfer, and
(separately) another person with a genuine rehire gap. Walk both all the
way through the model, landing on the same, agreed tenure and attrition
treatment. Answers the rubric's own defense questions directly, in the room.

**9. Data quality & what happens if this breaks**
The four business-rule tests in plain language — especially the two
RUBRIC.md names explicitly: transfers net to zero, department headcount
sums to company total.

**10. What's fixed vs. what needs a source-system fix**
Two-column list from `exec_summary.md`. Ends with a clear ask: a proper
transfer event type at the source, not just "trust this new number
instead."

*(Optional 11th slide: known limitation — payroll cost normalization as
a follow-on phase.)*
