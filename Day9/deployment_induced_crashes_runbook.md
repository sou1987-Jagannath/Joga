# Deployment-Induced App Crashes — Investigation & Resolution Runbook
**Purpose:** Quick reference for DWP Support when investigating application crashes that correlate with recent deployments  
**Scope:** Issues where SCCM deployment log shows success but user/DEX reports indicate application instability  

---

## Quick Incident Triage (First 10 Minutes)

### Step 1: Confirm Scope
- [ ] Affected device count and percentage of total fleet
- [ ] Specific application(s) crashing
- [ ] First crash report timestamp (from Nexthink DEX or user report)
- [ ] Current DEX Score for affected device group

**Question to ask:** "Are all devices or only a subset crashing?"  
→ If subset: **suspect hardware stratification** (proceed to Step 5)  
→ If all: **suspect broader incompatibility** (proceed to Step 2)

---

### Step 2: Check Recent Deployments
- [ ] Query SCCM: "What deployed to this collection in the last 24 hours?"
- [ ] Note deployment start time, completion time, reported success/failure count
- [ ] Calculate **deployment completion → first crash (time delta)**

**Expected pattern for this incident type:**
- Delta: 5–30 minutes (post-install initialization window)
- SCCM result: "X of X succeeded, 0 failures"
- First crash: Begins AFTER deployment completes

**If no recent deployments:** Escalate to different incident category (possible hardware failure, security incident, malware)

---

### Step 3: Identify Crashing Process
- [ ] In Nexthink DEX, identify top crashing process(es)
- [ ] Note percentage of total crashes attributed to this process
- [ ] Check if this process is included in the deployed application/update

**Critical question:** "Is the crashing process part of the deployed update?"  
→ If yes: **Possible version incompatibility** (proceed to Step 4)  
→ If no: Escalate (issue may be secondary effect, not direct cause)

---

### Step 4: Review Vendor Release Notes
- [ ] Locate release notes for the deployed version
- [ ] Search for keywords: "known issue," "limitation," "incompatible," "RAM," "disk," "crash"
- [ ] Check if vendor explicitly documents this application crashing on certain configurations
- [ ] Document any known limitations with specific thresholds (RAM, disk space, OS version)

**Expected finding for this incident type:**
```
"Known limitation: On devices with under 8GB RAM, the auto-save 
indexing process can cause high disk I/O and intermittent crashes 
during the first few hours after installation while the initial 
index builds."
```

---

### Step 5: Stratify Affected Devices by Hardware
- [ ] Query CMDB/asset database for RAM, disk, CPU specs of affected vs. unaffected devices
- [ ] Create a 2-row table:
  - Affected devices: Average RAM, disk space, other specs
  - Unaffected devices: Average RAM, disk space, other specs
- [ ] Look for clear stratification pattern

**Pattern to search for:**
- All affected devices have <X GB RAM
- All unaffected devices have ≥X GB RAM
- Vendor release notes mention the same threshold

**If stratification found:** This is diagnostic confirmation. Proceed to Step 6.

---

### Step 6: Correlation Validation
Create a simple correlation matrix (can be text or table):

```
Evidence Point               | Observed | Vendor Doc | Match?
────────────────────────────│──────────│────────────│────────
Crashing process            | DocMgr   | Auto-save  | ✓
                            |          | indexing   |
Post-install timing         | +16 min  | "first few | ✓
                            |          | hours"     |
High disk I/O              | Yes      | "high disk | ✓
                            |          | I/O"       |
RAM threshold              | 4GB      | "under 8GB"| ✓
                            | devices  |            |
Percentage affected        | 40%      | 40% of     | ✓
                            |          | fleet <8GB |
```

**Outcome:** If 4 or more matches, you have **strong correlation** to a vendor-documented limitation.

---

## Remediation Decision Tree

### Decision Point 1: Scope of Impact

```
        Incident Scope?
              |
       ┌──────┴──────┐
       |             |
   <20% of fleet    ≥20% of fleet
       |             |
   Option A:      Option B:
   Targeted      Fleet-wide
   Rollback      Rollback
```

**Option A - Targeted Rollback** (if <20% affected):
- More surgical; preserves v2.1 for compatible devices (8GB+)
- Requires accurate hardware asset data
- Medium risk: Classification errors could leave some users on broken version

**Option B - Fleet-Wide Rollback** (if ≥20% affected):
- Faster, lower risk of miscategorization
- Simpler communication to users
- Acceptable if new version has no critical features users depend on

---

### Decision Point 2: Workaround vs. Rollback

```
       Is there a workaround?
              |
       ┌──────┴──────┐
       |             |
   Workaround    No workaround
   available      available
       |             |
       v             v
  Implement      Proceed to
  workaround     Rollback
```

**Example workarounds:**
- Increase virtual RAM (not applicable for physical RAM constraint)
- Disable auto-save feature via registry/group policy (check vendor docs if this is an option)
- Schedule feature activation after hours (if indexing can be deferred)

**For this incident:** No workaround exists (auto-save is core feature). Rollback is required.

---

## Rollback Procedure

