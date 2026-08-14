Version: v 1.0  
Date: 07/08/2026  
Status: Draft

# L2/L3 KB: Finance Team Cannot Access Shared Drives

## Background
Finance users depend on S: for month-end reports and shared working files. If S: mapping or permissions break, finance workflows stop with no practical workaround.

## Symptom
Engineer-observed:
1. Multiple Finance users report Access Denied on S:.
2. Some users may not see S: at all, others see S: but cannot open it.
3. Unaffected comparison users can access S: from same office network.

User-reported:
1. "S: drive is missing" or "I get Access Denied."
2. "I cannot open finance files needed for reporting."

## Root Cause
Verified cause for this incident: Finance drive-map policy still pointed users to an outdated path and/or users were not consistently mapped to the corrected target after migration, while required access group/ACL alignment was incomplete.

Confirming evidence:
1. GPO drive map item for S: did not match approved target path \\FINBRIDGE-FS02\Finance.
2. Affected client net use output showed stale mapping or disconnected status.
3. Affected users lacked effective permissions until FIN-SharedDrive-Users membership and share/NTFS ACL alignment were corrected.
4. Post-fix, affected and control users mapped S: to same target and could open files.

## Detection
1. On affected endpoint, run:
```powershell
net use
```
Check: S: exists and Remote path equals \\FINBRIDGE-FS02\Finance.

2. On affected endpoint, run:
```powershell
gpresult /r
```
Check: GPO-FIN-DriveMap-S appears under applied user policies.

3. In GPMC path, open:
Group Policy Management > Forest: finbridge.local > Domains > finbridge.local > Group Policy Objects > GPO-FIN-DriveMap-S > Edit > User Configuration > Preferences > Windows Settings > Drive Maps.
Check: S: mapping Action=Replace and Path=\\FINBRIDGE-FS02\Finance.

4. In ADUC path, open affected user > Member Of.
Check: FIN-SharedDrive-Users group membership is present.

5. On file server FINBRIDGE-FS02:
- Share permission path: Computer Management > Shared Folders > Shares > Finance > Properties > Share Permissions
- NTFS permission path: D:\Finance > Properties > Security
Check: FIN-SharedDrive-Users has expected access at both layers.

6. Comparison check:
Run net use and gpresult /r on one unaffected Finance user.
Check: unaffected user maps to \\FINBRIDGE-FS02\Finance with same GPO applied.

## Resolution
1. Open GPMC path:
Group Policy Management > Forest: finbridge.local > Domains > finbridge.local > Group Policy Objects > GPO-FIN-DriveMap-S > Edit > User Configuration > Preferences > Windows Settings > Drive Maps.
Set S: Action=Replace, Path=\\FINBRIDGE-FS02\Finance, Reconnect=Enabled, then save. [ELEVATED]
Expected result: Policy has correct mapping target.

2. Open ADUC and add missing affected users to FIN-SharedDrive-Users. [ELEVATED]
Expected result: Group membership is correct for all impacted users.

3. On FINBRIDGE-FS02, align share and NTFS permissions for FIN-SharedDrive-Users. [ELEVATED]
Expected result: Both permission layers allow intended access.

4. On affected endpoint, execute:
```powershell
net use S: /delete
gpupdate /force
shutdown /l
```
Expected result: stale mapping removed, policy reapplied, user signs in to refreshed mapping.

5. After sign-in, execute:
```powershell
net use
```
Expected result: S: points to \\FINBRIDGE-FS02\Finance and status is OK.

6. Ask user to open one known folder and one known file on S:.
Expected result: No Access Denied.

## Verification
1. Sample at least 3 previously affected users.
Success criteria: all 3 map S: to \\FINBRIDGE-FS02\Finance and can open files.

2. Validate GPO application with gpresult /r on one affected endpoint and one control endpoint.
Success criteria: both show GPO-FIN-DriveMap-S in applied user policies.

3. Confirm no new S: access incidents for 30 minutes in Service Desk queue.
Success criteria: zero new Finance shared-drive tickets.

## Rollback
1. Restore previous GPO-FIN-DriveMap-S backup in GPMC. [ELEVATED]
Expected result: prior policy state is reinstated.

2. Revert any emergency ACL changes on FINBRIDGE-FS02 to pre-change baseline from documented backup. [ELEVATED]
Expected result: permissions return to known safe baseline.

3. Force client refresh:
```powershell
gpupdate /force
shutdown /l
```
Expected result: endpoints return to rollback configuration.

4. If users remain blocked, apply temporary direct mapping command:
```powershell
net use S: \\FINBRIDGE-FS02\Finance /persistent:yes
```
Expected result: interim access restored while escalation continues.

5. Escalate with evidence bundle: GPO screenshot, group membership export, share ACL, NTFS ACL, net use and gpresult output.
Expected result: L3 can complete root-fix quickly.

## Preventive
1. Add release checklist control: validate GPO drive path against approved target before migration cutover.
2. Add post-cutover validation: sample 5 Finance users for net use + file-open test within first 30 minutes.
3. Add ACL drift check script on FINBRIDGE-FS02 to compare share and NTFS ACLs daily.
4. Add Service Desk early alert: if 2 or more Finance S: tickets in 15 minutes, trigger DWP incident bridge.

## Related
1. Related feedback source: Day7/post_migration_top3_action_priorities.md.
2. Related self-service context: Day7/post_migration_self_service_guides.md.
