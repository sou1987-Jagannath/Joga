#Requires -Version 5.1

<#
.SYNOPSIS
    Safely cleans up temporary files on DWP-managed Windows endpoints.

.DESCRIPTION
    Identifies temporary files across well-known temp locations, optionally
    filtered by age, and moves them to a staging folder instead of deleting
    outright. This makes every run reversible via -Rollback. Locked files are
    skipped and logged rather than causing the script to abort. A dry-run mode
    lists candidate files without touching the filesystem.

    Four operating modes:
      Normal  — Moves qualifying temp files to a dated staging folder.
      DryRun  — Lists files that would be moved; no filesystem changes.
      Rollback — Restores files from a staging session back to their original paths.
      Purge   — Permanently deletes a staging session (commits the deletion).

.PARAMETER DryRun
    List all files that would be processed. No files are moved or deleted.

.PARAMETER DaysOld
    Only target files whose LastWriteTime is older than this many days.
    Default is 0 (targets all files regardless of age).

.PARAMETER StagingPath
    Root folder where staged (soft-deleted) files are held pending rollback or purge.
    Default: C:\TempCleanupStaging

.PARAMETER LogDirectory
    Folder for the script's timestamped activity log files.
    Default: C:\TempCleanupStaging\Logs

.PARAMETER AdditionalPaths
    Extra folder paths to include in the cleanup scan, in addition to the
    built-in temp locations.

.PARAMETER Rollback
    Restore files from a previous staging session back to their original paths.
    Uses the most recent session unless -RollbackSessionId is specified.

.PARAMETER RollbackSessionId
    The session ID (folder name, format Session_yyyyMMdd_HHmmss) to roll back.
    If omitted, the most recent session is used.

.PARAMETER Purge
    Permanently delete a staging session, removing the ability to roll it back.
    Uses the most recent session unless -RollbackSessionId is specified.

.EXAMPLE
    .\TempCleanup.ps1 -DryRun
    List all temp files that qualify for cleanup without making changes.

.EXAMPLE
    .\TempCleanup.ps1 -DaysOld 7
    Move temp files older than 7 days to staging.

.EXAMPLE
    .\TempCleanup.ps1 -Rollback
    Restore files from the most recent staging session.

.EXAMPLE
    .\TempCleanup.ps1 -Rollback -RollbackSessionId "Session_20260810_143000"
    Restore files from a specific staging session.

.EXAMPLE
    .\TempCleanup.ps1 -Purge
    Permanently delete the most recent staging session.

.EXAMPLE
    .\TempCleanup.ps1 -AdditionalPaths "D:\MyApp\Cache","E:\TempWork"
    Include custom paths in the cleanup scan.
#>

[CmdletBinding()]
param (
    # Simulate only; no files are moved or deleted
    [switch]$DryRun,

    # Minimum file age in days; 0 = no age filter (all files)
    [ValidateRange(0, 3650)]
    [int]$DaysOld = 0,

    # Root folder for staged files awaiting rollback or purge
    [string]$StagingPath = "C:\TempCleanupStaging",

    # Folder that receives the timestamped activity log
    [string]$LogDirectory = "C:\TempCleanupStaging\Logs",

    # Extra paths to scan in addition to the built-in temp locations
    [string[]]$AdditionalPaths = @(),

    # Switch into rollback mode
    [switch]$Rollback,

    # Target a specific staging session for rollback or purge
    [string]$RollbackSessionId = "",

    # Permanently delete the staging session (no further rollback possible)
    [switch]$Purge
)

# ---------------------------------------------------------------------------
# SECTION 1 — Runtime constants, session identity, and summary counters
# Establishes the unique session ID used to name the staging folder and log
# file, derives all runtime paths from parameters, and initialises counters
# that are accumulated throughout the run and printed in the final report.
# ---------------------------------------------------------------------------

# Unique identifier for this execution — used as the staging sub-folder name
$SessionId      = "Session_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
$RunTimeStamp   = Get-Date -Format 'yyyyMMdd_HHmmss'

