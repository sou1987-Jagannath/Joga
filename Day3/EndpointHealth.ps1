#Requires -Version 5.1

<#
.SYNOPSIS
    Reports endpoint health status for DWP-managed Windows machines.

.DESCRIPTION
    Strictly read-only script that gathers and displays endpoint health
    information including uptime, disk space, pending reboot status,
    top CPU/memory processes, and recent system errors. No system state
    is modified. Suitable for regular health checks and compliance audits.

.EXAMPLE
    .\EndpointHealth.ps1

.NOTES
    Author: DWP Engineering
    Version: 1.0
    Read-only operation — no registry writes, no service restarts, no file deletions.
#>

[CmdletBinding()]
param()

# ---------------------------------------------------------------------------
# SECTION 0 — Global header and formatting helpers
# Establishes the timestamp and colour-coded output functions used throughout
# the script.
# ---------------------------------------------------------------------------

$ReportTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$ComputerName    = $env:COMPUTERNAME
$OSInfo          = Get-CimInstance -ClassName Win32_OperatingSystem

# Helper to print section headers with visual separator
function Write-SectionHeader {
    param ([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

# Helper to highlight warnings in red
function Write-Warning-Red {
    param ([string]$Message)
    Write-Host "  [WARNING] $Message" -ForegroundColor Red
}

# Helper to highlight info in green
function Write-Info-Green {
    param ([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

# Header banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  DWP ENDPOINT HEALTH REPORT                                ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Computer: $ComputerName" -ForegroundColor Gray
Write-Host "  Timestamp: $ReportTimestamp" -ForegroundColor Gray
Write-Host "  User: $env:USERNAME" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------------------------
# SECTION 1 — System Uptime
# Retrieves the last boot time from Win32_OperatingSystem and calculates
# the elapsed time since reboot. This value is read-only and does not
# trigger any system changes.
# ---------------------------------------------------------------------------

Write-SectionHeader "1. SYSTEM UPTIME"

try {
    # VERIFY: Win32_OperatingSystem is a standard WMI class available on all Windows systems
    $lastBootTime = $OSInfo.LastBootUpTime
    $uptime       = (Get-Date) - $lastBootTime
    
    Write-Host "  Last boot: $($lastBootTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "  Current time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "  Uptime: $($uptime.Days) day(s), $($uptime.Hours) hour(s), $($uptime.Minutes) minute(s)" -ForegroundColor White
    
    if ($uptime.Days -lt 1) {
        Write-Warning-Red "Machine has been up for less than 1 day — recent reboot detected."
    }
    else {
        Write-Info-Green "Machine uptime is normal."
    }
}
catch {
    Write-Host "  [ERROR] Could not retrieve uptime information: $_" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# SECTION 2 — Free Disk Space
# Iterates through all logical disk drives and reports total size, used space,
# and free space. Flags drives with critically low free space. This is a
# purely informational read-only operation.
# ---------------------------------------------------------------------------

Write-SectionHeader "2. DISK SPACE ANALYSIS"

try {
    # VERIFY: Get-Volume is standard on Windows 8.1+ and Windows Server 2012 R2+
    # For older systems, use Get-WmiObject Win32_LogicalDisk instead
    $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
    
    if ($volumes.Count -eq 0) {
        Write-Host "  No fixed disk drives found." -ForegroundColor Yellow
    }
    else {
        foreach ($vol in $volumes) {
            $driveLetter = $vol.DriveLetter
            $sizeGB      = [math]::Round($vol.Size / 1GB, 2)
            $freeGB      = [math]::Round($vol.SizeRemaining / 1GB, 2)
            $usedGB      = $sizeGB - $freeGB
            $percentFree = [math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 2)
            
            Write-Host "  Drive: $($driveLetter):"
            Write-Host "    Total: $sizeGB GB | Used: $usedGB GB | Free: $freeGB GB ($percentFree%)"
            
            # Flag drives with less than 10% free space
            if ($percentFree -lt 10) {
                Write-Warning-Red "Drive $($driveLetter): is running low on free space (less than 10% remaining)."
            }
            elseif ($percentFree -lt 20) {
                Write-Host "    [CAUTION] Free space is below 20%." -ForegroundColor Yellow
            }
        }
    }
}
catch {
    Write-Host "  [ERROR] Could not retrieve disk space information: $_" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# SECTION 3 — Pending Reboot Check
# Queries the Windows registry for indicators that a reboot is pending.
# Multiple registry locations are checked to detect pending updates, pending
# rename operations, and component-based updates. This is a read-only
# registry query and does not modify any keys.
# ---------------------------------------------------------------------------

Write-SectionHeader "3. PENDING REBOOT STATUS"

try {
    $rebootPending = $false
    $reasons       = [System.Collections.Generic.List[string]]::new()
    
    # --- Check 1: Windows Update pending reboot ---
    # VERIFY: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired
    # This key exists on systems with pending Windows Update restarts.
    try {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $rebootPending = $true
            $reasons.Add("Windows Update reboot pending")
        }
    }
    catch { }
    
    # --- Check 2: Rename pending (CBS / System File Replacer) ---
    # VERIFY: HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations
    # Non-empty values indicate files queued for rename on next boot.
    try {
        $renameOps = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
                        -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($renameOps -and $renameOps.PendingFileRenameOperations) {
            $rebootPending = $true
            $reasons.Add("File rename operations pending (CBS / Update components)")
        }
    }
    catch { }
    
    # --- Check 3: Component-based servicing pending ---
    # VERIFY: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending
    try {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $rebootPending = $true
            $reasons.Add("Component-based servicing reboot pending")
        }
    }
    catch { }
    
    # --- Check 4: Domain join / rename pending ---
    # VERIFY: HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\AvoidSpnSet
    try {
        $avoidSpn = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' `
                        -Name 'AvoidSpnSet' -ErrorAction SilentlyContinue
        if ($avoidSpn -and $avoidSpn.AvoidSpnSet) {
            $rebootPending = $true
            $reasons.Add("Domain join or rename operation pending")
        }
    }
    catch { }
    
    # Report result
    if ($rebootPending) {
        Write-Warning-Red "REBOOT PENDING"
        foreach ($reason in $reasons) {
            Write-Host "    - $reason" -ForegroundColor Yellow
        }
    }
    else {
        Write-Info-Green "No reboot pending."
    }
}
catch {
    Write-Host "  [ERROR] Could not check pending reboot status: $_" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# SECTION 4 — Top 5 Processes by Memory (Working Set)
# Lists the 5 processes consuming the most RAM (private working set).
# This is a snapshot at the moment the script runs and does not trigger
# any process actions.
# ---------------------------------------------------------------------------

Write-SectionHeader "4. TOP 5 PROCESSES BY MEMORY (WORKING SET)"

try {
    # VERIFY: Get-Process is a standard PowerShell cmdlet available on all Windows systems
    $topMemProcs = Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 5
    
    if ($topMemProcs.Count -eq 0) {
        Write-Host "  No processes found." -ForegroundColor Yellow
    }
    else {
        $counter = 1
        foreach ($proc in $topMemProcs) {
            $memMB = [math]::Round($proc.WorkingSet / 1MB, 2)
            Write-Host "  $counter. $($proc.ProcessName) (PID: $($proc.Id))"
            Write-Host "       Memory: $memMB MB" -ForegroundColor White
            $counter++
        }
    }
}
catch {
    Write-Host "  [ERROR] Could not retrieve process memory information: $_" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# SECTION 5 — Top 5 Processes by CPU
# Lists the 5 processes with the highest CPU time (cumulative).
# This reflects the total CPU time a process has consumed since it started,
# not the instantaneous CPU percentage. This is a read-only observation.
# ---------------------------------------------------------------------------

Write-SectionHeader "5. TOP 5 PROCESSES BY CPU TIME"

try {
    # VERIFY: Get-Process with TotalProcessorTime is standard on all Windows systems
    # TotalProcessorTime = cumulative CPU time since process start (not real-time %)
    $topCpuProcs = Get-Process | Sort-Object -Property TotalProcessorTime -Descending | Select-Object -First 5
    
    if ($topCpuProcs.Count -eq 0) {
        Write-Host "  No processes found." -ForegroundColor Yellow
    }
    else {
        $counter = 1
        foreach ($proc in $topCpuProcs) {
            $cpuSeconds = $proc.TotalProcessorTime.TotalSeconds
            Write-Host "  $counter. $($proc.ProcessName) (PID: $($proc.Id))"
            Write-Host "       CPU Time: $([math]::Round($cpuSeconds, 2)) seconds" -ForegroundColor White
            $counter++
        }
    }
}
catch {
    Write-Host "  [ERROR] Could not retrieve process CPU information: $_" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# SECTION 6 — Last 5 System Log Errors
# Queries the Windows Event Log for the most recent 5 critical and error
# entries in the System event log. This is a read-only diagnostic query
# and does not clear or modify any event logs.
#
# IMPORTANT: This section requires sufficient permissions to read the System
# event log. Non-admin users may see fewer or no results depending on local
# event log security descriptors.
# ---------------------------------------------------------------------------

Write-SectionHeader "6. LAST 5 SYSTEM LOG ERRORS"

try {
    # VERIFY: 'System' is the standard Windows Event Log; name may differ in non-English locales
    # On some systems, try 'System' (English) or the localised equivalent
    $systemErrors = $null
    
    # Try the English name first
    try {
        $systemErrors = Get-WinEvent -LogName 'System' -MaxEvents 5000 -ErrorAction SilentlyContinue |
                        Where-Object { $_.LevelDisplayName -in @('Error', 'Critical') } |
                        Sort-Object -Property TimeCreated -Descending |
                        Select-Object -First 5
    }
    catch {
        # If 'System' fails, the fallback would be language-dependent
        Write-Host "  [WARN] Could not query 'System' log — verify the event log name for your OS locale." -ForegroundColor Yellow
    }
    
    if ($systemErrors -and $systemErrors.Count -gt 0) {
        $counter = 1
        foreach ($event in $systemErrors) {
            Write-Host "  $counter. [$($event.LevelDisplayName)] $(
                $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))"
            Write-Host "       Source: $($event.ProviderName)" -ForegroundColor DarkGray
            Write-Host "       Event ID: $($event.Id)" -ForegroundColor DarkGray
            Write-Host "       Message: $(
                $event.Message -split "`n" | Select-Object -First 1)" -ForegroundColor White
            Write-Host ""
            $counter++
        }
    }
    else {
        Write-Info-Green "No critical or error events in the System log (recent)."
    }
}
catch {
    Write-Host "  [ERROR] Could not retrieve system event log entries: $_" -ForegroundColor Red
    Write-Host "  Ensure you have permissions to read the System event log." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# SECTION 7 — Report footer
# Prints a closing timestamp and summary line.
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Report generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "  [NOTE] This script is READ-ONLY. No system state has been modified." -ForegroundColor Green
Write-Host ""
