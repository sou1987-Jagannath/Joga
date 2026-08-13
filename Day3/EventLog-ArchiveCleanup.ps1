#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Archives and cleans up Windows Event Logs on DWP-managed endpoints.

.DESCRIPTION
    This script exports Windows Event Logs to EVTX archive files and clears
    them from the system. It supports dry-run simulation, a configurable age
    threshold, idempotent execution (skips if today's archive already exists),
    rollback of a previous archive session, structured error handling, and a
    final summary report. All actions are written to a date-timestamped log file.

.PARAMETER DryRun
    Simulates the operation. Prints the count of event records that would be
    archived/deleted per log without making any changes.

.PARAMETER DaysOld
    Only process event logs that contain events older than this many days.
    Default is 3.

.PARAMETER ArchivePath
    Root directory where archived EVTX files will be stored per run date.
    Default: C:\EventLogArchives

.PARAMETER LogDirectory
    Directory where the script activity log file is written.
    Default: C:\EventLogArchives\ScriptLogs

.PARAMETER Rollback
    Instead of archiving, restores archived logs from the specified RollbackDate
    by copying them to a Restored subfolder for review in Event Viewer.

.PARAMETER RollbackDate
    The archive date (format: yyyyMMdd) to roll back. Defaults to today's date.

.EXAMPLE
    # Dry run — see what would be archived without making changes
    .\EventLog-ArchiveCleanup.ps1 -DryRun

.EXAMPLE
    # Archive and clear logs containing events older than 7 days
    .\EventLog-ArchiveCleanup.ps1 -DaysOld 7

.EXAMPLE
    # Archive to a custom path
    .\EventLog-ArchiveCleanup.ps1 -ArchivePath "D:\Backups\EventLogs"

.EXAMPLE
    # Roll back the archive created on 10 August 2026
    .\EventLog-ArchiveCleanup.ps1 -Rollback -RollbackDate "20260810"
#>

[CmdletBinding()]
param (
    # Simulate only — no files written, no logs cleared
    [switch]$DryRun,

    # Minimum age in days for events that qualify a log for archiving
    [ValidateRange(1, 3650)]
    [int]$DaysOld = 3,

    # Root folder that will hold dated archive sub-folders
    [string]$ArchivePath = "C:\EventLogArchives",

    # Folder for this script's own activity log files
    [string]$LogDirectory = "C:\EventLogArchives\ScriptLogs",

    # Switch into rollback mode
    [switch]$Rollback,

    # Archive date to restore during rollback (defaults to today)
    [ValidatePattern('^\d{8}$')]
    [string]$RollbackDate = (Get-Date -Format 'yyyyMMdd')
)

# ---------------------------------------------------------------------------
# SECTION 1 — Script-wide constants and state tracking
# Establishes the runtime date stamp, paths derived from parameters, and the
# counters used in the final summary report.
# ---------------------------------------------------------------------------

# Timestamp used in both the archive folder name and the log file name
$RunDateStamp  = Get-Date -Format 'yyyyMMdd'
$RunTimeStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'

# Each run's archives live in their own dated sub-folder for easy rollback
$TodayArchiveFolder = Join-Path $ArchivePath $RunDateStamp

# Manifest file records every action taken so rollback knows what to restore
$ManifestFile = Join-Path $TodayArchiveFolder "manifest_$RunTimeStamp.csv"

# Script activity log — one per execution run
$ScriptLogFile = Join-Path $LogDirectory "EventLogCleanup_$RunTimeStamp.log"

# Summary counters
$Summary = [ordered]@{
    LogsEvaluated   = 0
    LogsSkipped     = 0   # Already archived today (idempotency)
    LogsArchived    = 0
    LogsCleared     = 0
    LogsFailed      = 0
    TotalOldEvents  = 0   # Across all targeted logs
    Errors          = [System.Collections.Generic.List[string]]::new()
}

# Cutoff: events with TimeCreated older than this date are "old"
$CutoffDate = (Get-Date).AddDays(-$DaysOld)

# ---------------------------------------------------------------------------
# SECTION 2 — Logging helper
# Write-Log writes a timestamped, severity-tagged message to both the console
# and the script activity log file. The log file is created on first call.
# ---------------------------------------------------------------------------

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DRY')]
        [string]$Level = 'INFO'
    )

    $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    # Echo to the console with colour coding for readability
    switch ($Level) {
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        'ERROR' { Write-Host $entry -ForegroundColor Red    }
        'DRY'   { Write-Host $entry -ForegroundColor Cyan   }
        default { Write-Host $entry }
    }

    # Append to the log file — errors here are non-fatal (best-effort logging)
    try {
        Add-Content -Path $ScriptLogFile -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Host "[WARN] Unable to write to log file: $_" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# SECTION 3 — Directory initialisation
# Creates the archive root, today's dated sub-folder, and the log directory
# if they do not already exist. Skipped entirely during dry runs.
# ---------------------------------------------------------------------------

function Initialize-Directories {
    foreach ($dir in @($LogDirectory, $ArchivePath, $TodayArchiveFolder)) {
        try {
            if (-not (Test-Path $dir)) {
                if (-not $DryRun) {
                    New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
                    Write-Log "Created directory: $dir"
                }
                else {
                    Write-Log "[DRY] Would create directory: $dir" -Level DRY
                }
            }
        }
        catch {
            Write-Log "Failed to create directory '$dir': $_" -Level ERROR
            $Summary.Errors.Add("Directory creation failed: $dir — $_")
        }
    }
}

# ---------------------------------------------------------------------------
# SECTION 4 — Manifest helpers
# The manifest is a CSV that records each archived log with its source name,
# archive file path, event count, and timestamp. It is the authoritative
# record used by the rollback function.
# ---------------------------------------------------------------------------

function Write-ManifestEntry {
    param (
        [string]$LogName,
        [string]$ArchiveFile,
        [int]$OldEventCount,
        [string]$Status         # Archived | Cleared | Failed
    )

    $row = [pscustomobject]@{
        Timestamp     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        LogName       = $LogName
        ArchiveFile   = $ArchiveFile
        OldEventCount = $OldEventCount
        Status        = $Status
    }

    try {
        # Export-Csv with -Append writes the header only on first call
        $row | Export-Csv -Path $ManifestFile -Append -NoTypeInformation -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to write manifest entry for '$LogName': $_" -Level WARN
    }
}

# ---------------------------------------------------------------------------
# SECTION 5 — Rollback function
# Locates the dated archive folder specified by -RollbackDate and copies all
# EVTX files into a Restored sub-folder. The original archived files are left
# intact. Instructions are printed on how to open the files in Event Viewer.
# ---------------------------------------------------------------------------

function Invoke-Rollback {
    Write-Log "=== ROLLBACK MODE — Target date: $RollbackDate ==="

    $rollbackSource = Join-Path $ArchivePath $RollbackDate
    $rollbackDest   = Join-Path $ArchivePath "Restored_$RollbackDate"

    # Verify the requested archive date folder exists
    if (-not (Test-Path $rollbackSource)) {
        Write-Log "No archive found for date '$RollbackDate' at: $rollbackSource" -Level ERROR
        Write-Log "Available archives:" -Level WARN
        try {
            Get-ChildItem -Path $ArchivePath -Directory -ErrorAction Stop |
                ForEach-Object { Write-Log "  $($_.Name)" -Level WARN }
        }
        catch {
            Write-Log "Could not list archive directory: $_" -Level ERROR
        }
        return
    }

    # Locate EVTX files in the archive
    try {
        $evtxFiles = Get-ChildItem -Path $rollbackSource -Filter '*.evtx' -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to read archive folder '$rollbackSource': $_" -Level ERROR
        return
    }

    if ($evtxFiles.Count -eq 0) {
        Write-Log "No EVTX files found in archive folder: $rollbackSource" -Level WARN
        return
    }

    # Create the restore destination folder
    try {
        if (-not (Test-Path $rollbackDest)) {
            New-Item -ItemType Directory -Path $rollbackDest -Force -ErrorAction Stop | Out-Null
        }
        Write-Log "Restore destination: $rollbackDest"
    }
    catch {
        Write-Log "Failed to create restore folder '$rollbackDest': $_" -Level ERROR
        return
    }

    # Copy each EVTX file to the restore folder
    $restoredCount = 0
    foreach ($file in $evtxFiles) {
        try {
            $destFile = Join-Path $rollbackDest $file.Name
            Copy-Item -Path $file.FullName -Destination $destFile -Force -ErrorAction Stop
            Write-Log "Restored: $($file.Name) -> $destFile"
            $restoredCount++
        }
        catch {
            Write-Log "Failed to restore '$($file.Name)': $_" -Level ERROR
        }
    }

    Write-Log "Rollback complete. $restoredCount of $($evtxFiles.Count) file(s) restored to: $rollbackDest"
    Write-Log "To view restored logs: Open Event Viewer > Action > Open Saved Log, then browse to: $rollbackDest"
}

# ---------------------------------------------------------------------------
# SECTION 6 — Core archive-and-clear function
# For a single named event log, this function:
#   1. Counts events older than $CutoffDate (dry-run stops here).
#   2. Checks for an existing archive (idempotency guard).
#   3. Exports the full log to an EVTX file via wevtutil.
#   4. Clears the log via wevtutil.
#   5. Writes a manifest entry.
# ---------------------------------------------------------------------------

function Invoke-ArchiveAndClear {
    param (
        [string]$LogName
    )

    $Summary.LogsEvaluated++
    Write-Log "Processing log: $LogName"

    # --- Step 6a: Count events older than the cutoff date ---
    # Uses Get-WinEvent FilterHashtable for efficient server-side filtering.
    $oldEventCount = 0
    try {
        $filterHT = @{
            LogName = $LogName
            EndTime = $CutoffDate
        }
        # ErrorAction SilentlyContinue suppresses the benign "no events found" error
        $oldEvents     = Get-WinEvent -FilterHashtable $filterHT -ErrorAction SilentlyContinue
        $oldEventCount = if ($oldEvents) { @($oldEvents).Count } else { 0 }
        $Summary.TotalOldEvents += $oldEventCount
    }
    catch {
        Write-Log "Failed to query events for '$LogName': $_" -Level ERROR
        $Summary.Errors.Add("Query failed: $LogName — $_")
        $Summary.LogsFailed++
        return
    }

    # Bail out if the log has no qualifying old events — nothing to do
    if ($oldEventCount -eq 0) {
        Write-Log "  No events older than $DaysOld day(s) found — skipping."
        $Summary.LogsSkipped++
        return
    }

    Write-Log "  Found $oldEventCount event(s) older than $DaysOld day(s)."

    # --- Step 6b: Dry-run short-circuit ---
    if ($DryRun) {
        Write-Log "  [DRY] Would archive and clear '$LogName' ($oldEventCount old event(s))." -Level DRY
        return
    }

    # --- Step 6c: Idempotency guard — skip if today's archive already exists ---
    # Archive filename encodes the log name (dots replaced with underscores) and date
    $safeName   = $LogName -replace '[/\\:\*\?"<>\|]', '_'
    $archiveFile = Join-Path $TodayArchiveFolder "$($safeName)_$RunDateStamp.evtx"

    if (Test-Path $archiveFile) {
        Write-Log "  Archive already exists for today — skipping (idempotent): $archiveFile" -Level WARN
        $Summary.LogsSkipped++
        return
    }

    # --- Step 6d: Export (archive) the event log to an EVTX file ---
    try {
        # wevtutil epl exports the full log; /ow:true overwrites if the file exists
        $exportOutput = & wevtutil epl $LogName $archiveFile /ow:true 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "wevtutil epl exited with code $LASTEXITCODE. Output: $exportOutput"
        }
        Write-Log "  Archived to: $archiveFile"
        $Summary.LogsArchived++

        Write-ManifestEntry -LogName $LogName -ArchiveFile $archiveFile `
                            -OldEventCount $oldEventCount -Status 'Archived'
    }
    catch {
        Write-Log "  Failed to archive '$LogName': $_" -Level ERROR
        $Summary.Errors.Add("Archive failed: $LogName — $_")
        $Summary.LogsFailed++
        return   # Do NOT clear the log if the archive failed
    }

    # --- Step 6e: Clear the event log ---
    # The log is only cleared AFTER a successful archive to protect data.
    try {
        $clearOutput = & wevtutil cl $LogName 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "wevtutil cl exited with code $LASTEXITCODE. Output: $clearOutput"
        }
        Write-Log "  Cleared log: $LogName"
        $Summary.LogsCleared++

        Write-ManifestEntry -LogName $LogName -ArchiveFile $archiveFile `
                            -OldEventCount $oldEventCount -Status 'Cleared'
    }
    catch {
        Write-Log "  Archive succeeded but CLEAR FAILED for '$LogName': $_" -Level ERROR
        Write-Log "  The archived EVTX is safe at: $archiveFile" -Level WARN
        $Summary.Errors.Add("Clear failed (archive is safe): $LogName — $_")
        $Summary.LogsFailed++
    }
}

