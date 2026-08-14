# DIFFERENTIAL DIAGNOSIS: Floor 6 Legal — Monday Login Failure & Slow Logon Incident

**Date:** 2026-08-14 (Monday morning)  
**Affected Floor:** Floor 6, Legal (45 users)  
**Reported Symptoms:** ~12+ users unable to log in OR experiencing severe logon delays  
**Recent Changes:** Win11 migration, Intune enrollment, Friday DMS deployment (Floor 6 only)  
**Investigation Goal:** Discriminate between independent suspects (DMS, Intune, Win11, Monday-specific factors) using fastest, non-destructive tests

---

## A. RANKED DIFFERENTIAL DIAGNOSIS TABLE

| Rank | Hypothesis | Why It Ranks Here | Fastest Check | Confirms If | Rules Out If |
|------|-----------|-------------------|---------------|------------|-------------|
| **1** | **Intune device compliance policy blocking logon** — 12+ devices report non-compliant (BitLocker, antivirus, Windows update pending); Azure AD conditional access policy requires compliance before sign-in allowed. | **HIGHEST LIKELIHOOD** (1) Recent Intune enrollment; (2) affects multiple users uniformly (not isolated); (3) Monday-morning high load common trigger for policy re-eval; (4) "can't log in" = policy block signature; (5) fast to check in Intune dashboard. | **Check 1A (5 min):** Intune admin portal → Device compliance → Filter: Legal-Win11 collection. Count devices reporting non-compliant vs. compliant. Identify top 3 non-compliance reasons (BitLocker, antivirus, Windows updates?). | **CONFIRMS:** >12 devices show non-compliant status with timestamps starting 08:00–09:00 Monday. Compliance block is active in conditional access policy logs. | **RULES OUT:** >90% of Legal-Win11 devices show compliant. No policy block in conditional access logs. |
| **2** | **Azure AD / Entra sign-in service degradation or temporary throttling** — Monday morning: peak concurrent login load post-weekend; transient service latency or throttling causing delays or temporary failures for legitimate users. | **HIGH LIKELIHOOD** (1) Monday-morning-specific (well-known peak load time); (2) explains "taking forever" symptom (latency, not outright rejection); (3) can affect all floors equally or spike for specific tenant; (4) self-resolves if infra recovers; (5) independent of Floor 6 changes. | **Check 2A (5 min):** Entra ID sign-in logs → Filter: timestamp 08:00–09:00 Monday, all floors. Compare success rate and latency for Legal floor vs. other floors. Check Microsoft 365 Health Dashboard (Service Health) for Azure AD degradation alerts. | **CONFIRMS:** Legal floor sign-in latency is 2–3x other floors OR service-wide degradation alert posted. | **RULES OUT:** Legal floor latency is baseline; other floors unaffected; no Azure AD health alert. |
| **3** | **Friday DMS deployment installed a problematic logon component (startup agent, logon script, profile shim, or resource-hogging background service)** — DMS app installed a logon-time executable or service that (a) crashes at startup, (b) hangs during credential validation, or (c) exhausts resources (RAM, CPU, disk I/O) during profile load. | **MEDIUM-HIGH LIKELIHOOD** (1) Correlates temporally (Friday deployment → Monday symptoms); (2) deployment scope matches symptom scope (DMS to Floor 6 only; symptoms on Floor 6); (3) startup component failure is plausible DMS deployment issue; (4) however, this is correlation, not proof; Win11 + Intune are also recent and also plausible. | **Check 3A (10 min):** On an affected device: (a) Event Viewer → Security/System/Application logs → filter "08:00–09:00 Monday" for DMS-related process errors or hangs. (b) Tasklist on affected device showing DMS processes at logon time (elevated CPU/memory?). (c) Check if DMS startup/logon scripts are in `HKLM\Software\Microsoft\Windows\CurrentVersion\Run` or Group Policy logon scripts. | **CONFIRMS:** DMS-related errors in event logs at logon time. DMS process hangs or crashes during 08:00–09:00 logon window. Logon scripts or startup agents fail. | **RULES OUT:** No DMS process errors at logon. DMS processes not running at startup. No DMS logon scripts in registry/GPO. |
| **4** | **FSLogix profile container mount failure or corruption** — Post-Win11 migration, FSLogix profile containers are not mounting correctly, or cached profiles are corrupted; user profile load hangs or fails. | **MEDIUM LIKELIHOOD** (1) Recent Win11 migration + Intune enrollment commonly introduces FSLogix issues; (2) profile-level problem affects all users equally; (3) however, FSLogix failures typically affect individual users or specific subnets, not 12+ uniformly; (4) slower to check than Intune/Azure AD. | **Check 4A (10 min):** On an affected device: (a) FSLogix logs (Event Viewer → Applications and Services → FSLogix Apps → Operational). Look for container mount errors or timeouts during 08:00–09:00 logon window. (b) Check FSLogix profile share accessibility and latency (`Test-Connection` + UNC path mount test). (c) Profile load duration via Windows Event Viewer (Security log, logon/logoff events: is profile load taking >60 seconds?). | **CONFIRMS:** FSLogix container mount errors. Profile container mount taking >30 seconds. Network share latency to profile server is high (>100ms). | **RULES OUT:** FSLogix logs show clean mounts. Profile load <15 seconds. Network latency baseline. |
| **5** | **Windows 11 migration issue — domain trust corruption, local profile corruption, or GPO application failure** — Win11 re-imaging or domain rejoin corrupted machine trust or local profiles; machines cannot authenticate or profile loads with errors. | **MEDIUM LIKELIHOOD** (1) Recent Win11 migration is a known risk for domain trust issues; (2) however, typically affects isolated machines post-imaging, not 12+ uniformly; (3) would expect scattered failures across multiple days, not concentrated Monday morning; (4) slower to check than Intune/Azure AD. | **Check 5A (10 min):** On affected device: (a) Test domain connectivity: `nltest /dsgetdc:finbridge.local` and `gpupdate /force` to verify domain trust and GPO application. (b) Event Viewer → System/Security logs → filter Netlogon and Group Policy events for trust or GPO failures (Event IDs 5719, 1129, 1030). (c) Device property: `systeminfo` → check domain membership and join status. | **CONFIRMS:** `nltest` fails to locate domain controller. Netlogon errors in event logs. Device shows as not domain-joined or offline. | **RULES OUT:** `nltest` succeeds. Netlogon events show successful channel setup. Device is domain-joined and responsive to GPO. |
| **6** | **DMS backend service unavailable or overloaded** — Friday DMS deployment included a backend server/database service that is now unavailable or degraded; on logon, DMS client attempts to contact backend, hangs, and blocks profile load. | **MEDIUM LIKELIHOOD** (1) Plausible if DMS is tightly coupled to logon flow; (2) backend outage would be immediately visible in DMS team's monitoring; (3) however, less likely than client-side logon issues; (4) slower to check (requires DMS team/backend access). | **Check 6A (10 min):** (a) Check DMS service monitoring / status dashboard (ask DMS team/owner for backend health). (b) Test backend connectivity from affected device: `Test-Connection` or `telnet` to DMS server / database port. (c) Check DMS client logs on affected device for connection timeouts or errors during 08:00–09:00 window. | **CONFIRMS:** DMS backend down or degraded during 08:00–09:00. Client connection timeouts or "service unavailable" errors in DMS logs. | **RULES OUT:** DMS backend online and responsive. Client connects successfully. No connection timeouts. |
| **7** | **Credential/certificate expiry or license key expiry triggered Monday** — User credentials, machine certificates, or software licenses expired over the weekend and must be renewed; authentication or app licensing fails at logon. | **LOW-MEDIUM LIKELIHOOD** (1) Monday-specific (weekend boundary); (2) plausible for multi-factor auth tokens or device certificates; (3) however, would typically affect scattered users across multiple days, not 12+ uniformly on one morning; (4) slower to check, requires cross-team coordination. | **Check 7A (10 min):** (a) Check affected users' Azure AD → account sign-in activity and conditional access logs for MFA or certificate-related errors (error codes 50076 = MFA required, 50058 = conditional access). (b) Check machine certificates: `certlm.msc` → Personal → Certificates → filter by expiry date. Are any close to or past expiry? (c) DMS license status (if applicable). | **CONFIRMS:** Users show MFA/certificate errors in Entra sign-in logs. Device certificates show expiry Saturday or Sunday. DMS license key expired over weekend. | **RULES OUT:** No MFA/certificate errors in sign-in logs. Device certificates all valid. DMS license is active. |
| **8** | **Network connectivity issue — Floor 6 subnet or domain controller access degraded** — Network outage, switch misconfiguration, or DC access latency prevents domain authentication on Floor 6 only. | **LOW LIKELIHOOD** (1) Would typically manifest as complete outage, not "some users slow, some can't log in"; (2) network team would have alerts; (3) independent of Friday changes; (4) affects other services too (would be reported separately). | **Check 8A (5 min):** (a) Network team: any Floor 6 subnet outages or latency alerts Monday morning? (b) Ping domain controllers from Floor 6 test device: `ping finbridge-dc01.finbridge.local` (latency >100ms?). (c) DHCP and DNS working: `ipconfig /all` and `nslookup` from affected device. | **CONFIRMS:** Network team reports Floor 6 connectivity issue. Ping to DC times out or shows >500ms latency. DHCP/DNS failures. | **RULES OUT:** No network alerts. Ping to DC <50ms. DHCP/DNS resolving correctly. |

