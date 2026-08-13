# TempCleanup.ps1 — README

A PowerShell 5.1 script for DWP engineers to safely clean up temporary files
on managed Windows endpoints.

---

## How It Works

Instead of deleting files outright, the script **moves** qualifying temp files
into a dated staging folder. This makes every run fully reversible via
`-Rollback` until a `-Purge` is explicitly performed. Locked files (held open
by another process) are skipped and logged — the script never aborts because
of a single locked file.

### Operating Modes

| Mode | Trigger | Effect |
|---|---|---|
| **Dry Run** | `-DryRun` | Lists candidate files; no filesystem changes |
| **Live** | *(default)* | Moves qualifying files to a staging session folder |
| **Rollback** | `-Rollback` | Restores files from a staging session to their original paths |
| **Purge** | `-Purge` | Permanently deletes a staging session (commits the deletion) |

---

## Requirements

| Requirement | Detail |
|---|---|
| PowerShell | 5.1 or later |
| Privileges | Standard User for own temp folders; **Administrator** for Windows\Temp and other user profiles |
| OS | Windows 10 / Windows 11 / Windows Server 2016+ |

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-DryRun` | Switch | Off | Simulate only. Lists all files that would be staged. No files are moved. |
| `-DaysOld` | Integer | `0` | Only target files whose last-modified date is older than this many days. `0` means all files regardless of age. Valid range: 0–3650. |
| `-StagingPath` | String | `C:\TempCleanupStaging` | Root folder where staged files are held. Each run creates a dated sub-folder (`Session_yyyyMMdd_HHmmss`). |
| `-LogDirectory` | String | `C:\TempCleanupStaging\Logs` | Folder for the timestamped activity log file. |
| `-AdditionalPaths` | String[] | *(empty)* | Extra folder paths to include in the cleanup scan alongside the built-in temp locations. |
| `-Rollback` | Switch | Off | Restore files from a staging session back to their original paths. |
| `-RollbackSessionId` | String | *(latest)* | The specific session to target for `-Rollback` or `-Purge`. Omit to use the most recent session. Format: `Session_yyyyMMdd_HHmmss`. |
| `-Purge` | Switch | Off | Permanently delete a staging session. Cannot be combined with `-Rollback`. |

---

## Usage Examples

### 1. Dry Run — Preview Files Only

```powershell
.\TempCleanup.ps1 -DryRun
```

Lists every temp file that would be moved. Nothing is touched. Use this before
any live run to understand the scope.

---

### 2. Live Run — Default Settings (all files, any age)

```powershell
.\TempCleanup.ps1
```

Moves all temp files (no age filter) to a new staging session under
`C:\TempCleanupStaging\Session_<timestamp>\`.

---

### 3. Age-Filtered Run

```powershell
.\TempCleanup.ps1 -DaysOld 7
```

Only moves files whose `LastWriteTime` is older than 7 days.

---

### 4. Custom Staging and Log Paths

```powershell
.\TempCleanup.ps1 -StagingPath "D:\TempStage" -LogDirectory "D:\Logs\TempCleanup"
```

Redirects both the staging folder and the log files to alternative drives.

---

### 5. Include Extra Folders

```powershell
.\TempCleanup.ps1 -AdditionalPaths "D:\MyApp\Cache","E:\WorkTemp"
```

Scans the built-in temp locations **plus** the two extra paths specified.

---

### 6. Rollback — Restore the Most Recent Session

```powershell
.\TempCleanup.ps1 -Rollback
```

Restores all files from the most recently created staging session to their
original paths.

---

### 7. Rollback — Restore a Specific Session

```powershell
.\TempCleanup.ps1 -Rollback -RollbackSessionId "Session_20260810_143000"
```

Targets a specific session by its folder name. Use this when multiple sessions
exist and you need to restore a particular one.

---

### 8. Purge — Commit the Deletion Permanently

```powershell
.\TempCleanup.ps1 -Purge
```

Permanently deletes the most recent staging session. After a purge, rollback
is no longer possible for that session.

---

### 9. Purge a Specific Session

```powershell
.\TempCleanup.ps1 -Purge -RollbackSessionId "Session_20260810_143000"
```

---

### 10. Dry Run with Custom Age and Extra Paths

```powershell
.\TempCleanup.ps1 -DryRun -DaysOld 14 -AdditionalPaths "C:\MyApp\Temp"
```

---

## Target Locations Scanned

### Always (any privilege level)

| Path | Notes |
|---|---|
| `$env:TEMP` | Current user's primary temp folder |
| `$env:TMP` | Current user's secondary temp folder (often same as TEMP) |

### Administrator only

| Path | Notes |
|---|---|
| `C:\Windows\Temp` | System-wide temp folder |
| `C:\Users\*\AppData\Local\Temp` | Temp folder for every local user profile |

The script logs a warning (but continues) when not running as Administrator
rather than failing hard.

---

## Output Files

| File | Location | Description |
|---|---|---|
| Activity log | `<LogDirectory>\TempCleanup_<timestamp>.log` | Full timestamped record of every action, skip, and error per run. |
| Staged files | `<StagingPath>\Session_<timestamp>\...` | Files moved from their original paths, preserving subfolder structure for accurate restore. |
| Manifest CSV | `<StagingPath>\Session_<timestamp>\manifest.csv` | Records original path, staged path, file size, and status (`Staged` / `RolledBack`). Drives the rollback operation. |

---

## Locked File Handling

When a file cannot be opened exclusively (another process holds a lock),
the script:

1. Logs it at `[WARN]` level with the message `SKIP (locked): <path>`.
2. Increments the `Locked files` counter in the summary.
3. **Continues** to the next file — the run is never aborted.

Locked files can be cleaned up by re-running the script after the locking
process releases them.

---

## Idempotency

The script is safe to run multiple times:

- **Same session**: if a file has already been moved to the current session's
  staging folder (derived path already exists), it is skipped.
- **File already gone**: if a file no longer exists at its source path when
  the script runs, it is silently skipped.
- **Rollback re-run**: if a file is already back at its original path, the
  rollback skips it rather than overwriting a potentially newer version.

---

## Rollback Design

```
Normal run:   [Original Path] --(Move)--> [StagingPath\Session_X\...]
Rollback:     [StagingPath\Session_X\...] --(Move)--> [Original Path]
Purge:        [StagingPath\Session_X\...] --(Delete permanently)-->  ✗
```

- The original directory structure is recreated during rollback if it was
  removed after the cleanup run.
- Staged files that are already back at their original path are skipped
  (rollback is idempotent).
- A file at the original path is **never overwritten** by rollback —
  the live version takes priority.

---

## Scheduling with Task Scheduler

```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
               -Argument '-NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\TempCleanup.ps1" -DaysOld 3'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At '06:00AM'
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfIdle:$false
Register-ScheduledTask -TaskName 'DWP-TempCleanup' -Action $action `
    -Trigger $trigger -Settings $settings -RunLevel Highest -Force
```

Schedule a weekly purge to prevent the staging folder from growing indefinitely:

```powershell
$purgeAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
                   -Argument '-NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\TempCleanup.ps1" -Purge'
$purgeTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At '06:30AM'
Register-ScheduledTask -TaskName 'DWP-TempCleanup-Purge' -Action $purgeAction `
    -Trigger $purgeTrigger -Settings $settings -RunLevel Highest -Force
```

---

## Summary Report Fields

| Field | Description |
|---|---|
| Files found | Total files enumerated across all scanned paths |
| Files staged | Files successfully moved to the staging session |
| Files skipped | Files not processed (age filter, already staged, or locked) |
| Of which locked | Subset of skipped files that were in use by another process |
| Files failed | Files where an unexpected error occurred during processing |
| Space reclaimed | Total size of staged files in MB |

---

## Security Notes

- No files are permanently deleted during a normal or dry-run execution.
- Admin rights are required to clean Windows\Temp and other user profiles.
- The staging folder should be on an access-controlled drive; ensure standard
  users cannot read or delete staged files from other user profiles.
- Do not use `-Purge` in the same scheduled task as the cleanup run — allow
  at least one day between cleanup and purge to give engineers time to
  validate and roll back if needed.
