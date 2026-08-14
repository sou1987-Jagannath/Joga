# Root Cause Analysis — Citrix VDI Session Launch Failure
**Incident:** FinBridge-VDI-Pool-02 — 22 users unable to launch desktop sessions  
**Date of Incident:** 2026-08-13  
**RCA Completed:** 2026-08-13  
**Author:** DWP VDI Team  
**Classification:** P2 — High Impact, Business Hours Outage  

---

## 1. Incident Statement

On 2026-08-13 at 08:58, 22 of 30 users on `FinBridge-VDI-Pool-02` could not launch Citrix desktop sessions. The Citrix Session Broker returned error 1030 — *"No machines available in the desktop group"* — after a 30-second timeout. The parallel pool `FinBridge-VDI-Pool-01` on the same site was fully operational throughout. The failure was isolated to machines served by Delivery Controller `dc-vdi-02.finbridge.local`.

---

## 2. Timeline of Events

| Time | Event |
|---|---|
| **2026-08-12 23:40** | Citrix Broker Service last recorded as running on `dc-vdi-02` |
| **2026-08-13 00:15** | Windows Update package installed on `dc-vdi-02`; reboot-required flag set by installer |
| **2026-08-13 00:15 (est.)** | Citrix Broker Service stopped — either directly stopped by WU service management or failed to recover after update |
| **2026-08-13 06:15:22** | `VDI-P02-014` attempts VDA registration against `dc-vdi-02:80` — connection refused |
| **2026-08-13 06:16:01** | `VDI-P02-017` attempts VDA registration against `dc-vdi-02:80` — connection refused |
| **2026-08-13 06:15–06:30 (est.)** | All 22 Pool-02 VDAs exhaust registration retries against dc-vdi-02; remain unregistered |
| **2026-08-13 08:58:03** | First user session launch request recorded (user jsmith, Pool-02) |
| **2026-08-13 08:58:34** | Broker times out (30,000 ms) — no available machines. Error 1030 returned |
| **2026-08-13 08:58+** | 22 users blocked from sessions; 8 users served by the 3 remaining registered machines |
| **2026-08-13 (incident response)** | Issue identified; dc-vdi-02 Broker Service started; VDAs begin re-registering |

---

## 3. Supporting Evidence

### 3.1 Broker Log Extract

```
[08:58:03] Session launch requested: user jsmith, Pool-02
[08:58:04] Broker: Querying available machines in Pool-02
[08:58:34] Broker: Timeout waiting for machine registration response (30000ms exceeded)
[08:58:34] Session launch FAILED: error 1030 'No machines available in the desktop group'
```

### 3.2 Machine Catalog Registration

| Pool | Provisioned | Registered | Unregistered |
|---|---|---|---|
| Pool-02 | 25 | 3 | **22** |
| Pool-01 | 20 | 19 | 1 |

### 3.3 VDA Registration Error (Pool-02 sample)

```
VDI-P02-014 — 06:15:22: Unable to contact Delivery Controller dc-vdi-02.finbridge.local:80 — connection refused
VDI-P02-017 — 06:16:01: Unable to contact Delivery Controller dc-vdi-02.finbridge.local:80 — connection refused
```

All 22 unregistered VDAs report the same error against `dc-vdi-02` only. No VDA reports an error against `dc-vdi-01`.

### 3.4 Delivery Controller State

| Controller | Broker Service | Last Running | Windows Update | Reboot Status |
|---|---|---|---|---|
| `dc-vdi-02` | **STOPPED** | 2026-08-12 23:40 | Installed 2026-08-13 00:15 | Reboot required — **not rebooted** |
| `dc-vdi-01` | RUNNING | — (14 days uptime) | None | No pending reboot |

### 3.5 Key Differential

- `dc-vdi-01` had no changes and serves Pool-01 without issue.
- `dc-vdi-02` had Windows Update applied at 00:15, service stopped at approximately 00:15, and serves Pool-02 exclusively.
- The only variable that changed between the two controllers is the Windows Update on dc-vdi-02.

---

## 4. Root Cause

> **Windows Update installed on `dc-vdi-02.finbridge.local` at 00:15 on 2026-08-13 stopped the Citrix Broker Service. The host was not rebooted after the update. The service remained STOPPED. All 22 Pool-02 VDAs that register exclusively against dc-vdi-02 received "connection refused" on port 80 from 06:15 onward, entered an unregistered state, and could not service launch requests. The broker returned error 1030 to all affected users from 08:58.**

