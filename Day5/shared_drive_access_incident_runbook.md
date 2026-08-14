Title: Finance Team Cannot Access Shared Drives - Runbook  
Version: 1.0  
Date: 07/08/2026  
Author: DWP Engineering  
Reviewed: self  
Status: draft  
Change: initial version from RCA

# Runbook: Finance Shared Drive Access Failure

## 1) Prerequisites
1. Confirm incident pattern: Finance users cannot open S: drive and receive Access Denied.
2. Confirm access to Group Policy Management Console (GPMC). [ELEVATED]
3. Confirm access to Active Directory Users and Computers (ADUC). [ELEVATED]
4. Confirm access to file server share and NTFS permissions. [ELEVATED]
5. Confirm at least one affected user and one unaffected user for comparison.
6. Confirm Service Desk communication channel is active.

## 2) Procedure
1. Open Group Policy Management > Forest: finbridge.local > Domains > finbridge.local > Group Policy Objects > GPO-FIN-DriveMap-S.
Expected result: The drive-mapping GPO is visible and editable.

2. Open Edit on GPO-FIN-DriveMap-S and navigate to User Configuration > Preferences > Windows Settings > Drive Maps.
Expected result: S: mapping item is visible.

3. Check S: mapping Path value.
Expected result: If path is legacy or incorrect, it is identified as mismatch against approved path \\FINBRIDGE-FS02\Finance.

4. Set Path to \\FINBRIDGE-FS02\Finance and Action to Replace, then save. [ELEVATED]
Expected result: GPO now targets the correct share path and will overwrite stale client mappings.

5. In ADUC, open affected user account > Member Of and verify membership in FIN-SharedDrive-Users. [ELEVATED]
Expected result: Affected user is present in the required access group.

6. On file server FINBRIDGE-FS02, open Computer Management > Shared Folders > Shares > Finance > Properties > Share Permissions.
Expected result: FIN-SharedDrive-Users has required share-level access.

7. On file server FINBRIDGE-FS02, open folder D:\Finance > Properties > Security.
Expected result: FIN-SharedDrive-Users has required NTFS access matching policy.

8. On affected client, open Command Prompt and run net use S: /delete.
Expected result: Existing S: mapping is removed.

9. On affected client, run gpupdate /force and then sign out/sign in.
Expected result: Updated GPO applies and S: remaps to the corrected path.

10. On affected client, run net use and validate S: points to \\FINBRIDGE-FS02\Finance.
Expected result: S: is connected to correct server/share.

11. Ask user to open a known finance folder and one file from S:.
Expected result: User can browse and open files without Access Denied.

12. Send Service Desk recovery update with incident time, cause, and fix summary.
Expected result: Service Desk has a clear closure-ready message.

## 3) Verification
1. Compare one affected and one unaffected user with net use output.
Success looks like: both users map S: to \\FINBRIDGE-FS02\Finance.

2. Check Group Policy application on affected client using gpresult /r.
Success looks like: GPO-FIN-DriveMap-S is listed under applied user policies.

3. Validate access test with affected user.
Success looks like: user can list folders, open file, and save test file if write access is expected.

4. Monitor Service Desk for 30 minutes.
Success looks like: no new Finance S: Access Denied tickets.

## 4) Rollback
1. In GPMC, restore previous version of GPO-FIN-DriveMap-S from GPO backup. [ELEVATED]
Expected result: Prior drive mapping configuration is restored.

2. On affected clients, run gpupdate /force and sign out/sign in.
Expected result: Clients return to previous known state.

3. If rollback still fails, disable the drive map item in GPO and publish temporary manual mapping command to users: net use S: \\FINBRIDGE-FS02\Finance /persistent:yes.
Expected result: Users regain interim access while root-cause deep dive continues.

4. Escalate to AD/File Services team with evidence bundle (GPO setting snapshot, group membership, share ACL, NTFS ACL, net use output).
Expected result: Tier-3 has complete diagnostics for final correction.

## 5) Notes
1. Mixed outcomes are possible if some users still have old cached mappings.
2. Share permission and NTFS permission must both allow access; either one can block users.
3. This incident is high business impact during month-end reporting windows.
4. Related content: Finance post-migration feedback noted S: drive as a blocker with no workaround.
