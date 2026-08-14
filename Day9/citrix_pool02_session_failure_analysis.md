# Citrix VDI Session Launch Failure — Incident Analysis
**Pool:** FinBridge-VDI-Pool-02  
**Date:** 2026-08-13  
**Analyst:** DWP VDI Team  

---

## Incident Summary

22 of 30 users on `FinBridge-VDI-Pool-02` were unable to launch Citrix desktop sessions starting from approximately 08:58. The Citrix Session Broker returned error **1030 — "No machines available in the desktop group"** after timing out at 30,000 ms. The parallel pool `FinBridge-VDI-Pool-01` on the same site was fully operational throughout the incident.

---

## Scope Facts

### Affected Users and Pool

| Item | Detail |
|---|---|
| Affected pool | `FinBridge-VDI-Pool-02` |
| Affected users | 22 of 30 |
| Unaffected pool (same site) | `FinBridge-VDI-Pool-01` |
| First recorded failure | 08:58:03 (user jsmith) |

### Broker Error

| Field | Value |
|---|---|
| Error code | 1030 |
| Error message | `No machines available in the desktop group` |
| Broker timeout | 30,000 ms exceeded waiting for machine registration response |
| Timestamp | 08:58:34 |

> **Error 1030** is a documented Citrix broker error that fires when all machines in a delivery group are unregistered, unavailable, or at capacity and no machine can fulfil the launch request.

### Machine Catalog Registration Status

| Pool | Provisioned | Registered | Unregistered | Maintenance Mode |
|---|---|---|---|---|
| Pool-02 | 25 | 3 | **22** | 0 |
| Pool-01 | 20 | 19 | 1 | 0 |

#### Sample Unregistered Machine Errors (Pool-02)

```
VDI-P02-014: Last registration attempt 06:15:22
  Error: Unable to contact Delivery Controller
         dc-vdi-02.finbridge.local:80 — connection refused

VDI-P02-017: Last registration attempt 06:16:01
  Error: Unable to contact Delivery Controller
         dc-vdi-02.finbridge.local:80 — connection refused
```

All unregistered Pool-02 VDAs report the same error targeting `dc-vdi-02.finbridge.local:80`.

### Delivery Controller Health

| Controller | Broker Service | Notes |
|---|---|---|
| `dc-vdi-02` (Pool-02) | **STOPPED** | Last running yesterday 23:40. Windows Update installed today 00:15 with reboot-required flag set. Host not rebooted. |
| `dc-vdi-01` (Pool-01) | RUNNING | 14 days uptime. No changes. No issues. |

---

## Probable Cause Analysis

### Ranked Hypotheses

**Hypothesis 1 — Windows Update stopped the Citrix Broker Service on dc-vdi-02** *(Highest confidence)*

The Citrix Broker Service on dc-vdi-02 was last running at 23:40. Windows Update ran 35 minutes later at 00:15 and set a reboot-required flag. WU routinely stops service dependencies during package installation. The service did not restart after the update and the host was not rebooted. All 22 VDAs that register against dc-vdi-02 subsequently failed registration. dc-vdi-01, which had no changes, served Pool-01 without issue. The isolation to a single controller with a precisely timed service event is the defining indicator.

**Hypothesis 2 — Pending reboot left dc-vdi-02 unable to run the service cleanly**

The reboot-required flag is set. Some updates replace locked DLLs or file handles that the Broker Service depends on, preventing stable operation until reboot. The service may start briefly and then crash. This is a variant of Hypothesis 1 — if starting the service does not hold, this is the explanation.

**Hypothesis 3 — KB patch compatibility conflict with installed Citrix version**

A specific Windows Update KB may have introduced a library or registry conflict with the Citrix Broker Service binaries. Less likely because the service stopped at the time of update install rather than after a successful start, but cannot be ruled out without checking the specific KB.

### Finalised Root Cause

**Windows Update installed on `dc-vdi-02.finbridge.local` at 00:15 stopped the Citrix Broker Service as part of its service management during package installation. The host was not rebooted. The service remained in a STOPPED state. All 22 Pool-02 VDAs that exclusively register against dc-vdi-02 received "connection refused" on port 80 from 06:15 onward, rendering them unregistered. With only 3 of 25 machines registered, the broker could not fulfil session requests and returned error 1030 to all 22 affected users from 08:58.**

---

## Remediation Steps

### Order of Operations

1. **Remote into dc-vdi-02** via RDP or console (not via Citrix).

2. **Record pre-change state** — capture service status and event log before touching anything:
   ```powershell
   Get-Service "CitrixBrokerService" | Select Name, Status, StartType
   Get-EventLog -LogName System -Source "Service Control Manager" -Newest 20 |
     Where-Object { $_.Message -match "Citrix" } | Select TimeGenerated, Message
   ```

3. **Start the Citrix Broker Service:**
   ```powershell
   Start-Service "CitrixBrokerService"
   Start-Sleep -Seconds 10
   Get-Service "CitrixBrokerService" | Select Name, Status
   ```

4. **Confirm port 80 is listening:**
   ```powershell
   netstat -ano | findstr ":80"
   # Or from another machine:
   Test-NetConnection -ComputerName dc-vdi-02.finbridge.local -Port 80
   ```

5. **Monitor VDA re-registration** (allow 2–5 minutes):
   ```powershell
   Get-BrokerMachine -DesktopGroupName "FinBridge-VDI-Pool-02" |
     Select MachineName, RegistrationState | Sort RegistrationState
   ```

6. **Test a user session launch** on Pool-02 to confirm end-to-end recovery.

7. **Schedule a controlled reboot** of dc-vdi-02 in the next maintenance window to clear the pending-reboot flag. Verify pool health after reboot.

### Verification Checks

| Check | Expected Result |
|---|---|
| `Get-Service "CitrixBrokerService"` on dc-vdi-02 | Status: Running |
| `Test-NetConnection dc-vdi-02.finbridge.local -Port 80` | TcpTestSucceeded: True |
| Pool-02 registered machine count | ≥ 22 registered |
| User test session launch on Pool-02 | Session launches, no error 1030 |
| Pending reboot key (post-reboot) | `Test-Path HKLM:\...\RebootPending` returns False |

---

## Preventive Actions

| Action | Detail |
|---|---|
| Maintenance window patching | Configure WSUS/Update Rings to patch Delivery Controllers only within an approved weekend maintenance window with human sign-off — not automated off-hours |
| Service health alerting | Alert on-call when `CitrixBrokerService` stops on any Delivery Controller. Target: page within 15 minutes, not 8+ hours |
| Pre-patch KB compatibility check | Cross-reference each approved KB against Citrix CTX support articles before applying to Delivery Controllers |
| VDA dual-controller registration | Configure Pool-02 VDAs to register against both dc-vdi-01 and dc-vdi-02. A single controller failure will then not cause a full pool outage |
