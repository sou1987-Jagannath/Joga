# Windows 11 Intune Compliance Policy Mapping (Security Baseline)

Version: v1.0  
Date: 2026-08-13  
Author: DWP Engineering

## Policy Scope
- Platform: Windows 10 and later (applies to Windows 11)
- Policy type: Compliance policy
- Noncompliance action target: 7-day grace period for all requirements

## Requirement 1 - BitLocker must be enabled on the OS drive
- Setting name: Require BitLocker
- Value: Require
- Effect: Device is marked noncompliant if BitLocker device encryption is not enabled.
- False-positive risk: Freshly provisioned devices can report compliance state before encryption status fully syncs; some devices encrypt after user sign-in completes.
- Recommendation: Keep BitLocker enforcement, but allow the 7-day grace period and ensure enrollment workflow completes encryption before user handoff.

## Requirement 2 - Secure Boot must be enabled
- Setting name: Require Secure Boot to be enabled on the device
- Value: Require
- Effect: Device is marked noncompliant if UEFI Secure Boot is disabled.
- False-positive risk: Legacy BIOS installs or firmware misconfiguration after motherboard/firmware updates can appear as noncompliant.
- Recommendation: Add a pre-enrollment hardware check for UEFI + Secure Boot support to avoid avoidable noncompliance tickets.

## Requirement 3 - Minimum OS build: N-1 (22621.2861)
- Setting name: Minimum OS version
- Value: 10.0.22621.2861
- Effect: Any Windows build lower than 22621.2861 is marked noncompliant.
- False-positive risk: Devices that installed update packages but have not restarted may still report the older build temporarily.
- Recommendation: Keep strict minimum version and align update rings so restart deadlines occur before compliance evaluation windows.

## Requirement 4 - Windows Defender real-time protection must be on
- Setting name: Require real-time protection
- Value: Require
- Effect: Device is marked noncompliant when Microsoft Defender real-time scanning is disabled.
- False-positive risk: Third-party antivirus coexistence or temporary troubleshooting disables can trigger noncompliance on otherwise healthy endpoints.
- Recommendation: Standardize one AV posture (Defender primary or approved managed exception) and document any temporary exception process with auto-expiry.

## Requirement 5 - Firewall must be enabled for all profiles
- Setting name: Firewall
- Value: Require
- Effect: Device is marked noncompliant if Windows Firewall is not enabled.
- False-positive risk: Local troubleshooting scripts or third-party security tools may momentarily disable a profile and trigger a noncompliant state.
- Recommendation: Enforce firewall state through Endpoint Security policy and avoid local admin scripts that toggle firewall services.

## Requirement 6 - A PIN or password must be configured
- Setting name: Require a password to unlock mobile devices
- Value: Require
- Effect: Device is marked noncompliant if no unlock credential is configured.
- False-positive risk: Shared kiosk-style devices or provisioning stages before first user sign-in can appear noncompliant.
- Recommendation: Exclude dedicated/shared kiosk device groups from this user-credential requirement rather than weakening the control globally.

## Requirement 7 - Device must not be jailbroken or rooted
- Setting name: Not directly available as a Windows compliance toggle (no direct "jailbroken/rooted" control for Windows)
- Value: Use Microsoft Defender for Endpoint integration: Require the device to be at or under the machine risk score = Low (recommended)
- Effect: Devices with suspicious compromise indicators are marked noncompliant through MDE risk scoring.
- False-positive risk: Aggressive attack-surface detections or stale MDE sensor health can inflate risk briefly.
- Recommendation: Use risk score-based compliance with SOC-approved triage criteria; monitor recurring false detections and tune indicators in Defender.

## Grace Period Configuration (7 days for all settings)
- Intune action setting: Actions for noncompliance > Mark device noncompliant
- Value: Immediately (0 days) for mark event, plus add notification/conditional access handling with grace process OR set schedule as operationally required
- Target requested here: 7 days grace period
- Recommended implementation: Set noncompliance action schedule to 7 days and align CA policy communications to avoid sudden user lockout.

## Latest UI Path (Best Current) and Change-Risk Flags
1. Create/edit policy path:
- Microsoft Intune admin center > Devices > Compliance policies > Policies > Create policy
- Platform: Windows 10 and later
- Profile type: Compliance policy
- Change risk: Medium [UI sections and labels can shift between "Policies" and "Create policy" flows]

2. Compliance settings pages (inside Windows policy):
- Device Health: Require BitLocker, Require Secure Boot to be enabled on the device
- Device Properties: Minimum OS version
- System Security: Firewall, Require a password to unlock mobile devices, Require real-time protection
- Microsoft Defender for Endpoint connector/risk settings: device risk score compliance
- Change risk: High [some tenants show Defender and risk controls under different grouped headings]

3. Noncompliance action path:
- Compliance policy > Properties > Actions for noncompliance
- Change risk: Low to Medium [wording stable, placement can move slightly]

## Flags Where UI Path/Label May Have Changed Since Training Data
- Require real-time protection: label placement can vary by tenant UX and integration state.
- Require a password to unlock mobile devices: naming is legacy and may appear under different device lock labels.
- MDE risk score setting for Windows compromise posture: depends on Defender connector enablement and can appear outside the base setting pages.

## Implementation Note
If any setting label is not visible exactly as written, use the policy search box within the compliance policy editor and confirm by matching control purpose (BitLocker, Secure Boot, OS version, Defender real-time protection, Firewall, unlock credential, MDE risk).
