# INCIDENT TRIAGE: Floor 6 Legal — Monday Morning Post-Migration Incident

**Report Time:** Monday, 08:30 local time  
**Affected Population:** Floor 6, Legal (45 users, Win11 + Intune + Friday DMS deployment)  
**Reporter:** IT Ops Lead  
**Incident Stage:** TRIAGE (First 30 minutes)  
**Classification:** MULTI-INCIDENT with common-cause potential

---

## A. TRIAGE TABLE — Executive Summary

| Rank | Incident | Severity | Blast Radius | Most Likely Cause | First Check | Owner | ETA |
|------|----------|----------|--------------|-------------------|-------------|-------|-----|
| **1 (CRITICAL)** | Unauthorized data access: Copilot surfaced confidential client matter | P0 - Legal/Confidentiality breach | 1 user (confirmed); unknown scope | DMS permission misconfiguration allowing over-broad indexing; Azure AD group membership; Copilot RAG data exposure | **Copilot enterprise data context logs + DMS permission audit** | Security/Legal | **Immediate** |
| **2 (HIGH)** | Login failures and severe slowness (12+ users, blocking work) | P1 - Availability/Productivity | 12+ users; cascading impact | Intune conditional access policy; Win11 auth cache corruption; domain trust issue post-migration | **Intune device compliance status + Azure AD sign-in logs (filter: Floor 6, 08:00–09:00)** | Identity/IAM | **15 min** |
| **3 (HIGH)** | Desktop shortcuts vanished; profile data loss | P1 - Data loss/Availability | 1 user (confirmed); likely more | Profile corruption during Win11 migration; FSLogix cache desync; DMS uninstall side-effect; local profile corruption | **FSLogix logs (Profile Volumes) + Windows Event Viewer: User Profile Service errors** | Desktop/Profile Mgmt | **20 min** |

---

## B. PER-INCIDENT DETAIL