---

## B. FIRST CHECK I WOULD RUN (Highest Information Value)

### **PRIMARY CHECK: Check 1A — Intune Device Compliance Dashboard (5 minutes)**

**Why This First?**
1. **Highest likelihood × fastest check ratio:** Intune compliance policy blocking logon is the most likely cause (Intune enrollment + conditional access policy + Monday load peak) and the fastest to confirm or rule out (dashboard query, no log-digging required).
2. **Information density:** A single check reveals:
   - Scope: how many devices are actually non-compliant (if <5, rules out Intune as cause of 12+ failures).
   - Mechanism: what specific compliance requirement is failing (BitLocker, antivirus, update).
   - Timeline: when devices became non-compliant (if 08:00 Monday, correlates with symptom onset).
   - Discriminates against other hypotheses: if 90%+ are compliant, immediately narrows focus to Azure AD, DMS, or FSLogix.
3. **Non-destructive:** Read-only dashboard check; no system changes.
4. **Actionable:** Result immediately informs whether to escalate to Intune/Identity team or pivot to application-level checks.

**Execution:**
```powershell
# Connect to Intune admin portal
# Navigate to: Devices → Device Compliance → Status
# Filter: Collection = "Legal-Win11"
# Review:
#   - Total devices in collection
#   - Count compliant vs. non-compliant
#   - For each non-compliant device:
#     - Device name
#     - Last sync time
#     - Non-compliance reason (BitLocker, antivirus outdated, Windows update pending, etc.)
#     - When it became non-compliant (if available in compliance history)
```

