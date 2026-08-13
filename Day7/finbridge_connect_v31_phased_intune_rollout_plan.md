# FinBridge Connect v3.1 Phased Intune Rollout Plan

Date created: 2026-08-11
Rollout window: 3 weeks (deadline by 2026-09-01)
Target fleet: 10,000 Windows 11 endpoints
Application: FinBridge Connect v3.1 (Win32 `.intunewin` app)
Previous stable version for rollback: FinBridge Connect v3.0
Detection method in Intune: registry version string

## 1. RING STRUCTURE

1. Ring 0 (Finance priority lane, parallel controlled lane)
1. Size: 500 Finance users total, split into two waves of 100 then 400.
2. Duration: 4 days total in week 1.
3. Who to include:
1. Finance power users, payroll operators, AP/AR owners, and Finance IT champions.
2. At least 10% of Ring 0 must be devices from the known at-risk 4GB RAM subset.
4. Purpose:
1. Meet the business commitment for Finance by end of week 1.
2. Validate core finance workflows under production conditions before broad enterprise rollout.
5. Intune assignment group type:
1. Assigned Entra ID user security group: SG-App-FinBridge-Ring0-Finance-Users.
2. Companion device group for hardware segmentation: SG-App-FinBridge-4GB-Devices.

2. Ring 1 (Pilot)
1. Size: 500 devices (about 5% of fleet), excluding Ring 0 users.
2. Duration: 4 days (week 1, in parallel with Ring 0 after first 24-hour stability check).
3. Who to include:
1. IT engineering, service desk, selected business champions from non-finance departments.
2. Include at least 50 devices from 4GB RAM cohort to validate low-spec behavior early.
4. Purpose:
1. Validate packaging, install behavior, detection accuracy, and uninstall/rollback readiness.
2. Validate support model before larger exposure.
5. Intune assignment group type:
1. Assigned Entra ID device security group: SG-App-FinBridge-Ring1-Pilot-Devices.

3. Ring 2 (Early)
1. Size: 2,500 devices (25% of fleet), excluding devices already in Ring 0 and Ring 1.
2. Duration: 6 days (week 2).
3. Who to include:
1. Business units with moderate criticality and geographically mixed sites.
2. Keep 4GB RAM devices isolated in a separate subgroup so failures can be contained without impacting all Ring 2 users.
4. Purpose:
1. Prove rollout at meaningful scale.
2. Confirm service desk volume and operational support are sustainable.
5. Intune assignment group type:
1. Assigned Entra ID device security group: SG-App-FinBridge-Ring2-Early-Devices.
2. Exclusion device group for at-risk cohort if needed: SG-App-FinBridge-4GB-Isolation.

4. Ring 3 (Broad)
1. Size: remaining 6,500 devices.
2. Duration: 7 days (week 3).
3. Who to include:
1. All remaining production endpoints after Ring 2 success criteria are met.
2. 4GB RAM group enters only if its specific health criteria are met.
4. Purpose:
1. Complete enterprise deployment inside the 3-week deadline.
2. Close rollout with controlled monitoring and fallback readiness.
5. Intune assignment group type:
1. Assigned Entra ID device security group: SG-App-FinBridge-Ring3-Broad-Devices.

5. Assignment method for all rings
1. App assignment for v3.1 should be Required for each active ring group.
2. Non-active rings remain unassigned or explicitly excluded until promotion.
3. Use explicit include and exclude group logic to prevent accidental cross-ring targeting.

## 2. ADVANCE CRITERIA

1. Measurement definitions (applies to all ring gates)
1. Install success rate = Installed devices / devices that checked in and received assignment in the monitoring window.
2. Error rate = Failed devices / devices that checked in and received assignment in the monitoring window.
3. User issue rate = count of FinBridge incident tickets / active ring users x 100.
4. Data sources:
1. Intune app Device install status and User install status for Installed and Failed counts.
2. Service desk queue tagged FinBridge-v3.1 for ticket counts.

2. Ring 1 to Ring 2 gate (evaluate after minimum monitoring period)
1. Monitoring period minimum: 48 hours after at least 90% of Ring 1 targets receive policy.
2. Install success rate to advance: at least 97.0%.
3. Error rate to advance: no more than 2.0%.
4. User-reported issue rate to advance: no more than 1.0 ticket per 100 users per 24 hours.
5. Time-bound decision point: formal go or hold decision within 4 business hours after the 48-hour report snapshot.

3. Ring 2 to Ring 3 gate (evaluate after minimum monitoring period)
1. Monitoring period minimum: 72 hours after at least 85% of Ring 2 targets receive policy.
2. Install success rate to advance: at least 98.0%.
3. Error rate to advance: no more than 1.5%.
4. User-reported issue rate to advance: no more than 0.7 tickets per 100 users per 24 hours.
5. Time-bound decision point: formal go or hold decision within 4 business hours after the 72-hour report snapshot.

4. Hold condition (pause without full rollback)
1. Trigger: detection inconsistency rate above 2.0% for 24 continuous hours in the active ring, where devices show local app presence but Intune detection remains Failed or Not detected.
2. Action on hold:
1. Freeze ring promotion.
2. Keep current ring assignment active.
3. Open packaging and detection-rule review.
4. Specific example:
1. In Ring 2, 70 of 2,500 devices report app binaries present and launchable, but Intune still reports Failed due to registry value format mismatch.
2. This triggers hold, not immediate rollback, while detection is corrected and revalidated.

