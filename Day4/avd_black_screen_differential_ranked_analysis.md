# AVD Incident Differential Analysis (Timing-Weighted)

Date: 2026-08-13  
Analyst context: DWP engineering triage

## Scope Facts
- Symptom: black screen post-login; clears after ~30s for some users, persists for others.
- Affected: ~40% of users on POOL-FIN-01.
- Unaffected: POOL-FIN-02 is completely unaffected.
- Since: ~07:00 this morning.
- Change: overnight image update to POOL-FIN-01 at 02:00; POOL-FIN-02 was not updated.

## Key Weighting Principle
The strongest clue is the treated-vs-control split:
- Treated pool: POOL-FIN-01 updated at 02:00.
- Control pool: POOL-FIN-02 not updated and unaffected.

This makes update-coupled causes rank highest.

## Most Consistent Cause With Unchanged/Unaffected Control Pool
1. Image regression in POOL-FIN-01.

Why this is most consistent:
- The only known differential change between pools is the image update.
- Symptoms begin the same morning after that update window.
- Impact in a subset (~40%) fits partial host rotation to the new image.

Fastest discriminator check:
- Correlate affected sessions to host image/build version and confirm whether black-screen users cluster on newly updated hosts.

## Re-Ranked Top 5 Likely Causes (Most Probable First)

1) Golden image regression on updated POOL-FIN-01 hosts
- Why this fits scope facts:
  - Directly explained by the only differential change.
  - Matches pool-specific impact and post-change timing.
- Single fastest check:
  - Map failing users to host image/build version; verify clustering on new-image hosts.

2) FSLogix profile container attach regression triggered by new image state
- Why this fits scope facts:
  - Black screen after authentication with variable duration fits attach latency/failure.
  - Still strongly update-coupled and pool-confined.
- Single fastest check:
  - On one failing host, review FSLogix attach events/timings for timeout/error spikes during incident window.

3) Display stack regression (graphics driver/RDP path) introduced by image update
- Why this fits scope facts:
  - Symptom is visual-path specific.
  - Pool-specific and update-timed behavior is consistent with image driver change.
- Single fastest check:
  - Compare failing vs healthy hosts for graphics driver version and display-related error events.

4) Logon policy/script/app-init delay bundled in updated image
- Why this fits scope facts:
  - Can produce post-login black screen via blocked shell initialization.
  - Can remain isolated to updated pool if packaged with image changes.
- Single fastest check:
  - Pull one affected logon timeline and identify a repeated stall in policy/script processing.

5) Resource contention on updated host subset at morning login peak
- Why this fits scope facts:
  - 07:00 onset and variable recovery fit login-storm contention.
  - However, this is less directly explained by control pool being unchanged/unaffected unless update altered host performance.
- Single fastest check:
  - Correlate affected sessions to per-host CPU/disk latency saturation during 07:00-08:00.

## Position Statement
Do not commit to a single root cause yet.  
Use host image/version correlation first, then FSLogix attach telemetry, to rapidly separate primary image regression from adjacent update-induced effects.

## Evidence Update (2024-03-15 07:00-07:30)

Source host evidence was reviewed for SHFIN-01-A (affected pool) and SHFIN-02-A (unaffected pool).

### SHFIN-01-A (POOL-FIN-01)
- 07:02:10, TerminalServices-LocalSessionManager, Event 21: Session logon succeeded (FINBRIDGE\mlopez, Session 3).
- 07:02:14, Kernel-General, Event 1: Boot time recorded as 02:03:11 (post-update restart context).
- 07:02:16, Application Error, Event 1000: dwm.exe fault, module igdumd64.dll, exception 0xc0000005.
- 07:02:17, TerminalServices-LocalSessionManager, Event 40: Session disconnected (Session 3).
- 07:02:18, Desktop Window Manager, Event 9009: DWM exited with code 0x40010004.
- 07:02:44, TerminalServices-LocalSessionManager, Event 21: Session logon succeeded (reconnect).
- 07:02:46, Application Error, Event 1000: repeated dwm.exe fault in igdumd64.dll.
- 07:02:47, TerminalServices-LocalSessionManager, Event 40: Session disconnected again.
- 07:03:01, Desktop Window Manager, Event 9009: repeated DWM exit.
- 07:03:10, TerminalServices-LocalSessionManager, Event 21: second reconnect succeeded (Session 4).
- 07:08:22, TerminalServices-LocalSessionManager, Event 21: Session logon succeeded (FINBRIDGE\akapoor, Session 5).
- 07:08:24, Application Error, Event 1000: same dwm.exe and igdumd64.dll crash signature.

### SHFIN-02-A (POOL-FIN-02, unaffected control)
- 07:01:44, TerminalServices-LocalSessionManager, Event 21: Session logon succeeded.
- 07:01:46, Desktop Window Manager, Event 9011: DWM started successfully.
- No Application Error Event 1000 in the comparison window.

## Hypothesis Elimination Update

1) Golden image regression on updated POOL-FIN-01 hosts
- Evidence status: Support
- Determining evidence: Event 1 at 07:02:14 plus repeated Event 1000 and Event 9009 on updated pool host; clean Event 9011 on control host.

2) FSLogix profile container attach regression triggered by new image state
- Evidence status: Contradict (as primary cause)
- Determining evidence: Event 21 success at 07:02:10 immediately followed by Event 1000 at 07:02:16 and Event 40 at 07:02:17 indicates crash-led disconnect chain.

3) Display stack regression introduced by image update
- Evidence status: Support
- Determining evidence: repeated Event 1000 (dwm.exe faulting in igdumd64.dll) at 07:02:16, 07:02:46, and 07:08:24; repeated Event 9009 at 07:02:18 and 07:03:01.

4) Logon policy/script/app-init delay bundled in updated image
- Evidence status: Contradict
- Determining evidence: Event 21 success then immediate DWM crash events (1000 and 9009), which does not match a pure logon-delay pattern.

5) Resource contention on updated host subset at morning login peak
- Evidence status: Contradict
- Determining evidence: consistent module-specific crash signature (igdumd64.dll in Event 1000) is stronger evidence of software/driver regression than generic load saturation.

## Surviving Hypothesis

Display stack regression introduced by the POOL-FIN-01 image update, specifically an Intel graphics driver path causing DWM crashes (dwm.exe faulting in igdumd64.dll).

## Resolution Plan (Detailed)

1. Immediate containment
- Put impacted POOL-FIN-01 session hosts into drain mode to stop new user assignments.
- Redirect new sessions to known healthy hosts/capacity while containment is active.

2. Roll back to last known good state
- Preferred: redeploy affected hosts from pre-update validated image.
- Alternative: roll back/uninstall the offending Intel graphics driver version on affected hosts.

3. Image hardening before re-rollout
- Pin a validated graphics driver version in the image pipeline.
- Apply stable AVD graphics settings consistently across all hosts in the pool.

4. Canary validation
- Deploy fixed image to a small subset first.
- Validate no recurrence of Event 1000 (dwm.exe/igdumd64.dll), Event 9009, or immediate Event 40 disconnect sequence after logon.

5. Controlled full rollout
- Rotate remaining hosts in batches.
- Halt rollout and revert the active batch if crash signature reappears.

6. Closure validation
- Compare pre/post incident metrics for black-screen rate and early-session disconnects.
- Confirm event baseline: affected pool no longer shows repeated Event 1000/9009 pattern.

7. Recurrence prevention
- Add release gates in image promotion: fail if canary shows DWM crash signatures.
- Keep staged deployment with explicit stop criteria and rollback trigger thresholds.
