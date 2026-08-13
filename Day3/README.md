# EventLog-ArchiveCleanup.ps1 — README

A PowerShell 5.1 script for DWP engineers to safely archive and clean up
Windows Event Logs on managed endpoints.

---

## Requirements

| Requirement | Detail |
|---|---|
| PowerShell | 5.1 or later |
| Privileges | Must be run as **Administrator** |
| OS | Windows 10 / Windows 11 / Windows Server 2016+ |

---

## What the Script Does

1. Evaluates a predefined list of Windows Event Logs.
2. For each log, counts events older than the configured age threshold.
3. If qualifying old events exist, exports the **full log** to an EVTX archive file.
4. Clears the live log **only after** a successful archive (data-safe design).
5. Records every action to a dated, timestamped script activity log.
6. Writes a CSV manifest of all archived logs for rollback reference.
7. Prints a summary report at the end of the run.

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-DryRun` | Switch | Off | Simulate only. Prints event counts per log without writing any files or clearing any logs. |
| `-DaysOld` | Integer | `3` | Only process logs that contain events **older than** this many days. Valid range: 1–3650. |
| `-ArchivePath` | String | `C:\EventLogArchives` | Root folder where dated archive sub-folders are created. |
| `-LogDirectory` | String | `C:\EventLogArchives\ScriptLogs` | Folder where the script's own activity log file is saved. |
| `-Rollback` | Switch | Off | Enter rollback mode — restores archived EVTX files from a previous run instead of archiving. |
| `-RollbackDate` | String | Today (`yyyyMMdd`) | The archive date to roll back. Must match an existing dated sub-folder. Format: `yyyyMMdd`. |

---

## Usage Examples

### 1. Dry Run — Preview Only

```powershell
.\EventLog-ArchiveCleanup.ps1 -DryRun
```

Prints the count of old events in each log. **No files are written and no logs are cleared.** Use this to assess impact before a live run.

---

### 2. Live Run — Default Settings (3-day threshold)

```powershell
.\EventLog-ArchiveCleanup.ps1
```

Archives and clears any log containing events older than 3 days. Archives saved to `C:\EventLogArchives\<yyyyMMdd>\`.

---

### 3. Custom Age Threshold

```powershell
.\EventLog-ArchiveCleanup.ps1 -DaysOld 7
```

Targets logs with events older than 7 days.

---

### 4. Custom Archive and Log Paths

```powershell
.\EventLog-ArchiveCleanup.ps1 -ArchivePath "D:\Backups\EventLogs" -LogDirectory "D:\Logs\EventCleanup"
```

Redirects all output files to alternative drives or paths.

---

### 5. Rollback — Restore a Previous Archive

```powershell
.\EventLog-ArchiveCleanup.ps1 -Rollback -RollbackDate "20260810"
```

Copies all EVTX files from the `20260810` archive folder to a `Restored_20260810` sub-folder. The original archive is left untouched.

After rollback, open the restored files in **Event Viewer**:

> Event Viewer → Action → Open Saved Log → browse to `C:\EventLogArchives\Restored_<date>\`

---

### 6. Rollback to Today's Archive

```powershell
.\EventLog-ArchiveCleanup.ps1 -Rollback
```

Defaults `RollbackDate` to today, so this restores whatever was archived in the current day's run.

---

## Output Files

| File | Location | Description |
|---|---|---|
| Activity log | `<LogDirectory>\EventLogCleanup_<timestamp>.log` | Full timestamped record of every action and error. |
| EVTX archives | `<ArchivePath>\<yyyyMMdd>\<LogName>_<yyyyMMdd>.evtx` | Exported event log files. One per processed log. |
| Run manifest | `<ArchivePath>\<yyyyMMdd>\manifest_<timestamp>.csv` | CSV listing every archived log, its file path, old-event count, and status. |

---

## Idempotency

If an EVTX archive file for **today's date** already exists for a given log,
that log is **skipped**. Re-running the script on the same day is safe —
it will not create duplicate archives or clear a log twice.

---

## Rollback Design

The rollback mechanism is **non-destructive**:

- Original archive EVTX files are **copied**, not moved.
- The archive folder is left intact after rollback.
- Restored files are placed in a separate `Restored_<date>` folder.
- Rolled-back logs are available for review in Event Viewer but are **not
  automatically re-injected** into the live Windows event log store
  (this is a Windows platform limitation for security reasons).

---

## Targeted Event Logs

The following logs are evaluated by default. Edit the `$TargetLogs` array in
the script to add or remove entries:

- `Application`
- `System`
- `Security`
- `Setup`
- `Microsoft-Windows-PowerShell/Operational`
- `Microsoft-Windows-TaskScheduler/Operational`
- `Microsoft-Windows-WindowsUpdateClient/Operational`
- `Microsoft-Windows-Bits-Client/Operational`

If a listed log does not exist on the target machine, it is silently skipped
with a warning — the script will not fail.

---

## Error Handling

- Every operation is wrapped in `try/catch`.
- Errors are logged at `[ERROR]` level and collected for the summary report.
- If an **archive fails**, the corresponding log is **not cleared** (fail-safe).
- The script continues processing remaining logs after any single failure.

---

## Security Notes

- The script requires **Administrator** privileges (`#Requires -RunAsAdministrator`).
- No credentials are stored or transmitted.
- Archive files are written locally; ensure `ArchivePath` is on an access-controlled drive.
- The `Security` event log may require the script to run as **SYSTEM** or a
  Domain Admin on some configurations.

---

## Scheduling with Task Scheduler

To run this script on a schedule (e.g., weekly), create a scheduled task:

```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
               -Argument '-NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\EventLog-ArchiveCleanup.ps1" -DaysOld 7'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '02:00AM'
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfIdle:$false
Register-ScheduledTask -TaskName 'DWP-EventLogCleanup' -Action $action `
    -Trigger $trigger -Settings $settings -RunLevel Highest -Force
```

---

## Summary Report Fields

| Field | Description |
|---|---|
| Logs evaluated | Total logs checked against the age threshold |
| Logs skipped | Logs with no old events, already archived today, or not found on this machine |
| Logs archived | Logs successfully exported to EVTX |
| Logs cleared | Logs successfully cleared after archiving |
| Logs failed | Logs where archive or clear encountered an error |
| Old events found | Total count of qualifying old events across all targeted logs |
