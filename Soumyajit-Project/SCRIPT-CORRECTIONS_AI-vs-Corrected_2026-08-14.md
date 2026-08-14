# SCRIPT CORRECTIONS: Floor 6 Intune Diagnostics
## AI-Generated vs. Hand-Corrected Side-by-Side Analysis

**Purpose:** Show actual debugging and corrections made to transform an AI-generated diagnostic script into production-ready code.

---

## FIX #1: Event Log Query Method (Deprecated vs. Current)

### ❌ AI-GENERATED (WRONG)
```powershell
$securityEvents = Get-EventLog -LogName Security -After $twoHoursAgo -ErrorAction SilentlyContinue | 
    Where-Object { $_.EventID -in $relevantEventIDs }
```

### ✅ CORRECTED
```powershell
$logonFailureFilter = @{
    LogName = 'Security'
    ID = 4625  # Failed logon
    StartTime = $twoHoursAgo
}
$failedLogons = Get-WinEvent -FilterHashtable $logonFailureFilter -ErrorAction SilentlyContinue
```

### 🔧 WHY THIS MATTERS (One line)
**Get-EventLog is deprecated in PowerShell 6+; Get-WinEvent is the current standard and filters at query time (faster, more efficient).**

---

## FIX #2: Compliance Status Checks (Registry Existence vs. Actual Status)

### ❌ AI-GENERATED (INADEQUATE)
```powershell
$complianceChecks = @{
    "BitLockerStatus" = "HKLM:\SYSTEM\CurrentControlSet\Services\bdedrv"
    "AntivirusStatus" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
}
foreach ($check in $complianceChecks.GetEnumerator()) {
    if (Test-Path $checkPath) {
        $status = "Present"
    } else {
        $status = "Not Found"
    }
}
```

### ✅ CORRECTED
```powershell
$defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defenderStatus) {
    $defenderEnabled = $defenderStatus.AntivirusEnabled
    $signatureAge = $defenderStatus.AntivirusSignatureAge
    # Reports actual status, not just "registry exists"
}

$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateupdateSearcher()
$searchResult = $updateSearcher.Search("IsInstalled=0")
$pendingUpdateCount = $searchResult.Updates.Count
# Actually counts pending updates
```

### 🔧 WHY THIS MATTERS (One line)
**Registry path existence ≠ compliance status; need actual cmdlets (Get-MpComputerStatus, WMI Update.Session) to query real-time status and compliance.**

---

## FIX #3: BitLocker Query (Robust Error Handling)

### ❌ AI-GENERATED (NO GUARD)
```powershell
$bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
foreach ($volume in $bitlockerVolumes) {
    $protectionStatus = $volume.ProtectionStatus
    # Could fail if volume is offline or BitLocker cmdlets not available
}
```

### ✅ CORRECTED
```powershell
if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
    try {
        $bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
        foreach ($volume in $bitlockerVolumes) {
            $protectionStatus = $volume.ProtectionStatus
            # Protected by pre-check for cmdlet availability
        }
    }
    catch {
        Write-Log "Error querying BitLocker: $_" "ERROR"
    }
} else {
    Write-Log "BitLocker cmdlets not available on this system" "INFO"
}
```

### 🔧 WHY THIS MATTERS (One line)
**Pre-check for cmdlet availability prevents cryptic errors on minimal Windows installs without BitLocker tools.**

---

## FIX #4: HKCU Registry Path (User Context Issue)

### ❌ AI-GENERATED (FAILS IN SYSTEM CONTEXT)
```powershell
$runKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"  # ← PROBLEM: HKCU requires user logged in
)
foreach ($runKey in $runKeys) {
    if (Test-Path $runKey) {
        $runEntries = Get-ItemProperty $runKey
    }
}
```

### ✅ CORRECTED
```powershell
$runKeysHKLM = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($runKey in $runKeysHKLM) {
    if (Test-Path $runKey -ErrorAction SilentlyContinue) {
        $entries = Get-ItemProperty $runKey -ErrorAction SilentlyContinue
        # Only check HKLM (machine-wide), not HKCU (user-specific)
    }
}
```

