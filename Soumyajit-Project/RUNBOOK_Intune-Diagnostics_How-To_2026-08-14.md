# INCIDENT DIAGNOSTIC RUNBOOK: Floor 6 Legal Login Failures
## Using the Intune Compliance Script to Diagnose Hypothesis #1

**Date:** 2026-08-14  
**Incident:** ~12+ users on Floor 6 unable to log in or experiencing severe delays (Monday morning)  
**Top Hypothesis:** Intune device compliance policy blocking logon  
**Diagnostic Tool:** Floor6-Intune-Diagnostics_CORRECTED.ps1

---

## QUICK START (First 15 Minutes)

### Step 1: Prepare the Diagnostic Script
- **Location:** `C:\Temp\Floor6-Intune-Diagnostics_CORRECTED.ps1`
- **Prerequisites:** 
  - PowerShell 5.1 or later (check: `$PSVersionTable.PSVersion`)
  - Run as Administrator (required for Event Viewer access)
  - Network access to affected Floor 6 device

### Step 2: Run Dry-Run Mode (No Changes to Device)
```powershell
# On your local machine, preview what the script will do:
.\Floor6-Intune-Diagnostics_CORRECTED.ps1 -DryRun -Verbose
```

**Expected output:** Script tells you what it will collect (compliance status, event logs, IME service, DMS components, FSLogix), output locations, and how to run full diagnostics.

### Step 3: Execute Full Diagnostics on Affected Floor 6 Device
```powershell
# Run on affected device via RDP/remote session:
.\Floor6-Intune-Diagnostics_CORRECTED.ps1 -OutputPath C:\Temp\Floor6-Diags -Verbose

# Output will be:
# - C:\Temp\Floor6-Diags\Floor6-Compliance-Report_YYYYMMDD_HHMMSS.csv
# - C:\Temp\Floor6-Diags\Floor6-Compliance-Report_YYYYMMDD_HHMMSS.json
# - C:\Temp\Floor6-Diags\Floor6-Intune-Diagnostics_YYYYMMDD_HHMMSS.log
```

### Step 4: Review Results (Instant Triage)
```
COMPLIANCE STATUS SUMMARY:
  CRITICAL: 2 checks
  FAIL: 3 checks
  WARNING: 1 check
  OK: 8 checks
```

**If CRITICAL or FAIL present:** Intune compliance policy is blocking logon. **Escalate to Intune admin immediately.**

**If all OK:** Compliance is fine. **Pivot to Azure AD sign-in logs** (Check 2A from differential diagnosis).

---

## DETAILED EVIDENCE CAPTURE (Full Diagnostic Flow)

### What the Script Collects

| Section | What It Checks | Why | Output |
|---------|----------------|-----|--------|
| **1. System Info** | Device name, domain, OS build, Intune enrollment | Establishes baseline and confirms Intune enrollment | Device metadata |
| **2. Enrollment Status** | Registry: HKLM:\SOFTWARE\Microsoft\Enrollments | Confirms device is Intune-enrolled (critical prerequisite) | Enrollment ID, status |
| **3. IME Service** | Intune Management Extension service status + logs | IME must be Running to enforce compliance policies; service logs show recent compliance check results | Service status (Running/Stopped) + error count |
| **4. BitLocker** | Get-BitLockerVolume → protection status and %-encrypted | BitLocker encryption is a common compliance requirement; "On" = compliant, "Off" = failed | Protection status (On/Off/Unknown) |
| **5. Defender** | Get-MpComputerStatus → antivirus enabled + signature age | Defender must be enabled; signature age >7 days = compliance fail | AV enabled (Yes/No), signature age (days) |
| **6. Windows Updates** | Pending updates via Microsoft.Update.Session | Pending updates block logon in many Intune policies | Count of pending updates |
| **7. Failed Logons** | Event ID 4625 (last 2 hours) via Get-WinEvent | If present, confirms authentication is failing (not just slow) | Count of failed logons + timestamps |
| **8. Group Policy** | Event IDs 1129/1030/1058 (last 2 hours) | GP failures indicate infrastructure problems | Count of GP failures |
| **9. DMS Components** | Registry: HKLM\...\Run for DocManager/DMS entries | If DMS startup component exists and crashes, could hang logon | DMS startup entries (if any) |
| **10. FSLogix** | FSLogix service + profile mount logs | Slow profile mount = slow/failed logon | Mount status + errors (if any) |

### Understanding the Output

**CSV Format (Open in Excel):**
```
Category,Check,Status,Value,Severity,Notes,Timestamp
Enrollment,Intune MDM Status,Enrolled,enrollment-id-here,OK,Device is enrolled in Intune,2026-08-14 09:15:42
Service,IME Service Status,Running,Automatic,OK,Intune Management Extension must be running,2026-08-14 09:15:42
Compliance,BitLocker: C:,On,100%,OK,BitLocker enabled,2026-08-14 09:15:45
Compliance,Defender AntiVirus Enabled,Yes,Yes,OK,Defender enabled,2026-08-14 09:15:47
Compliance,Defender Signature Age,Current,2 days,OK,Signatures current,2026-08-14 09:15:47
Compliance,Windows Update Pending,None,0,OK,No pending updates,2026-08-14 09:15:48
Authentication,Failed Logon Attempts (4625),FAILED,12,CRITICAL,Multiple failed logons - likely compliance policy blocking,2026-08-14 09:15:52
```