### INCIDENT 1: UNAUTHORIZED DATA ACCESS — Copilot Surfaced Confidential Client Matter
**RANK: CRITICAL (Incident #1, MUST investigate before all others)**

#### 1.1 Symptom (Unverified Report)
Paralegal reported that Copilot (Microsoft AI assistant) displayed a confidential client matter to which the user explicitly stated she has never had access. The user can read/see client data she should not be able to view.

#### 1.2 Severity & Risk Assessment
- **Severity:** P0 — CRITICAL (potential confidentiality/privilege breach)
- **Why:** 
  - **Legal floor context:** Floor 6 = Legal dept. Client matters are subject to attorney-client privilege, GDPR, and potentially regulatory compliance obligations (e.g., data handling controls, audit trails).
  - **Data exposure vector:** If Copilot is surfacing data outside assigned permissions, this indicates systemic misconfiguration affecting unknown scope of users and documents.
  - **Compliance impact:** Unauthorized disclosure of privileged information creates liability and audit findings.
  - **Scope unknown:** If this happened to 1 user, unknown how many other users are seeing data they shouldn't.

#### 1.3 Hypothesis Ranking (Most Likely → Least Likely)

**HYPOTHESIS 1 (MOST LIKELY): DMS Permission Model Misconfigured — Overly Broad Access After Rollout**
- **Context fit:** DMS was deployed Friday afternoon; Copilot integration typically includes document indexing/RAG (Retrieval Augmented Generation) that respects or bypasses DMS permission boundaries.
- **Mechanism:** If DMS was deployed with default permissions (e.g., all Legal staff can read all documents) or Copilot's indexing crawled documents without respecting individual permission ACLs, Copilot would surface data beyond assigned permissions.
- **Data point:** The user reports seeing data she "swears she's never had access to" — suggests the DMS permission matrix is not honoring role-based access control (RBAC).
- **Likelihood:** HIGH — new app deployments frequently have permission boundary issues.

**HYPOTHESIS 2 (LIKELY): Azure AD/Entra Group Membership Over-Provisioning**
- **Context fit:** Recent Win11 migration + Intune enrollment; group membership sync issues common post-migration.
- **Mechanism:** User was added to an Azure AD group (e.g., "Legal-All-Access" or "Legal-Paralegals-HigherTier") during migration that grants broad DMS permissions; Copilot respects AAD group membership and surfaces all content for that group.
- **Data point:** Only one user reported it (so far), but unknown if others have the permission but haven't triggered Copilot search yet.
- **Likelihood:** MEDIUM-HIGH — group membership hygiene is a known post-migration risk.

**HYPOTHESIS 3 (POSSIBLE): Copilot Enterprise Search Indexing Misconfigured — No Granular Permission Enforcement**
- **Context fit:** Copilot in Microsoft 365 (enterprise version) can be deployed with weaker permission boundaries if not configured for per-user document filtering.
- **Mechanism:** DMS documents were indexed into Copilot's knowledge base without respecting individual user permissions; Copilot returns results based on broad indexing, not per-user ACL.
- **Data point:** If Copilot's indexing happened Friday night (automated post-deployment), it may have ingested all documents with default broad permissions.
- **Likelihood:** MEDIUM — depends on Copilot deployment model (consumer vs. enterprise).

**HYPOTHESIS 4 (LESS LIKELY): Client Matter Was Legitimately Assigned to User, User Forgot / Compliance Misunderstanding**
- **Context fit:** User's memory or understanding of her own permissions is incorrect.
- **Mechanism:** Document was assigned to her role/group but she didn't realize it; seeing it in Copilot triggered recall confusion.
- **Data point:** User stated definitively she "swears she's never had access" — suggests reasonable confidence, but human memory is fallible.
- **Likelihood:** LOW — but must rule out before escalating as breach.

#### 1.4 First Diagnostic Check (Discriminates Between Hypotheses 1–4)
**PRIMARY CHECK: Copilot Enterprise Activity Logs + DMS Permission Audit**

**Step 1A (5 min):** Copilot/Search Admin Center
- Query: Copilot content interaction logs for the paralegal user's session where she saw the client matter.
- Look for: What document was indexed? Who owns it? What permission ACL does it have?
- **Discriminates:** If DMS document shows owner ≠ user and no RBAC entry for user, confirms Hypothesis 1 (permission misconfiguration).

**Step 1B (10 min):** DMS Permission Audit
- Query: DMS admin console → Document Access Control → Client matter document → Who has read access?
- Look for: Is the paralegal listed? If yes, under what role? If no, she shouldn't see it (confirms unauthorized access).
- **Discriminates:** Confirms whether this is DMS-level permission failure or Copilot indexing bypass.

**Step 1C (10 min):** Azure AD Group Membership Audit
- Query: Azure AD / Entra ID → Groups → Filter for Legal floor groups → Check paralegal's membership.
- Look for: Is she in a group that grants DMS access beyond her stated role?
- **Discriminates:** Confirms Hypothesis 2 (group over-provisioning).

**Step 1D (5 min):** User Interview
- Question: "What role do you have in the DMS? What client matters should you be able to access? Who typically assigns you access?"
- **Discriminates:** Rules out Hypothesis 4 (user confusion).

**Expected Timeline:** 30 minutes total (parallel checks: 1A + 1B + 1C + user interview).

#### 1.5 Escalation Criteria
**ESCALATE IMMEDIATELY if:**
- Copilot/DMS logs confirm user saw document with no matching ACL entry → **ESCALATE TO:** Security incident response + Legal/Compliance officer. **WHY:** Confirmed data breach; legal holds may be required.
- DMS audit shows >5 users with over-provisioned permissions → **ESCALATE TO:** Security + DMS product team for emergency remediation review.
- Azure AD groups show systematic over-provisioning → **ESCALATE TO:** Identity governance team; audit trail required for regulatory investigation.

**DO NOT** (non-destructive principle):
- Do NOT reset user passwords or revoke access broadly yet (impacts 12+ other users with login issues).
- Do NOT restart Copilot service or wipe indices yet (may destroy audit trail).
- Do NOT modify DMS permissions until root cause confirmed (may hide evidence).

---

### INCIDENT 2: LOGIN FAILURES & SLOWNESS — 12+ Users Unable to Access or Severely Delayed
**RANK: HIGH (#2, investigate immediately after Incident 1)**

#### 2.1 Symptom (Unverified Report)
"At least a dozen people can't log in or it's taking forever." Users unable to complete login or facing extreme delays during authentication. Blocks all work.

#### 2.2 Severity & Risk Assessment
- **Severity:** P1 — HIGH (availability/productivity impact)
- **Why:**
  - **Blast radius:** 12+ users = 26% of Floor 6 capacity already impaired; if trend continues, could affect all 45 users.
  - **Time sensitivity:** Monday morning = highest-impact time; each hour of downtime affects billable work (Legal dept.).
  - **Root cause scope:** If authentication infrastructure is broken, cascading failures will emerge throughout the day.
  - **Less urgent than Incident 1:** Not an active data breach (reactive), but high business impact.

#### 2.3 Hypothesis Ranking (Most Likely → Least Likely)

**HYPOTHESIS 1 (MOST LIKELY): Intune Device Compliance Policy Blocking Authentication**
- **Context fit:** Recent Intune enrollment of Win11 devices; conditional access policies often have misconfigurations in new deployments.
- **Mechanism:** Intune policy requires device to be compliant before sign-in is allowed. If 12+ devices report non-compliant status (common issues: BitLocker not enabled, antivirus outdated, Windows update pending), Azure AD blocks sign-in or requires remediation loop.
- **Data point:** Affects multiple users (12+), suggests infrastructure issue, not individual machine issue.
- **Likelihood:** HIGH — Intune + Win11 migration is a known pain point for login delays.

**HYPOTHESIS 2 (LIKELY): Azure AD Sign-In Throttling or Temporary Auth Service Degradation**
- **Context fit:** Monday morning; high concurrent login load post-weekend; Windows 11 migration may have caused surge in auth attempts.
- **Mechanism:** Azure AD/Entra ID experiencing brief throttling or service degradation; legitimate users experiencing delays or temporary failures during peak load.
- **Data point:** "Taking forever" suggests latency, not outright rejection — typical of throttling or service lag.
- **Likelihood:** MEDIUM-HIGH — common on Monday mornings; often resolves itself.

**HYPOTHESIS 3 (POSSIBLE): Domain Trust Issue Post-Win11 Migration**
- **Context fit:** Recent Win11 migration; machine re-imaging or domain rejoin can cause trust issues.
- **Mechanism:** Local machine lost or corrupted domain trust relationship with Active Directory (or Intune device trust). Kerberos authentication fails; user cannot obtain ticket.
- **Data point:** Multiple machines affected suggests systematic migration issue, not random hardware failure.
- **Likelihood:** MEDIUM — possible but usually isolated to individual machines, not 12+ simultaneously.

**HYPOTHESIS 4 (LESS LIKELY): Corrupted User Profile or FSLogix Cache — Profile Load Delay**
- **Context fit:** Win11 migration + FSLogix profile management common; profile corruption causes sign-in delays.
- **Mechanism:** User profile (cached locally or in FSLogix container) is corrupted or bloated; sign-in process must repair/rebuild, causing extreme delays.
- **Data point:** Would typically affect individual users, not 12+ simultaneously — unless common profile storage is degraded (FSLogix server, profile share).
- **Likelihood:** MEDIUM — possible if FSLogix backend is under load or degraded.

**HYPOTHESIS 5 (LESS LIKELY): DMS Rollout Installed Logon Script That Blocks Authentication**
- **Context fit:** Friday DMS deployment; poorly designed DMS setup scripts sometimes run at logon and hang if misconfigured.
- **Mechanism:** DMS installation added a logon script or background service that hangs during authentication phase, blocking credential submission.
- **Data point:** Timing aligns with Friday DMS rollout; not confirmed whether DMS installs logon-time components.
- **Likelihood:** LOW-MEDIUM — requires coordination with DMS vendor; less common than Intune/Azure AD issues.

#### 2.4 First Diagnostic Check (Discriminates Between Hypotheses 1–5)
**PRIMARY CHECK: Azure AD Sign-In Logs + Intune Device Compliance Status**

**Step 2A (5 min):** Azure AD / Entra Sign-In Logs
- Query: Entra admin portal → Sign-in logs → Filter: Floor 6 users, timestamp 08:00–09:00 local time.
- Look for: 
  - Sign-in failures with error code (e.g., 50058 = conditional access policy; 50076 = MFA challenge; 65001 = device compliance).
  - Success vs. failure rate for Legal floor vs. other floors (control group).
  - Whether failures cluster within a time window or are random.
- **Discriminates:** If errors show "device non-compliant" (50076/65001), points to Hypothesis 1. If throttling indicators, points to Hypothesis 2. If domain trust errors (Kerberos failures), points to Hypothesis 3.

**Step 2B (5 min):** Intune Device Compliance Dashboard
- Query: Intune admin portal → Device compliance → Filter: Device group "Legal-Win11"
- Look for: How many devices report compliant vs. non-compliant? What are the top non-compliance reasons? (BitLocker, antivirus, Windows updates, etc.)
- **Discriminates:** If >12 devices report non-compliant, strongly supports Hypothesis 1.

**Step 2C (5 min):** Device Event Viewer — Local Machine (Pick One Affected Device)
- Query: Event Viewer → Windows Logs → Security → Filter: Kerberos errors, domain trust events
- Look for: Event ID 4769 (Kerberos TGT request), 5825 (Kerberos failed), or domain trust failures.
- **Discriminates:** If Kerberos errors present, points to Hypothesis 3 (domain trust).

**Step 2D (5 min):** FSLogix Status Check
- Query: Via affected device or Intune: Run `Get-FSLogixContainerState` or check FSLogix event logs.
- Look for: Profile container mount failures, slow I/O on profile share, container attachment delays.
- **Discriminates:** If FSLogix reports delays/failures, points to Hypothesis 4.

**Step 2E (5 min):** DMS Service Status
- Query: Check DMS application service status on affected devices. Is the DMS service running? Does it hang during startup?
- **Discriminates:** If DMS service crashes or hangs at startup, points to Hypothesis 5.

**Expected Timeline:** 20 minutes total (parallel checks: 2A + 2B + 2C + 2D + 2E, with 2A and 2B running simultaneously).

#### 2.5 Escalation Criteria
**ESCALATE IMMEDIATELY if:**
- >20 devices report non-compliant in Intune → **ESCALATE TO:** Intune admin; likely requires emergency compliance policy adjustment or device remediation.
- Azure AD shows >50% sign-in failure rate for Legal floor vs. <5% for other floors → **ESCALATE TO:** Microsoft support (Azure AD incident); production incident.
- Kerberos/domain trust errors dominate event logs → **ESCALATE TO:** Active Directory/Hybrid Identity team; domain health check required.

**DO NOT** (non-destructive principle):
- Do NOT mass-reset user credentials yet (may lock out more users if underlying auth infrastructure is still broken).
- Do NOT push emergency Intune policy changes (can worsen compliance issues).

---

### INCIDENT 3: DESKTOP SHORTCUTS DISAPPEARED — Profile Data Loss
**RANK: HIGH (#3, investigate after Incidents 1 & 2)**

#### 3.1 Symptom (Unverified Report)
"Someone else says their desktop shortcuts vanished." User reported that desktop icons/shortcuts are missing; previously visible shortcuts are no longer present on the user's desktop.

#### 3.2 Severity & Risk Assessment
- **Severity:** P1 — HIGH (data loss / productivity impact)
- **Why:**
  - **Scope unknown:** Reported by 1 user; unknown if others affected. If widespread, indicates systemic profile corruption.
  - **Data loss concern:** Desktop shortcuts may be quick-access links to local files, shared drives, or application shortcuts. Vanishing suggests profile data corruption.
  - **Recurrence risk:** If root cause is automated (profile sync, migration artifact), will repeat for other users.
  - **Less urgent than Incidents 1 & 2:** Isolated user impact so far, but must rule out systemic profile issue.

#### 3.3 Hypothesis Ranking (Most Likely → Least Likely)

**HYPOTHESIS 1 (MOST LIKELY): Profile Corruption During Win11 Migration — Profile Refresh**
- **Context fit:** Recent Win11 migration; profile migration scripts sometimes encounter errors and clear desktop shortcuts during profile import.
- **Mechanism:** Win11 migration script reset user desktop during profile transfer; old shortcuts were not imported to new profile or were corrupted during copy.
- **Data point:** Timing aligns with recent Win11 migration; single-user report may indicate it only affected some users or some users haven't noticed yet.
- **Likelihood:** HIGH — common post-migration symptom if profile migration was incomplete or used "clean profile" option.

**HYPOTHESIS 2 (LIKELY): FSLogix Profile Container Issue — Cache Desync or Mount Failure**
- **Context fit:** Recent Win11 + Intune enrollment; FSLogix is used for roaming profiles in Intune-managed environments.
- **Mechanism:** FSLogix profile container failed to mount correctly, or cache (local copy of profile) is stale/corrupted. User's shortcuts are stored in the container; desync causes them to appear missing locally.
- **Data point:** Intermittent FSLogix mount failures post-migration can cause this; if container remounts, shortcuts may reappear.
- **Likelihood:** MEDIUM-HIGH — FSLogix issues common in newly-enrolled devices.

**HYPOTHESIS 3 (POSSIBLE): User Profile Service Crash — Desktop Folder Corrupted**
- **Context fit:** Windows User Profile Service can corrupt desktop folder if it crashes mid-sync or if profile corruption occurs.
- **Mechanism:** User Profile Service encountered error during desktop folder sync; desktop.ini or shortcuts folder became inaccessible or was cleared.
- **Data point:** Event Viewer would show "User Profile Service" errors; profile would show as partially loaded.
- **Likelihood:** MEDIUM — possible but typically logged in Event Viewer.

**HYPOTHESIS 4 (POSSIBLE): DMS Installation or Uninstallation Side Effect — Cleanup Script Removed Shortcuts**
- **Context fit:** Friday DMS deployment; if DMS uninstall or rollback script ran, it might have modified shell folders.
- **Mechanism:** DMS installer/uninstaller script mistakenly modified registry or deleted user shell folders (e.g., HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders).
- **Data point:** Timing aligns with Friday DMS rollout; specific to users who installed DMS.
- **Likelihood:** MEDIUM — depends on DMS installer quality; less common than profile corruption.

**HYPOTHESIS 5 (LESS LIKELY): User Accidentally Deleted Shortcuts / Desktop Cleanup Tool Ran**
- **Context fit:** User performed unintended action; desktop cleanup utility removed old shortcuts.
- **Mechanism:** User or automated maintenance tool deleted shortcuts; not a system issue.
- **Data point:** Would require user confirmation; low probability in a Monday morning mass report.
- **Likelihood:** LOW — but must check with user.

#### 3.4 First Diagnostic Check (Discriminates Between Hypotheses 1–5)
**PRIMARY CHECK: FSLogix Logs + Windows Event Viewer (User Profile Service)**

**Step 3A (5 min):** FSLogix Event Logs (on affected device or via Intune)
- Query: Event Viewer → Applications and Services Logs → FSLogix Apps → Operational
- Look for: Any errors or warnings during profile container mount, especially around time user last logged in.
- **Discriminates:** If FSLogix shows mount errors, points to Hypothesis 2. If no errors, likely not FSLogix.

**Step 3B (5 min):** User Profile Service Event Logs
- Query: Event Viewer → Windows Logs → System → Filter: "User Profile Service", Error level
- Look for: Errors during profile load/unload time; corruption warnings.
- **Discriminates:** If User Profile Service errors present, points to Hypothesis 3.

**Step 3C (5 min):** Desktop Folder File System Check
- Query: On affected device, check: `dir "%userprofile%\Desktop"` and `dir "%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"`
- Look for: Are shortcuts files (.lnk) present but hidden? Or completely gone? Check file timestamps.
- **Discriminates:** If files exist but are hidden/read-only, points to Hypothesis 1 or 3. If gone, points to Hypothesis 4.

**Step 3D (5 min):** Registry Check — Shell Folders Integrity
- Query: On affected device, run: `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v Desktop`
- Look for: Is Desktop folder path correct and accessible? Or is it corrupted/pointing to wrong location?
- **Discriminates:** If registry is corrupted, points to Hypothesis 4 (DMS side effect) or 3 (profile corruption).

**Step 3E (5 min):** User Interview
- Question: "When did you last see the shortcuts? Did they disappear suddenly or gradually? Did you install/update anything Friday?"
- **Discriminates:** Narrows down timing and correlation with DMS deployment (Hypothesis 4) or migration (Hypothesis 1).

**Expected Timeline:** 20 minutes total (parallel checks: 3A + 3B + 3C + 3D + user interview).

#### 3.5 Escalation Criteria
**ESCALATE if:**
- >3 users report missing shortcuts in next check → **ESCALATE TO:** Desktop management / profile team; systemic profile issue likely.
- FSLogix shows systematic mount failures across multiple devices → **ESCALATE TO:** FSLogix/Intune support; infrastructure issue.
- DMS installer is confirmed to have modified shell folders → **ESCALATE TO:** DMS vendor + security review (installer quality).

**DO NOT** (non-destructive principle):
- Do NOT push a new profile refresh to all Legal users (risks affecting all 45 users).
- Do NOT manually reset registry or delete FSLogix containers (non-reversible; may destroy other profile data).
- Do NOT re-run Win11 migration scripts (only do if root cause is confirmed as incomplete migration).

---

## C. COMMON-CAUSE ANALYSIS — Are These Incidents Independent or Related?

### Assessment: **LIKELY PARTIALLY RELATED, with mixed independence**

**Evidence for Common Cause (Win11 Migration + Intune Enrollment + DMS Rollout):**
1. All three incidents cluster on Monday morning, immediately after Friday DMS deployment and following recent Win11 migration + Intune enrollment.
2. Incidents 2 & 3 share a profile-management context: both involve authentication (Incident 2) and profile data (Incident 3), suggesting both could stem from the same Win11/Intune/FSLogix migration issue.
3. Incident 1 (data access) could be secondary to a broken permission sync during Intune enrollment — if Azure AD groups were over-provisioned during migration, Copilot would inherit those permissions.

**Evidence for Independence:**
1. Incident 1 involves data access/Copilot behavior; Incidents 2 & 3 involve authentication/profile storage — different technical stacks.
2. Incident 1 specifically relates to DMS deployment (Friday); Incidents 2 & 3 relate to Win11/Intune (which happened before Friday).
3. Incident 2 (login failures) affects 12+ users broadly; Incident 3 (shortcuts) affects 1 user so far — different blast radii suggest different root causes.

### Preferred Investigation Sequencing (Leveraging Partial Correlation):
1. **START with Incident 1 (Copilot/DMS data access).** If DMS permission audit shows systematic over-provisioning, check whether Azure AD group over-provisioning happened during Win11 migration (Hypothesis 2). This connects Incident 1 to root causes affecting Incident 2.
2. **NEXT, investigate Incident 2 (login failures)** with full awareness that Intune device compliance may be the common thread affecting both auth (Incident 2) and profile access (Incident 3).
3. **PARALLEL with Step 2, investigate Incident 3** with focus on FSLogix/profile corruption as a secondary symptom of Intune misconfiguration.

### If All Three Trace to Intune Misconfiguration:
- **Single root cause:** Intune enrollment policy (e.g., device compliance, conditional access, profile sync settings) was misconfigured during Win11 migration, causing cascading failures in auth, profile access, and (indirectly) permission enforcement via Azure AD group membership.
- **Remediation scope:** Single fix to Intune policy, rather than separate fixes for each incident.

---

## D. IMMEDIATE ACTION SUMMARY (First 30 Minutes)

| Time | Owner | Task | Why | Non-Destructive? |
|------|-------|------|-----|------------------|
| **0–5 min** | Incident Owner #1 (Security) | Begin Incident 1 diagnostic (Steps 1A–1B: Copilot logs + DMS permission audit) | Security/legal priority; longest investigation path | Yes — read-only audit |
| **0–5 min** | Incident Owner #2 (IAM/Intune) | Begin Incident 2 diagnostic (Steps 2A–2B in parallel: Azure AD sign-in logs + Intune compliance) | High blast radius; can be done in parallel with Incident 1 | Yes — read-only logs |
| **5–10 min** | Incident Owner #1 | Complete Incident 1 Steps 1C–1D (Azure AD groups + user interview) | Narrow down permission root cause | Yes |
| **5–10 min** | Incident Owner #2 | Complete Incident 2 Steps 2C–2E (Event Viewer + FSLogix + DMS status) | Determine if Intune/domain/profile/DMS issue | Yes |
| **10–15 min** | Incident Owner #3 (Desktop Mgmt) | Begin Incident 3 diagnostic (Steps 3A–3E: FSLogix + Event Viewer + file check) | Can run in parallel; lower priority | Yes |
| **15–20 min** | All Owners | **FINDINGS SYNC:** Consolidate diagnostic results; determine if common cause or separate incidents | Informs next escalation and remediation decision | — |
| **20–30 min** | Escalation Lead | **DECISION & ESCALATION:** Based on findings, escalate to appropriate teams (Security, IAM, Desktop Mgmt, Vendor) with recommended remediation path | Prevents further degradation; legal/compliance compliance | Depends on findings |

---

## E. ESCALATION PATHS BY FINDING SCENARIO

### Scenario A: Incident 1 Confirmed Breach (Copilot/DMS Permission Failure)
- **Escalate to:** Security incident response + Legal/Compliance officer + DMS vendor
- **Actions:** Immediately suspend affected user's access to Copilot pending investigation; audit all users' DMS permission scope; potential legal holds on affected documents.
- **Timeline:** STAT (within 15 min of confirmation)

### Scenario B: Incident 2 Confirmed Intune/Azure AD Infrastructure Issue
- **Escalate to:** Intune admin + Identity team + Microsoft support (if Azure AD)
- **Actions:** Emergency review of Intune device compliance policy; conditional access policy audit; possible temporary policy adjustment to unblock login.
- **Timeline:** Within 20 min of confirmation

### Scenario C: Incident 3 Confirmed Systemic Profile Corruption (FSLogix or Win11 Migration)
- **Escalate to:** Desktop/Profile management team + Win11 migration project lead
- **Actions:** Profile integrity check for all Legal floor users; possible FSLogix cache rebuild or profile refresh (non-destructive); investigate migration script logs.
- **Timeline:** Within 25 min of confirmation; non-urgent if isolated to 1–2 users.

### Scenario D: All Three Incidents Trace to Single Intune Misconfiguration
- **Escalate to:** Intune admin (primary) + Security (permission implication) + Desktop Mgmt (profile implication)
- **Actions:** Emergency Intune policy review and correction; parallel remediation of all three symptoms with single policy fix.
- **Timeline:** Within 25 min; single remediation can resolve multiple incidents.

---

## F. GUARDRAILS & DECISION POINTS

### Treat as Potential Breach Until Ruled Out
- Unauthorized data access claim (Incident 1) is **ASSUMED BREACH** until diagnostic data proves otherwise. Err on the side of escalation.

### Preserve Audit Trail
- Do NOT modify permissions, reset services, or restart Copilot/DMS until root cause is confirmed and evidence is preserved.

### Prioritize Non-Destructive Diagnostics
- All diagnostic steps in this triage are read-only (logs, compliance status checks, registry reads).
- Any destructive action (profile reset, policy change, service restart) requires confirmation from escalation owner after root cause is identified.

### Parallel Investigation Over Sequential
- Investigate Incidents 1, 2, and 3 in parallel where possible (different tools/teams). This compresses 30-minute triage into single window vs. sequential investigation.

---

**Document prepared by:** DWP Senior Engineering Triage  
**Document date:** 2026-08-14  
**Classification:** Internal — Incident Response  
**Version:** 1.0 (Initial Triage)
