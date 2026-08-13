Version: v 1.0  
Date: 07/08/2026  
Status: Draft

# L2/L3 KB: AVD Black Screen Post-Login (POOL-FIN-01)

## Background
This service provides Finance users with virtual Windows desktops through Azure Virtual Desktop. Stable sign-in is business-critical because Finance start-of-day workflows depend on immediate desktop access. If desktop rendering fails after authentication, users cannot work even when identity and entitlement are valid.

## Symptom
Engineer-observed pattern:
1. Incident starts after overnight change on POOL-FIN-01.
2. Around 40% of POOL-FIN-01 users report black screen after login.
3. Some sessions recover after about 30 seconds; others disconnect and reconnect.
4. POOL-FIN-02 remains unaffected in the same time window.

User-reported pattern:
1. "I can sign in, then screen goes black."
2. "Sometimes it comes back after a short wait."
3. "Sometimes I get disconnected and have to reconnect."

## Root Cause
Verified technical cause: display stack regression introduced by the overnight POOL-FIN-01 update, with repeated Desktop Window Manager crashes.

Evidence that confirms root cause:
1. Affected host SHFIN-01-A shows Application Error Event ID 1000 with:
- Faulting application name: dwm.exe
- Faulting module name: igdumd64.dll
- Exception code: 0xc0000005
- Timestamps: 07:02:16, 07:02:46, 07:08:24
2. Affected host SHFIN-01-A shows Desktop Window Manager Event ID 9009 at 07:02:18 and 07:03:01.
3. Session chain on affected host: TerminalServices-LocalSessionManager Event ID 21 (logon succeeded) followed by Event ID 40 (session disconnected).
4. Control host SHFIN-02-A (POOL-FIN-02) shows DWM Event ID 9011 (started successfully) and no matching repeated Event ID 1000 pattern in comparison window.

## Detection
Run these checks before any remediation. Target completion time: under 3 minutes.

1. On the affected host (example: SHFIN-01-A), run this PowerShell command to pull Application log Event ID 1000 quickly:
```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-6)} |
Where-Object { $_.Message -match 'Faulting application name: dwm.exe' -and $_.Message -match 'Faulting module name: igdumd64.dll' } |
Select-Object -First 10 TimeCreated, Id, ProviderName, Message | Format-List
```
Expected confirmation:
- Log location confirmed: Application log.
- Event ID confirmed: 1000.
- Required module confirmed: igdumd64.dll.
- Supporting value confirmed: exception code 0xc0000005 appears in Message.

2. On the same affected host, run this command for Desktop Window Manager Operational Event ID 9009:
```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9009; StartTime=(Get-Date).AddHours(-6)} |
Select-Object -First 10 TimeCreated, Id, ProviderName, Message | Format-List
```
Expected confirmation:
- Log location confirmed: Microsoft-Windows-Desktop Window Manager/Operational.
- Event ID confirmed: 9009.
- Time correlation: Event 9009 timestamps are near the Event 1000 timestamps from step 1.

3. On the affected host, run this command for logon/disconnect sequence validation:
```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; Id=@(21,40); StartTime=(Get-Date).AddHours(-6)} |
Select-Object -First 20 TimeCreated, Id, Message | Format-List
```
Expected confirmation:
- Event 21 (logon succeeded) appears before Event 40 (session disconnected) in the same user incident window.

4. On control host SHFIN-02-A in POOL-FIN-02, run this command for healthy baseline:
```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9011; StartTime=(Get-Date).AddHours(-6)} |
Select-Object -First 10 TimeCreated, Id, ProviderName, Message | Format-List
```
Expected confirmation:
- Healthy baseline event confirmed: Event ID 9011 on POOL-FIN-02 control host.
- Comparison rule: control host shows DWM start success while affected host shows Event 1000 (dwm.exe/igdumd64.dll) plus Event 9009.

5. If PowerShell is unavailable, perform the same check in Event Viewer with exact log paths:
- Application log: Event Viewer > Windows Logs > Application > Filter Current Log > Event ID 1000.
- DWM log: Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational > Filter Current Log > Event ID 9009 (affected) and 9011 (control).
Expected confirmation:
- Same result as command-line checks, with Event 1000 and Event 9009 on affected host and Event 9011 on control host.

## Resolution
Goal: restore user access in 5-10 minutes by isolating bad hosts and keeping healthy hosts active, then begin image rollback workstream.

