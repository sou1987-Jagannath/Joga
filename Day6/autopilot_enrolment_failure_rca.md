# Root Cause Analysis: Autopilot Enrolment Failure

Date: 2026-08-11
Incident type: Windows Autopilot enrolment failure
Scope: Device failed Autopilot because a legacy MDM enrolment already existed

## Summary

The device failed Autopilot enrolment because it already had an existing MDM enrolment record from a prior manual enrolment on 2023-11-04. The export identifies the failure as `EnrollmentState: Failed` with error code `0x80180014` and the description that the device is already enrolled in MDM. Because the stale enrolment was still present, Autopilot could not complete its own enrolment flow.

The environment checks in the export do not point to licensing or network as the cause. The device is Azure AD joined, Intune P1 and Autopilot licensing are present, and all endpoints were reachable with no proxy.

## Impact

- Autopilot enrolment did not complete.
- Policy deployment did not start successfully, shown by `ProfilesApplied: 0 of 4`.
- The device remained in a failed enrolment state instead of transitioning to managed Autopilot provisioning.
- The error also surfaced `0x80070005` / Access denied during policy processing.

## Supporting evidence

| Evidence item | Value | Interpretation |
|---|---|---|
| EnrolmentState | Failed | Autopilot provisioning did not complete |
| ErrorCode | `0x80180014` | Export states the device is already enrolled in MDM |
| ErrorDescription | The device is already enrolled in MDM | Direct confirmation of the conflict |
| MDMEnrolled | Yes (previous enrolment from 2023-11-04) | Stale prior enrolment exists |
| EnrolmentSource | Legacy manual MDM enrolment | Conflicting old management path |
| AzureADJoined | Yes | Device identity is present in Entra ID |
| ProfilesApplied | 0 of 4 | Policy application did not complete |
| LastError | `0x80070005` (Access denied) | Secondary failure during policy processing |
| IntuneP1License | Yes | Licensing is not the blocker |
| AutopilotLicense | Yes | Licensing is not the blocker |
| Network | All endpoints reachable, no proxy | Connectivity is not the blocker |

## Incident timeline

Only the dates present in the export are used below. No exact time-of-day was provided.

| Time | Event |
|---|---|
| 2023-11-04 | Legacy manual MDM enrolment exists on the device |
| 2026-08-11 | Autopilot enrolment attempt fails with `0x80180014` |
| 2026-08-11 | Policy application shows `ProfilesApplied: 0 of 4` and `0x80070005` / Access denied |

## 5-Why analysis

### Why 1: Why did Autopilot enrolment fail?

Because the device returned `0x80180014` and the export says the device is already enrolled in MDM.

### Why 2: Why was the device already enrolled in MDM?

Because a previous manual MDM enrolment from 2023-11-04 still existed on the device.

### Why 3: Why did the previous enrolment block Autopilot?

Because Autopilot could not create a new management enrolment while a conflicting MDM enrolment record was still present.

### Why 4: Why was the conflicting enrolment still present?

Because the legacy manual enrolment had not been fully removed before the Autopilot attempt.

### Why 5: Why was the legacy enrolment not removed first?

Because the device was moved into the Autopilot process without completing cleanup of the old management state, leaving the prior enrolment and associated identity artifacts active.

## Root cause statement

The root cause is a stale legacy MDM enrolment on the device that was not removed before the Autopilot attempt. That existing enrolment conflicted with the new Autopilot enrolment and caused the failure.

## Contributing conditions

- The device already had a prior manual MDM enrolment from 2023-11-04.
- The device was Azure AD joined, so identity existed but management state was not clean.
- The export shows licensing and network were both healthy, narrowing the issue to enrolment state rather than access or entitlement.
- Policy processing also failed, which is consistent with the device never reaching a clean managed state.

## Corrective action taken or required

### Intune admin center actions

Access requirement: admin center only.

1. Locate the device in Intune admin center under Devices -> All devices.
2. Confirm the record matches the stale manual MDM enrolment.
3. Delete the stale Intune device object.
4. Check Entra ID / Azure AD for any duplicate stale device object and remove it if present.
5. If the device must be re-provisioned, wipe it only after the stale records are removed so it returns to a clean OOBE state.

### Device-side actions

Access requirement: physical or remote interactive device access.

1. Open Settings -> Accounts -> Access work or school.
2. Disconnect the legacy work/school connection associated with the manual enrolment.
3. If the stale state remains, reset or wipe the device to OOBE.
4. Re-run Autopilot from the clean device state.

## Preventive actions

1. Add a mandatory pre-Autopilot check for all redeployed or legacy-managed devices to ensure no manual MDM enrolment remains.
2. Require deletion of old Intune and Entra ID device objects before Autopilot assignment when devices are converted from legacy management.
3. Use a standard deprovisioning checklist that includes removing work/school connections and confirming the device is at a clean OOBE reset state.
4. Train support staff to treat `0x80180014` with a known existing enrolment as a cleanup issue, not a licensing or network issue, when the supporting evidence matches this pattern.

## Verification criteria

The remediation is successful when the next Autopilot attempt results in:

- Successful enrolment completion.
- A fresh Intune device record for the new enrolment.
- No repeat `0x80180014` failure.
- Policy application moving beyond `ProfilesApplied: 0 of 4`.
- The device appearing in the expected managed state after sync.

## Closure note

This incident is consistent with a stale-enrolment conflict rather than a license, network, or general policy issue. The fastest durable fix is to remove the legacy enrolment state completely before attempting Autopilot again.