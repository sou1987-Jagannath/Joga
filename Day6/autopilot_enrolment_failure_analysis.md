# Autopilot Enrolment Failure Analysis and Remediation

Date: 2026-08-11
Scope: Windows Autopilot enrolment failure caused by conflicting legacy MDM enrolment

## Executive summary

The failure is caused by an existing MDM enrolment record on the device from 2023-11-04. The export shows `EnrollmentState: Failed` and `ErrorCode: 0x80180014` with the description that the device is already enrolled in MDM. That conflicting enrolment blocks Autopilot from completing.

The `0x80180014` and `0x80070005` codes are treated as provided by the export. No extra meaning is inferred beyond the supplied descriptions.

## Confirmed evidence

- Enrolment failed.
- Error code: `0x80180014`.
- Error description: The device is already enrolled in MDM.
- Existing MDM enrolment: Yes, with a previous manual enrolment from 2023-11-04.
- Enrolment source: Legacy manual MDM enrolment.
- Azure AD joined: Yes.
- Policy application failed: `ProfilesApplied: 0 of 4`.
- Secondary error: `0x80070005` / Access denied.
- Licensing is correct: Intune P1 = Yes, Autopilot license = Yes.
- Network is healthy: all endpoints reachable, no proxy.

## Final root cause

The device still has a stale legacy MDM enrolment, and that existing enrolment conflicts with the Autopilot enrolment flow. Because the device is already enrolled, Autopilot cannot complete until the old enrolment state is removed and the device is returned to a clean provisioning state.

## Remediation plan

### 1) Intune admin center cleanup

Access requirement: admin center only.

1. Open the Intune admin center.
2. Go to Devices -> All devices.
3. Search for the device by device name, serial number, or user.
4. Open the device record and confirm it matches the legacy manual enrolment.
5. Remove the stale record from Intune by deleting the device object.
6. If a duplicate or stale device object also exists in Entra ID / Azure AD, delete the duplicate so only the intended deployment identity remains.
7. If the device is still online and managed, issue a Wipe action only after the stale record cleanup so the device can return to OOBE in a clean state.

### 2) Device-side cleanup

Access requirement: physical access to the device or equivalent remote interactive access.

1. On the device, open Settings -> Accounts -> Access work or school.
2. Select the legacy work/school connection that corresponds to the old manual enrolment.
3. Choose Disconnect to remove the old enrolment connection.
4. If the stale MDM state does not clear fully, perform a full device reset or wipe so the device returns to OOBE.
5. Reconnect the device to the network at OOBE and let Autopilot re-run from the clean state.

## Correct order of operations

1. Confirm the device has the legacy MDM enrolment and identify the matching Intune record.
2. Delete the stale Intune device record.
3. Remove any duplicate stale Entra ID / Azure AD device object if present.
4. Disconnect the legacy work/school connection on the device.
5. Wipe or reset the device back to OOBE.
6. Start Autopilot provisioning again.
7. Wait for policy application and first sync to finish.

## Verification after remediation

Autopilot is considered successful when all of the following are true:

- The device reaches the desktop from Autopilot without failing enrolment.
- Intune shows a fresh device record for the new enrolment, not the old 2023-11-04 legacy record.
- The previous `0x80180014` failure is gone.
- Policy application succeeds and the device no longer shows `ProfilesApplied: 0 of 4`.
- The device appears under the intended Autopilot / Intune management record with current status updated after sync.

## Preventive action for other devices

Add a pre-enrolment validation step for all redeployed or legacy-managed devices: do not assign Autopilot until the old manual MDM enrolment has been fully removed from Intune and the device has been reset to a clean OOBE state. This prevents the same stale-enrolment conflict from recurring on other devices.

## Practical operating note

If a device is being converted from legacy manual management to Autopilot, treat the removal of the old enrolment as a mandatory cleanup step before any new Autopilot assignment or reset. If the stale record remains, the Autopilot flow will continue to fail with the same conflict.