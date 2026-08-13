# User Logon Incident Differential Analysis (Scope-Only)

Date: 2026-08-13  
Analyst: DWP Engineering

## Scope Facts
- Symptom: user cthompson not able to login.
- Who: cthompson only (single-user impact).
- Since: approximately 08:40 this morning.
- Change: nil.

## Differential Ranking (Most Probable First)

1) User-specific identity credential issue (bad password, expired password, lockout)
- Why this fits scope facts:
  - Single-user-only impact strongly favors a user-specific identity problem.
  - No reported platform change reduces likelihood of system-wide regression.
- Single fastest check:
  - Check latest identity sign-in log for cthompson failure reason (invalid credentials, lockout, password expired).

2) Conditional access or MFA challenge failure for cthompson
- Why this fits scope facts:
  - Can block only one user based on policy state, device state, location, or challenge completion.
  - No global change is required for a per-user policy enforcement outcome.
- Single fastest check:
  - Review cthompson's most recent sign-in decision details for CA/MFA deny or unmet requirement.

3) Missing or changed user entitlement to target desktop/app
- Why this fits scope facts:
  - Authentication may succeed while service access fails for one user if assignment/group mapping is wrong.
  - Single-user scope aligns with accidental de-assignment or group membership drift.
- Single fastest check:
  - Verify cthompson is currently assigned to the required workspace/app group/host pool access group.

4) Profile initialization failure specific to cthompson (for example profile attach/load failure)
- Why this fits scope facts:
  - Can present as login failure for one user while others remain healthy.
  - No infrastructure change is needed for a user profile corruption/attach issue.
- Single fastest check:
  - On target session host, inspect profile-related events for cthompson at approximately 08:40.

5) Client-side issue on cthompson endpoint (cached token/client corruption/network edge case)
- Why this fits scope facts:
  - Single-user and no backend change can indicate endpoint-specific client state failure.
  - Often appears suddenly at a specific time with no shared blast radius.
- Single fastest check:
  - Attempt login for cthompson from alternate client path (web client or second device/network) to isolate endpoint vs service.

## Position Statement
Do not commit to a single root cause yet.  
Start with identity sign-in failure reason, then CA/MFA decision trace, then entitlement verification, because these three checks most quickly separate user-auth, policy, and access-assignment paths.
