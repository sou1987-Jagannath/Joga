# AVD Black Screen Incident RCA

Document date: 2026-08-13  
Incident date: 2024-03-15  
Service: Azure Virtual Desktop (Finance)

## 1. Executive Summary
On 2024-03-15, Finance users in POOL-FIN-01 experienced black screens immediately after login, with some sessions recovering after about 30 seconds and others disconnecting repeatedly. The issue started after an overnight image update applied only to POOL-FIN-01. Investigation confirmed repeated Desktop Window Manager crashes caused by the Intel graphics driver module (igdumd64.dll) on updated hosts. The corrective action (rollback to known good graphics/image state and controlled host recovery) was completed, and service was verified as stable at 10:00 AM.

## 2. Incident Scope and Impact
1. Affected population: approximately 40 percent of users in POOL-FIN-01.
2. Unaffected control group: POOL-FIN-02 users had normal logins.
3. User symptom: black screen post-login, variable duration, occasional disconnect and reconnect loop.
4. Business impact: delayed start of work for Finance users, increased Service Desk call volume, productivity disruption.

## 3. Supporting Evidence

### 3.1 Scope and change evidence
1. POOL-FIN-01 received overnight image update at 02:00.
2. POOL-FIN-02 did not receive that update.
3. First reports began around 07:00.

### 3.2 Host event evidence (affected host: SHFIN-01-A)
1. 07:02:10 - TerminalServices-LocalSessionManager Event 21: session logon succeeded (FINBRIDGE\\mlopez, Session 3).
2. 07:02:14 - Kernel-General Event 1: host boot time 02:03:11 (post-update restart).
3. 07:02:16 - Application Error Event 1000: dwm.exe faulting in igdumd64.dll, exception 0xc0000005.
4. 07:02:17 - TerminalServices-LocalSessionManager Event 40: session disconnected.
5. 07:02:18 - Desktop Window Manager Event 9009: DWM exited with code 0x40010004.
6. 07:02:44 - TerminalServices-LocalSessionManager Event 21: session logon succeeded (reconnect).
7. 07:02:46 - Application Error Event 1000: repeated dwm.exe fault in igdumd64.dll.
8. 07:02:47 - TerminalServices-LocalSessionManager Event 40: session disconnected again.
9. 07:03:01 - Desktop Window Manager Event 9009: repeated DWM exit.
10. 07:03:10 - TerminalServices-LocalSessionManager Event 21: second reconnect succeeded (Session 4).
11. 07:08:22 - TerminalServices-LocalSessionManager Event 21: session logon succeeded (FINBRIDGE\\akapoor, Session 5).
12. 07:08:24 - Application Error Event 1000: same dwm.exe and igdumd64.dll crash signature.

### 3.3 Control evidence (unaffected host: SHFIN-02-A, POOL-FIN-02)
1. 07:01:44 - TerminalServices-LocalSessionManager Event 21: session logon succeeded.
2. 07:01:46 - Desktop Window Manager Event 9011: DWM started successfully.
3. No Application Error Event 1000 for dwm.exe in the comparison window.

## 4. Timeline (All times local)
1. 02:00 - Image update deployed to POOL-FIN-01.
2. 02:03 - Updated host reboot observed (Kernel-General Event 1 indicates boot at 02:03:11).
3. 07:00 - First user reports of black screen begin.
4. 07:02 to 07:08 - Repeated DWM crash and session disconnect/reconnect sequence observed on SHFIN-01-A.
5. 07:01 to 07:02 - Control host in POOL-FIN-02 shows successful DWM startup with no crash signature.
6. 07:15 to 09:30 - Containment and remediation steps executed on affected pool.
7. 10:00 - Service verified restored; users logging into POOL-FIN-01 hosts without reported issues.

## 5. Root Cause Statement
The incident was caused by a display stack regression introduced through the overnight POOL-FIN-01 image update. Specifically, Desktop Window Manager (dwm.exe) repeatedly crashed in Intel graphics module igdumd64.dll (Application Error Event 1000), causing post-login black screens and session instability.

## 6. Contributing Factors
1. Differential rollout: only POOL-FIN-01 received the updated image, concentrating risk in one business pool.
2. Insufficient pre-production graphics stability validation for AVD logon scenarios.
3. Lack of automated release gate to block promotion when DWM crash signatures appear.
4. No early canary alarm tied to Event 1000 plus DWM Event 9009 pattern.

## 7. 5 Whys Analysis
1. Why did users see black screens and disconnections?
Because user sessions encountered Desktop Window Manager failures shortly after successful logon, leading to disconnect/reconnect loops.

2. Why did Desktop Window Manager fail?
Because dwm.exe crashed with access violation (0xc0000005) in Intel graphics module igdumd64.dll (Event 1000).

3. Why was the crashing graphics module present in production hosts?
Because the overnight image update introduced a driver/build combination that was unstable for affected AVD session hosts.

4. Why was an unstable driver/build combination promoted?
Because image validation did not include a strict pass/fail gate for post-logon DWM crash telemetry under representative pooled AVD load.

5. Why did validation miss this specific failure mode?
Because release controls focused on provisioning and basic login success, but did not enforce targeted graphics-path health checks and staged telemetry-based promotion criteria.

## 8. Resolution Actions Implemented
1. Isolated affected hosts in POOL-FIN-01 and prevented new assignment to unstable nodes during active remediation.
2. Reverted affected hosts to known good image or graphics driver state.
3. Reintroduced hosts in controlled batches after validation checks showed no recurring DWM crash signature.
4. Monitored post-fix sessions for early-session disconnect patterns and user-reported black screen symptoms.

## 9. Service Restoration Verification
1. Verification time: 10:00 AM.
2. Verified outcome: users successfully logging into POOL-FIN-01 hosts.
3. Field validation: no new user issues reported after remediation.
4. Technical validation: prior crash sequence (Event 1000 dwm.exe/igdumd64.dll plus Event 9009) no longer observed in the post-fix verification window.

## 10. Preventive and Corrective Action Plan

### 10.1 Immediate hardening
1. Pin approved graphics driver versions in AVD golden image definitions.
2. Disable uncontrolled driver drift in image build and host lifecycle processes.
3. Standardize graphics-related policy settings across pool hosts.

### 10.2 Release governance improvements
1. Enforce canary-first deployment for host pool image updates.
2. Add promotion gates that fail rollout when any canary host emits:
- Application Error Event 1000 for dwm.exe with igdumd64.dll.
- Desktop Window Manager Event 9009 within post-logon window.
3. Require side-by-side control comparison before broad rollout.

### 10.3 Monitoring and alerting
1. Create alerts for sudden increase in Event 1000 (dwm.exe) and Event 9009 on any updated host ring.
2. Add dashboard view for first-5-minute post-logon stability metrics by pool and image version.
3. Trigger automatic rollout pause when crash thresholds are exceeded.

### 10.4 Operational readiness
1. Maintain a documented one-click rollback runbook for image and driver regressions.
2. Pre-assign incident roles for image rollback, host drain, user communications, and telemetry validation.
3. Conduct quarterly game-day simulation for AVD image regression response.

## 11. Lessons Learned
1. Treated-versus-control pool comparisons can rapidly isolate update-coupled faults.
2. Successful logon events do not imply desktop stability; compositor and graphics telemetry must be included in health checks.
3. Canary telemetry gates are essential for preventing pool-wide user impact from image regressions.

## 12. Incident Closure
Status: Resolved  
Resolution confirmed at 10:00 AM with successful user logins to POOL-FIN-01 and no ongoing issue reports.
