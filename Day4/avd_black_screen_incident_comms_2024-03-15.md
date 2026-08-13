# AVD Incident Communications (Three Audiences, Same Facts)

## Audience 1 - Non-technical executive
Your access and data are safe. This morning, about 40% of Finance users in one virtual desktop group (POOL-FIN-01) saw a black screen after sign-in because of an overnight update; a second group (POOL-FIN-02) was unaffected. We reversed the problematic display component, restored service, and confirmed normal sign-ins by 10:00 AM with no new issues reported. No action is required unless you still see a black screen.

## Audience 2 - Affected end-user team (10 people, non-technical)
Your access and data are safe. This morning, about 40% of users in the Finance virtual desktop group POOL-FIN-01 saw a black screen after sign-in because an overnight update caused the desktop display part to fail, while POOL-FIN-02 was unaffected. We rolled back the problematic display component, restored service, and confirmed normal sign-ins by 10:00 AM with no new issues reported. If you see the same issue again, sign out and back in once, then contact the Service Desk if it continues.

## Audience 3 - Engineer-to-engineer internal note
Incident facts (same as user comms):
- Impact: ~40% of POOL-FIN-01 users saw black screen post-login.
- Unaffected control: POOL-FIN-02.
- Trigger window: overnight POOL-FIN-01 image update at 02:00.
- Symptom start: ~07:00.
- Resolution state: restored and verified at 10:00 AM; no new issues reported.

Root cause:
- Display stack regression introduced in updated POOL-FIN-01 image.
- Repeated host evidence on SHFIN-01-A:
  - App Error Event 1000: dwm.exe faulting module igdumd64.dll, exception 0xc0000005 (07:02:16, 07:02:46, 07:08:24).
  - DWM Event 9009 exits (07:02:18, 07:03:01).
  - Session chain: LSM Event 21 success followed by Event 40 disconnect.
- Control host SHFIN-02-A showed DWM Event 9011 successful start and no matching Event 1000 in comparison window.

Exact action taken:
1. Contained by draining/removing unstable POOL-FIN-01 hosts from new session assignments.
2. Reverted affected hosts to known-good image/graphics driver state (rollback of problematic display component).
3. Reintroduced hosts in controlled batches after confirming crash signature did not recur.

Config detail:
- Faulting binary path observed: C:\Windows\System32\igdumd64.dll.
- Faulting app: C:\Windows\System32\dwm.exe.
- Updated ring: POOL-FIN-01 only.
- Control ring unchanged: POOL-FIN-02.

Verification step:
1. User validation: successful sign-ins to POOL-FIN-01 after remediation.
2. Time validation: service stable by 10:00 AM.
3. Telemetry validation: no continuing Event 1000 (dwm.exe/igdumd64.dll) plus Event 9009 recurrence pattern in post-fix window.

Preventive action required:
1. Pin approved graphics driver versions in the golden image and block drift.
2. Enforce canary-first rollout with promotion gates that fail on DWM crash signatures (Event 1000 + Event 9009) in post-logon window.
3. Add automated alerting and rollout auto-pause thresholds for these events on newly updated host rings.
4. Keep documented rapid rollback runbook and scheduled regression drills.
