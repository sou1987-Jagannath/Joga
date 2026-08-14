# RUNBOOK: Floor 6 DMS Deployment — Login Failure Containment & Recovery

**Title:** Floor 6 DMS Deployment — Login Failure Containment & Recovery  
**Document Type:** Runbook (Source of Truth)  
**Version:** v1.0  
**Last Updated:** 2026-08-14  
**Owner:** DWP Engineering / Incident Response  
**Applies To:** FinBridge Floor 6 (Legal dept., Windows 11 + Intune)  
**Status:** Production-Ready

---

## PURPOSE & SCOPE

**What this fixes:** Login failures and severe logon delays on ~12+ Floor 6 devices caused by the Document Manager v2.1 app deployment via Intune on Friday afternoon.

**Symptom that triggers this runbook:** Users on Floor 6 report they cannot log in, or logins take 5–10 minutes. Failures began Monday morning, ~24 hours after app deployment. 12+ devices from the Legal-Win11 group affected uniformly.

---

## PREREQUISITES

### Access & Roles Required
- **Intune Service Admin** or **Cloud Application Administrator** role in Microsoft Entra ID
- PowerShell 5.1 or later (7+ preferred)
- PowerShell execution policy allows script running (set via `Set-ExecutionPolicy`)

### Tools Required
- **Option A (GUI):** Intune Admin Center web interface (intune.microsoft.com)
- **Option B (CLI):** Microsoft Graph PowerShell SDK installed and imported (`Install-Module Microsoft.Graph -Scope CurrentUser`)

### Information to Gather BEFORE Starting
1. **Affected group ID and name:** Confirm the Floor 6 device group is named `Legal-Win11` (or verify actual name in Intune)
2. **App name:** Confirm the problematic app is `Document Manager v2.1` (or verify actual app name and version)
3. **Group membership:** Verify the Legal-Win11 group contains ~45 devices (Floor 6 device count)
4. **Deployment ring status:** Confirm the app is currently assigned to Legal-Win11 with "Required" or other active intent

### Verification of Prerequisites
Run this PowerShell check before starting:
```powershell
# Verify you have Intune admin role (will fail if not)
Get-MgRoleManagement -RoleType DirectoryRoles -ErrorAction Stop

# Verify Microsoft Graph module is installed
Get-Module Microsoft.Graph -ListAvailable
```

---

## PROCEDURE

### OPTION A: Remove Floor 6 from Deployment Ring (Fastest, Reversible)

**Use this first.** This stops the deployment from reaching new Floor 6 devices and prevents re-installation, but does NOT uninstall the app from devices that already have it installed.

---

#### **Step 1: Launch Intune Admin Center (GUI Method)**

**Action:**
1. Navigate to https://intune.microsoft.com in your browser
2. Log in with your Intune admin credentials

**Expected Result:**
- Intune Admin Center dashboard loads
- You see left sidebar with "Home", "Devices", "Apps", etc.

---

#### **Step 2: Locate the DMS App in Intune (GUI Method)**

**Action:**
1. Left sidebar → **Apps** → **Mobile applications** (or **Windows** → **Windows apps**, depending on app type)
2. Search bar: type `Document Manager v2.1`
3. Click the app name when it appears

**Expected Result:**
- App details page loads
- Shows app name, version, publisher, and other metadata
- You see an **Assignments** tab at the top

---

#### **Step 3: Review Current Assignments (GUI Method)**

**Action:**
1. Click the **Assignments** tab
2. Scan the table for the row labeled `Legal-Win11`
3. Note the **Intent** column for that row (should read "Required" or similar)

**Expected Result:**
- Assignment table shows all groups/users this app targets
- You see a row for `Legal-Win11` (Floor 6 group)
- Intent shows "Required" or "Available" or similar (active deployment state)
- No errors displayed

---

#### **Step 4: Verify Scope (GUI Method)**

