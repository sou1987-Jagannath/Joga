# INCIDENT PREVENTION CONTROL: Floor 6 Incident Review

**Control Name:** Pre-Copilot Enablement Least-Privilege Access Review

---

## WHY THIS CONTROL HAS HIGHEST LEVERAGE

Two distinct failures occurred Monday: a login outage (operational) and data exposure (compliance/legal risk). The data-access incident—where a paralegal's AI assistant surfaced confidential client information she shouldn't have seen—is the higher-leverage failure to prevent. An operational outage is reversible and damages availability; a confidentiality breach damages FinBridge's core client trust and carries regulatory exposure. The login issue, while painful, is also a known problem (phased deployments are standard practice). The access-governance gap is novel to the Copilot era and specific to how AI search surfaces existing permission misconfigurations. Fixing this gap prevents the more serious incident and addresses the less-obvious blind spot.

---

## HOW THE CONTROL WORKS

**Trigger:** When a new Copilot or AI-assisted search capability is requested to be enabled for a department with existing data repositories (SharePoint, Teams documents, email, client files).

**Gate:** Blocks Copilot enablement until an access-rights audit is completed and passed. No pilot, no rollout, no feature switch until gate is met.

**Owner:** Data Governance Officer (or Information Security + Department Head jointly; must include someone who owns data, not just systems).

**Pass/Fail Criteria:**
- **PASS:** Audit shows no oversharing—users have access only to information required for their role. No client files visible across silos unless justifiable by business function.
- **FAIL:** Audit finds excessive sharing (e.g., paralegal can see all client matters instead of assigned matters, admin has access to attorney-client files, etc.). Access is remediated and re-audited before Copilot switch-on.
- **Default:** Fail unless explicitly passed. No silent approval.

---

## THE COUNTERFACTUAL: WHERE MONDAY'S INCIDENT GETS STOPPED

**Thursday morning (day before Copilot was to go live on Floor 6):**

1. DWP Engineering submits request: "Enable Copilot for Floor 6 Legal, new rollout planned for Friday."
2. **Control FIRES.** Access review trigger activates: sensitive-data department + Copilot = mandatory review gate.
3. Data Governance team reviews Floor 6 SharePoint, Teams, and Document Manager permissions.
4. Review discovers: The paralegal's account has been granted access to the shared "client matters" repository at the floor level (intended only for assigned cases) due to a prior admin bulk-grant for "Legal staff."
5. **GATE FAILS.** Access is oversharing; remediates by restricting paralegal to only assigned-matters folder.
6. **Result:** Copilot enablement is held until access is fixed and re-audited (Thursday afternoon, passes on re-check).
7. **Monday morning:** Copilot goes live after 24-hour delay, but with corrected access. Paralegal's AI assistant **cannot** surface the client matter she isn't assigned to, because the underlying permission is now correct.
   - The data-exposure incident is prevented entirely.
   - (The login outage from the document-management app still occurs, because this control doesn't address deployment practice; but at least the compliance incident is stopped.)

---

## COST & TRADE-OFF

- **Time delay:** 3–5 working days per new Copilot rollout for access audit and remediation.
- **Resource cost:** 8–16 hours of Data Governance review per department; may require additional access-remediation work (unsharing, reapplying role-based folders, etc.).
- **Operational friction:** Departments expecting fast rollout face a gate. Requires buy-in that the delay is worth the breach prevention.
- **Scope creep risk:** May uncover other access issues beyond Copilot scope, requiring broader remediation.

**Trade-off justification:** For a legal firm where confidentiality is the primary obligation to clients, the delay cost is acceptable. Breach incidents have no acceptable speed-up.

---

## HOW YOU'D KNOW IT'S WORKING

**Single metric:** "100% of new Copilot enablements for departments handling sensitive client data have a documented, passed least-privilege access review on file before the feature switch is activated."

**Measurement:**
- Maintain a control-gate log: department name, review start date, review completion date, pass/fail result, remediation (if any).
- Audit: zero Copilot feature activations without a completed PASS review in the log.
- Quarterly check: sample 3–5 recent Copilot rollouts, verify access reviews exist and were completed before activation.

**Signal that it's broken:** Any Copilot deployment for a new department that bypasses the gate, or a gate logged but no evidence of actual review.

---

## RUNNER-UP CONTROL (noted, not developed)

A phased ring-based deployment with automated health gates (canary 5% → 25% → 100%) would have caught the login failures on Friday before the full floor was affected. This is also a strong control and would prevent the operational outage, but it is standard practice at mature organizations and does not address the novel access-governance gap specific to AI-assisted discovery.

---

**Status:** Ready for Incident Review Board consideration.

