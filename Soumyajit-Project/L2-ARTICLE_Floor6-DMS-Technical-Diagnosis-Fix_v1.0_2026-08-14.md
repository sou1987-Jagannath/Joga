# L2 TECHNICAL ARTICLE: Floor 6 DMS Deployment Login Failures — Diagnosis, Fix, Verification

**Title:** Floor 6 DMS Deployment Login Failures — Diagnosis, Fix, Verification  
**Document Type:** L2 Technical Article  
**Version:** v1.0  
**Last Updated:** 2026-08-14  
**Owner:** DWP Engineering  
**Applies To:** FinBridge Floor 6 (Legal dept., Windows 11 + Intune)  
**Source:** RUNBOOK_Floor6-DMS-Login-Fix_v1.0_2026-08-14.md

---

## RECOGNITION & DIAGNOSIS

### Symptom Cluster
- **Primary:** Multiple users on Floor 6 report login failures or severe slowness (5–10 minute logons vs. baseline <2 min)
- **Timing:** Symptoms began Monday morning at first logon, ~24 hours after Friday afternoon deployment
- **Scope:** ~12+ devices from the Legal-Win11 group (Floor 6 device collection) affected uniformly
- **Not scattered:** Failures are concentrated on one floor and one device group, not distributed across other floors or device groups

### Diagnostic Confirmation

**This incident matches the DMS deployment cause IF all of the following are true:**

1. **Deployment scope matches affected floor:** The "Document Manager v2.1" app was deployed via Intune to the `Legal-Win11` device group on Friday (~24 hours before failures)
2. **Affected device count matches deployment ring:** The 12+ failed-logon devices are members of `Legal-Win11`
3. **Temporal correlation is tight:** Failures started at first user logon Monday morning, not Friday evening or Saturday (would indicate independent cause)
4. **No fleet-wide pattern:** Other floors and device groups without the DMS app are NOT affected (rules out Intune device compliance policy or Azure AD infrastructure issue)

**Look-alike conditions to rule out before acting:**
- **Intune device compliance policy block:** Check if 12+ devices are non-compliant (BitLocker OFF, pending Windows updates, outdated antivirus). (See Floor6-Intune-Diagnostics script for standalone compliance check.)
- **Azure AD sign-in throttling:** Check if sign-in latency is global (affecting other floors equally). (See Entra ID sign-in logs for service-wide degradation.)
- **Windows 11 migration side-effect:** Check if FSLogix profile mount failures or domain trust issues are present. (See device event logs for FSLogix/Netlogon errors.)

### Prerequisite: Run Differential Diagnosis

Before proceeding with this fix, confirm DMS is the top hypothesis by reviewing `floor6_login_failure_differential_diagnosis_2026-08-14.md`. That document ranks DMS deployment as the most-likely cause and specifies the discriminating tests.

---

## ROOT CAUSE EXPLANATION

**Why this happens:** Document Manager v2.1 (based on source fix notes) includes a logon-time startup component or uses a profile-level configuration that interferes with Windows logon flow on Floor 6 devices. The exact mechanism is either:
1. A startup executable that crashes at logon time
2. A logon script that hangs or times out during profile load
3. A resource-heavy background service that exhausts available memory/CPU during the critical logon window, causing timeouts

Affected devices deployed the app Friday afternoon; users first logged in Monday morning (weekend transition + app initialization attempt).

---

## FIX PROCEDURE (FROM RUNBOOK STEPS 1–8)

### Prerequisites (Runbook Prerequisites Section)

**Verify before starting:**
- [ ] You have Intune Service Admin or Cloud Application Administrator role in Entra ID
- [ ] Microsoft Graph PowerShell SDK is installed: `Get-Module Microsoft.Graph -ListAvailable`
- [ ] Legal-Win11 group exists and contains ~45 Floor 6 devices
- [ ] Document Manager v2.1 app exists and is assigned to Legal-Win11

**If any prerequisite is missing, stop and escalate to Intune admin.**

---

### OPTION A: Remove Floor 6 from Deployment Ring (Runbook Steps 1–6)

**Approach:** Delete the app assignment for the Legal-Win11 group, preventing further deployment of DMS to Floor 6 devices. Devices that already have the app retain it; active uninstall is Option B.

**Why do this first:** Fastest, most reversible, stops new deployments immediately.

#### Using Intune Admin Center (GUI)

**Step 1–2 (Launch & Locate):** Navigate to intune.microsoft.com → **Apps** → **Mobile applications** → search `Document Manager v2.1`

**Step 3–4 (Review & Verify Scope):** Click the app → **Assignments** tab. Locate the `Legal-Win11` row. Confirm Intent column shows "Required" or active deployment state. Verify row shows `Legal-Win11` exactly (not "All devices" or other floors).