### Pre-Rollback Checklist
- [ ] Confirm previous version (Document Manager v2.0) is available in SCCM
- [ ] Notify users 15 minutes before rollback: "We're pushing an update to fix crashes. Plan for 5 minutes of unavailability."
- [ ] Create a snapshot/bookmark of current DEX metrics for comparison

### Rollback Steps
1. **In SCCM, create a new deployment**
   - Collection: Legal-Win11 (all 45 devices)
   - Package: Document Manager v2.0 (previous stable version)
   - Action: Install
   - Schedule: ASAP (immediate)
   - Deadline: 30 minutes (gives users time to save work)

2. **Confirm deployment start in SCCM log**
   - Status should show "Deployment started"
   - Do not proceed until deployment shows "In Progress"

3. **Monitor DEX during rollback**
   - Expected: DEX Score should recover to 85+ within 10 minutes of completion
   - Expected: App crash rate should drop to <0.5% within 10 minutes
   - If not: Escalate (rollback may have failed)

### Post-Rollback Validation (30 minutes post-completion)
- [ ] DEX Score for Legal-Win11 collection: **Target > 85** ✓
- [ ] App crash rate for Legal-Win11: **Target < 0.5%** ✓
- [ ] DocManager.exe crashes: **Target < 5 per hour** ✓
- [ ] User reports: **No new crash complaints** ✓

**If all targets met:** Incident resolved. Close ticket.  
**If any target missed:** Escalate; possible secondary issue.

---

## Post-Incident Handoff: Process Improvements

### For Change Management
- [ ] **Action:** Create pre-deployment checklist that includes "Vendor release notes reviewed for known issues"
- [ ] **Action:** Require change risk to be assessed as HIGH if vendor explicitly documents crashes/issues on certain hardware
- [ ] **Approval gate:** Changes with documented hardware incompatibilities must include mitigation plan (e.g., staged rollout to compatible devices only)

### For Desktop Engineering
- [ ] **Action:** Create SCCM device collections segmented by hardware specs (e.g., "Legal-Win11-4GB-RAM", "Legal-Win11-8GB-RAM")
- [ ] **Action:** For future deployments with hardware thresholds, use segmented collections
- [ ] **Timeline:** Implement for Legal within 2 weeks; enterprise-wide by end of Q2

### For Nexthink Operations
- [ ] **Action:** Create an automated alert for deployment windows: "If DEX Score drops >20 points within 30 min of deployment end, escalate to Change Management"
- [ ] **Action:** Establish SLA: Deployments must show stable DEX metrics (score >85) for 30 minutes before marked "Complete"
- [ ] **Tool:** Add post-deployment DEX validation as a gate in the deployment workflow

### For IT Operations (Knowledge Management)
- [ ] **Document:** Document Manager v2.1 hardware incompatibility (4GB RAM devices) in the Known Issues KB
- [ ] **Reference:** Link this RCA to the Known Issues entry
- [ ] **Escalation:** Add to "Deployments to avoid" list for 4GB-heavy device groups until workaround/fix from vendor

---

## Communication Template

### Initial Response (When Incident Confirmed)
```
Subject: Incident Identified — Legal Floor Document Manager Crashes

We've identified the root cause of the app crashes you reported this 
morning. A software update deployed at 09:44 includes a feature that 
is incompatible with devices having less than 8GB RAM.

Our Legal floor has 18 devices with 4GB RAM, which are affected.

We're rolling back to the previous stable version now. Expected 
resolution time: 20–30 minutes.

Affected users: You will see a brief update notification. Please save 
your work before 10:15 AM.

We will follow up with a detailed incident report and steps to prevent 
recurrence.

— DWP Support
```

### Closure Communication
```
Subject: Resolved — Legal Floor Document Manager Incident

The Document Manager crash issue has been resolved.

Root Cause: Document Manager v2.1 deployed at 09:44 included an 
auto-save indexing feature that requires 8GB RAM. Devices with 4GB 
RAM experienced crashes while the index was building.

Resolution: Rolled back to Document Manager v2.0 (previous stable 
version).

Prevention: We've implemented a process to review vendor release notes 
for known incompatibilities before broad deployment and will use 
targeted deployment for hardware-specific issues in the future.

Incident report: [Link to RCA document]

— DWP Support
```

---

## Escalation Criteria

**Escalate to Management if:**
- Incident duration exceeds 4 hours
- More than 50% of a department affected
- Data loss or security exposure confirmed
- Multiple departments affected simultaneously

**Escalate to Vendor if:**
- Rollback does not resolve the issue
- Multiple versions affected (suggests systemic bug, not hardware issue)
- Vendor's documented workaround does not work

---

## Appendix: Deployment-Induced Incident Checklist

Use this checklist to confirm you have a **deployment-induced incident** (vs. other causes):

- [ ] Incident occurred within 30 minutes of deployment completion
- [ ] DEX metrics were stable before deployment completion time
- [ ] DEX metrics degraded after deployment completion time
- [ ] Crashing process is part of the deployed application/update
- [ ] SCCM deployment log shows "Success" with 0 failures
- [ ] Vendor release notes document this exact scenario (or similar)
- [ ] Affected devices match hardware profile vendor identifies as incompatible
- [ ] Unaffected devices have different hardware profile
- [ ] Crash rate and process pattern match vendor documentation

**If 7+ items checked:** High confidence in deployment-induced classification.

