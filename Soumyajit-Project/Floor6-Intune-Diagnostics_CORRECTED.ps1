# PowerShell Diagnostic Script: Floor 6 Legal Intune Device Compliance Check - CORRECTED VERSION
# Purpose: Gather evidence for Hypothesis #1 (Intune device compliance blocking logon)
# Usage: .\Floor6-IntuneDiagnostics-CORRECTED.ps1 [-DryRun] [-OutputPath C:\Temp] [-Verbose]
# Date: 2026-08-14

#region PARAMETERS
param(
    [switch]$DryRun = $false,
    [string]$OutputPath = "C:\Temp\Floor6-Diagnostics",
    [switch]$Verbose = $false
)
#endregion

#region INITIALIZATION
if (-not (Test-Path $OutputPath)) {
    try {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Cannot create output directory: $_"
        exit 1
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$OutputPath\Floor6-Intune-Diagnostics_$timestamp.log"
$csvOutput = "$OutputPath\Floor6-Compliance-Report_$timestamp.csv"
$jsonOutput = "$OutputPath\Floor6-Compliance-Report_$timestamp.json"

# Output arrays for structured results
$complianceResults = @()
$eventLogFindings = @()
$systemInfo = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    if ($Verbose) { Write-Host $logEntry -ForegroundColor Gray }
}

function Test-AdminPrivileges {
    $currentPrincipal = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentPrincipal)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#endregion

#region DRY-RUN MODE
if ($DryRun) {
    Write-Host "=== DRY-RUN MODE ===" -ForegroundColor Yellow
    Write-Host "This script will collect the following evidence:"
    Write-Host "  1. Device name, domain, OS version, Intune enrollment status"
    Write-Host "  2. BitLocker encryption status (compliance requirement)"
    Write-Host "  3. Windows Defender status and definition version (compliance)"
    Write-Host "  4. Windows Update pending status (compliance)"
    Write-Host "  5. Intune Management Extension service status and logs"
    Write-Host "  6. Security Event Log: failed logons, Kerberos failures (last 2 hours)"
    Write-Host "  7. System Event Log: Group Policy failures, domain trust issues (last 2 hours)"
    Write-Host "  8. Logon script execution time from Group Policy logs"
    Write-Host "  9. DMS application startup/logon components"
    Write-Host " 10. FSLogix profile mount status and timing"
    Write-Host ""
    Write-Host "Output: CSV (for pivot tables), JSON (for structured parsing), LOG (timestamped)"
    Write-Host "Location: $OutputPath"
    Write-Host ""
    Write-Host "To run with actual data collection: .\Floor6-IntuneDiagnostics-CORRECTED.ps1 -OutputPath $OutputPath"
    exit 0
}

# Check for admin privileges (required for event log access)
if (-not (Test-AdminPrivileges)) {
    Write-Host "WARNING: This script is not running as Administrator. Some checks may fail." -ForegroundColor Yellow
    Write-Host "Recommend: Run PowerShell as Administrator for complete diagnostics." -ForegroundColor Yellow
}

Write-Log "Script started. Output path: $OutputPath" "START"

#endregion

#region SECTION 1: SYSTEM & DEVICE INFORMATION
Write-Log "=== SECTION 1: System and Device Information ===" "INFO"

try {
    $computerName = [System.Net.Dns]::GetHostName()
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
    $domainName = $computerInfo.CsDomain
    
    $systemInfo += [PSCustomObject]@{
        ComputerName = $computerName
        Domain = $domainName
        OS = $osInfo.Caption
        BuildNumber = $osInfo.BuildNumber
        InstallDate = $osInfo.InstallDate
        LastBootTime = $osInfo.LastBootUpTime
        DiagnosticTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IsInDomain = $computerInfo.CsPartOfDomain
    }
    
    Write-Log "Device: $computerName | Domain: $domainName | OS Build: $($osInfo.BuildNumber)" "INFO"
}
catch {
    Write-Log "Error retrieving system info: $_" "ERROR"
    exit 1
}

#endregion

#region SECTION 2: INTUNE MDM ENROLLMENT STATUS
Write-Log "=== SECTION 2: Intune MDM Enrollment Status ===" "INFO"

try {
    $intuneEnrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    $intuneStatus = $false
    $enrollmentID = "N/A"
    $enrollmentTime = "N/A"
    
    if (Test-Path $intuneEnrollmentPath) {
        $enrollments = @(Get-ChildItem $intuneEnrollmentPath -ErrorAction SilentlyContinue)
        if ($enrollments.Count -gt 0) {
            $intuneStatus = $true
            $enrollmentID = $enrollments[0].PSChildName
            
            # Get enrollment timestamp
            $enrollmentProps = Get-ItemProperty "$intuneEnrollmentPath\$enrollmentID" -ErrorAction SilentlyContinue
            $enrollmentTime = $enrollmentProps.EnrollmentTime
            
            Write-Log "Intune enrollment detected. ID: $enrollmentID (Enrolled: $enrollmentTime)" "INFO"
        }
    }
    
    $complianceResults += [PSCustomObject]@{
        Category = "Enrollment"
        Check = "Intune MDM Status"
        Status = if ($intuneStatus) { "Enrolled" } else { "NOT ENROLLED" }
        Value = $enrollmentID
        Severity = if ($intuneStatus) { "OK" } else { "CRITICAL" }
        Notes = if ($intuneStatus) { "Device is enrolled in Intune" } else { "Device NOT enrolled - compliance policies will not apply" }
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
catch {
    Write-Log "Error checking Intune enrollment: $_" "ERROR"
}

#endregion

#region SECTION 3: INTUNE MANAGEMENT EXTENSION (IME) SERVICE STATUS
Write-Log "=== SECTION 3: Intune Management Extension Service ===" "INFO"

try {
    $imeService = Get-Service "IntuneManagementExtension" -ErrorAction SilentlyContinue
    
    if ($imeService) {
        $imeStatus = $imeService.Status
        $imeStartType = $imeService.StartType
        
        Write-Log "IME Service Status: $imeStatus | StartType: $imeStartType" "INFO"
        
        # Check IME log for recent compliance check results
        $imeLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
        $imeErrors = @()
        $imeLastCheck = "Unknown"
        
        if (Test-Path $imeLogPath) {
            $imeLog = Get-Content $imeLogPath -Tail 200 -ErrorAction SilentlyContinue
            $imeErrors = $imeLog | Select-String -Pattern "error|failed|compliance check failed" -ErrorAction SilentlyContinue
            
            # Extract last compliance check timestamp
            $checkLine = $imeLog | Select-String -Pattern "compliance|policy" -ErrorAction SilentlyContinue | Select-Object -Last 1
            if ($checkLine) { $imeLastCheck = $checkLine.ToString().Substring(0, 50) }
        }
        
        $complianceResults += [PSCustomObject]@{
            Category = "Service"
            Check = "IME Service Status"
            Status = $imeStatus
            Value = $imeStartType
            Severity = if ($imeStatus -eq "Running") { "OK" } else { "CRITICAL" }
            Notes = "Intune Management Extension must be running for compliance checks"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        if ($imeErrors.Count -gt 0) {
            Write-Log "IME errors found: $($imeErrors.Count) entries" "WARN"
            $complianceResults += [PSCustomObject]@{
                Category = "Service"
                Check = "IME Log Errors"
                Status = "Errors Detected"
                Value = $imeErrors.Count
                Severity = "WARNING"
                Notes = "Check IME logs for detailed error messages"
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        Write-Log "IME Service not found - possible Intune unenrollment" "WARN"
        $complianceResults += [PSCustomObject]@{
            Category = "Service"
            Check = "IME Service Status"
            Status = "NOT FOUND"
            Value = "N/A"
            Severity = "CRITICAL"
            Notes = "Intune Management Extension service is not installed"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking IME service: $_" "ERROR"
}

#endregion

#region SECTION 4: BITLOCKER COMPLIANCE
Write-Log "=== SECTION 4: BitLocker Encryption Status ===" "INFO"

try {
    # Check if BitLocker cmdlets are available
    $blStatus = "N/A"
    $blPercentage = "N/A"
    $blVersion = "N/A"
    $blErrors = $null
    
    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        try {
            $bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
            
            foreach ($volume in $bitlockerVolumes) {
                $protectionStatus = $volume.ProtectionStatus
                $encryptionPercentage = $volume.EncryptionPercentage
                
                Write-Log "BitLocker: $($volume.MountPoint) - Status: $protectionStatus - Progress: $encryptionPercentage%" "INFO"
                
                $complianceResults += [PSCustomObject]@{
                    Category = "Compliance"
                    Check = "BitLocker: $($volume.MountPoint)"
                    Status = $protectionStatus
                    Value = "$encryptionPercentage%"
                    Severity = if ($protectionStatus -eq "On") { "OK" } else { "FAIL" }
                    Notes = if ($protectionStatus -ne "On") { "COMPLIANCE FAILED: BitLocker not enabled" } else { "BitLocker enabled" }
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        }
        catch {
            Write-Log "Error querying BitLocker: $_" "ERROR"
        }
    } else {
        Write-Log "BitLocker cmdlets not available on this system" "INFO"
    }
}
catch {
    Write-Log "Error in BitLocker check: $_" "ERROR"
}

#endregion

#region SECTION 5: MICROSOFT DEFENDER STATUS
Write-Log "=== SECTION 5: Microsoft Defender Antivirus Status ===" "INFO"

try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    
    if ($defenderStatus) {
        $defenderEnabled = $defenderStatus.AntivirusEnabled
        $rtpEnabled = $defenderStatus.RealTimeProtectionEnabled
        $signatureAge = $defenderStatus.AntivirusSignatureAge
        
        Write-Log "Defender: Enabled=$defenderEnabled | RealTimeProtection=$rtpEnabled | SignatureAge=$signatureAge days" "INFO"
        
        $complianceResults += [PSCustomObject]@{
            Category = "Compliance"
            Check = "Defender AntiVirus Enabled"
            Status = if ($defenderEnabled) { "Yes" } else { "No" }
            Value = $defenderEnabled
            Severity = if ($defenderEnabled) { "OK" } else { "FAIL" }
            Notes = if (-not $defenderEnabled) { "COMPLIANCE FAILED: Defender not enabled" } else { "Defender enabled" }
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $complianceResults += [PSCustomObject]@{
            Category = "Compliance"
            Check = "Defender Signature Age"
            Status = if ($signatureAge -le 7) { "Current" } else { "Outdated" }
            Value = "$signatureAge days"
            Severity = if ($signatureAge -le 7) { "OK" } else { "FAIL" }
            Notes = if ($signatureAge -gt 7) { "COMPLIANCE FAILED: Signatures >7 days old ($signatureAge days)" } else { "Signatures current" }
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    } else {
        Write-Log "Defender not found or not available" "WARN"
        $complianceResults += [PSCustomObject]@{
            Category = "Compliance"
            Check = "Defender Status"
            Status = "NOT FOUND"
            Value = "N/A"
            Severity = "FAIL"
            Notes = "Microsoft Defender not accessible (possible compliance failure)"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking Defender: $_" "ERROR"
}

#endregion

#region SECTION 6: WINDOWS UPDATE STATUS
Write-Log "=== SECTION 6: Windows Update Pending Status ===" "INFO"

try {
    # Check for pending updates using WMI
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateupdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0") -ErrorAction SilentlyContinue
    
    $pendingUpdateCount = $searchResult.Updates.Count
    
    Write-Log "Pending Windows Updates: $pendingUpdateCount" "INFO"
    
    $complianceResults += [PSCustomObject]@{
        Category = "Compliance"
        Check = "Windows Update Pending"
        Status = if ($pendingUpdateCount -eq 0) { "None" } else { "Pending" }
        Value = $pendingUpdateCount
        Severity = if ($pendingUpdateCount -eq 0) { "OK" } else { "FAIL" }
        Notes = if ($pendingUpdateCount -gt 0) { "COMPLIANCE FAILED: $pendingUpdateCount updates pending (may block logon)" } else { "No pending updates" }
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
catch {
    Write-Log "Error checking Windows Updates: $_" "WARN"
    $complianceResults += [PSCustomObject]@{
        Category = "Compliance"
        Check = "Windows Update Status"
        Status = "CHECK_FAILED"
        Value = "N/A"
        Severity = "UNKNOWN"
        Notes = "Could not query update status (check manually via Settings > Update & Security)"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

#endregion

#region SECTION 7: EVENT VIEWER ANALYSIS - LOGON FAILURES (Last 2 Hours)
Write-Log "=== SECTION 7: Security Event Log - Authentication Failures ===" "INFO"

try {
    $twoHoursAgo = (Get-Date).AddHours(-2)
    
    # Use Get-WinEvent instead of deprecated Get-EventLog
    $logonFailureFilter = @{
        LogName = 'Security'
        ID = 4625  # Failed logon
        StartTime = $twoHoursAgo
    }
    
    $failedLogons = Get-WinEvent -FilterHashtable $logonFailureFilter -ErrorAction SilentlyContinue
    
    if ($failedLogons.Count -gt 0) {
        Write-Log "FAILED LOGONS DETECTED: $($failedLogons.Count) in last 2 hours" "WARN"
        $complianceResults += [PSCustomObject]@{
            Category = "Authentication"
            Check = "Failed Logon Attempts (4625)"
            Status = "FAILED"
            Value = $failedLogons.Count
            Severity = "CRITICAL"
            Notes = "Multiple failed logon attempts - likely compliance policy blocking logon"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        # Sample first 3 failures
        $failedLogons | Select-Object -First 3 | ForEach-Object {
            $eventLogFindings += [PSCustomObject]@{
                EventID = $_.ID
                Time = $_.TimeCreated
                Source = "Security"
                Details = "Failed logon - check Intune compliance status"
                Severity = "CRITICAL"
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        Write-Log "No failed logons in last 2 hours (good sign)" "INFO"
        $complianceResults += [PSCustomObject]@{
            Category = "Authentication"
            Check = "Failed Logon Attempts"
            Status = "NONE"
            Value = 0
            Severity = "OK"
            Notes = "No failed logons in last 2 hours"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error querying failed logons: $_" "WARN"
}

#endregion

#region SECTION 8: EVENT VIEWER - KERBEROS & DOMAIN TRUST
Write-Log "=== SECTION 8: System Event Log - Group Policy & Domain Trust ===" "INFO"

try {
    $twoHoursAgo = (Get-Date).AddHours(-2)
    
    # Group Policy failures
    $gpFailureFilter = @{
        LogName = 'System'
        ID = @(1129, 1030, 1058)  # GP failures
        StartTime = $twoHoursAgo
    }
    
    $gpFailures = Get-WinEvent -FilterHashtable $gpFailureFilter -ErrorAction SilentlyContinue
    
    if ($gpFailures.Count -gt 0) {
        Write-Log "GROUP POLICY FAILURES: $($gpFailures.Count) events" "WARN"
        $complianceResults += [PSCustomObject]@{
            Category = "Infrastructure"
            Check = "Group Policy Application Failures"
            Status = "FAILED"
            Value = $gpFailures.Count
            Severity = "WARNING"
            Notes = "GP failures may indicate domain connectivity or policy corruption"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    # Domain trust issues
    $trustFailureFilter = @{
        LogName = 'System'
        ID = @(5719)  # DC not available
        StartTime = $twoHoursAgo
    }
    
    $trustFailures = Get-WinEvent -FilterHashtable $trustFailureFilter -ErrorAction SilentlyContinue
    
    if ($trustFailures.Count -gt 0) {
        Write-Log "DOMAIN TRUST FAILURES: $($trustFailures.Count) events" "WARN"
        $complianceResults += [PSCustomObject]@{
            Category = "Infrastructure"
            Check = "Domain Controller Availability (5719)"
            Status = "FAILED"
            Value = $trustFailures.Count
            Severity = "CRITICAL"
            Notes = "Domain controller not reachable - authentication will fail"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error querying system events: $_" "WARN"
}

#endregion

#region SECTION 9: DMS LOGON COMPONENT CHECK (Refined)
Write-Log "=== SECTION 9: DMS Application Logon Components ===" "INFO"

try {
    $dmsStartupFound = $false
    $dmsRunEntries = @()
    
    # Check HKLM Run keys (machine-wide startup)
    $runKeysHKLM = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    
    foreach ($runKey in $runKeysHKLM) {
        if (Test-Path $runKey -ErrorAction SilentlyContinue) {
            $entries = Get-ItemProperty $runKey -ErrorAction SilentlyContinue
            
            foreach ($prop in $entries.PSObject.Properties) {
                if ($prop.Value -like "*DocManager*" -or $prop.Value -like "*DMS*" -or $prop.Name -like "*DocManager*") {
                    $dmsStartupFound = $true
                    $dmsRunEntries += "$($prop.Name) = $($prop.Value)"
                    Write-Log "DMS startup entry found: $($prop.Name)" "WARN"
                }
            }
        }
    }
    
    # Check for DMS logon script (Group Policy)
    $scriptPath = "C:\Windows\System32\GroupPolicy\User\Scripts\Logon"
    $dmsLogonScripts = @()
    if (Test-Path $scriptPath -ErrorAction SilentlyContinue) {
        $dmsLogonScripts = Get-ChildItem $scriptPath -Filter "*DMS*" -ErrorAction SilentlyContinue
    }
    
    if ($dmsStartupFound -or $dmsLogonScripts.Count -gt 0) {
        Write-Log "DMS logon components found - potential logon flow impact" "WARN"
        $complianceResults += [PSCustomObject]@{
            Category = "Application"
            Check = "DMS Logon Components"
            Status = "FOUND"
            Value = "$($dmsRunEntries.Count) startup entries, $($dmsLogonScripts.Count) logon scripts"
            Severity = "WARNING"
            Notes = "DMS runs at logon - check event logs for hangs/crashes during 08:00-09:00"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    } else {
        Write-Log "No DMS logon components detected" "INFO"
        $complianceResults += [PSCustomObject]@{
            Category = "Application"
            Check = "DMS Logon Components"
            Status = "NONE"
            Value = "N/A"
            Severity = "OK"
            Notes = "DMS does not run at logon (rules out DMS as logon cause)"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking DMS components: $_" "ERROR"
}

#endregion

#region SECTION 10: FSLOGIX PROFILE STATUS
Write-Log "=== SECTION 10: FSLogix Profile Mount Status ===" "INFO"

try {
    $fslogixPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
    $fslogixInstalled = Test-Path $fslogixPath
    
    if ($fslogixInstalled) {
        Write-Log "FSLogix detected" "INFO"
        
        # Check FSLogix operational log for mount timing and errors
        $fslogixLogPath = "C:\ProgramData\FSLogix\Logs"
        
        if (Test-Path $fslogixLogPath) {
            $latestLog = Get-ChildItem $fslogixLogPath -Filter "*.log" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            
            if ($latestLog) {
                $fslogixContent = Get-Content $latestLog -ErrorAction SilentlyContinue
                
                # Parse for mount duration and errors
                $mountErrors = $fslogixContent | Select-String -Pattern "Error|Failed|Timeout|Exception" -ErrorAction SilentlyContinue
                $mountTimes = $fslogixContent | Select-String -Pattern "Elapsed:|Mount time:" -ErrorAction SilentlyContinue
                
                $mountDuration = "Unknown"
                if ($mountTimes.Count -gt 0) {
                    $mountDuration = $mountTimes[-1].ToString()
                }
                
                Write-Log "FSLogix mount log analyzed. Duration: $mountDuration | Errors: $($mountErrors.Count)" "INFO"
                
                $complianceResults += [PSCustomObject]@{
                    Category = "Profile"
                    Check = "FSLogix Profile Mount"
                    Status = if ($mountErrors.Count -eq 0) { "OK" } else { "ERRORS" }
                    Value = "$($mountErrors.Count) errors in logs"
                    Severity = if ($mountErrors.Count -eq 0) { "OK" } else { "WARNING" }
                    Notes = if ($mountErrors.Count -gt 0) { "FSLogix mount errors detected - check profile share connectivity" } else { "FSLogix profile mounts cleanly" }
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        } else {
            Write-Log "FSLogix logs directory not found" "WARN"
        }
    } else {
        Write-Log "FSLogix not installed" "INFO"
        $complianceResults += [PSCustomObject]@{
            Category = "Profile"
            Check = "FSLogix Status"
            Status = "NOT_INSTALLED"
            Value = "N/A"
            Severity = "OK"
            Notes = "FSLogix not in use - local profile handling in use"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking FSLogix: $_" "ERROR"
}

#endregion

#region OUTPUT GENERATION
Write-Log "=== Generating structured output files ===" "INFO"

try {
    # Export to CSV (for Excel pivot tables and filtering)
    $complianceResults | Export-Csv -Path $csvOutput -NoTypeInformation -Encoding UTF8 -Force
    Write-Log "CSV export complete: $csvOutput" "INFO"
    
    # Export to JSON (for structured programmatic parsing)
    $jsonObject = @{
        Metadata = @{
            ComputerName = $systemInfo[0].ComputerName
            DiagnosticTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            BuildNumber = $systemInfo[0].BuildNumber
        }
        ComplianceChecks = $complianceResults
        EventLogFindings = $eventLogFindings
    }
    $jsonObject | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonOutput -Encoding UTF8 -Force
    Write-Log "JSON export complete: $jsonOutput" "INFO"
}
catch {
    Write-Log "Error generating output: $_" "ERROR"
}

# Display structured console output
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "FLOOR 6 INTUNE COMPLIANCE DIAGNOSTIC REPORT" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Summary by category
Write-Host "COMPLIANCE STATUS SUMMARY:" -ForegroundColor Green
$complianceResults | Group-Object -Property Severity | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) checks" -ForegroundColor $(if ($_.Name -eq "OK") { "Green" } else { "Red" })
}
Write-Host ""

Write-Host "DETAILED FINDINGS:" -ForegroundColor Green
$complianceResults | Format-Table -Property Category, Check, Status, Severity, Notes -AutoSize -Wrap | Out-Host

if ($eventLogFindings.Count -gt 0) {
    Write-Host ""
    Write-Host "EVENT LOG DETAILS (Last 2 Hours):" -ForegroundColor Yellow
    $eventLogFindings | Format-Table -Property Time, EventID, Severity, Details -AutoSize | Out-Host
}

Write-Host ""
Write-Host "OUTPUT FILES SAVED:" -ForegroundColor Yellow
Write-Host "  CSV (Excel): $(Split-Path $csvOutput -Leaf)" -ForegroundColor Yellow
Write-Host "  JSON (Parsing): $(Split-Path $jsonOutput -Leaf)" -ForegroundColor Yellow
Write-Host "  LOG (Details): $(Split-Path $logFile -Leaf)" -ForegroundColor Yellow
Write-Host "  Location: $OutputPath" -ForegroundColor Yellow
Write-Host ""

# Diagnosis summary
$failureCount = @($complianceResults | Where-Object { $_.Severity -eq "FAIL" }).Count
$criticalCount = @($complianceResults | Where-Object { $_.Severity -eq "CRITICAL" }).Count

Write-Host "DIAGNOSTIC SUMMARY:" -ForegroundColor $(if ($failureCount -gt 0 -or $criticalCount -gt 0) { "Red" } else { "Green" })
if ($criticalCount -gt 0) {
    Write-Host "  ⚠️  CRITICAL ISSUES FOUND: $criticalCount" -ForegroundColor Red
    Write-Host "     Action: Escalate to Intune/Identity team immediately" -ForegroundColor Red
}
if ($failureCount -gt 0) {
    Write-Host "  ⚠️  COMPLIANCE FAILURES: $failureCount checks failed" -ForegroundColor Yellow
    Write-Host "     Action: Review failed items and remediate per Intune policy" -ForegroundColor Yellow
}
if ($failureCount -eq 0 -and $criticalCount -eq 0) {
    Write-Host "  ✓ All compliance checks passed" -ForegroundColor Green
    Write-Host "    Action: If user still experiencing login issues, check Azure AD sign-in logs" -ForegroundColor Green
}

Write-Host ""
Write-Log "Script completed successfully" "COMPLETE"

#endregion
