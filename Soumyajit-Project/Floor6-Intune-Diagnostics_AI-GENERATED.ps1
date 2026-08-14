# PowerShell Diagnostic Script: Floor 6 Legal Intune Device Compliance Check
# Purpose: Gather evidence for Hypothesis #1 (Intune device compliance blocking logon)
# Usage: .\Floor6-IntuneDiagnostics.ps1 [-DryRun] [-OutputPath C:\Temp]
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
    $null = New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction Stop
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$OutputPath\Floor6-Intune-Diagnostics_$timestamp.log"
$csvOutput = "$OutputPath\Floor6-Compliance-Report_$timestamp.csv"

# Output arrays for structured results
$complianceResults = @()
$eventLogFindings = @()
$systemInfo = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    if ($Verbose) { Write-Host $logEntry }
}

#endregion

#region DRY-RUN MODE
if ($DryRun) {
    Write-Host "=== DRY-RUN MODE ===" -ForegroundColor Yellow
    Write-Host "This script will:"
    Write-Host "  1. Query local device name and domain membership"
    Write-Host "  2. Check Intune MDM enrollment status"
    Write-Host "  3. Query Event Viewer for compliance/auth failures (last 2 hours)"
    Write-Host "  4. Parse Windows logon process for timing and resource usage"
    Write-Host "  5. Output results to CSV and log file"
    Write-Host ""
    Write-Host "To run with actual data collection, execute without -DryRun flag"
    Write-Host "Output location: $OutputPath"
    exit 0
}

Write-Log "Script started. Output path: $OutputPath" "START"

#endregion

#region SECTION 1: SYSTEM & DEVICE INFORMATION
Write-Log "=== SECTION 1: System and Device Information ===" "INFO"