# ---------------------------------------------------------------------------
# SECTION 7 — Target log list
# Defines the Windows Event Logs this script will evaluate. Classic Windows
# logs that are safe to archive on managed endpoints are listed here.
# Extend or trim this list to match your organisation's requirements.
# ---------------------------------------------------------------------------

$TargetLogs = @(
    'Application',
    'System',
    'Security',
    'Setup',
    'Microsoft-Windows-PowerShell/Operational',
    'Microsoft-Windows-TaskScheduler/Operational',
    'Microsoft-Windows-WindowsUpdateClient/Operational',
    'Microsoft-Windows-Bits-Client/Operational'
)

# ---------------------------------------------------------------------------
# SECTION 8 — Script entry point
# Orchestrates directory setup, mode detection (rollback vs. archive), the
# per-log processing loop, and the final summary report.
# ---------------------------------------------------------------------------

Write-Log "======================================================"
Write-Log " DWP EventLog Archive & Cleanup Script"
Write-Log " Run mode  : $(if ($DryRun) { 'DRY RUN (no changes)' } elseif ($Rollback) { 'ROLLBACK' } else { 'LIVE' })"
Write-Log " Cutoff    : Events older than $DaysOld day(s) (before $($CutoffDate.ToString('yyyy-MM-dd')))"
Write-Log " Archive   : $TodayArchiveFolder"
Write-Log " Script log: $ScriptLogFile"
Write-Log "======================================================"

