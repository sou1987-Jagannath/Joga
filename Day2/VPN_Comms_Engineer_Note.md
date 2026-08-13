# VPN Issue — Engineer Internal Note

**Root cause:** Win11 in-place upgrade silently removed legacy VPN client. Intune re-deployment of the new client did not trigger due to a detection-rule gap — detection script was checking for the old client binary path, which no longer existed post-upgrade, so the requirement evaluated as "not applicable" rather than "not installed".

**Action taken:**
1. Manually removed stale VPN registry entries under `HKLM\SOFTWARE\<vendor>`.
2. Force-triggered Intune sync via Company Portal / `Sync` action in Intune portal.
3. New VPN client deployed via Intune app policy.
4. Split-tunnel config applied as part of client deployment profile.

**Verification:** Confirmed connectivity to all internal subnets post-deployment. No data loss.

**Preventive action required:** Update Intune detection rule to check for the new client binary path (or use a version-agnostic registry key). Add a post-upgrade VPN validation step to the Win11 upgrade checklist. Review other Intune app detection rules that reference legacy binary paths before next upgrade wave.
