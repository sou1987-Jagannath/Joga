Title: AVD Black Screen Post-Login (POOL-FIN-01 Display Regression) Runbook  
Version: 1.0  
Date: 07/08/2026  
Author: Sathishbabu  
Reviewed: self  
Status: draft  
Change: initial version from RCA

# Runbook: AVD Black Screen Post-Login (POOL-FIN-01 Display Regression)

## 1) Prerequisites

1. Confirm incident matches this pattern: POOL-FIN-01 users report black screen after sign-in, with reconnect/disconnect behavior.
2. Obtain Azure subscription access with rights to manage AVD host pool session hosts and host assignment state. [ELEVATED]
3. Obtain permission to modify or redeploy session host image/driver state in the compute resource group. [ELEVATED]
4. Confirm access to Event Viewer data (or centralized logs) for affected and control hosts. [ELEVATED]
5. Identify one affected host in POOL-FIN-01 and one control host in POOL-FIN-02.
6. Prepare communication channel with Service Desk for user-impact updates.
7. Record maintenance window start time and incident change record ID.

## 2) Procedure

1. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts, then open the first unstable host and set Allow new sessions to No. [ELEVATED]
Expected result: The host shows Status available but New sessions disabled (drain mode enabled).

2. In Azure portal, repeat step 1 for each POOL-FIN-01 host reported with black-screen behavior. [ELEVATED]
Expected result: Every unstable host in the Session hosts grid shows New sessions disabled.

3. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions and refresh.
Expected result: New sessions appear only on hosts with Allow new sessions set to Yes.

4. On one affected host (for example SHFIN-01-A), sign in with admin rights and open Event Viewer > Windows Logs > Application. [ELEVATED]
Expected result: Application log opens on the selected affected host.

5. In Event Viewer on the affected host, use Filter Current Log with Event IDs 1000 and Time range around incident start.
Expected result: At least one Application Error Event 1000 appears for faulting application dwm.exe and faulting module igdumd64.dll.

6. On the same affected host, open Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational, then filter for Event ID 9009.
Expected result: Event 9009 entries exist close to the Event 1000 timestamps.

7. On one control host in POOL-FIN-02, open Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational and filter for Event ID 9011 in the same comparison window.
Expected result: Event 9011 shows successful DWM start and repeated Event 1000 dwm.exe/igdumd64.dll is absent.

8. In your image catalog or deployment record, select the exact pre-update image version used before the overnight POOL-FIN-01 change. [ELEVATED]
Expected result: A rollback target image version is documented in the incident record.

9. Redeploy the first drained host from the selected pre-update image using your standard host build pipeline. [ELEVATED]
Expected result: The VM provisioning task completes successfully and the host returns online.

10. In Azure portal, open POOL-FIN-01 > Session hosts and confirm the rebuilt host is listed as Available.
Expected result: Host status is Available with no registration errors.

11. Keep the rebuilt host drained by confirming Allow new sessions remains No.
Expected result: Host remains available for controlled testing only.

12. Launch one controlled test login to the rebuilt host using a test account assigned to POOL-FIN-01.
Expected result: Desktop loads without black screen and without immediate disconnect.

13. On the rebuilt host, recheck Event Viewer for new Event ID 1000 (dwm.exe/igdumd64.dll) and Event ID 9009 after the test login window.
Expected result: No new matching Event 1000 or Event 9009 entries are generated after test login.

14. In Azure portal, set Allow new sessions to Yes for the rebuilt host. [ELEVATED]
Expected result: Host is returned to normal session assignment.

15. Repeat steps 9 through 14 for each remaining drained host, one host at a time. [ELEVATED]
Expected result: Each host is returned to service only after passing the same no-crash validation.

16. Send a restoration update to Service Desk with completion time, remediated host list, and validation summary.
Expected result: Service Desk has the final status and user-facing guidance.

## 3) Verification

1. In Azure portal, open Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions and verify three consecutive user sign-ins complete on remediated hosts.
Success looks like: Each user reaches a usable desktop with no black screen and session state remains Active for at least 5 minutes.

2. On each remediated host, check Event Viewer > Windows Logs > Application for Event ID 1000 in the post-fix observation window.
Success looks like: Zero new Event 1000 entries with dwm.exe as faulting application and igdumd64.dll as faulting module.

3. On each remediated host, check Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational for Event ID 9009 in the same window.
Success looks like: Zero new Event 9009 entries after host reintroduction.

4. In Azure portal, review POOL-FIN-01 user sessions timeline for disconnect patterns after successful logon.
Success looks like: No recurring pattern of logon success followed immediately by disconnect for validated users.

5. In Service Desk queue, filter incidents by service AVD and keyword black screen for 30 minutes after final host undrain.
Success looks like: No new POOL-FIN-01 black-screen incidents are opened in that window.

6. Update the incident ticket with verification timestamp, hosts validated, and event-log screenshots or export references.
Success looks like: Incident record contains complete closure evidence and is approved for closure.

## 4) Rollback

Use this emergency rollback when any reintroduced host shows black screen again. Target completion time: under 3 minutes.

1. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts, open the failing host, and set Allow new sessions to No. [ELEVATED]
Expected result: New sessions disabled is shown for that host.

2. In Azure portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions, filter by the failing host name, select each session, and click Disconnect. [ELEVATED]
Expected result: Active session count on the failing host drops to 0.

3. In Azure portal, return to POOL-FIN-01 > Session hosts and confirm at least one healthy host has Allow new sessions set to Yes. [ELEVATED]
Expected result: There is available healthy capacity for immediate user reconnection.

4. In Azure portal, open Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions and click Refresh twice.
Expected result: Reconnected users appear on healthy hosts, not on the failing host.

5. In Service Desk console, post incident update: Failing host isolated, users redirected, service available on healthy hosts.
Expected result: Frontline team has immediate user handling message and does not route users back to failing host.

6. In your change system, create follow-up task: Rebuild isolated host from last known good image before returning it to service. [ELEVATED]
Expected result: Host stays isolated until rebuild and validation are completed.

## 5) Notes

1. Edge case: Some users may recover after about 30 seconds; treat this as unstable and continue remediation because crash pattern can still recur.
2. Warning: Do not undrain a host before completing post-login crash-event checks.
3. Warning: Manual one-off driver changes on random hosts can create configuration drift; prefer image-based rebuild for consistency.
4. Related incident pattern: control pool unaffected while updated pool fails indicates update-coupled regression.
5. Related known signals: Event 1000 (dwm.exe, igdumd64.dll, 0xc0000005) plus DWM Event 9009 and logon/disconnect sequence.
6. Closure target used in prior incident: service validated restored by 10:00 AM with no new user issues reported.