**Step 5 (Remove):** Click the three-dot menu on `Legal-Win11` row → **Remove** → confirm dialog → **OK**

**Step 6 (Verify):** Refresh page. `Legal-Win11` should no longer appear in assignments table.

**Expected Result:** Floor 6 removed from DMS deployment ring. Devices on next check-in will not receive new app deployment. (Does NOT uninstall already-installed app.)

#### Using Microsoft Graph PowerShell (CLI)

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All", "Directory.Read.All" -ErrorAction Stop

# Retrieve app and group (Steps 1–3)
$dmsApp = Get-MgDeviceAppManagementMobileApp -Filter "displayName eq 'Document Manager v2.1'" -ErrorAction Stop
$floor6Group = Get-MgGroup -Filter "displayName eq 'Legal-Win11'" -ErrorAction Stop

Write-Host "App: $($dmsApp.DisplayName) | Group: $($floor6Group.DisplayName) with $((Get-MgGroupMember -GroupId $floor6Group.Id | Measure-Object).Count) members"

# Get current assignment (Step 4)
$assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$floor6Assignment = $assignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if (-not $floor6Assignment) {
    Write-Host "Floor 6 not currently assigned (already removed or never assigned)"
    exit 0
}

Write-Host "Found assignment. Intent: $($floor6Assignment.Intent). Removing..."

# Remove assignment (Step 5)
Remove-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -MobileAppAssignmentId $floor6Assignment.Id -ErrorAction Stop

Write-Host "✓ Removal command sent"

# Verify removal (Step 6)
Start-Sleep -Seconds 2
$verify = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id | 
    Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if ($verify) {
    Write-Warning "Assignment still present (Intune sync delay expected)"
} else {
    Write-Host "✓ VERIFIED: Floor 6 removed from deployment"
}
```

**Expected Result:** PowerShell confirms app found, group found with ~45 members, assignment found and removed, verification shows removal successful.

---

### OPTION B: Set Assignment Intent to Uninstall (Runbook Step 8)

**Use this IF, after 30 minutes post-Option-A and device check-in, logins STILL fail.** This actively uninstalls DMS from Floor 6 devices.

**Approach:** Change the app assignment intent from "Required" to "Uninstall" for the Legal-Win11 group.

#### Using Intune Admin Center (GUI)

**Step 8 (Uninstall Intent):** Go to **Apps** → **Mobile applications** → `Document Manager v2.1` → **Assignments** tab. Click the `Legal-Win11` row. Change Intent dropdown from "Required" to "Uninstall". Click **Save**.

**Expected Result:** Intent shows "Uninstall". On next device check-in, Floor 6 devices will receive uninstall command.

#### Using Microsoft Graph PowerShell (CLI)

```powershell
# Assume $dmsApp and $floor6Group from prior steps

$assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$floor6Assignment = $assignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if (-not $floor6Assignment) {
    Write-Error "Floor 6 not assigned. Use Option A first or re-add with Uninstall intent."
    exit 1
}

# Update intent to uninstall (Step 8)
$updateParams = @{
    Intent = "uninstall"
    Target = $floor6Assignment.Target
}

Update-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -MobileAppAssignmentId $floor6Assignment.Id `
    -BodyParameter $updateParams -ErrorAction Stop

Write-Host "✓ Floor 6 assignment intent changed to UNINSTALL"
Write-Host "Devices will uninstall app on next check-in (5–30 min typical)"
```

**Expected Result:** Intent updated to "uninstall". Devices receive uninstall command on policy sync.

---

## VERIFICATION (CRITICAL)

### Verification Test 1: Policy Propagation (Runbook Verification Test 1)

**After 15–30 minutes post-fix:**

1. In Intune, go to **Devices** → **Windows**
2. Select one affected Floor 6 device (e.g., `DESKTOP-ABC123`)
3. Go to **Apps** or **App installation status** tab
4. Find `Document Manager v2.1` in the app list
5. **For Option A:** Status should show "Not Installed" or "Removed"
6. **For Option B:** Status should show "Uninstalling" or "Uninstalled"

**Expected Result:** App status has changed from "Installed" to "Not Installed"/"Removed"/"Uninstalling". Proceed to Test 2.

### Verification Test 2: Test Login Performance (Runbook Verification Test 2) — CRITICAL

**This is the definitive test:**

1. On an affected Floor 6 device, completely sign out (sign-out, not lock)
2. Have a user login with their credentials
3. Measure login time from credential entry to desktop ready (<2 min is normal)
4. Previous login time was 5–10 min (failure state)
5. New login time should be <2 min (normal)