**Expected Output if TRUE (Intune is the cause):**
```
Legal-Win11 Collection:
- Total: 45 devices
- Compliant: 33
- Non-compliant: 12
- Top non-compliance reasons:
  * BitLocker not enabled (7 devices)
  * Antivirus outdated (3 devices)
  * Windows update pending (2 devices)
- Last sync: Monday 08:15–08:45 (correlates with failure onset ~08:00)
- Conditional access policy active: "Require device compliance" = YES
```

**Expected Output if FALSE (Intune is NOT the cause):**
```
Legal-Win11 Collection:
- Total: 45 devices
- Compliant: 44
- Non-compliant: 1 (chronic issue, not Monday-specific)
- No policy block active in conditional access
```

---

## C. DEPLOYMENT VERDICT CRITERIA — Confirm or Rule Out Friday DMS Deployment

### THE QUESTION
Is the Friday DMS deployment the root cause of Monday login failures?

### CONFIRM DMS as Root Cause: Evidence Required

**Scoping Test: Affected Device = DMS-Installed Device**
- ✓ **CONFIRMS:** Cross-reference the 12+ devices with login failures against the SCCM/Intune deployment log for "Legal Document Manager v2.1". Result: 12/12 failed devices received DMS deployment. Zero failures on devices that did NOT receive DMS.
- ✗ **RULES OUT:** DMS was deployed to 45 devices; only 12 report failures. Other 33 devices received the same DMS package but are fine. (This doesn't rule out DMS entirely, but rules out "DMS broke all machines"; points toward selective failure mode — e.g., DMS on 4GB RAM machines, or specific configuration/OS version interaction.)

**Timing Test: Failure Onset Aligns with DMS Logon Time**
- ✓ **CONFIRMS:** Event logs on affected device show DMS process failures or hangs at logon time, specifically during 08:00–09:00 Monday morning window (24+ hours after Friday deployment). No failures reported Friday evening / Saturday / Sunday.
- ✗ **RULES OUT:** Failures began Friday evening or Saturday (would have been reported immediately). Failures began Monday but at 07:00 (before first logon, suggesting independent factor like GPO refresh or Intune policy sync, not DMS). DMS process starts cleanly; no errors at logon time.

**Mechanism Test: DMS Component Plausibly Breaks Logon Flow**
- ✓ **CONFIRMS:** One or more of:
  - DMS installer added a logon script or startup service that hangs or crashes (Event Viewer shows DMS executable failure during 08:00–09:00 logon).
  - DMS profile changes (e.g., registry changes, shell folders, shortcuts) corrupt or conflict with profile load.
  - DMS process consumes resources (RAM, CPU, disk I/O) during logon, causing profile load timeout.
  - DMS authenticates against a backend service at logon; backend is unavailable or unresponsive.
- ✗ **RULES OUT:** DMS installer does not add logon script or startup service. DMS profile changes are isolated and safe. No resource exhaustion during logon. DMS backend is online and responsive. DMS logon component completes in <2 seconds.

### RULE OUT DMS as Root Cause: Evidence Required

**Anti-Correlation Tests:**
1. ✓ **Single strongest rule-out:** Device received DMS, logon works fine.
   - If even 1–2 machines received Friday DMS but have zero login issues, DMS is not the direct, universal cause. (Points to selective failure mode: Intune policy, FSLogix issue, or machine-specific issue, not DMS itself.)

2. ✓ **Timing rule-out:** Failures began before Friday DMS deployment.
   - If audit logs show login issues Friday afternoon before DMS was deployed, or if failures were ongoing Saturday/Sunday before Monday, DMS deployment is not the trigger.

3. ✓ **Floor-scope rule-out:** Other floors also affected equally, even without DMS.
   - If other floors (not receiving DMS) report similar login failures Monday, suggests Floor 6 failures are independent of DMS (points to Intune, Azure AD, or Monday-specific infrastructure factor).

4. ✓ **Process-level rule-out:** DMS process does not appear in logon window; no DMS-related errors in event logs.
   - If DMS is installed on affected device but does not run at logon, and no DMS errors are logged, DMS is not breaking the logon flow.

5. ✓ **Mechanism rule-out:** Devices without DMS installed have identical logon behavior.
   - If a control device (same floor, same configuration, same Intune policies, but did NOT receive DMS) also exhibits slow logon or failure, DMS is not the cause.

### DECISION TREE: DMS Verdict

```
START: 12+ devices failing to logon Monday, after Friday DMS deployment to Floor 6.

├─ SCOPING TEST: Did all failing devices receive DMS?
│  ├─ YES: Proceed to TIMING TEST
│  └─ NO (1+ failing device didn't get DMS): DMS is NOT universal cause → Pivot to Intune/Azure AD
│
├─ TIMING TEST: Did failures start Monday morning at logon time (08:00–09:00)?
│  ├─ YES: Proceed to MECHANISM TEST
│  └─ NO (failures Friday evening or Saturday): DMS not the trigger → Pivot to Intune policy sync or Windows update
│
├─ MECHANISM TEST: Does DMS have a logon component? Is it crashing/hanging in event logs?
│  ├─ YES (DMS startup/logon script errors visible): DIAGNOSIS = DMS DEPLOYMENT FAILURE
│  │    Action: Emergency DMS rollback or startup component disable; validate all 45 devices
│  │
│  └─ NO (no DMS logon component, no errors): DMS is NOT breaking logon → Pivot to Intune device compliance or Azure AD
│
└─ ANTI-CORRELATION: Do any devices with DMS work fine? Or do other floors fail without DMS?
   ├─ YES: DMS is NOT the cause → Root cause is Intune, Azure AD, or Monday infrastructure
   └─ NO: Consistent correlation, but mechanism must be proven before remediation
```

---

## D. INDEPENDENT SUSPECTS — Why NOT to Assume DMS is the Cause

### Suspect 1: Intune Device Compliance Policy (More Likely Than DMS)
- **Why:** Intune enrollment is recent (recent enough to be "recently migrated" per scenario). Conditional access policies blocking non-compliant devices are a textbook source of Monday-morning lockouts.
- **Evidence required to confirm:** Intune compliance dashboard shows 12+ devices non-compliant at 08:00 Monday. Conditional access logs show policy block.
- **Why DMS is a red herring:** Correlation is tempting (Friday DMS → Monday failure), but Intune policy failures happen all the time Monday morning after policy refresh over the weekend. The timing and uniformity (12+ devices, same symptom) point more to infrastructure policy than to an application.

### Suspect 2: Monday-Morning Infrastructure Factors (Independent of Friday Changes)
- **Examples:** Policy refresh after weekend, license renewal, MFA token expiry, certificate expiry, Azure AD sign-in throttling.
- **Why:** These are predictably Monday-morning phenomena and are independent of DMS, Win11, or Intune enrollment.
- **Evidence required to confirm:** Azure AD sign-in logs show latency spike or throttling. MFA or certificate errors logged. Service Health dashboard shows degradation.

### Suspect 3: Win11 Migration (Independent of DMS)
- **Why:** Win11 migration is also recent and is a known source of FSLogix, domain trust, and profile issues.
- **Evidence required to confirm:** FSLogix logs show mount failures. Domain trust errors. Profile corruption.
- **Why DMS is a red herring:** If the root cause is Win11 migration, the correlation with Friday DMS is coincidence. The DMS deployment happened on the same floor that recently migrated to Win11, so it looks causal—but it's not.

### How to Disambiguate: The Control Test
**The single strongest test to rule DMS in or out:**
- **Pick one device on Floor 6 that received DMS:** Does it fail logon?
- **Pick one device on Floor 6 that did NOT receive DMS (if any):** Does it fail logon?
- **If both fail:** DMS is not the cause (same failure mode independent of DMS).
- **If only DMS devices fail:** DMS is plausibly involved (but mechanism must still be proven).
- **If only non-DMS devices fail:** DMS is ruled out entirely (cause is Intune, Azure AD, or Win11).

---

## E. CRITICAL: The Copilot Data Access Incident Is a Separate Security Signal, NOT a Login Cause

### Correct Interpretation
The Copilot incident (paralegal seeing unauthorized client matter) is:
- ✓ A **permission misconfiguration** (data access control failure).
- ✓ A **security signal** requiring escalation to Security/Legal/Compliance.
- ✓ **Likely related to Friday DMS deployment's permission model or Azure AD group sync**, but independent of login/logon failures.

### Why Copilot Is NOT a Cause of Login Failures
- ✗ Copilot does NOT affect authentication or logon flow.
- ✗ Copilot failure to surface data would delay document retrieval, not block logon.
- ✗ The Copilot incident affects **1 user's data access scope**; login failures affect **12+ users' authentication**.
- ✗ Copilot incident is a **permission/visibility problem** (user can see data she shouldn't); login incident is an **authentication problem** (users cannot authenticate at all).

### How They May Be Related (But Not As Cause-Effect)
**Common root cause hypothesis:** Friday DMS deployment included permission changes (e.g., group membership, SharePoint permission inheritance) that:
1. Broadened the paralegal's access scope → Copilot exposed unauthorized data (security incident).
2. Misconfigured Intune device groups or Azure AD groups → Intune device compliance policy blocked 12+ users at logon (authentication incident).

**Same deployment, two different failure modes, two different technical stacks.**

### Correct Diagnostic Approach
- **Copilot incident:** Investigate DMS permission model, Friday deployment permission changes, Azure AD group membership sync. Escalate to Security/Legal.
- **Login failures:** Investigate Intune device compliance, Azure AD sign-in path, FSLogix, DMS logon component. Escalate to Identity/Desktop team.
- **Do not conflate them:** Solving one does not solve the other.

---

## F. EVIDENCE PRESERVATION & NON-DESTRUCTIVE CHECKS ONLY

### Checks That Are SAFE (Read-Only, No System Changes)
- ✓ Intune compliance dashboard review
- ✓ Azure AD sign-in logs query
- ✓ Event Viewer logs on affected device
- ✓ FSLogix operational logs
- ✓ Registry read (`reg query`)
- ✓ Service status query (`Get-Service`)
- ✓ Network connectivity test (`ping`, `nslookup`, `Test-Connection`)

### Checks That Are DESTRUCTIVE or EVIDENCE-DESTROYING (Hold Until Root Cause Confirmed)
- ✗ **DO NOT:** Mass password reset (covers up authentication mechanism; wipes clear logon attempts for audit trail).
- ✗ **DO NOT:** Re-push Win11 migration profile to all 45 devices (resets FSLogix, destroys evidence of what broke).
- ✗ **DO NOT:** Uninstall DMS fleet-wide without confirming it's the cause (if DMS is not the cause, uninstalling spreads impact; if it is, uninstalling hides evidence of what broke).
- ✗ **DO NOT:** Clear event logs or Copilot chat history (destroys audit trail required for incident investigation and legal/compliance review).
- ✗ **DO NOT:** Modify Intune device compliance policy without understanding why devices are non-compliant (may mask the real issue; may cause future policy violations).

### Recommended Sequence
1. **Run all safe checks (1A, 2A, 4A) in parallel.** (5–10 minutes, high information density.)
2. **Analyze results. Identify most likely hypothesis.**
3. **Run the discriminating test for that hypothesis.** (Additional 5–10 minutes.)
4. **Once root cause is confirmed, plan remediation.** (Do not modify anything until root cause is proven.)

---

## G. COMMON-CAUSE vs. COINCIDENT FAILURE ANALYSIS

### Question: Are Incidents Related or Independent?

**Incidents:**
1. 12+ users cannot log in or experience severe delays (Incident A: Login Failure).
2. Paralegal sees unauthorized client matter in Copilot (Incident B: Data Access/Security).
3. One user reports desktop shortcuts vanished (Incident C: Profile Corruption).

### Assessment: **PARTIAL COMMON CAUSE, PARTIALLY INDEPENDENT**

**Evidence for Common Cause (Friday DMS Deployment or Win11/Intune Migration):**
- All three clustered Monday morning, after Friday DMS deployment and recent Win11/Intune changes.
- Both Incident A and Incident B could be explained by "DMS deployment included permission/group sync changes":
  - Incident A: Intune device groups misconfigured by DMS → device compliance policy blocks logon.
  - Incident B: DMS permission inheritance misconfigured → paralegal granted over-broad access.
- Incident C (shortcuts) could stem from Win11 migration profile corruption, which is orthogonal to DMS but same timeframe.

**Evidence for Independence:**
- Incident A (login) = authentication failure (identity/infrastructure stack).
- Incident B (data access) = permission misconfiguration (data governance stack).
- Incident C (shortcuts) = profile data loss (profile management stack).
- Different technical stacks = different root causes likely.

### Preferred Hypothesis
**LEAN TOWARD: 60% common-cause infrastructure misconfiguration (Intune device compliance + Azure AD group sync from Friday DMS deployment), 40% coincident profile-level issue (Win11 migration + FSLogix).**

**Why:**
- The concentration (12+ users, same floor, Monday morning) suggests infrastructure-level policy failure, not coincidence.
- The commonality (Friday DMS touched permissions, group sync, and deployment scripts) makes it plausible as a single change affecting multiple stacks.
- However, Incident C (shortcuts) is less correlated with Incidents A & B (different users, different mechanism), suggesting some independence.

### Remediation Implication
- **If common-cause (Intune policy):** Single fix (restore device compliance policy or correct device group membership) resolves Incident A; may indirectly resolve Incident B if it's tied to the same group sync error.
- **If independent:** Incident A requires Intune/Azure AD fix; Incident B requires DMS permission audit/correction; Incident C requires FSLogix investigation.

---

## H. SUMMARY: Recommended Investigation Path (30 Minutes)

| Time | Check | Owner | Expected Outcome |
|------|-------|-------|------------------|
| **0–5 min** | **Check 1A:** Intune device compliance dashboard (Legal-Win11 collection) | Intune admin | Reveals if 12+ devices non-compliant; if YES, Intune is primary suspect |
| **0–5 min (parallel)** | **Check 2A:** Azure AD sign-in logs (Floor 6, 08:00–09:00); Service Health dashboard | Identity/IAM | Reveals if infrastructure degradation or policy block; if YES, Azure AD is suspect |
| **5–10 min** | **Check 3A:** Event Viewer on affected device (DMS-related errors at logon); Tasklist (DMS processes) | Desktop Support / affected user | Reveals if DMS logon component is crashing; if YES, DMS is suspect |
| **5–10 min (parallel)** | **Check 4A:** FSLogix logs; profile load duration (Security log logon events) | Desktop Support | Reveals if profile mount/load failures; if YES, FSLogix/Win11 migration is suspect |
| **10–15 min** | **Decision point:** Consolidate findings. Identify most likely hypothesis from Checks 1A–4A. | Incident commander | Determines escalation path (Intune, Identity, Desktop, or DMS) |
| **15–25 min** | **Discriminating test for most likely hypothesis** (run targeted Check 5, 6, or 7 based on findings) | Relevant team | Confirms or rules out primary hypothesis |
| **25–30 min** | **Escalation & remediation plan:** Brief findings to appropriate team; recommend non-destructive next steps. | Incident commander | Hands off to owning team; plan coordinated remediation |

---

**Document prepared by:** DWP Senior Support Engineering  
**Document date:** 2026-08-14  
**Classification:** Internal — Incident Diagnosis  
**Version:** 1.0
