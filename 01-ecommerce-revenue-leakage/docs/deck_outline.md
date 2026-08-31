# Deck Outline — Engagement 01 (10 slides)

**Audience:** VP of Finance, Head of Operations, Data Lead. They disagree
going in — the deck's job is to get them to a shared number without either
side feeling overruled.

---

**1. Title & framing**
"Why Finance and Ops See Different Numbers — And What We're Doing About It."
One line: this was never a bug, it was two undocumented definitions.

**2. The situation as stated to us**
VP Finance's and Head of Ops' quotes from kickoff, side by side. Let them
recognize their own words — establishes we listened before we modeled.

**3. The real question**
"When is revenue real?" — five definitional questions from BRIEF.md §3, framed
as decisions, not bugs.

**4. What we found in the raw data**
Four data-quality issues, plainly stated (retried/failed payments, gateway
double-logs, partial + lagged refunds, missing shipping timestamps). No
jargon — this slide is for the whole room, not just the Data Lead.

**5. One mart, two views**
Diagram: `fct_revenue` in the middle, Finance's cash-basis columns branching
one way, Ops' fulfillment-basis columns branching the other. This is the
"nobody has to give up their number" slide.

**6. The bridge — walking Ops' number to Finance's number**
The reconciliation bridge table, one row (their most recent closed month),
walked live: start at Ops' number, add WIP, add cancellation leakage,
subtract duplicates, subtract refunds, land exactly on Finance's number.

**7. The headline finding: cancellation leakage**
Dollar amount, order count, trend. Framed as a decision needed from the
room (refund it or write it off) — not just a data footnote.

**8. Why the gap moves month to month**
Refund timing lag, visualized. Answers the VP's "it changes month to month"
complaint directly — this is expected mechanics now, not mystery.

**9. Data quality & what happens if this breaks**
The four business-rule tests, in plain language, and the "blue-green swap"
story — the board never sees a wrong number, even transiently.

**10. What's fixed vs. what still needs source-system work**
Two-column list from `exec_summary.md`. Ends with a clear ask, not just a
report.

*(Optional 11th slide: known limitations — currency, refund-reason
breakdown — framed as "next phase," not omissions.)*