# Always create at minimum the log directory so Write-Log can persist entries
Initialize-Directories

# --- Rollback mode: restore a previous archive, then exit ---
if ($Rollback) {
    try {
        Invoke-Rollback
    }
    catch {
        Write-Log "Rollback encountered an unexpected error: $_" -Level ERROR
    }
    exit 0
}

# --- Archive mode: process each target log ---
foreach ($logName in $TargetLogs) {
    # Verify the log exists on this machine before attempting any operation
    try {
        $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop
        Write-Log "Log found: $logName (Records: $($logInfo.RecordCount))"
    }
    catch {
        Write-Log "Log '$logName' not found or inaccessible on this machine — skipping." -Level WARN
        $Summary.LogsSkipped++
        continue
    }

    # Process the log through archive and clear
    try {
        Invoke-ArchiveAndClear -LogName $logName
    }
    catch {
        Write-Log "Unexpected error processing '$logName': $_" -Level ERROR
        $Summary.Errors.Add("Unexpected: $logName — $_")
        $Summary.LogsFailed++
    }
}

# ---------------------------------------------------------------------------
# SECTION 9 — Summary report
# Prints a structured summary of the run to both the console and the log file.
# ---------------------------------------------------------------------------

Write-Log "======================================================"
Write-Log " SUMMARY REPORT"
Write-Log "======================================================"
Write-Log " Logs evaluated  : $($Summary.LogsEvaluated)"
Write-Log " Logs skipped    : $($Summary.LogsSkipped)"
Write-Log " Logs archived   : $($Summary.LogsArchived)"
Write-Log " Logs cleared    : $($Summary.LogsCleared)"
Write-Log " Logs failed     : $($Summary.LogsFailed)"
Write-Log " Old events found: $($Summary.TotalOldEvents)"
if ($DryRun) {
    Write-Log " [DRY RUN — no files written, no logs cleared]" -Level DRY
}
if ($Summary.Errors.Count -gt 0) {
    Write-Log " Errors ($($Summary.Errors.Count)):" -Level WARN
    foreach ($err in $Summary.Errors) {
        Write-Log "   - $err" -Level WARN
    }
}
Write-Log "======================================================"
Write-Log " Script log saved to: $ScriptLogFile"
if (-not $DryRun -and $Summary.LogsArchived -gt 0) {
    Write-Log " Archives saved to  : $TodayArchiveFolder"
    Write-Log " Rollback command   : .\EventLog-ArchiveCleanup.ps1 -Rollback -RollbackDate $RunDateStamp"
}
Write-Log "======================================================"
