# Deck Outline — Engagement 04 (10 slides)

**Audience:** CRO, Head of Credit Risk, Head of Collections — plus, per the
brief's framing, this needs to survive a due-diligence lender's scrutiny too.

---

**1. Title & framing**
"One PAR Number You Can Sign Your Name To." Direct answer to the CRO's own
words from kickoff.

**2. The situation as stated to us**
CRO's, Head of Collections', and Head of Credit Risk's quotes, side by side.
Establishes we heard both sides — and that they disagree — before we modeled.

**3. The real question**
Five definitional questions from BRIEF.md §3, framed as decisions the room
gets to see, not black-box outputs.

**4. What we found in the raw data**
Plainly stated: partial payments, gateway double-posts, and — the important
one — the restructuring clock reset. No jargon.

**5. One mart, two views**
`fct_loan_performance` in the middle: `loan_status`/register membership
(servicer's/Collections' view) branching one way, `true_dpd`/`risk_bucket`
(ledger-computed) branching the other.

**6. The bridge — reported PAR to true PAR**
The reconciliation bridge, walked live for the whole book: start at
reported PAR, add hidden restructure risk, add unregistered delinquents,
subtract stale entries, land exactly on true PAR.

**7. The headline finding: hidden restructure risk**
Loan count, outstanding value, and — if time allows — two or three
representative examples (loan restructured, ledger shows 90+ DPD again,
never re-entered the register).

**8. Why this keeps happening**
The mechanism, not just the symptom: restructuring resets the visible clock
and effectively removes the loan from watch-list logic. Ends with a
process recommendation, not just a data footnote.

**9. Data quality & what happens if this breaks**
The four business-rule tests in plain language — especially
"true PAR must never fall below reported PAR," framed as the regression
guard against ever silently re-adopting the register as truth.

**10. What's fixed vs. what still needs a process change**
Two-column list from `exec_summary.md`. Ends with a clear ask: a
restructuring review trigger, not just "trust this new number instead."

*(Optional 11th slide: known limitations — outstanding-balance estimate,
currency — framed as "next phase.")*