Use these variables in CLI examples:
```powershell
$subId = "<subscription-id>"
$rg = "<resource-group>"
$pool = "POOL-FIN-01"
$api = "2022-09-09"
```

1. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts, open each failing host, then set Properties > Allow new sessions = No. [ELEVATED]
Expected result: Each failing host shows New sessions disabled.

2. Fast command option for step 1 (run once per failing host): [ELEVATED]
```powershell
$host = "<session-host-name>"   # example: shfin-01-a.domain.local
az rest --method PATCH `
	--url "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/hostPools/$pool/sessionHosts/$host?api-version=$api" `
	--body '{"properties":{"allowNewSession":false}}'
```
Expected result: Command returns host resource JSON with allowNewSession set to false.

3. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions, filter by each failing host, select all sessions, click Disconnect. [ELEVATED]
Expected result: Active sessions on failing hosts drop to 0.

4. Fast command option for step 3: list current user sessions and identify IDs on failing hosts. [ELEVATED]
```powershell
az rest --method GET `
	--url "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/hostPools/$pool/userSessions?api-version=$api"
```
Expected result: Output shows user session IDs and host names; failing-host sessions are identifiable for disconnect action.

5. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts and confirm at least one healthy host has Allow new sessions = Yes.
Expected result: Healthy hosts continue receiving new user logins.

6. Start permanent fix task with exact image reference: Azure portal > Azure Compute Gallery > Images > <golden-image-name> > Versions, record last known-good version ID in change record. [ELEVATED]
Expected result: Known-good image version ID is documented and approved for rebuild/replacement workflow.

7. Post Service Desk update: "Failing POOL-FIN-01 hosts drained, user sessions redirected, service restored on healthy hosts; rebuild from known-good image in progress."
Expected result: Frontline team gives consistent user guidance.

## Verification
1. In Azure portal, open Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Success criteria: failing hosts show Allow new sessions = No; healthy hosts show Allow new sessions = Yes.

2. Fast command check for host drain state:
```powershell
az rest --method GET `
	--url "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/hostPools/$pool/sessionHosts?api-version=$api"
```
Success criteria: affected hosts have properties.allowNewSession = false.

3. In Azure portal, open Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions and refresh twice.
Success criteria: active sessions are only on healthy hosts; no new active sessions appear on drained failing hosts.

4. Fast command check for session placement:
```powershell
az rest --method GET `
	--url "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/hostPools/$pool/userSessions?api-version=$api"
```
Success criteria: session list does not include drained failing hosts as active destination.

5. On one remediated host candidate, confirm no new crash signature in logs:
- Event Viewer > Windows Logs > Application > Event ID 1000
- Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational > Event ID 9009
Success criteria: no new Event 1000 (dwm.exe/igdumd64.dll) and no new Event 9009 in post-action window.

## Rollback
Use this rollback if symptoms worsen after any change. Target completion: under 3 minutes.

1. Azure portal path: Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > <failing-host> > Properties > Allow new sessions = No. [ELEVATED]
Expected result: New connections are blocked on failing host immediately.

2. Fast command for step 1: [ELEVATED]
```powershell
$host = "<session-host-name>"
az rest --method PATCH `
	--url "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/hostPools/$pool/sessionHosts/$host?api-version=$api" `
	--body '{"properties":{"allowNewSession":false}}'
```
Expected result: allowNewSession is false in command output.

3. Azure portal path: Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions > filter by <failing-host> > select all > Disconnect. [ELEVATED]
Expected result: Active session count on failing host is 0.

4. Fast command path for validation:
```powershell
az rest --method GET `
	--url "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/hostPools/$pool/userSessions?api-version=$api"
```
Expected result: no active sessions remain on failing host.

5. Azure portal path: Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts; verify at least one healthy host remains with Allow new sessions = Yes.
Expected result: users reconnect to healthy hosts and service remains available.

6. Keep failing host isolated and open rebuild task with known-good image version from Azure portal > Azure Compute Gallery > Images > <golden-image-name> > Versions. [ELEVATED]
Expected result: failing host is not returned to service until rebuilt and revalidated.

## Preventive
Implement these exact process/tooling changes:

1. Owner: Release engineer | Timing: before deployment | Mode: Automated [REQUIRES: CI/CD release gate + log query hook].
Control: Keep the image promotion gate that blocks release when canary hosts show Event 1000 (dwm.exe + igdumd64.dll) or Event 9009 in first 15 minutes post-logon.
Pass/Fail signal: Pass = zero matching events; Fail = >=1 matching event on any canary host.
If fail: Promotion stops, change manager is notified, and rollout does not start.

