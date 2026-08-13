# Week 2 Post-Migration Feedback Review
**Date:** 2026-08-12
**Analyst:** DWP Post-Migration Review
**Source:** 40 FinBridge staff comments — Week 2 follow-up survey

---

## Summary

Week 2 shows significant recovery on the three issues prioritised last week. However one issue from Week 1 remains completely unresolved, and one new issue has emerged that is escalating quickly.

---

## What Has Been Resolved

| Theme | Week 1 Count | Week 2 Confirmation Comments | Status |
|---|---|---|---|
| Account Lockout & Auth Failures | 7 | 1, 7, 12, 15, 19, 22, 29, 34, 36 — **9 comments confirming fix** | ✅ Resolved |
| OneDrive Files Missing | 4 | 3, 11, 21, 26, 32, 39 — **6 comments confirming fix** | ✅ Resolved |
| VPN Instability | 4 | 10, 27, 36 — **3 comments confirming stable** | ✅ Resolved |

---

## Still Unresolved — Now Escalating

### Floor 3 Printer Not Mapping
**Week 2 count:** 10 comments (IDs: 2, 5, 9, 14, 18, 23, 28, 31, 35, 40)
**Severity:** Blocker — now entering a third week for some users
**Trend:** Worsening. Staff tone has shifted from frustrated to resigned, with multiple users threatening manager escalation and calling for the printer to be physically replaced.

Representative quotes:
- *"Floor 3 printer -- genuinely considering escalating this to my manager."*
- *"Printer on floor 3 -- at this point just send us a new printer."*
- *"Floor 3 printer is now a running joke on our team, still broken."*

**Action required:**
This has moved beyond a configuration issue in perception. A visible, in-person update or hardware replacement decision is needed today to prevent formal escalation.

---

## New Issue — Requires Immediate Triage

### Excel Crashing on Large Files
**Week 2 count:** 9 comments (IDs: 4, 8, 13, 16, 20, 24, 30, 33, 37)
**Severity:** Blocker — users are losing unsaved work
**Who is affected:** Finance team confirmed; files over ~10MB trigger the crash
**Trend:** Emerging fast. Nine comments in the first week of reports suggests this will grow.

Representative quotes:
- *"Excel crash is really disruptive, losing unsaved work each time."*
- *"Excel crashing has become a real productivity problem for finance team."*
- *"New Excel crash issue — happens specifically with files over 10MB."*

**Likely cause area:** Memory allocation or compatibility issue between the new Win11 build and the installed version of Microsoft 365 / Excel. The 10MB file-size trigger is a useful diagnostic detail for the engineering team.

**Action required:**
Raise as a Priority 1 ticket immediately. Finance team using large budget spreadsheets is a business-critical workflow. Interim advice: enable AutoSave to OneDrive to reduce data loss while the fix is investigated.

---

## Week 2 Overall Sentiment

| Category | Comment Count |
|---|---|
| Confirmed resolved / positive | 21 |
| Floor 3 printer (persisting Blocker) | 10 |
| Excel crash (new Blocker) | 9 |

**Total comments: 40**

---

## Recommended Actions for Today

1. **Excel crash** — Raise P1 ticket; send interim AutoSave guidance to finance team now
2. **Floor 3 printer** — Make a decision: engineer on-site today or hardware replacement; communicate a visible update to the floor 3 team directly
