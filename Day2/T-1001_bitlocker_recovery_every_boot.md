Summary: New Windows 11 laptop prompts for BitLocker recovery key on every boot.

Impact:
- Affected user(s): 1 known user (ticket reporter); to-verify if additional new laptops are affected.
- Service impact: Repeated recovery prompts block normal startup flow and delay user access each reboot.
- Business urgency: High for the affected user due to ongoing productivity loss; to-verify if urgency should be escalated based on wider scope.

Known facts:
- Ticket ID: T-1001.
- Device type: New Windows 11 laptop.
- Reported issue: BitLocker recovery key is requested every boot.
- Pattern: Recurs on each boot per ticket statement.

Missing information to gather:
- Device details: hostname, asset tag, serial number, assigned user.
- Exact trigger pattern: cold boot, restart, wake-from-sleep, or all (to-verify).
- Start point: since first setup or after a specific change/update (to-verify).
- Any recent firmware/BIOS changes, docking/peripheral changes, or hardware replacements (to-verify).
- TPM status and health in firmware/OS (to-verify).
- BitLocker protector configuration and recovery key escrow location/availability.
- Whether other newly issued Win11 devices show the same symptom (scope check).

Likely category:
- Endpoint Security - BitLocker / Device Encryption (to-verify).

First diagnostic step:
- On the affected laptop, capture the immediate BitLocker recovery context and validate BitLocker + TPM state (including protector status) before any remediation changes.