### 🔧 WHY THIS MATTERS (One line)
**Script runs as admin/system context; HKCU fails unless logged-in user's registry is loaded; removed HKCU entirely since DMS logon components would be machine-wide.**

---

## FIX #5: Intune Management Extension (IME) Service Check (Added Entirely)

### ❌ AI-GENERATED (MISSING)
```powershell
# (No IME service check at all)
# Script only checked registry enrollment, not active service status
```

### ✅ CORRECTED
```powershell
$imeService = Get-Service "IntuneManagementExtension" -ErrorAction SilentlyContinue
if ($imeService) {
    $imeStatus = $imeService.Status
    $imeStartType = $imeService.StartType
    
    # Check IME log for recent compliance check results
    $imeLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
    if (Test-Path $imeLogPath) {
        $imeLog = Get-Content $imeLogPath -Tail 200
        $imeErrors = $imeLog | Select-String -Pattern "error|failed|compliance check failed"
    }
}
```

### 🔧 WHY THIS MATTERS (One line)
**IME service must be Running to enforce compliance policies; if it's Stopped, no compliance checks happen → critical diagnostic signal.**

---

## FIX #6: Output Format (Unstructured vs. Actionable JSON/CSV)

### ❌ AI-GENERATED (TEXT-ONLY)
```powershell
Write-Host "Some text output"
# No machine-readable output; can't pivot in Excel or parse in another script
```

### ✅ CORRECTED
```powershell
# Export to CSV (for Excel pivot tables)
$complianceResults | Export-Csv -Path $csvOutput -NoTypeInformation -Encoding UTF8 -Force

# Export to JSON (for programmatic parsing)
$jsonObject = @{
    Metadata = @{ ComputerName = ...; DiagnosticTime = ... }
    ComplianceChecks = $complianceResults
    EventLogFindings = $eventLogFindings
}
$jsonObject | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonOutput -Encoding UTF8 -Force

# Structured console output with severity filtering
$complianceResults | Group-Object -Property Severity | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) checks"
}
```

### 🔧 WHY THIS MATTERS (One line)
**CSV enables Excel analysis/filtering; JSON enables integration with SIEM/ticketing; severity summary gives instant triage status.**

---

## FIX #7: Admin Privilege Check (Added)

### ❌ AI-GENERATED (MISSING)
```powershell
# No check for admin privileges
# Script silently fails if run as non-admin
```

### ✅ CORRECTED
```powershell
function Test-AdminPrivileges {
    $currentPrincipal = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentPrincipal)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-AdminPrivileges)) {
    Write-Host "WARNING: Running as non-admin. Some checks may fail." -ForegroundColor Yellow
}
```

### 🔧 WHY THIS MATTERS (One line)
**Event Viewer access requires admin; early warning prevents silent failures and wasted troubleshooting time.**

---

## FIX #8: Logon Duration Calculation (Wrong Math)

### ❌ AI-GENERATED (INCORRECT)
```powershell
$lastLogonEvent = Get-EventLog -LogName Security -InstanceId 4624 -Newest 1
$logonTime = $lastLogonEvent.TimeGenerated
$currentTime = Get-Date
$logonDuration = ($currentTime - $logonTime).TotalSeconds
# This calculates time SINCE logon, not logon DURATION
```

### ✅ CORRECTED
```powershell
# Parse FSLogix mount time from logs (actual logon duration)
$fslogixContent = Get-Content $latestLog
$mountTimes = $fslogixContent | Select-String -Pattern "Elapsed:|Mount time:"
if ($mountTimes.Count -gt 0) {
    $mountDuration = $mountTimes[-1].ToString()
    # Reports actual profile/logon duration from logs
}
```

### 🔧 WHY THIS MATTERS (One line)
**Time since logon ≠ logon duration; need to parse FSLogix logs to measure actual profile mount time (critical for slow-logon diagnosis).**

---