**Action:**
1. Hover over the `Legal-Win11` row in the assignments table
2. Confirm the entry shows exactly this group, not "All devices" or other floors
3. If the table shows device count, verify it's ~45 (Floor 6 size)

**Expected Result:**
- Tooltip or hover text confirms target is specifically `Legal-Win11`
- Scope is Floor 6 only, not fleet-wide
- Proceed to Step 5

**If scope is wrong (e.g., "All devices" or includes other floors):**
- STOP. Do not proceed. Contact Intune admin before removing — wrong scope means your removal will affect other floors.

---

#### **Step 5: Remove Floor 6 from Assignment (GUI Method)**

**Action:**
1. On the `Legal-Win11` row, click the three-dot menu (**...**)
2. Select **Remove** (or **Edit** → change Intent to "Uninstall", then Save — see Option B below for intent-change approach)
3. A confirmation dialog appears: "Remove this group from assignment?"
4. Click **OK** or **Confirm**
5. System saves automatically (or click **Save** if prompted)

**Expected Result:**
- Dialog closes
- `Legal-Win11` row disappears from the assignments table (or status changes to "Removed")
- No errors displayed
- System shows "Assignment removed successfully" or similar confirmation message

---

#### **Step 6: Verify Removal (GUI Method)**

**Action:**
1. Refresh the page (F5 or browser refresh button)
2. Return to **Apps** → **Mobile applications** → `Document Manager v2.1` → **Assignments** tab
3. Scan the assignments table for `Legal-Win11`

**Expected Result:**
- `Legal-Win11` is NO LONGER in the assignments table
- App is still assigned to other groups/users (if any), but Floor 6 is gone
- No errors

---

#### **Step 1–6 (PowerShell/Microsoft Graph Alternative)**

**Instead of GUI, use this PowerShell script to perform Steps 1–6:**

```powershell
# PREREQUISITES: Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All", "Directory.Read.All" -ErrorAction Stop

# STEP 1–2: Retrieve the DMS app
$dmsApp = Get-MgDeviceAppManagementMobileApp -Filter "displayName eq 'Document Manager v2.1'" -ErrorAction Stop
if (-not $dmsApp) {
    Write-Error "DMS app 'Document Manager v2.1' not found. Verify app name and retry."
    exit 1
}
Write-Host "✓ Found app: $($dmsApp.DisplayName) | ID: $($dmsApp.Id)"

# STEP 3: Retrieve the Floor 6 group
$floor6Group = Get-MgGroup -Filter "displayName eq 'Legal-Win11'" -ErrorAction Stop
if (-not $floor6Group) {
    Write-Error "Floor 6 group 'Legal-Win11' not found. Verify group name and retry."
    exit 1
}
$memberCount = (Get-MgGroupMember -GroupId $floor6Group.Id | Measure-Object).Count
Write-Host "✓ Found group: $($floor6Group.DisplayName) | ID: $($floor6Group.Id) | Members: $memberCount"

# STEP 4–5: Get current assignments and verify scope
$assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$floor6Assignment = $assignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if (-not $floor6Assignment) {
    Write-Host "✓ Floor 6 is NOT currently assigned to this app (already removed or never assigned)."
    exit 0
}

Write-Host "⚠️  Floor 6 IS assigned with intent: $($floor6Assignment.Intent)"
Write-Host "Proceeding to remove..."

# STEP 6: Remove the assignment
$assignmentId = $floor6Assignment.Id
Remove-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id -MobileAppAssignmentId $assignmentId -ErrorAction Stop

Write-Host "✓ Removal command sent to Intune"

# STEP 7: Verify removal
Start-Sleep -Seconds 2
$verifyAssignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$stillAssigned = $verifyAssignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if ($stillAssigned) {
    Write-Warning "⚠️  Assignment still present (Intune sync delay; retry in 1 minute)"
} else {
    Write-Host "✓ VERIFIED: Floor 6 successfully removed from DMS deployment"
}
```