**Key Columns:**
- **Severity:** OK = pass, WARNING = borderline, FAIL = fails compliance, CRITICAL = blocks logon
- **Value:** Actual status (e.g., "12" failed logons)
- **Notes:** Interpretation and action (e.g., "COMPLIANCE FAILED: BitLocker not enabled")

**JSON Format (Programmatic Parsing):**
```json
{
  "Metadata": {
    "ComputerName": "DESKTOP-ABC123",
    "DiagnosticTime": "2026-08-14 09:15:52",
    "BuildNumber": "22631"
  },
  "ComplianceChecks": [
    {
      "Category": "Compliance",
      "Check": "BitLocker: C:",
      "Status": "On",
      "Value": "100%",
      "Severity": "OK",
      "Notes": "BitLocker enabled",
      "Timestamp": "2026-08-14 09:15:45"
    },
    ...
  ]
}
```

---

## DIAGNOSTIC DECISION TREE

### START: Script executed successfully. Review results.

```
STEP 1: Check Severity Count
├─ Any CRITICAL or FAIL checks?
│  ├─ YES → Go to STEP 2A (Compliance Policy Blocking)
│  └─ NO → Go to STEP 2B (Compliance OK, Other Cause)
│
STEP 2A: Compliance Policy Blocking Logon
├─ Check: "Failed Logon Attempts" = CRITICAL or FAIL?
│  ├─ YES (12+ failed logons in Event Log) → Intune policy is blocking logon
│  │    ACTION: Escalate to Intune admin
│  │    Evidence: CSV shows which compliance check(s) failed
│  │    Remediation: Adjust device compliance policy or grant exemption
│  │
│  └─ NO (No failed logons) → User cannot log in, but not auth failure
│       Go to STEP 3 (Check for other causes)
│
STEP 2B: Compliance OK, Other Cause
├─ All compliance checks pass? → User should be able to log in
│  ACTION: Compliance is NOT the cause
│  ACTION: Pivot to Azure AD sign-in logs (Check 2A from differential)
│  Evidence: CSV shows all "OK" → policy is not blocking
│  Next Diagnostic: Query Entra ID sign-in logs for throttling/MFA
│
STEP 3: Root Cause Analysis (If Logon Fails But Compliance OK)
├─ Check "IME Service Status" = Running?
│  ├─ YES → Service is running, but compliance check not being enforced
│  │    Check Event Log for other errors (Group Policy, FSLogix, DMS)
│  │
│  └─ NO → IME service stopped; compliance policies not enforced
│       However, if service is stopped, Azure AD CA policy may still block
│       ACTION: Start IME service and re-test
│
STEP 4: DMS and FSLogix (Secondary Factors)
├─ "DMS Logon Components" = FOUND?
│  ├─ YES → DMS runs at logon; check event logs for DMS crashes
│  │    ACTION: Review Event Viewer for DMS-related exceptions during 08:00-09:00
│  │
│  └─ NO → DMS does not run at logon; rules out DMS as cause
│
├─ "FSLogix Profile Mount" = Errors?
│  ├─ YES → FSLogix mount taking >30 seconds or failing
│  │    ACTION: Check profile share connectivity and performance
│  │
│  └─ NO → FSLogix clean
│
```

---

## ACTUAL INCIDENT SCENARIO: How the Script Would Work

### Scenario: User Reports "Can't log in" on Floor 6 Device

**Time: Monday 08:45 AM**

```powershell
# 1. Remote into affected device via RDP
# 2. Open PowerShell as Administrator
# 3. Copy Floor6-Intune-Diagnostics_CORRECTED.ps1 to device
# 4. Run:
.\Floor6-Intune-Diagnostics_CORRECTED.ps1 -OutputPath C:\Temp\Floor6-Diags -Verbose

# Wait 3-5 minutes for diagnostics to complete
```

**Scenario A: BitLocker is OFF (Compliance Failed)**
```
COMPLIANCE STATUS SUMMARY:
  CRITICAL: 1 check
  FAIL: 1 check
  OK: 8 checks

DETAILED FINDINGS:
Category    Check                    Status  Severity  Notes
Compliance  BitLocker: C:            Off     FAIL      COMPLIANCE FAILED: BitLocker not enabled
Compliance  Windows Update Pending   Pending FAIL      COMPLIANCE FAILED: 5 updates pending
Authentication Failed Logon Attempts (4625) FAILED CRITICAL Multiple failed logons - policy blocking

ACTION:
  1. BitLocker is OFF → compliance policy blocks logon
  2. Windows updates pending → also blocks logon
  3. Escalate to Intune admin: "Device non-compliant due to BitLocker OFF + pending updates"
  4. Intune admin can either:
     a. Enable BitLocker on device + apply updates, then allow logon
     b. Grant temporary exemption to user pending remediation
```

