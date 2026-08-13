Summary: Company Portal app installation fails with error 0x87D1041C.

Impact:
- Affected user(s): 1 known user/device; to-verify whether additional devices are failing for the same app.
- Service impact: Required business app is unavailable on the endpoint.
- Business urgency: Medium to high depending on app criticality (to-verify).

Known facts:
- Ticket ID: T-1004.
- Reported issue: Company app fails to install from Company Portal.
- Reported error code: 0x87D1041C.

Missing information to gather:
- Exact app name/version and whether it is required or available assignment.
- Device identity (hostname/serial/user) and enrollment/compliance state.
- Whether failure occurs on all retries and since when.
- Full Company Portal error text and timestamp (to-verify).
- Whether other apps install successfully on the same device.
- Intune app assignment, requirement rules, and detection rule outcomes for this device (to-verify).
- Free disk space, pending reboot state, and network reachability to content source (to-verify).

Likely category:
- Intune / Endpoint Manager - Company Portal App Deployment (to-verify).

First diagnostic step:
- In Intune, review the targeted app install status for the affected device and user, focusing on requirement/detection results and the latest failure event details.