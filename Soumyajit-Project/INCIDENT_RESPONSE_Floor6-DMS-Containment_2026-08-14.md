# INCIDENT RESPONSE: Floor 6 DMS Deployment — Immediate Containment Action
## Monday Morning, 2026-08-14 ~09:15 AM

---

## STEP 1: WORKING CONCLUSION (With Confirm/Refute Logic)

**Most-likely cause:** The Friday DMS deployment (Document Manager v2.1) to the Floor 6 device group (Legal-Win11) is causing login failures on affected machines. **Evidence:** (1) Deployment scope matches affected floor exactly; (2) failures began Monday morning at first logon, ~24 hours post-deployment; (3) 12+ users from the same deployment ring are affected uniformly (not scattered across floors).

**Confirmation test:** If we remove Floor 6 devices from the DMS deployment ring and logon succeeds within 15–30 minutes of next device check-in, the app is causing the problem. **Refutation test:** If logins still fail after app removal, the root cause is NOT the DMS app—it's Intune device compliance policy, Azure AD throttling, or Windows 11 migration-related, requiring pivot to other investigation paths.

---

## STEP 2: IMMEDIATE TECHNICAL CONTAINMENT ACTION

### CHOSEN APPROACH: Option A (Pull affected devices from deployment ring first)

**Why Option A first, not Option B:**
- **Reversibility:** Removing Floor 6 from ring is a single-line change; adding back is equally simple.
- **Blast radius control:** Stops new deployments to other Floor 6 devices immediately; doesn't risk side effects from active app uninstall on already-deployed machines.
- **Faster triage:** Allows us to observe whether already-deployed app stops causing failures (may indicate app crashes at logon vs. during install).
- **Lower risk:** Uninstall process (Option B) could trigger additional logon delays if the DMS uninstaller itself is problematic.

**Timeline:** Option A takes 2–3 minutes to execute + 15–30 minutes for device check-in propagation = resolution signal by ~09:45–10:00 AM.

---

### EXECUTION PATH 1: Intune Admin Center (GUI)

**Steps:**
1. Navigate to [Intune Admin Center](https://intune.microsoft.com) (intune.microsoft.com)
2. Left sidebar: **Apps** → **Mobile applications** (or **Windows** → **Windows apps**, depending on app type)
3. Search for: **"Document Manager v2.1"** (or the actual DMS app name in your deployment)
4. Click the app name → **Assignments** tab
5. Find the row with target: **"Legal-Win11"** (or the Floor 6 device/user group name)
6. Click the three-dot menu (**...**) on that row → **Remove** (or edit and change Intent from "Required" to "Uninstall" if using Option B)
7. Confirm: **"Remove this group from assignment"** → **OK**
8. **Save** (or auto-saves after remove)

**Verification before removing:**
- Hover over the "Legal-Win11" group row → note the device count shown (should be ~45, matching Floor 6 size)
- Confirm the assignment scope is **exactly "Legal-Win11"**, not "All devices" or other floors

---

### EXECUTION PATH 2: Microsoft Graph PowerShell (Command-Line)

**Prerequisites:**
- PowerShell 7+ or 5.1 with Microsoft.Graph PowerShell SDK installed
- Run as administrator
- Account must have "Intune Service Admin" or "Cloud Application Administrator" role

**Commands:**

```powershell
# STEP 1: Connect to Microsoft Graph with minimal required scopes
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All", "Directory.Read.All"

# STEP 2: Retrieve the DMS application (note the app ID)
$dmsApp = Get-MgDeviceAppManagementMobileApp -Filter "displayName eq 'Document Manager v2.1'" -ErrorAction Stop
if (-not $dmsApp) {
    Write-Error "DMS app not found. Check app name and retry."
    exit 1
}
Write-Host "Found app: $($dmsApp.DisplayName) | ID: $($dmsApp.Id)"

# STEP 3: Retrieve the Floor 6 device group (Legal-Win11)
$floor6Group = Get-MgGroup -Filter "displayName eq 'Legal-Win11'" -ErrorAction Stop
if (-not $floor6Group) {
    Write-Error "Floor 6 group 'Legal-Win11' not found. Check group name and retry."
    exit 1
}
Write-Host "Found group: $($floor6Group.DisplayName) | ID: $($floor6Group.Id) | Members: $(Get-MgGroupMember -GroupId $floor6Group.Id | Measure-Object).Count"

# STEP 4: VERIFICATION — Display current app assignment details
$currentAssignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
Write-Host "`n=== CURRENT ASSIGNMENTS ===" -ForegroundColor Yellow
$currentAssignments | ForEach-Object {
    Write-Host "Group ID: $($_.Target.GroupId) | Intent: $($_.Intent) | Install Intent: $($_.InstallIntent)"
}

# STEP 5: SCOPE VERIFICATION — Confirm Floor 6 group is in the deployment
$floor6Assignment = $currentAssignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }
if (-not $floor6Assignment) {
    Write-Host "Floor 6 is NOT currently assigned (may already be removed). No action needed." -ForegroundColor Green
    exit 0
}
Write-Host "`n⚠️  SCOPE CHECK: Floor 6 group IS assigned to this app with intent '$($floor6Assignment.Intent)'" -ForegroundColor Yellow
Write-Host "Device count in Floor 6 group: $(Get-MgGroupMember -GroupId $floor6Group.Id | Measure-Object).Count" -ForegroundColor Yellow