# Staging sub-folder where files moved in this session are stored
$SessionStageDir = Join-Path $StagingPath $SessionId

# Manifest CSV records each file operation for rollback reference
$ManifestFile    = Join-Path $SessionStageDir "manifest.csv"

# Script activity log — one file per execution
$ScriptLogFile   = Join-Path $LogDirectory "TempCleanup_$RunTimeStamp.log"

# Cutoff time: files last written before this moment qualify as "old"
# When DaysOld is 0 the cutoff is in the future so every file qualifies
$CutoffTime = if ($DaysOld -gt 0) { (Get-Date).AddDays(-$DaysOld) } else { (Get-Date).AddSeconds(1) }

# Determine whether the current session is running with administrator rights
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Summary counters — accumulated per file throughout the run
$Summary = [ordered]@{
    FilesFound    = 0
    FilesStaged   = 0     # Moved to staging (live run)
    FilesSkipped  = 0     # Age filter, already staged, or locked
    FilesFailed   = 0     # Unexpected errors
    LockedFiles   = 0     # In-use files that were skipped
    BytesReclaimed = 0L   # Total size of staged files
    Errors        = [System.Collections.Generic.List[string]]::new()
}

# ---------------------------------------------------------------------------
# SECTION 2 — Write-Log helper
# Writes a timestamped, severity-tagged line to both the console (with colour)
# and the script activity log file. The log file path must be initialised
# before the first call to Write-Log (see Section 3).
# ---------------------------------------------------------------------------

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DRY', 'SKIP')]
        [string]$Level = 'INFO'
    )

    $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        'ERROR' { Write-Host $entry -ForegroundColor Red    }
        'DRY'   { Write-Host $entry -ForegroundColor Cyan   }
        'SKIP'  { Write-Host $entry -ForegroundColor DarkGray }
        default { Write-Host $entry }
    }

    try {
        Add-Content -Path $ScriptLogFile -Value $entry -ErrorAction Stop
    }
    catch {
        # Best-effort logging; a log-write failure must not abort the run
        Write-Host "[WARN] Could not write to log file: $_" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# SECTION 3 — Directory initialisation
# Creates the log directory and, for live runs, the session staging directory.
# Any failure here is non-fatal for the log folder (we fall back to console
# only) but fatal for the staging folder (we cannot safely stage files).
# ---------------------------------------------------------------------------

function Initialize-Directories {
    # Log directory must exist before Write-Log can persist entries
    try {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Host "[WARN] Could not create log directory '$LogDirectory': $_" -ForegroundColor Yellow
    }

    # Staging directory is only needed during a live (non-dry, non-rollback) run
    if (-not $DryRun -and -not $Rollback -and -not $Purge) {
        try {
            if (-not (Test-Path $SessionStageDir)) {
                New-Item -ItemType Directory -Path $SessionStageDir -Force -ErrorAction Stop | Out-Null
                Write-Log "Staging directory created: $SessionStageDir"
            }
        }
        catch {
            Write-Log "FATAL: Could not create staging directory '$SessionStageDir': $_" -Level ERROR
            throw  # Abort — cannot stage files without the staging folder
        }
    }
}

# ---------------------------------------------------------------------------
# SECTION 4 — Locked-file detection
# Attempts to open the file with exclusive read access. If the OS refuses
# (because another process holds a lock) the function returns $true so the
# caller can skip the file gracefully instead of causing an error mid-move.
# ---------------------------------------------------------------------------

function Test-FileLocked {
    param ([string]$FilePath)
    try {
        $stream = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
        $stream.Close()
        $stream.Dispose()
        return $false
    }
    catch [System.IO.IOException] {
        return $true   # File is held open by another process
    }
    catch [System.UnauthorizedAccessException] {
        return $true   # No read permission — treat as locked/inaccessible
    }
    catch {
        return $true   # Unknown access error — err on the side of caution
    }
}

# ---------------------------------------------------------------------------
# SECTION 5 — Manifest helpers
# The manifest CSV is the authoritative record for rollback. Each row
# captures the original path, the staged path, the file size, and the
# operation status. Write-ManifestEntry appends one row per processed file.
# Read-Manifest loads all rows from a session's manifest.
# ---------------------------------------------------------------------------

function Write-ManifestEntry {
    param (
        [string]$OriginalPath,
        [string]$StagedPath,
        [long]$FileSizeBytes,
        [string]$Status   # Staged | RolledBack | Purged | Failed
    )

    $row = [pscustomobject]@{
        Timestamp     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        SessionId     = $SessionId
        OriginalPath  = $OriginalPath
        StagedPath    = $StagedPath
        FileSizeBytes = $FileSizeBytes
        Status        = $Status
    }

    try {
        $row | Export-Csv -Path $ManifestFile -Append -NoTypeInformation -ErrorAction Stop
    }
    catch {
        Write-Log "Could not write manifest entry for '$OriginalPath': $_" -Level WARN
    }
}

function Read-Manifest {
    param ([string]$ManifestPath)
    try {
        if (Test-Path $ManifestPath) {
            return Import-Csv -Path $ManifestPath -ErrorAction Stop |
                   Where-Object { $_.Status -eq 'Staged' }
        }
        else {
            Write-Log "Manifest not found: $ManifestPath" -Level ERROR
            return @()
        }
    }
    catch {
        Write-Log "Failed to read manifest '$ManifestPath': $_" -Level ERROR
        return @()
    }
}

# ---------------------------------------------------------------------------
# SECTION 6 — Target path resolution
# Builds the list of folders to scan. Always includes the current user's temp
# folders. When running as Administrator, also includes C:\Windows\Temp and
# every local user profile's AppData\Local\Temp. Duplicates are removed.
# Any paths provided via -AdditionalPaths are appended.
# ---------------------------------------------------------------------------

function Get-TargetPaths {
    $paths = [System.Collections.Generic.List[string]]::new()

    # Current user temp locations (always safe to target)
    foreach ($envVar in @($env:TEMP, $env:TMP)) {
        if ($envVar -and (Test-Path $envVar)) {
            $paths.Add($envVar)
        }
    }

    if ($IsAdmin) {
        # System-wide temp folder requires admin rights to enumerate
        $winTemp = "$env:SystemRoot\Temp"
        if (Test-Path $winTemp) { $paths.Add($winTemp) }

        # All local user profile temp folders
        try {
            Get-ChildItem 'C:\Users' -Directory -ErrorAction Stop |
                ForEach-Object {
                    $profileTemp = Join-Path $_.FullName 'AppData\Local\Temp'
                    if (Test-Path $profileTemp) { $paths.Add($profileTemp) }
                }
        }
        catch {
            Write-Log "Could not enumerate user profile temp folders: $_" -Level WARN
        }
    }
    else {
        Write-Log "Not running as Administrator — Windows\Temp and other user profiles will not be scanned." -Level WARN
    }

    # Caller-supplied extra paths
    foreach ($extra in $AdditionalPaths) {
        if (Test-Path $extra) {
            $paths.Add($extra)
        }
        else {
            Write-Log "Additional path not found, skipping: $extra" -Level WARN
        }
    }

    # Deduplicate (e.g. TEMP and TMP often resolve to the same folder)
    return $paths | Sort-Object -Unique
}

# ---------------------------------------------------------------------------
# SECTION 7 — Single-file processing (stage or dry-run report)
# Evaluates one file against the age threshold, checks for a lock, and
# either lists it (dry run), moves it to the session staging folder (live),
# or skips/logs it. All outcomes update the shared $Summary counters.
# Per-file try/catch ensures a single failure never aborts the loop.
# ---------------------------------------------------------------------------

function Invoke-ProcessFile {
    param ([System.IO.FileInfo]$File)

    $Summary.FilesFound++

    try {
        # --- Age filter ---
        if ($DaysOld -gt 0 -and $File.LastWriteTime -ge $CutoffTime) {
            Write-Log "SKIP (too new): $($File.FullName)" -Level SKIP
            $Summary.FilesSkipped++
            return
        }

        # --- Locked-file check (idempotent — skipping a locked file is safe to retry) ---
        if (Test-FileLocked -FilePath $File.FullName) {
            Write-Log "SKIP (locked): $($File.FullName)" -Level WARN
            $Summary.LockedFiles++
            $Summary.FilesSkipped++
            return
        }

        # --- Dry-run branch: report only, no filesystem changes ---
        if ($DryRun) {
            Write-Log "[DRY] Would stage: $($File.FullName)  ($([math]::Round($File.Length / 1KB, 2)) KB,  Modified: $($File.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" -Level DRY
            $Summary.FilesSkipped++   # Nothing was actually staged
            return
        }

        # --- Idempotency: derive the staged path and skip if already staged ---
        # Preserve the relative sub-path so the original location is recoverable
        $relativePath = $File.FullName.TrimStart('\').TrimStart('/')
        $relativePath = $relativePath -replace '^[A-Za-z]:\\', ''   # strip drive letter
        $stagedPath   = Join-Path $SessionStageDir $relativePath

        if (Test-Path $stagedPath) {
            Write-Log "SKIP (already staged in this session): $($File.FullName)" -Level SKIP
            $Summary.FilesSkipped++
            return
        }

        # --- Ensure the destination sub-directory exists ---
        $stagedDir = Split-Path $stagedPath -Parent
        if (-not (Test-Path $stagedDir)) {
            New-Item -ItemType Directory -Path $stagedDir -Force -ErrorAction Stop | Out-Null
        }

        # --- Move the file to staging ---
        Move-Item -Path $File.FullName -Destination $stagedPath -Force -ErrorAction Stop

        $Summary.FilesStaged++
        $Summary.BytesReclaimed += $File.Length
        Write-Log "Staged: $($File.FullName) -> $stagedPath"

        Write-ManifestEntry -OriginalPath  $File.FullName `
                            -StagedPath    $stagedPath    `
                            -FileSizeBytes $File.Length   `
                            -Status        'Staged'
    }
    catch {
        Write-Log "ERROR processing '$($File.FullName)': $_" -Level ERROR
        $Summary.FilesFailed++
        $Summary.Errors.Add("$($File.FullName) — $_")
    }
}

# ---------------------------------------------------------------------------
# SECTION 8 — Rollback function
# Resolves the target session (latest or specified), reads its manifest, and
# moves each staged file back to its original path. Existing files at the
# original path are NOT overwritten — they take priority over the staged copy.
# Idempotent: re-running rollback for the same session skips already-restored
# files gracefully.
# ---------------------------------------------------------------------------

function Invoke-Rollback {
    Write-Log "=== ROLLBACK MODE ==="

    # Resolve which session to roll back
    $targetSessionDir = if ($RollbackSessionId) {
        Join-Path $StagingPath $RollbackSessionId
    }
    else {
        # Pick the most recently created session folder
        try {
            Get-ChildItem -Path $StagingPath -Directory -Filter 'Session_*' -ErrorAction Stop |
                Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
        }
        catch { $null }
    }

    if (-not $targetSessionDir -or -not (Test-Path $targetSessionDir)) {
        Write-Log "No staging session found to roll back. Path: $targetSessionDir" -Level ERROR
        List-AvailableSessions
        return
    }

    Write-Log "Rolling back session: $targetSessionDir"
    $targetManifest = Join-Path $targetSessionDir "manifest.csv"
    $entries = Read-Manifest -ManifestPath $targetManifest

    if ($entries.Count -eq 0) {
        Write-Log "No staged entries found in manifest — nothing to restore." -Level WARN
        return
    }

    $restoredCount = 0
    $skippedCount  = 0
    $failedCount   = 0

    foreach ($entry in $entries) {
        try {
            # Idempotency: skip if file is already back at its original path
            if (Test-Path $entry.OriginalPath) {
                Write-Log "SKIP (already exists at original path): $($entry.OriginalPath)" -Level SKIP
                $skippedCount++
                continue
            }

            if (-not (Test-Path $entry.StagedPath)) {
                Write-Log "SKIP (staged file missing, may have been purged): $($entry.StagedPath)" -Level WARN
                $skippedCount++
                continue
            }

            # Re-create the original directory if it was removed
            $originalDir = Split-Path $entry.OriginalPath -Parent
            if (-not (Test-Path $originalDir)) {
                New-Item -ItemType Directory -Path $originalDir -Force -ErrorAction Stop | Out-Null
            }

            Move-Item -Path $entry.StagedPath -Destination $entry.OriginalPath -Force -ErrorAction Stop
            Write-Log "Restored: $($entry.StagedPath) -> $($entry.OriginalPath)"
            $restoredCount++
        }
        catch {
            Write-Log "Failed to restore '$($entry.OriginalPath)': $_" -Level ERROR
            $failedCount++
        }
    }

    Write-Log "Rollback complete — Restored: $restoredCount | Skipped: $skippedCount | Failed: $failedCount"
}

# ---------------------------------------------------------------------------
# SECTION 9 — Purge function
# Permanently deletes a staging session folder and all files within it,
# removing the ability to roll back that session. This is the "commit"
# step that converts the soft-delete into a hard delete.
# ---------------------------------------------------------------------------

function Invoke-Purge {
    Write-Log "=== PURGE MODE ==="

    $targetSessionDir = if ($RollbackSessionId) {
        Join-Path $StagingPath $RollbackSessionId
    }
    else {
        try {
            Get-ChildItem -Path $StagingPath -Directory -Filter 'Session_*' -ErrorAction Stop |
                Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
        }
        catch { $null }
    }

    if (-not $targetSessionDir -or -not (Test-Path $targetSessionDir)) {
        Write-Log "No staging session found to purge. Path: $targetSessionDir" -Level ERROR
        List-AvailableSessions
        return
    }

    Write-Log "Purging session: $targetSessionDir"

    try {
        # Count files before deletion for the log record
        $fileCount = (Get-ChildItem -Path $targetSessionDir -Recurse -File -ErrorAction Stop).Count
        Remove-Item -Path $targetSessionDir -Recurse -Force -ErrorAction Stop
        Write-Log "Purge complete — $fileCount file(s) permanently deleted from: $targetSessionDir"
    }
    catch {
        Write-Log "Failed to purge session '$targetSessionDir': $_" -Level ERROR
    }
}

# ---------------------------------------------------------------------------
# SECTION 10 — Available sessions helper
# Lists all staging session folders so the engineer can choose a session ID
# for -Rollback or -Purge operations.
# ---------------------------------------------------------------------------

function List-AvailableSessions {
    Write-Log "Available staging sessions:"
    try {
        $sessions = Get-ChildItem -Path $StagingPath -Directory -Filter 'Session_*' -ErrorAction Stop |
                    Sort-Object Name -Descending

        if ($sessions.Count -eq 0) {
            Write-Log "  (none found under $StagingPath)" -Level WARN
        }
        else {
            foreach ($s in $sessions) {
                $manifestPath = Join-Path $s.FullName 'manifest.csv'
                $entryCount   = 0
                if (Test-Path $manifestPath) {
                    try { $entryCount = (Import-Csv $manifestPath).Count } catch {}
                }
                Write-Log "  $($s.Name)  ($entryCount manifest entries)"
            }
        }
    }
    catch {
        Write-Log "Could not list sessions under '$StagingPath': $_" -Level WARN
    }
}

# ---------------------------------------------------------------------------
# SECTION 11 — Main entry point
# Validates the run mode, initialises directories, then dispatches to either
# rollback, purge, or the main file-scan loop depending on the supplied
# parameters. Only one non-default mode may be active at a time.
# ---------------------------------------------------------------------------

# Mutual exclusion guard — rollback and purge are distinct modes
if ($Rollback -and $Purge) {
    Write-Error "Cannot use -Rollback and -Purge together. Choose one."
    exit 1
}

# Banner
Write-Log "============================================================"
Write-Log " DWP Temp File Cleanup Script"
Write-Log " Mode       : $(if ($DryRun) { 'DRY RUN' } elseif ($Rollback) { 'ROLLBACK' } elseif ($Purge) { 'PURGE' } else { 'LIVE' })"
Write-Log " Age filter : $(if ($DaysOld -eq 0) { 'All files (no age filter)' } else { "Older than $DaysOld day(s)" })"
Write-Log " Session ID : $SessionId"
Write-Log " Log file   : $ScriptLogFile"
Write-Log " Running as : $(if ($IsAdmin) { 'Administrator' } else { 'Standard User' })"
Write-Log "============================================================"

# Initialise folders (log dir always; staging dir only for live runs)
Initialize-Directories

# --- Rollback mode ---
if ($Rollback) {
    try { Invoke-Rollback }
    catch { Write-Log "Rollback encountered an unexpected error: $_" -Level ERROR }
    exit 0
}

# --- Purge mode ---
if ($Purge) {
    try { Invoke-Purge }
    catch { Write-Log "Purge encountered an unexpected error: $_" -Level ERROR }
    exit 0
}

# --- Normal / Dry-run mode: scan target paths and process files ---

$targetPaths = Get-TargetPaths

if ($targetPaths.Count -eq 0) {
    Write-Log "No valid target paths found. Exiting." -Level WARN
    exit 0
}

Write-Log "Scanning $($targetPaths.Count) target path(s):"
foreach ($p in $targetPaths) { Write-Log "  $p" }

foreach ($folder in $targetPaths) {
    Write-Log "--- Scanning: $folder"

    try {
        # Recurse into all sub-folders; skip the folder entries themselves
        $files = Get-ChildItem -Path $folder -Recurse -File -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Could not enumerate '$folder': $_" -Level ERROR
        $Summary.Errors.Add("Enumerate failed: $folder — $_")
        continue
    }

    foreach ($file in $files) {
        Invoke-ProcessFile -File $file
    }
}

# ---------------------------------------------------------------------------
# SECTION 12 — Summary report
# Aggregates and prints all counters collected during the run. Errors are
# listed individually so the engineer can see exactly which files failed.
# ---------------------------------------------------------------------------

$mbReclaimed = [math]::Round($Summary.BytesReclaimed / 1MB, 2)

Write-Log "============================================================"
Write-Log " SUMMARY REPORT"
Write-Log "============================================================"
Write-Log " Files found      : $($Summary.FilesFound)"
Write-Log " Files staged     : $($Summary.FilesStaged)"
Write-Log " Files skipped    : $($Summary.FilesSkipped)  (includes locked, age-filtered, already staged)"
Write-Log "   of which locked: $($Summary.LockedFiles)"
Write-Log " Files failed     : $($Summary.FilesFailed)"
Write-Log " Space reclaimed  : $mbReclaimed MB"

if ($DryRun) {
    Write-Log " [DRY RUN — no files were moved or deleted]" -Level DRY
}
elseif ($Summary.FilesStaged -gt 0) {
    Write-Log " Staging session  : $SessionStageDir"
    Write-Log " Rollback command : .\TempCleanup.ps1 -Rollback -RollbackSessionId `"$SessionId`""
    Write-Log " Purge command    : .\TempCleanup.ps1 -Purge    -RollbackSessionId `"$SessionId`""
}

if ($Summary.Errors.Count -gt 0) {
    Write-Log " Errors ($($Summary.Errors.Count)):" -Level WARN
    foreach ($e in $Summary.Errors) {
        Write-Log "   - $e" -Level WARN
    }
}

Write-Log " Activity log     : $ScriptLogFile"
Write-Log "============================================================"