## 3. ROLLBACK TRIGGERS

1. Trigger A: install failure rate automatic halt
1. Condition: failure rate at or above 8.0% in any active ring during a rolling 12-hour window, after at least 200 installation attempts in that ring.
2. Required action: automatic rollout halt for next ring promotions.
3. Decision owner: End User Compute Lead (primary) plus Change Manager (approver).
4. Decision window: 2 hours from threshold breach alert.
5. Exact Intune action:
1. Remove Required assignment of v3.1 from next ring group.
2. Add affected ring devices to SG-App-FinBridge-Rollback-Active.
3. Assign v3.1 as Uninstall to SG-App-FinBridge-Rollback-Active.
4. Assign v3.0 as Required to SG-App-FinBridge-Rollback-Active.

2. Trigger B: application crash rate rollback consideration
1. Condition: at least 5.0% of active-ring devices report one or more FinBridge v3.1 app crashes in a rolling 24-hour window, confirmed by endpoint telemetry and service desk correlation.
2. Required action: immediate rollback review and likely ring-level rollback.
3. Decision owner: EUC Lead, Application Owner, and Major Incident Manager jointly.
4. Decision window: 4 hours from confirmed threshold breach.
5. Exact Intune action:
1. Freeze new assignments to all subsequent rings.
2. Apply v3.1 Uninstall assignment to impacted ring group.
3. Apply v3.0 Required assignment to the same impacted ring group.

3. Trigger C: business-critical failure immediate rollback
1. Condition: Finance cannot execute payroll or payment release due to FinBridge v3.1 functional failure for 30 minutes or longer during a production processing window.
2. Required action: immediate rollback regardless of percentage affected.
3. Decision owner: Major Incident Manager with Finance Service Owner approval.
4. Decision window: 60 minutes from incident declaration.
5. Exact Intune action:
1. For SG-App-FinBridge-Ring0-Finance-Users and any already-promoted finance-adjacent groups, set v3.1 to Uninstall.
2. Assign v3.0 as Required to those same groups.
3. Maintain rollback state until finance business sign-off.

4. Trigger D: 4GB RAM at-risk device failure isolation
1. Condition: failure rate at or above 12.0% on SG-App-FinBridge-4GB-Devices within any rolling 24-hour window.
2. Required action: isolate at-risk hardware from further v3.1 exposure without stopping healthy hardware rollout.
3. Decision owner: EUC Lead with Device Engineering Lead.
4. Decision window: 4 hours from threshold breach.
5. Exact Intune action:
1. Add SG-App-FinBridge-4GB-Devices to v3.1 exclusion assignments for all remaining rings.
2. Move those devices to SG-App-FinBridge-4GB-Isolation.
3. Assign v3.0 as Required to SG-App-FinBridge-4GB-Isolation.

5. Rollback governance notes
1. Every rollback action must create a change record and incident reference before assignment changes are saved.
2. Post-rollback health check must be completed within 24 hours to confirm v3.0 stability.

## 4. FINANCE DEADLINE RESOLUTION

1. Option A: compress pilot to place Finance in Ring 2 by end of week 1
1. Minimum safe pilot duration: 3 days with at least 48 hours of stable monitoring after 90% assignment coverage.
2. Introduced risk: reduced observation window may miss slower-burn issues such as memory pressure on 4GB RAM devices and delayed detection anomalies.
3. Compensating control: increase telemetry checks to every 4 hours and require same-day packaging hotfix capability before promoting to Finance.

2. Option B: create a separate Finance Ring 0 before main pilot completion
1. Ring 0 structure:
1. Wave 1: 100 Finance users for 24-hour observation.
2. Wave 2: remaining 400 Finance users only if Wave 1 passes gate.
2. Ring 0 advance conditions:
1. Install success at least 98.0% within 24 hours.
2. Error rate no more than 1.5%.
3. No payroll-blocking critical incident.
3. Ring 0 rollback plan:
1. If thresholds breach, set v3.1 Uninstall for SG-App-FinBridge-Ring0-Finance-Users.
2. Reassign v3.0 as Required for the same group within a 2-hour decision window.

3. Recommendation
1. Recommended approach: Option B.
2. Justification:
1. It meets the Finance end-of-week-1 commitment without weakening the integrity of Ring 1 and Ring 2 gates for the rest of the 10,000-device fleet.
2. It limits business risk by containing high-priority rollout to a controlled Finance cohort with explicit rollback controls.
3. It preserves data quality for the main pilot, which is critical for a safe broad rollout under a fixed 3-week deadline.

4. Week-by-week execution summary
1. Week 1:
1. Run Ring 0 Finance waves and Ring 1 pilot.
2. Complete Ring 1 gate decision by end of week.
2. Week 2:
1. Run Ring 2 after Ring 1 gate passes.
2. Evaluate Ring 2 criteria at 72-hour minimum monitoring point.
3. Week 3:
1. Run Ring 3 broad deployment.
2. Keep rollback groups active and monitored through deadline day.