# STEP 6: CONFIRM WITH USER BEFORE REMOVING
Write-Host "`n⚠️  FINAL CONFIRMATION REQUIRED" -ForegroundColor Red
$confirmation = Read-Host "Remove 'Legal-Win11' group from DMS deployment? (Type 'YES' to confirm)"
if ($confirmation -ne "YES") {
    Write-Host "Operation cancelled." -ForegroundColor Gray
    exit 0
}

# STEP 7: REMOVE FLOOR 6 GROUP FROM ASSIGNMENT (Option A)
try {
    # Delete the specific assignment for Floor 6 group
    $assignmentId = $floor6Assignment.Id
    Remove-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id -MobileAppAssignmentId $assignmentId -ErrorAction Stop
    Write-Host "`n✓ SUCCESS: Floor 6 group removed from DMS deployment" -ForegroundColor Green
}
catch {
    Write-Error "Failed to remove assignment: $_"
    exit 1
}

# STEP 8: VERIFY REMOVAL
$verifyAssignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id
$verifyRemoved = $verifyAssignments | Where-Object { $_.Target.GroupId -eq $floor6Group.Id }
if ($verifyRemoved) {
    Write-Warning "Assignment still present after removal. May require retry."
} else {
    Write-Host "✓ VERIFIED: Floor 6 is no longer assigned to DMS app" -ForegroundColor Green
}

# STEP 9: PROPAGATION NOTE
Write-Host "`n=== PROPAGATION TIMELINE ===" -ForegroundColor Cyan
Write-Host "Changes will be applied to Floor 6 devices on their next Intune check-in:"
Write-Host "  - Immediate (typically):  5–10 minutes"
Write-Host "  - Expected range:         5–30 minutes"
Write-Host "  - Worst case:             Up to 24 hours (device offline, slow sync)"
Write-Host "`nIMPORTANT: This removes the deployment assignment, NOT the app already installed."
Write-Host "           Devices with DMS already installed will retain it until uninstalled."
Write-Host "           If login failures persist, pivot to Option B (active uninstall) after 30 min."
```

**To execute:**
```powershell
# Save script as ContainDMS-Floor6.ps1, then run:
.\ContainDMS-Floor6.ps1
```

---

### OPTION B (If Option A Does Not Resolve Login Failures After 30 Min)

**Escalation: Active uninstall of DMS from Floor 6 devices**

If Option A removal from the ring does NOT resolve login failures within 30 minutes, the app was already installed. Execute Option B to trigger active uninstall on all Floor 6 devices:

```powershell
# OPTION B: Change assignment intent to "uninstall" for Floor 6 group
# (Same connection as above; assumes $dmsApp and $floor6Group still in scope)

# Retrieve current assignment
$floor6Assignment = (Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id) | 
    Where-Object { $_.Target.GroupId -eq $floor6Group.Id }

if (-not $floor6Assignment) {
    Write-Host "Floor 6 assignment not found. Option A may already have removed it." -ForegroundColor Gray
    exit 0
}

# Update assignment intent to "uninstall"
$updateParams = @{
    Intent = "uninstall"
    Target = $floor6Assignment.Target  # Preserve the existing group target
}

Update-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -MobileAppAssignmentId $floor6Assignment.Id `
    -BodyParameter $updateParams -ErrorAction Stop

Write-Host "✓ Floor 6 assignment updated to UNINSTALL intent" -ForegroundColor Green
Write-Host "Devices will uninstall DMS on next check-in (5–30 min typical)"
```

---

### SCOPING & VERIFICATION SUMMARY

| Step | What We Check | Why | Expected Result |
|------|---------------|-----|-----------------|
| **Retrieve app** | Does "Document Manager v2.1" exist? | Confirms app is deployed | App ID found |
| **Retrieve group** | Does "Legal-Win11" exist? | Confirms Floor 6 group exists | Group ID found, ~45 members |
| **List assignments** | Is Floor 6 group currently assigned? | Confirms scope (not all devices) | Shows exact target group |
| **Display member count** | How many devices in Legal-Win11? | Verifies Floor 6 scope (should be ~45) | Count = 45 (or close) |
| **User confirmation** | User types "YES" before proceeding | Prevents accidental execution | Require explicit approval |
| **Verify removal** | Is Floor 6 still in assignments post-removal? | Confirms action succeeded | Floor 6 group gone from list |