**Scenario B: All Compliance Checks OK**
```
COMPLIANCE STATUS SUMMARY:
  OK: 10 checks

DETAILED FINDINGS:
Category    Check                    Status  Severity  Notes
Enrollment  Intune MDM Status        Enrolled OK      Device is enrolled
Compliance  BitLocker: C:            On      OK       BitLocker enabled
Compliance  Defender AntiVirus       Yes     OK       Defender enabled
Compliance  Defender Signature Age   Current OK       Signatures current (2 days)
Compliance  Windows Update Pending   None    OK       No pending updates
Service     IME Service Status       Running OK       IME service running
Authentication Failed Logon Attempts (4625) NONE OK  No failed logons in last 2h
Profile     FSLogix Profile Mount    OK      OK       FSLogix clean

DIAGNOSTIC SUMMARY:
✓ All compliance checks passed
  Action: If user still experiencing login issues, check Azure AD sign-in logs

ACTION:
  1. Device compliance is NOT the cause
  2. Escalate to Identity/Azure AD team: "User logon failing despite device compliance OK"
  3. Check Azure AD sign-in logs (Check 2A from differential) for:
     - Conditional Access policy block
     - Azure AD service degradation
     - MFA or certificate errors
```

---

## EVIDENCE PRESERVATION (For Compliance/Legal Review)

### What to Save
1. **CSV file** → Attach to ticket for Excel analysis
2. **JSON file** → Save for programmatic analysis / SIEM ingestion
3. **Log file** → Full details for forensic review
4. **Event Viewer screenshots** → Capture failed logon events (Event ID 4625) for audit trail

### How to Share Results
```powershell
# Compress results for ticket attachment
$files = Get-ChildItem C:\Temp\Floor6-Diags\
Compress-Archive -Path $files -DestinationPath C:\Temp\Floor6-Diags.zip

# Copy to network share for team review
Copy-Item C:\Temp\Floor6-Diags.zip \\network\support\incidents\Floor6-LoginFailure-20260814\
```

---

## TROUBLESHOOTING THE SCRIPT ITSELF

| Issue | Symptom | Fix |
|-------|---------|-----|
| Script runs but "no output" | Script completes silently | Add `-Verbose` flag to see progress |
| "Access Denied" errors | Running as non-admin | Run PowerShell as Administrator |
| BitLocker/Defender check returns "N/A" | Cmdlets not available | Normal on minimal Windows builds; non-blocking |
| "Event log inaccessible" | Insufficient permissions | Run as admin; may need domain admin for network trace |
| "Output path not found" | `-OutputPath` directory doesn't exist | Script creates it automatically; check path syntax |

---

## INTEGRATION WITH OVERALL DIAGNOSTIC FLOW

This script is **Check 3A** from the Differential Diagnosis table.

```
Diagnostic Flow:
  → Check 1A (Intune compliance dashboard) — 5 min, high-level overview
  → Check 2A (Azure AD sign-in logs) — 5 min, infrastructure check
  → Check 3A (This Script: Floor 6 Intune Diagnostics) ← YOU ARE HERE
     Runs locally on affected device
     Deep-dives into device compliance, IME service, event logs
     Confirms or rules out Intune policy as root cause
  → Based on 3A results, escalate to Intune/Identity/Desktop team
```

---

## REFERENCE: Script Execution Timeline

| Step | Time | Owner | Output |
|------|------|-------|--------|
| 1. Run dry-run to preview | 1 min | On-call engineer | Confirmation of what script will do |
| 2. Copy script to Floor 6 device | 2 min | Help desk / RDP session | Script ready to execute |
| 3. Execute full diagnostics | 3–5 min | Device owner or admin | CSV + JSON + LOG files |
| 4. Review results | 2 min | On-call engineer | Instant diagnosis (CRITICAL/FAIL vs. OK) |
| 5. Escalate to owning team | 1 min | Incident commander | Ticket with CSV attachment + root cause hypothesis |

**Total time: 10–15 minutes from incident report to escalation with actionable evidence.**

---

**Document prepared by:** DWP Engineering  
**Classification:** Internal — Incident Response Runbook  
**Version:** 1.0  
**Related Files:**
- `Floor6-Intune-Diagnostics_CORRECTED.ps1` (Production script)
- `Floor6-Intune-Diagnostics_AI-GENERATED.ps1` (AI baseline for comparison)
- `SCRIPT-CORRECTIONS_AI-vs-Corrected_2026-08-14.md` (Detailed fix explanations)
- `floor6_login_failure_differential_diagnosis_2026-08-14.md` (Full diagnostic strategy)