**Expected Result:**
- Script connects to Intune without errors
- Finds app `Document Manager v2.1`
- Finds group `Legal-Win11` with ~45 members
- Removes the assignment
- Verification shows Floor 6 no longer assigned

---

### OPTION B: Set Assignment to Uninstall (If Option A Does Not Resolve Failures)

**Use this if, after 30 minutes, logins STILL fail.** This actively uninstalls the app from devices that already have it.

---

#### **Step 8: Change Assignment Intent to "Uninstall" (GUI Method)**

**Action:**
1. Return to **Apps** → **Mobile applications** → `Document Manager v2.1` → **Assignments** tab
2. If Floor 6 is still there (because it was re-added in Step 1 of this option), click its row
3. In the detail pane, change the **Intent** dropdown from "Required" to "Uninstall"
4. Click **Save**

**Expected Result:**
- Intent changes to "Uninstall"
- System saves the change
- Devices will uninstall the app on next check-in

---

#### **Step 8 (PowerShell Alternative):**

```powershell
# Assume $dmsApp and $floor6Group are still in scope from Option A steps above

# Retrieve the assignment (if re-added)
$assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$floor6Assignment = $assignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if (-not $floor6Assignment) {
    Write-Host "Floor 6 is not currently assigned. Use Option A first, or re-add Floor 6 to the assignment with Uninstall intent."
    exit 0
}

# Update the assignment intent to "uninstall"
$updateParams = @{
    Intent = "uninstall"
    Target = $floor6Assignment.Target
}

Update-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -MobileAppAssignmentId $floor6Assignment.Id `
    -BodyParameter $updateParams -ErrorAction Stop

Write-Host "✓ Floor 6 assignment updated to UNINSTALL intent"
Write-Host "Devices will uninstall the app on next check-in (5–30 min typical)"
```

**Expected Result:**
- Intent updated to "uninstall"
- Devices will receive uninstall command on policy sync

---

## VERIFICATION

### Test 1: Confirm Devices Received Policy Change (5–30 minutes post-action)

**Action:**
1. Wait 15–30 minutes for devices to check in with Intune
2. In Intune: **Devices** → **Windows** → select one affected Floor 6 device by name (e.g., `DESKTOP-ABC123`)
3. Click **Device configuration** or **App installation status** tab
4. Look for `Document Manager v2.1` in the app list
5. For Option A (removal from ring): Status should show as "Not Installed" or "Removed" (not "Installed")
6. For Option B (uninstall intent): Status should show "Uninstalling" or "Uninstalled"

**Expected Result:**
- App status changed from "Installed" to "Not Installed" or "Uninstalling"
- No errors displayed
- Proceed to Test 2

---

### Test 2: Test Login on Affected Device (Critical Validation)

**Action:**
1. On an affected Floor 6 device, perform a test login:
   - If user is still logged in, sign out completely (sign-out, don't just lock)
   - At login screen, enter a test user's credentials (ask one of the affected users, or use a test account)
   - Measure login time with a stopwatch (start at credential entry, end at desktop loaded)
2. Login time should now be <2 minutes (baseline), not the previous 5–10 minute failure state

**Expected Result:**
- Test login succeeds without errors
- Login completes in <2 minutes (normal speed)
- Desktop loads, user can open apps without hangs

---

### Test 3: Check Event Viewer for New Errors

**Action:**
1. On the test device, open Event Viewer (right-click Start → Event Viewer, or search "eventvwr.msc")
2. Go to **Security log** → filter for Event ID 4625 (failed logon) in the last 1 hour
3. Go to **Application log** → filter for errors from `Document Manager` or `DMS`

**Expected Result:**
- No new failed logon events (4625) in the last 1 hour
- No DMS application errors
- Event Viewer shows clean logon history

---

### Verification Failure Indicator

**If verification fails (login still slow/fails after 30 min + policy sync complete):**
- App removal is NOT the root cause
- Move to Section G, Escalation Trigger

---

## ROLLBACK

**If Option A or B causes harm or doesn't resolve the issue, reverse it:**

### Rollback Option A (Re-add Floor 6 to Deployment Ring)

**GUI Method:**
1. Go to **Apps** → **Mobile applications** → `Document Manager v2.1`
2. Click **Assignments** tab
3. Click **Add groups** or **Create assignment**
4. Select `Legal-Win11` (Floor 6 group)
5. Set Intent to **Required**
6. Click **Save**

**PowerShell Method:**
```powershell
# Assume $dmsApp and $floor6Group are still in scope

