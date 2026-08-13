# Windows 11 Intune Compliance Policy Translation (Security Baseline)

Date: 2026-08-10
Platform: Windows 10 and later (applies to Windows 11 devices)
Policy type: Device compliance policy

## Latest known UI path (as of Microsoft Learn updates through 2026-07)

1. Intune admin center -> Devices -> Manage devices -> Compliance -> Policies -> Create policy
2. Platform: Windows 10 and later
3. Compliance settings tab -> configure categories:
- Device health
- Device properties
- System security
- Microsoft Defender for Endpoint (optional for risk-based controls)
- Custom Compliance (optional, for script-based checks)
4. Actions for noncompliance -> Mark device noncompliant -> schedule: 7 days

UI path drift flag:
- Medium risk of minor menu text changes (for example, Compliance under Devices can be relabeled in UX refreshes).
- Setting names below are stable and match current Microsoft Learn reference terminology.

## Requirement mapping

| Requirement | Settings name (exact Intune name) | Value | Effect (plain English) | False-positive risk | Recommendation to reduce false positives (without weakening security) | Latest UI path to setting | UI path drift flag |
|---|---|---|---|---|---|---|---|
| 1) BitLocker must be enabled on the OS drive | Require BitLocker | Require | Device is noncompliant unless BitLocker state is attested as enabled for trusted boot/device health. | Common: encryption completed but no reboot yet; attestation not refreshed after imaging; TPM/attestation transient issues. | Communicate mandatory reboot after enabling BitLocker; add helpdesk runbook to force device sync and reboot before escalation. Keep setting at Require. | Compliance settings -> Device health -> Windows Health Attestation Service evaluation rules -> Require BitLocker | Low |
| 2) Secure Boot must be enabled | Require Secure Boot to be enabled on the device | Require | Device is noncompliant if Secure Boot is off or cannot be attested. | Older/unsupported TPM scenarios can report noncompliant; firmware/UEFI misconfig after hardware servicing. | Keep Require. Pre-validate hardware baseline (UEFI + supported TPM) and use dynamic groups to exclude unsupported legacy devices while they are replaced. | Compliance settings -> Device health -> Windows Health Attestation Service evaluation rules -> Require Secure Boot to be enabled on the device | Low |
| 3) Minimum OS build N-1 (22621.2861) | Minimum OS version | 10.0.22621.2861 | Blocks compliance for devices below the required Windows build. | Devices pending quality update install/restart; reporting lag right after update. | Keep minimum at 10.0.22621.2861. Pair with update rings and deadline notifications so healthy devices patch before grace expires. | Compliance settings -> Device properties -> Operating system version -> Minimum OS version | Low |
| 4) Windows Defender real-time protection must be on | Real-time protection | Require | Device is noncompliant if Defender real-time scanning is disabled. | Third-party AV coexistence or passive mode behavior can confuse expected state; temporary disable during troubleshooting. | If third-party AV is standard, validate coexistence model first. Keep Real-time protection = Require, and standardize AV posture to avoid mixed states. | Compliance settings -> System security -> Defender -> Real-time protection | Medium (category layout can shift) |
| 5) Firewall must be enabled for all profiles | Firewall | Require | Requires Windows Firewall enabled and prevents user disablement; noncompliant if firewall is off/conflicted. | Conflicting GPO can override MDM; immediate post-boot sync can briefly show Error/noncompliant. | Keep Require. Migrate conflicting GPO firewall settings to Intune policy; allow one extra sync/reboot validation step before incident creation. | Compliance settings -> System security -> Device security -> Firewall | Medium (category layout can shift) |
| 6) A PIN or password must be configured | Require a password to unlock mobile devices; Password type | Require; Device default (or Alphanumeric if required by policy) | Device is noncompliant unless an unlock secret (PIN/password) is configured. | Shared/kiosk scenarios and specialty endpoints may not use interactive unlock in a standard way; policy interpretation differences on non-mobile form factors. | Keep Require. Set Password type = Device default unless a stronger standard is formally required; avoid over-tight complexity in compliance policy and enforce complexity via endpoint security/account policies. | Compliance settings -> System security -> Password -> Require a password to unlock mobile devices; Password type | Medium (label still says mobile devices in UI) |
| 7) Device must not be jailbroken or rooted | Custom compliance (Windows) (no direct built-in Windows jailbreak/root setting) | Require (with discovery script/rules) OR use MDE risk control: Require the device to be at or under the machine risk score = Low | Enforces a custom compromised-state check, or blocks devices with elevated risk signals from Defender for Endpoint. | Script logic quality issues, stale Defender risk telemetry, or false detections from security tooling can mark healthy endpoints noncompliant. | Preferred: use Defender for Endpoint risk score <= Low for production reliability, and add custom compliance only if you need a specific rooted/jailbroken heuristic. Pilot before broad assignment. | Compliance settings -> Custom Compliance -> Custom compliance; or Compliance settings -> Microsoft Defender for Endpoint -> Require the device to be at or under the machine risk score | High (implementation choice and menu placement can vary by tenant features) |