**Expected Result:** Login succeeds, completes in <2 minutes, desktop loads without hangs. User can open apps normally.

**If login is still slow or fails:** Move to Escalation Trigger (Section below).

### Verification Test 3: Event Viewer (Runbook Verification Test 3)

1. On the test device, open Event Viewer
2. **Security log:** Filter for Event ID 4625 (failed logon) in last 1 hour. Should show zero new failures.
3. **Application log:** Filter for errors from `Document Manager` or `DMS`. Should show zero.

**Expected Result:** Clean event logs, no new failures or DMS errors.

---

## ROLLBACK (IF FIX DOES NOT WORK)

### Rollback Option A (Undo Removal)

**If login failures persist after Option A, the removal was not the fix. Re-add Floor 6 to verify DMS is not the cause:**

**GUI:** Go to **Apps** → **Mobile applications** → `Document Manager v2.1` → **Assignments** → **Add groups** → select `Legal-Win11` → Intent: **Required** → **Save**

**PowerShell:**
```powershell
$assignmentParams = @{
    Target = @{ "@odata.type" = "#microsoft.graph.deviceAndAppManagementAssignmentTarget"; GroupId = $floor6Group.Id }
    Intent = "required"
}

New-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -BodyParameter $assignmentParams -ErrorAction Stop

Write-Host "✓ Floor 6 re-added to DMS deployment"
```

**Expected Result:** Floor 6 reappears in assignments with "Required" intent.

### Rollback Option B (Change Uninstall Back to Required)

**GUI:** Go to **Apps** → **Mobile applications** → `Document Manager v2.1` → **Assignments** tab. Click `Legal-Win11` row. Change Intent from "Uninstall" to "Required". Save.

**PowerShell:**
```powershell
$updateParams = @{
    Intent = "required"
    Target = $floor6Assignment.Target
}

Update-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -MobileAppAssignmentId $floor6Assignment.Id `
    -BodyParameter $updateParams -ErrorAction Stop

Write-Host "✓ Floor 6 intent changed back to Required"
```

**Expected Result:** Intent changed to "Required". Devices re-install app on next check-in.

---

## PROPAGATION REALITY (CRITICAL FOR TRIAGE)

**Intune policy changes are NOT instant.**

- **Typical:** 5–15 minutes (most devices check in on this interval)
- **Expected range:** 5–30 minutes (covers ~90% of devices)
- **Worst case:** Up to 24 hours (offline device, sync disabled, network latency)

**What this fix does:**
- **Option A:** Removes deployment assignment; stops new installations; already-installed app remains until uninstalled
- **Option B:** Triggers active uninstall on devices that have the app

**What this fix does NOT do:**
- Auto-restarts devices (user-initiated only, though not required for policy to apply)

---

## ESCALATION TRIGGER (MOVE TO NEXT STEP IF VERIFICATION FAILS)

**IF, after 30 minutes post-fix and device check-in, Verification Test 2 (login test) STILL fails:**

### This Means
DMS removal is NOT the root cause. Login failures are driven by another factor.

### Escalation Path
1. **Stop Option A/B troubleshooting.** Escalate to Identity/Azure AD team.
2. **Parallel investigation:** Run the Floor 6 Intune Diagnostics script (`Floor6-Intune-Diagnostics_CORRECTED.ps1`) on an affected device to rule out device compliance policy independently.
3. **Check Azure AD sign-in logs** (Entra ID admin center → Sign-in logs, filter Floor 6 users 08:00–09:00 Monday) for:
   - Conditional Access policy blocks (error code 50076, 65001)
   - Azure AD service degradation alerts
   - Kerberos/domain trust failures
4. **Review differential diagnosis** (`floor6_login_failure_differential_diagnosis_2026-08-14.md`) to rank next hypotheses (Intune device compliance, Azure AD, Windows 11 migration).

### Documentation Reference
See `INCIDENT_RESPONSE_Floor6-DMS-Containment_2026-08-14.md` for staff communication during escalation.

---

## RELATED DOCUMENTS

- **Runbook (Source):** RUNBOOK_Floor6-DMS-Login-Fix_v1.0_2026-08-14.md
- **Differential Diagnosis:** floor6_login_failure_differential_diagnosis_2026-08-14.md
- **Device Diagnostic Script:** Floor6-Intune-Diagnostics_CORRECTED.ps1
- **L1 User Article:** L1-ARTICLE_Floor6-Login-Issues-User-Guide_v1.0_2026-08-14.md
- **Incident Response Context:** INCIDENT_RESPONSE_Floor6-DMS-Containment_2026-08-14.md

---

**L2 Article Version:** v1.0  
**Effective Date:** 2026-08-14  
**Last Reviewed:** 2026-08-14