**Contributing factor:** Pool-02 VDAs were configured to register against only one Delivery Controller (`dc-vdi-02`). No fallback registration target existed. A single controller failure was therefore sufficient to take the entire pool offline.

---

## 5. Five Whys Analysis

| Why | Answer |
|---|---|
| **Why** could users not launch Pool-02 sessions? | The broker returned error 1030 — no registered machines were available to serve launch requests |
| **Why** were 22 machines unregistered? | All 22 VDAs reported "connection refused" when attempting to register against `dc-vdi-02.finbridge.local:80` |
| **Why** was port 80 on dc-vdi-02 refusing connections? | The Citrix Broker Service on dc-vdi-02 was STOPPED — nothing was listening on port 80 |
| **Why** was the Citrix Broker Service stopped? | Windows Update ran on dc-vdi-02 at 00:15 and stopped the service during package installation; the service did not restart and the host was not rebooted |
| **Why** did no one detect or recover from this before business hours? | No monitoring alert existed for the Citrix Broker Service stopping on a Delivery Controller; the update ran unattended with no change-control gate and no post-update health verification |

---

## 6. Remediation Actions Taken

1. Remoted into `dc-vdi-02` via RDP.
2. Captured pre-change service state and event log.
3. Started the Citrix Broker Service: `Start-Service "CitrixBrokerService"`.
4. Confirmed port 80 restored (`netstat -ano | findstr ":80"`).
5. Monitored VDA re-registration via `Get-BrokerMachine -DesktopGroupName "FinBridge-VDI-Pool-02"`.
6. Confirmed ≥ 22 machines returned to Registered state.
7. Verified user session launch on Pool-02 succeeded with no error 1030.
8. Scheduled controlled reboot of dc-vdi-02 in next maintenance window to clear pending-reboot flag.

---

## 7. Verification Checks

| Check | Expected Result | Status |
|---|---|---|
| Citrix Broker Service on dc-vdi-02 | RUNNING | Confirmed post-remediation |
| Port 80 listening on dc-vdi-02 | TcpTestSucceeded: True | Confirmed post-remediation |
| Pool-02 registered machine count | ≥ 22 | Confirmed post-remediation |
| User session launch on Pool-02 | No error 1030 | Confirmed post-remediation |
| Pending reboot flag cleared | Test-Path returns False | Pending — after next maintenance reboot |

---

## 8. Preventive Actions

### 8.1 Immediate (within 1 week)

| Action | Owner | Detail |
|---|---|---|
| Configure Pool-02 VDAs with dual-controller registration | VDI Team | Add `dc-vdi-01` as a secondary registration target in VDA policy for Pool-02. A single controller failure will no longer take the full pool offline. |
| Create Citrix Broker Service stop alert | Monitoring Team | Alert on-call immediately when `CitrixBrokerService` enters a non-running state on any Delivery Controller. Target: page within 15 minutes. |

### 8.2 Short Term (within 1 month)

| Action | Owner | Detail |
|---|---|---|
| Enforce maintenance window patching for Delivery Controllers | Change Management | Configure WSUS / Update Rings to target a dedicated "Citrix-DC" group with deferred approval and weekend-only install schedule. No automated off-hours updates on production Delivery Controllers. |
| Post-patch automated health check | Automation Team | After any update installs on a Delivery Controller, trigger an automated health check script that verifies `CitrixBrokerService` is running and port 80 is responsive. Alert and roll back if check fails. |

### 8.3 Ongoing

| Action | Owner | Detail |
|---|---|---|
| Pre-patch Citrix KB compatibility review | VDI Team | Before approving any Windows Update KB for Delivery Controllers, cross-reference against Citrix CTX support articles for the installed Citrix version and XenApp/XenDesktop release. |
| Monthly VDA registration topology audit | VDI Team | Verify all pools have at least two Delivery Controller registration targets configured and that no pool is single-controller dependent. |

---

## 9. Lessons Learned

1. **Single points of failure in VDA registration are a design risk.** A pool configured against only one Delivery Controller has zero tolerance for that controller going unavailable. Dual-controller registration is a baseline requirement.

2. **Unattended patching on production infrastructure without post-change health verification is unsafe.** Windows Update ran, stopped a service, set a reboot-required flag, and no automated check validated the host before business hours.

3. **An 8+ hour gap between failure and detection indicates a monitoring gap, not a detection-speed gap.** The service stopped at ~00:15 and was not identified until 08:58. A service-stop alert would have reduced impact to near zero.

---

## 10. Related Documents

- [citrix_pool02_session_failure_analysis.md](citrix_pool02_session_failure_analysis.md) — Incident analysis with scope facts and ranked hypotheses