$assignmentParams = @{
    Target = @{
        "@odata.type" = "#microsoft.graph.deviceAndAppManagementAssignmentTarget"
        GroupId = $floor6Group.Id
    }
    Intent = "required"
}

New-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -BodyParameter $assignmentParams -ErrorAction Stop

Write-Host "✓ Floor 6 re-added to DMS deployment with Required intent"
```

**Expected Result:**
- Floor 6 (Legal-Win11) reappears in assignments with intent "Required"
- Devices will re-deploy the app on next check-in

---

### Rollback Option B (Change Uninstall Intent Back to Required)

**GUI Method:**
1. Go to **Apps** → **Mobile applications** → `Document Manager v2.1`
2. Click **Assignments** tab
3. Click the Floor 6 row → detail pane opens
4. Change Intent from "Uninstall" to "Required"
5. Click **Save**

**PowerShell Method:**
```powershell
# Assume $dmsApp and $floor6Group are still in scope

$assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$floor6Assignment = $assignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

$updateParams = @{
    Intent = "required"
    Target = $floor6Assignment.Target
}

Update-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -MobileAppAssignmentId $floor6Assignment.Id `
    -BodyParameter $updateParams -ErrorAction Stop

Write-Host "✓ Floor 6 assignment intent changed back to Required"
```

**Expected Result:**
- Intent changed back to "Required"
- Devices will re-install the app on next check-in

---

## NOTES

### Propagation Reality (Critical for Expectations)

**Intune is NOT instant.** Changes apply on device check-in, not immediately:
- **Typical propagation:** 5–15 minutes (most devices)
- **Expected range:** 5–30 minutes (covers ~90% of devices)
- **Worst case:** Up to 24 hours (device offline, sync disabled, network issues)

**What this action does vs. does NOT do:**
- ✓ **Option A (removal):** Stops new deployments of the app. Devices that already have the app keep it until uninstalled separately.
- ✓ **Option B (uninstall):** Actively triggers uninstall on devices that have the app.
- ✗ Neither option restarts devices automatically. Device restart is user-initiated (though not required for app removal to take effect).

---

### Escalation Trigger (Move to Next Step If This Fails)

**IF, after 30 minutes post-fix and device check-in, logins STILL fail:**

1. **This is NOT the root cause.** DMS removal is not the solution.
2. **Escalate to:** Identity/Azure AD team
3. **New diagnosis path:** Check Azure AD sign-in logs (Entra ID admin center) for:
   - Conditional Access policy blocks
   - Azure AD service degradation
   - MFA or certificate errors
   - Kerberos/domain trust issues
4. **Parallel investigation:** Run local device diagnostics on affected Floor 6 device using the Floor 6 Intune Diagnostics script (see related documents)

---

### Related Documents & References

- **Differential Diagnosis:** `floor6_login_failure_differential_diagnosis_2026-08-14.md` (explains why DMS is ranked as top hypothesis)
- **Device Diagnostic Script:** `Floor6-Intune-Diagnostics_CORRECTED.ps1` (confirms device compliance status independently)
- **Incident Response Summary:** `INCIDENT_RESPONSE_Floor6-DMS-Containment_2026-08-14.md` (context and staff communication)

---

**Runbook Version:** v1.0  
**Last Reviewed:** 2026-08-14  
**Next Review:** After resolution or escalation of the associated incident  
**Approval:** DWP Engineering Lead