2. Owner: Change manager | Timing: during deployment | Mode: Manual [REQUIRES: change workflow stage controls].
Control: Keep staged rollout policy at 10% canary, 30% pilot, then 100% only after approval at each gate.
Pass/Fail signal: Pass = no Event 1000/9009 threshold breach and no spike in black-screen tickets per stage; Fail = any breach.
If fail: Freeze at current stage, keep affected hosts drained, and revert stage hosts to known-good image.

3. Owner: DWP engineer | Timing: during deployment | Mode: Automated [REQUIRES: Azure Monitor + Log Analytics alert rules].
Control: Keep alert rule on updated-ring hosts for Event 1000 (dwm.exe/igdumd64.dll) >=2 in 10 min OR Event 9009 >=2 in 10 min per host.
Pass/Fail signal: Pass = no alert fired in rollout window; Fail = alert fired with host and event count.
If fail: Trigger on-call notification and immediate manual rollback sequence for flagged host.

4. Owner: Change manager | Timing: during deployment | Mode: Manual (automation candidate).
Control: Keep mandatory control-pool comparison checkpoint between updated POOL-FIN-01 and non-updated POOL-FIN-02.
Pass/Fail signal: Pass = POOL-FIN-02 baseline Event 9011 present with no repeated Event 1000 pattern while updated pool is clean; Fail = divergence indicates instability.
If fail: Block expansion to next stage and open incident bridge; Automation approach: scheduled workbook diff report per stage.

5. Owner: Image owner | Timing: before deployment | Mode: Manual (automation candidate).
Control: Keep known-good baseline inventory with image version ID, driver package version, publish date, and rollback target ID in every change record.
Pass/Fail signal: Pass = change record includes all 4 fields and approved baseline; Fail = any field missing or not approved.
If fail: Change manager rejects CAB release; Automation approach: mandatory template fields with submit validation.

6. Owner: DWP engineer | Timing: before deployment | Mode: Automated [REQUIRES: smoke-test script + test host pool].
Control: Pre-deployment smoke-test gate on canary host executes one test logon and 15-minute event scan for Event 1000 and 9009.
Pass/Fail signal: Pass = test logon succeeds and zero matching events; Fail = failed logon or >=1 matching event.
If fail: Cancel release before user-facing deployment and return image to image owner.

7. Owner: Service desk lead | Timing: during deployment | Mode: Manual (automation candidate).
Control: In-flight monitoring check every 10 minutes during rollout window for new POOL-FIN-01 black-screen tickets.
Pass/Fail signal: Pass = ticket count remains at baseline; Fail = >=2 new black-screen tickets in 10 minutes.
If fail: Notify DWP on-call and pause rollout; Automation approach: queue rule and threshold alert in ticketing tool.

8. Owner: DWP engineer | Timing: after deployment | Mode: Manual.
Control: Post-deployment validation before change closure checks 3 consecutive successful user logins and no new Event 1000/9009 on remediated hosts for 30 minutes.
Pass/Fail signal: Pass = all checks clear; Fail = any failed login or matching event recurrence.
If fail: Keep change open, re-enable containment (drain failing host), and execute rollback.

9. Owner: Release engineer | Timing: during deployment | Mode: Automated [REQUIRES: rollout orchestrator integration].
Control: Rollback trigger auto-fires when any host hits Event 1000>=2/10 min or Event 9009>=2/10 min, setting host allowNewSession=false.
Pass/Fail signal: Pass = trigger not fired; Fail = trigger fired and host state changes to drained within 2 minutes.
If fail: If auto-drain fails, perform manual drain via Azure portal and stop rollout.

10. Owner: Image owner | Timing: after deployment | Mode: Manual.
Control: Knowledge update control requires runbook, L1, and L2/L3 KB updates within 2 business days for any Sev2+ display regression incident.
Pass/Fail signal: Pass = updated documents linked in incident closure; Fail = missing document links by deadline.
If fail: Change manager blocks final PIR sign-off until documentation is completed.

## Related
1. Related runbook: Day5/avd_black_screen_display_regression_runbook.md
2. Related incident analysis: Day4/avd_black_screen_differential_ranked_analysis.md
3. Related RCA: Day4/avd_black_screen_incident_rca_2024-03-15.md
4. Related communications: Day4/avd_black_screen_incident_comms_2024-03-15.md
5. Related known-error record: Day4/known_error_avd_black_screen_pool_fin_01.md
