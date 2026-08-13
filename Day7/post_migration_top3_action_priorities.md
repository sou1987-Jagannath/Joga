# Post-Migration Feedback — Top 3 Action Priorities
**Date:** 2026-08-12
**Analyst:** DWP Post-Migration Review
**Source:** 50 FinBridge staff comments following Win11 migration

---

## Ranking Methodology
Themes are weighted by **severity first, volume second**. A Blocker with a workaround is treated as lower severity than a Blocker with no workaround at all. Within the same severity tier, volume acts as the tiebreaker.

**Critical distinction applied here:** the floor 3 printer (6 comments) has a physical workaround — staff are walking to floor 2. That makes it operationally Friction, not a true Blocker. The S: drive and OneDrive issues have zero workaround; affected users are simply stopped.

---

## Rank 1 — Account Lockout & Authentication Failures
**Theme count:** 7 comments (IDs: 1, 11, 16, 21, 29, 37, 45)
**Severity:** Blocker — no workaround

**Why it ranks here:**
Highest-severity AND highest-volume issue. Users cannot authenticate into any system — AVD, local session, or any cloud service. Critically, this is a **repeat pattern**: multiple users report their second or third lockout within the same week, which signals a systemic policy misconfiguration rather than isolated incidents. No self-service recovery path exists, and at least one user waited 2+ hours without IT callback.

**Manager summary:**
> Seven staff are experiencing repeat account lockouts post-migration with no self-service recovery path, and the recurrence pattern strongly suggests a password policy or MFA misconfiguration that will continue to generate lockouts until the root cause is fixed.

---

## Rank 2 — OneDrive Files Missing or Sync Errors
**Theme count:** 4 comments (IDs: 14, 23, 34, 42)
**Severity:** Blocker — no workaround, data integrity risk

**Why it ranks #2 over a higher-count theme:**
Ranked above the floor 3 printer (6 comments) because missing files have **no workaround**. Users cannot retrieve their data from an alternative source. Two users face hard same-day deadlines (Q1 report, active client meeting). Even if the files are only unsynced rather than deleted, the user cannot distinguish the two — and perceived data loss triggers senior escalations. Count is secondary when the per-person impact is this acute.

**Manager summary:**
> Four users report missing OneDrive files with same-day business deadlines, and until IT confirms whether data is unsynced or lost, each affected user is completely blocked and at risk of escalating to senior leadership.

---

## Rank 3 — Shared Drive (S:) Access Denied
**Theme count:** 3 comments (IDs: 7, 18, 31)
**Severity:** Blocker — no workaround, financial system impact

**Why it ranks #3 over the printer (6 comments):**
Ranked above the floor 3 printer despite lower volume because the S: drive has **no workaround**. Staff cannot access finance shared files from any alternative path, and the affected users are explicitly blocked on month-end financial reporting — a hard business cycle deadline. The printer issue, by contrast, has a workaround that staff are already using (floor 2). Three users completely stopped on a financial close task outranks six users who are slowed but functional.

**Manager summary:**
> Three finance staff have been denied access to the S: drive since migration with no workaround available, directly blocking month-end reporting and creating a financial compliance risk if not resolved today.

---

## Themes Not in Top 3 (action today if capacity allows)
| Theme | Count | Severity | Workaround? | Note |
|---|---|---|---|---|
| Floor 3 Printer Not Mapping | 6 | Friction* | Yes — floor 2 printer | *Demoted: workaround exists. High-volume, should be resolved today regardless |
| VPN Instability | 4 | Blocker | Partial — reconnect manually | Client-facing; escalate if not resolved by EOD |
