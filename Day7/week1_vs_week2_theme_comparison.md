# Week 1 vs Week 2 Theme Comparison
**Date:** 2026-08-12
**Analyst:** DWP Post-Migration Review

---

## Week 1 Themes — Status in Week 2

---

### 1. Account Lockout & Authentication Failures
**Week 1:** 7 comments | Blocker
**Week 2 status:** ✅ Resolved

**Evidence from Week 2:**
Nine separate comments confirm the fix — users specifically called out that lockouts have stopped and login speed is back to normal.
- *"Account lockouts have completely stopped, appreciate the fix."* (W2-19)
- *"Login and lockout issues from week 1 are fully resolved for me."* (W2-34)
- *"Login fast and reliable this week."* (W2-22)

---

### 2. VPN Instability
**Week 1:** 4 comments | Blocker
**Week 2 status:** ✅ Resolved

**Evidence from Week 2:**
Three direct confirmations that VPN is now stable — no drop reports in the entire week 2 dataset.
- *"VPN has been rock solid this week, no complaints."* (W2-10)
- *"VPN stable, no drops this week at all."* (W2-27)

---

### 3. Floor 3 Printer Not Mapping
**Week 1:** 6 comments | Friction (workaround: floor 2)
**Week 2 status:** 🔴 Worsening

**Evidence from Week 2:**
10 comments — up from 6 in Week 1. Tone has shifted from frustrated to resigned and confrontational. One user notes this is now entering **week 3**. Multiple users are threatening manager escalation or requesting hardware replacement.
- *"Floor 3 printer unresolved for two weeks running now, needs escalation."* (W2-40)
- *"Floor 3 printer still not mapped automatically, third week now actually."* (W2-23)
- *"Printer floor 3 is now a running joke on our team, still broken."* (W2-18)

---

### 4. Shared Drive (S:) Access Denied
**Week 1:** 3 comments | Blocker
**Week 2 status:** ✅ Resolved

**Evidence from Week 2:**
Zero mentions of S: drive access issues across all 40 comments. The complete absence of complaints, combined with general positive sentiment comments (W2-6, W2-17, W2-25, W2-38), indicates this has been resolved.

---

### 5. OneDrive Files Missing or Sync Errors
**Week 1:** 4 comments | Blocker
**Week 2 status:** ✅ Resolved

**Evidence from Week 2:**
Six comments explicitly confirm files are present and sync is working — the highest resolution confirmation count of any Week 1 issue.
- *"OneDrive files all showing up fine now."* (W2-3)
- *"Files all present, sync working as expected."* (W2-32)
- *"OneDrive fully working, no more missing file reports from me."* (W2-39)

---

### 6. Slow Login / Profile Load Performance
**Week 1:** 3 comments | Friction
**Week 2 status:** ✅ Resolved

**Evidence from Week 2:**
Login speed is directly called out as restored across multiple comments. This theme has merged into the broader auth recovery signal.
- *"Login is back to normal now, thanks for the fix!"* (W2-1)
- *"Login speed is back to what it used to be, thank you."* (W2-12)

---

### 7. Start Menu & App Navigation Confusion
**Week 1:** 4 comments | Friction
**Week 2 status:** ✅ Resolved (by absence)

**Evidence from Week 2:**
No comments raise start menu, search, or app navigation issues. Users appear to have adapted or the issue self-resolved with familiarity.

---

### 8. UI & Desktop Personalisation Changes
**Week 1:** 10 comments | Minor
**Week 2 status:** ✅ Resolved (by absence)

**Evidence from Week 2:**
No cosmetic or personalisation complaints raised in Week 2. Consistent with the expectation that these were one-time disruptions resolved by users re-applying their preferences.

---

---

## New Theme in Week 2 — Not Present in Week 1

### ⚠️ Excel Crashing on Large Files
**Week 2 count:** 9 comments (IDs: 4, 8, 13, 16, 20, 24, 30, 33, 37)
**Severity:** Blocker
**Affected group:** Finance team confirmed; trigger identified as files over ~10MB

**This theme did not appear in any Week 1 comment.** It is emerging fast — 9 reports in the first week of occurrence is the same volume as the printer issue at its peak. Users are losing unsaved work, and the finance team is specifically named as impacted, making this a business-critical risk.

- *"Excel crash is really disruptive, losing unsaved work each time."* (W2-13)
- *"New Excel crash issue — happens specifically with files over 10MB."* (W2-33)
- *"Excel crashing has become a real productivity problem for finance team."* (W2-20)

**Recommended action:** Raise as Priority 1. The file-size trigger (10MB) is a strong diagnostic signal to share with the engineering team. Issue interim AutoSave guidance to finance staff immediately to reduce data loss while the fix is investigated.

---

## At-a-Glance Summary

| Week 1 Theme | W1 Count | W2 Status | W2 Evidence Count |
|---|---|---|---|
| Account Lockout & Auth | 7 | ✅ Resolved | 9 confirmations |
| VPN Instability | 4 | ✅ Resolved | 3 confirmations |
| Floor 3 Printer | 6 | 🔴 Worsening | 10 complaints (up from 6) |
| Shared Drive S: Access | 3 | ✅ Resolved | 0 complaints |
| OneDrive Files Missing | 4 | ✅ Resolved | 6 confirmations |
| Slow Login Performance | 3 | ✅ Resolved | Multiple confirmations |
| Start Menu Navigation | 4 | ✅ Resolved (by absence) | 0 complaints |
| UI / Desktop Changes | 10 | ✅ Resolved (by absence) | 0 complaints |
| **Excel Crash (NEW)** | — | 🔴 **New Blocker** | **9 complaints, week 1 of reports** |