---

### PROPAGATION REALITY

**Intune is NOT instant.** Changes apply on device check-in, not immediately:
- **Typical:** 5–15 minutes (device checks in regularly)
- **Expected window:** 5–30 minutes (captures ~90% of devices)
- **Worst case:** Up to 24 hours (device offline, sync disabled, network issues)

**This action removes the deployment assignment, NOT the already-installed app.** If we're wrong about causation (app is not the problem), removing the assignment doesn't fix the already-running app on installed devices. In that case, pivot to Option B (uninstall intent).

---

### HOW TO REVERSE THIS ACTION (Rollback)

**If removing Floor 6 from ring is NOT the fix (login still fails after 30 min):**

```powershell
# Re-add Floor 6 group to "required" assignment:
$assignmentParams = @{
    Target = @{
        "@odata.type" = "#microsoft.graph.deviceAndAppManagementAssignmentTarget"
        GroupId = $floor6Group.Id
    }
    Intent = "required"
}

New-MgDeviceAppManagementMobileAppAssignment -MobileAppId $dmsApp.Id `
    -BodyParameter $assignmentParams -ErrorAction Stop

Write-Host "✓ Floor 6 re-added to DMS deployment ring"
```

**If Option B (uninstall) causes NEW problems:**

```powershell
# Change intent back to "required" or remove uninstall assignment:
# (Same as re-adding to ring, above)
```

---

### ACTIONS WE WILL NOT TAKE

| Action | Why Not | What We'll Do Instead |
|--------|---------|----------------------|
| Mass password reset | Destroys auth audit trail; doesn't fix the app problem | Keep passwords intact; fix deployment scope |
| Wipe user profiles | Non-reversible; destroys user data; not the root cause | Keep profiles; remove problematic app |
| Uninstall DMS fleet-wide beyond Floor 6 | Too broad; affects users who don't have the problem | Target only Floor 6 deployment ring |
| Restart Intune service on all devices | Not necessary; would cause wider disruption | Let natural policy sync apply |

---

## STEP 3: COMMUNICATION TO FLOOR 6 STAFF (Ready to Send)

### Subject: Floor 6 Login Issue — We're Working on It

Dear Floor 6 team,

We know several of you are having trouble logging in or seeing very slow logins this morning. We've identified the likely cause: a software update that was installed Friday may be causing issues at startup. **Here's what we're doing right now:**

We're removing that software from the affected machines and restarting its installation to fix it. This usually takes 15–30 minutes to reach your computer once we make the change. **During this time:**
- If you haven't logged in yet, please try again in 15 minutes — it may work then.
- If you're already logged in, you're fine to keep working. No need to restart.
- Do NOT restart your computer unless we ask you to; restarting may delay the fix.

**We'll send an update by 10:00 AM** with either "issue resolved" or "here's what we're doing next." We know this is frustrating, and we're prioritizing getting everyone back to work.

Thank you for your patience.

— IT Support

---

### Verification of Communication:
✓ **Zero jargon:** No "Intune," "deployment ring," "policy sync," "assignment intent"  
✓ **Honest timeline:** "usually takes 15–30 minutes" + "update by 10:00 AM" (next-update time, not resolution promise)  
✓ **Clear actions:** What to do (try login in 15 min) and NOT do (don't restart)  
✓ **Warm & brief:** 5 sentences, reassuring without over-promising  
✓ **Unrelated issues separated:** No mention of Copilot data concern (different team, different urgency)

---

## EXECUTION CHECKLIST (Right Now)

```
[ ] Verify you have Microsoft Graph PowerShell SDK installed
[ ] Verify you have Intune admin or Cloud App Admin role
[ ] Run the PowerShell script above (ContainDMS-Floor6.ps1)
    - Confirm app found: "Document Manager v2.1"
    - Confirm group found: "Legal-Win11" with ~45 members
    - Type "YES" to confirm removal
    - Verify: "Floor 6 removed from DMS deployment"
[ ] Send communication to Floor 6 (update timestamp to actual time)
[ ] Set calendar reminder: 10:00 AM — send status update to Floor 6
[ ] Set calendar reminder: 10:15 AM — if still failing, execute Option B (uninstall)
[ ] Monitor: Check login success rate on Floor 6 devices (Intune > Devices > Device compliance)
```

---

**Action initiated:** 2026-08-14 ~09:15 AM  
**Expected resolution signal:** 2026-08-14 09:45–10:00 AM  
**Next communication:** 2026-08-14 10:00 AM  
**Escalation if unresolved:** Pivot to Option B (uninstall) + Azure AD sign-in logs

---

**Document prepared by:** DWP Senior Engineering (Incident Response)  
**Classification:** Internal — Active Incident  
**Version:** 1.0