## Grace period translation (all settings)

Set one noncompliance action for the policy:

- Action: Mark device noncompliant
- Schedule (days after noncompliance): 7

Latest UI path:
- Actions for noncompliance tab -> Mark device noncompliant -> Schedule = 7

Note:
- During those 7 days, effective status can appear as InGracePeriod before becoming NonCompliant.

## Recommended implementation notes

1. Use one dedicated policy name, for example: Windows 11 Compliance - Security Baseline N-1.
2. Assign first to a pilot device group, then broaden scope after 1-2 update cycles.
3. Keep this compliance policy focused on pass/fail checks; enforce detailed hardening (for example, firewall profile rules, password complexity) in Endpoint Security or Configuration profiles.
4. For Requirement 7 wording, document internally that "jailbreak/root" is a mobile term; Windows equivalent should be represented through MDE risk and/or custom compliance logic.

## Validation steps after assignment and first sync

### 1) Where to check this device's compliance state for this specific policy

Primary path (best for policy-specific status):

1. Intune admin center -> Devices -> Manage devices -> Compliance -> Policies
2. Select policy: Windows 11 Compliance - Security Baseline N-1 (or your policy name)
3. Open Device status
4. Search/select the test device
5. Open the device row to view per-setting results (including BitLocker)

Alternative path (best when starting from a known device):

1. Intune admin center -> Devices -> All devices
2. Select the test device
3. Open Device compliance
4. Select the same policy to view effective status and setting-level details

UI path drift flag:
- Medium. The location of Compliance under Devices and the naming of Device status can shift slightly in admin center refreshes.

### 2) Compliance states and Conditional Access impact

- Compliant:
	- Device met all evaluated settings for this policy.
	- For Conditional Access policies that require a compliant device, access is allowed (assuming other CA conditions are met).

- Not compliant:
	- Device failed one or more evaluated settings, or grace period expired.
	- For CA policies requiring compliant device, access is blocked or challenged according to CA design.

- In grace period:
	- Device currently fails at least one setting, but still within the configured noncompliance grace window (7 days in this policy).
	- For this policy, this means the Mark device noncompliant action is delayed, so the device is in temporary remediation time before this policy drives a noncompliant block.
	- Conditional Access still evaluates the device's resulting compliance state across all assigned compliance policies; if another policy already returns Not compliant, access can still be blocked.
	- Best practice: treat In grace period as urgent remediation and clear it before grace expiry.

### 3) BitLocker false-positive triage (BitLocker enabled but policy shows noncompliant)

Most common cause A: Health attestation is stale (boot-time measurement timing)

- Why it happens:
	- Require BitLocker is based on device health attestation measured at boot; state can lag after encryption changes or upgrade.
- Fastest check:
	- On endpoint, run `manage-bde -status C:` and confirm Protection Status is On.
	- Then reboot once and trigger Company Portal sync; recheck device status in policy.

Most common cause B: Device synced before post-change reboot completed

- Why it happens:
	- Encryption/protector state changed during upgrade, but compliance evaluated before final restart and attestation refresh.
- Fastest check:
	- Validate last boot time on device (`systeminfo` -> System Boot Time), confirm whether a reboot occurred after upgrade/BitLocker change.
	- If not, reboot and sync.

Most common cause C: TPM/firmware attestation transient or platform issue

- Why it happens:
	- TPM readiness, firmware state, or attestation service hiccups can report noncompliant despite encrypted OS volume.
- Fastest check:
	- On endpoint, check TPM is ready with `Get-Tpm` (PowerShell) and confirm `TpmReady = True`.
	- In Intune, compare setting-level result for BitLocker with any concurrent Secure Boot/TPM anomalies.

Operational triage shortcut:

1. Confirm `manage-bde -status C:` shows encrypted/protected.
2. Confirm reboot happened after latest upgrade or encryption state change.
3. Sync from Company Portal and recheck policy Device status after evaluation cycle.
4. Escalate only if still noncompliant after reboot + sync + TPM ready verification.