try {
    $computerName = [System.Net.Dns]::GetHostName()
    $domainName = (Get-WmiObject Win32_ComputerSystem).Domain
    $osInfo = Get-WmiObject Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber
    $lastBootTime = $osInfo.LastBootUpTime
    
    $systemInfo += [PSCustomObject]@{
        ComputerName = $computerName
        Domain = $domainName
        OS = $osInfo.Caption
        BuildNumber = $osInfo.BuildNumber
        LastBootTime = $lastBootTime
        DiagnosticTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    Write-Log "Device: $computerName, Domain: $domainName, OS: $($osInfo.Caption)" "INFO"
}
catch {
    Write-Log "Error retrieving system info: $_" "ERROR"
}

#endregion

#region SECTION 2: INTUNE MDM ENROLLMENT STATUS
Write-Log "=== SECTION 2: Intune MDM Enrollment Status ===" "INFO"

try {
    # Check if device is Intune-enrolled via registry
    $intuneEnrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    $intuneStatus = $false
    $enrollmentID = "N/A"
    
    if (Test-Path $intuneEnrollmentPath) {
        $enrollments = Get-ChildItem $intuneEnrollmentPath -ErrorAction SilentlyContinue
        if ($enrollments.Count -gt 0) {
            $intuneStatus = $true
            $enrollmentID = $enrollments[0].PSChildName
            Write-Log "Intune enrollment detected. Enrollment ID: $enrollmentID" "INFO"
        }
    }
    
    # Query MDM certificate status
    $mdmCertPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\$enrollmentID\DMClient\Provider"
    $mdmCert = Get-ItemProperty $mdmCertPath -Name "DMCertEnrollment" -ErrorAction SilentlyContinue
    
    $complianceResults += [PSCustomObject]@{
        Check = "Intune Enrollment"
        Status = if ($intuneStatus) { "Enrolled" } else { "Not Enrolled" }
        EnrollmentID = $enrollmentID
        DetailValue = if ($intuneStatus) { "Device is Intune-enrolled" } else { "WARNING: Device not Intune-enrolled" }
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
catch {
    Write-Log "Error checking Intune enrollment: $_" "ERROR"
    $complianceResults += [PSCustomObject]@{
        Check = "Intune Enrollment"
        Status = "Error"
        DetailValue = $_.Exception.Message
        Timestamp = Get-Date
    }
}

#endregion

#region SECTION 3: DEVICE COMPLIANCE POLICY STATUS (via WMI/Registry)
Write-Log "=== SECTION 3: Device Compliance Policy Status ===" "INFO"

try {
    # Query Device Management WMI class for compliance status
    $dmPath = "HKLM:\SOFTWARE\Microsoft\DeviceManagementServiceConfig"
    
    # Check for common compliance requirements
    $complianceChecks = @{
        "BitLockerStatus" = "HKLM:\SYSTEM\CurrentControlSet\Services\bdedrv"
        "AntivirusStatus" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        "WindowsUpdateStatus" = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    }
    
    foreach ($check in $complianceChecks.GetEnumerator()) {
        $checkName = $check.Key
        $checkPath = $check.Value
        
        if (Test-Path $checkPath) {
            $status = "Present"
            Write-Log "Compliance check '$checkName' found at registry path" "INFO"
        } else {
            $status = "Not Found"
            Write-Log "Compliance check '$checkName' NOT found (may indicate non-compliance)" "WARN"
        }
        
        $complianceResults += [PSCustomObject]@{
            Check = "Compliance: $checkName"
            Status = $status
            RegistryPath = $checkPath
            DetailValue = "Check if this setting is compliant with Intune policy"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking compliance policy: $_" "ERROR"
}

#endregion

#region SECTION 4: EVENT VIEWER - LOGON & COMPLIANCE FAILURES (Last 2 Hours)
Write-Log "=== SECTION 4: Event Viewer Analysis (Last 2 Hours) ===" "INFO"

try {
    $twoHoursAgo = (Get-Date).AddHours(-2)
    $relevantEventIDs = @(
        4625,  # Failed logon
        4771,  # Pre-authentication failed (Kerberos)
        4776,  # The Domain Controller attempted to validate credentials
        1030,  # Group Policy failure
        1129,  # Group Policy failure - no domain controller
        1058,  # Failed to access SYSVOL
        5719,  # Domain Controller not available
        4720   # User account created (possible account lockout reset)
    )
    
    Write-Log "Querying Security event log for compliance/auth failures..." "INFO"
    
    $securityEvents = @()
    try {
        $securityEvents = Get-EventLog -LogName Security -After $twoHoursAgo -ErrorAction SilentlyContinue | 
            Where-Object { $_.EventID -in $relevantEventIDs } | 
            Select-Object @{Name="EventID"; Expression={$_.EventID}}, 
                          @{Name="Time"; Expression={$_.TimeGenerated}}, 
                          @{Name="Source"; Expression={$_.Source}}, 
                          @{Name="Message"; Expression={$_.Message.Substring(0, [Math]::Min(150, $_.Message.Length))}}
    }
    catch {
        Write-Log "Error accessing Security event log: $_" "WARN"
    }
    
    if ($securityEvents.Count -gt 0) {
        Write-Log "Found $($securityEvents.Count) relevant security events in last 2 hours" "WARN"
        foreach ($event in $securityEvents) {
            $eventLogFindings += [PSCustomObject]@{
                EventID = $event.EventID
                Time = $event.Time
                Source = $event.Source
                MessageSnippet = $event.Message
                Severity = "Check"
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        Write-Log "No relevant security events found in last 2 hours (good sign)" "INFO"
    }
}
catch {
    Write-Log "Error querying Event Viewer: $_" "ERROR"
}

#endregion

#region SECTION 5: LOGON PROCESS TIMING & RESOURCE ANALYSIS
Write-Log "=== SECTION 5: Logon Process Timing Analysis ===" "INFO"

try {
    # Query last logon event to estimate logon duration
    $lastLogonEvent = Get-EventLog -LogName Security -InstanceId 4624 -Newest 1 -ErrorAction SilentlyContinue
    
    if ($lastLogonEvent) {
        $logonTime = $lastLogonEvent.TimeGenerated
        $currentTime = Get-Date
        $logonDuration = ($currentTime - $logonTime).TotalSeconds
        
        Write-Log "Last successful logon: $logonTime (approx $($logonDuration) seconds ago)" "INFO"
        
        $complianceResults += [PSCustomObject]@{
            Check = "Last Logon Event"
            Status = if ($logonDuration -lt 600) { "Recent" } else { "Older" }
            DetailValue = "Last logon was $([Math]::Round($logonDuration)) seconds ago"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    # Check for hung processes during logon (common symptom of compliance check hanging)
    $processes = Get-Process | Where-Object { $_.Handles -gt 1000 } | Select-Object Name, Handles, CPU, Memory
    if ($processes.Count -gt 0) {
        Write-Log "High-handle processes detected (potential logon hang indicators):" "WARN"
        foreach ($proc in $processes) {
            Write-Log "  $($proc.Name): $($proc.Handles) handles, $($proc.CPU)% CPU, $([Math]::Round($proc.Memory/1MB))MB RAM" "WARN"
        }
    }
}
catch {
    Write-Log "Error analyzing logon timing: $_" "ERROR"
}

#endregion

#region SECTION 6: CONDITIONAL ACCESS POLICY INDICATORS
Write-Log "=== SECTION 6: Conditional Access Policy Indicators ===" "INFO"

try {
    # Check for MFA/CA enforcement indicators in registry
    $caPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    
    $complianceResults += [PSCustomObject]@{
        Check = "Conditional Access Policy"
        Status = "Requires Azure AD logs to confirm"
        DetailValue = "Local device cannot confirm CA policy; check Entra ID sign-in logs for policy blocks"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    Write-Log "Conditional Access policy status requires Entra ID sign-in log review (not available locally)" "INFO"
}
catch {
    Write-Log "Error checking CA indicators: $_" "ERROR"
}

#endregion

#region SECTION 7: DMS LOGON COMPONENT CHECK
Write-Log "=== SECTION 7: DMS Application Logon Component Check ===" "INFO"

try {
    # Check for DMS startup/logon scripts in registry
    $runKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )
    
    $dmsStartupFound = $false
    
    foreach ($runKey in $runKeys) {
        if (Test-Path $runKey) {
            $runEntries = Get-ItemProperty $runKey -ErrorAction SilentlyContinue
            $dmsEntries = $runEntries.PSObject.Properties | Where-Object { $_.Value -like "*DocManager*" -or $_.Value -like "*DMS*" }
            
            if ($dmsEntries) {
                $dmsStartupFound = $true
                Write-Log "DMS startup entry found: $($dmsEntries.Name)" "WARN"
                $complianceResults += [PSCustomObject]@{
                    Check = "DMS Startup Component"
                    Status = "Found"
                    DetailValue = "DMS runs at startup: $($dmsEntries.Value)"
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        }
    }
    
    if (-not $dmsStartupFound) {
        Write-Log "No DMS startup component found in registry" "INFO"
        $complianceResults += [PSCustomObject]@{
            Check = "DMS Startup Component"
            Status = "Not Found"
            DetailValue = "DMS does not run at startup (good for logon performance)"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking DMS logon component: $_" "ERROR"
}

#endregion

#region SECTION 8: FILE SYSTEM & FSLogix PROFILE CHECK
Write-Log "=== SECTION 8: FSLogix Profile Status ===" "INFO"

try {
    # Check if FSLogix is installed
    $fslogixPath = "HKLM:\SOFTWARE\FSLogix"
    $fslogixInstalled = Test-Path $fslogixPath
    
    if ($fslogixInstalled) {
        Write-Log "FSLogix detected" "INFO"
        
        # Check FSLogix log file for mount errors
        $fslogixLogPath = "C:\ProgramData\FSLogix\Logs"
        if (Test-Path $fslogixLogPath) {
            $latestLog = Get-ChildItem $fslogixLogPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestLog) {
                $fslogixContent = Get-Content $latestLog -Tail 50 -ErrorAction SilentlyContinue
                $mountErrors = $fslogixContent | Select-String -Pattern "error|failed|timeout" -ErrorAction SilentlyContinue
                
                if ($mountErrors.Count -gt 0) {
                    Write-Log "FSLogix errors detected in recent logs: $($mountErrors.Count) entries" "WARN"
                    $complianceResults += [PSCustomObject]@{
                        Check = "FSLogix Profile Mount"
                        Status = "Errors Detected"
                        DetailValue = "FSLogix mount errors or timeouts in recent logs"
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                } else {
                    Write-Log "FSLogix logs show no recent mount errors" "INFO"
                }
            }
        }
    } else {
        Write-Log "FSLogix not installed on this device" "INFO"
        $complianceResults += [PSCustomObject]@{
            Check = "FSLogix Status"
            Status = "Not Installed"
            DetailValue = "FSLogix not in use on this device"
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}
catch {
    Write-Log "Error checking FSLogix: $_" "ERROR"
}

#endregion

#region OUTPUT RESULTS
Write-Log "=== Generating output files ===" "INFO"

# Export to CSV
try {
    $complianceResults | Export-Csv -Path $csvOutput -NoTypeInformation -Encoding UTF8
    Write-Log "Results exported to: $csvOutput" "INFO"
}
catch {
    Write-Log "Error exporting CSV: $_" "ERROR"
}

# Display summary to console
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Floor 6 Intune Compliance Diagnostic - Summary" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

if ($systemInfo) {
    Write-Host "System Information:" -ForegroundColor Green
    $systemInfo | Format-Table -AutoSize | Out-String | Write-Host
}

Write-Host "Compliance & Status Checks:" -ForegroundColor Green
$complianceResults | Format-Table -AutoSize -Property Check, Status, DetailValue | Out-String | Write-Host

if ($eventLogFindings.Count -gt 0) {
    Write-Host "Event Log Findings (Last 2 Hours):" -ForegroundColor Yellow
    $eventLogFindings | Format-Table -AutoSize | Out-String | Write-Host
}

Write-Host "Files saved to: $OutputPath" -ForegroundColor Yellow
Write-Host "  CSV Report: $(Split-Path $csvOutput -Leaf)" -ForegroundColor Yellow
Write-Host "  Log File: $(Split-Path $logFile -Leaf)" -ForegroundColor Yellow
Write-Host ""

Write-Log "Script completed successfully" "COMPLETE"

#endregion