## FIX #9: Severity/Compliance Status Mapping (Added)

### ❌ AI-GENERATED (NO SEVERITY)
```powershell
$complianceResults += [PSCustomObject]@{
    Check = "BitLocker"
    Status = $status
    DetailValue = "..."
    # No way to sort/prioritize results
}
```

### ✅ CORRECTED
```powershell
$complianceResults += [PSCustomObject]@{
    Category = "Compliance"
    Check = "BitLocker: $($volume.MountPoint)"
    Status = $protectionStatus
    Value = "$encryptionPercentage%"
    Severity = if ($protectionStatus -eq "On") { "OK" } else { "FAIL" }
    Notes = if ($protectionStatus -ne "On") { "COMPLIANCE FAILED: BitLocker not enabled" } else { "..." }
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
```

### 🔧 WHY THIS MATTERS (One line)
**Severity column enables instant triage (OK/WARNING/FAIL/CRITICAL); on-call engineer can scan one column instead of reading all details.**

---

## FIX #10: Error Handling (Generic Catches vs. Specific Logging)

### ❌ AI-GENERATED (SWALLOWS ERRORS)
```powershell
catch {
    Write-Log "Error checking Intune enrollment: $_" "ERROR"
}
# Silently continues; unclear if actual problem or transient issue
```

### ✅ CORRECTED
```powershell
catch {
    Write-Log "Error checking Intune enrollment: $_" "ERROR"
    exit 1  # Halt if enrollment check fails (critical path)
}

# Or for non-critical checks:
catch {
    Write-Log "Error checking Defender: $_" "WARN"
    $complianceResults += [PSCustomObject]@{
        Check = "Defender Status"
        Status = "CHECK_FAILED"
        Severity = "UNKNOWN"
        Notes = "Could not query Defender (check manually)"
    }
    # Report the failure, don't hide it
}
```

### 🔧 WHY THIS MATTERS (One line)
**Distinguish critical-path failures (enrollment check must succeed) from informational failures (Defender check failure is reportable but non-blocking).**

---

## SUMMARY TABLE: AI-Generated vs. Corrected

| Issue | AI-Generated | Corrected | Impact |
|-------|-------------|-----------|--------|
| Event log query | Get-EventLog (deprecated) | Get-WinEvent (current) | Better performance, forward-compatible |
| Compliance status | Check registry paths exist | Run actual status cmdlets | Accurate compliance reporting |
| BitLocker check | Assumes cmdlet available | Pre-checks cmdlet availability | Handles all Windows versions |
| Registry paths | Includes HKCU (fails in system context) | HKLM only | Works in admin/system context |
| IME service check | Missing entirely | Added with log parsing | Catches service-level failures |
| Output format | Text only | CSV + JSON | Actionable for humans and systems |
| Admin check | Silent failure | Early warning message | Prevents wasted troubleshooting |
| Logon duration | Wrong calculation | Parses FSLogix logs correctly | Accurate timing data |
| Severity mapping | No severity column | OK/WARN/FAIL/CRITICAL | Instant triage |
| Error handling | Generic catch | Distinguish critical vs. informational | Better incident routing |

---

## HOW TO USE THESE SCRIPTS

### Run Dry-Run Mode (No Changes, Preview)
```powershell
.\Floor6-Intune-Diagnostics_CORRECTED.ps1 -DryRun -Verbose
```

### Run Full Diagnostics
```powershell
.\Floor6-Intune-Diagnostics_CORRECTED.ps1 -OutputPath C:\Temp\Floor6-Diags -Verbose
```

### Parse Results
```powershell
# In Excel: Open CSV file, create pivot table by Severity/Category
# In PowerShell: 
$results = Get-Content C:\Temp\Floor6-Diags\Floor6-Compliance-Report_*.json | ConvertFrom-Json
$results.ComplianceChecks | Where-Object { $_.Severity -eq "FAIL" }
```

---

**Document prepared by:** DWP Engineering  
**Date:** 2026-08-14  
**Version:** 1.0 (Corrected from AI-generated baseline)
