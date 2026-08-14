# SECURITY INCIDENT ANALYSIS: Floor 6 Legal — Copilot Access Control Breach Discovery

**Date:** 2026-08-14  
**Incident Classification:** Potential Data Confidentiality / Legal Privilege Breach  
**Affected Floor:** Floor 6, Legal (45 users)  
**Discovery Method:** Copilot surfaced undisclosed access to restricted client matter  
**Severity:** CRITICAL — Legal/Compliance Risk

---

## 1. WHAT THIS REPORT ACTUALLY IS

**The Reality:**
Copilot only surfaced content that the paralegal already held permissions to access. Copilot does not fabricate, speculate, or "leak" data outside the user's permission boundary; it respects and enforces the underlying Microsoft 365 permission model (SharePoint/OneDrive ACLs, DMS access controls, Azure AD group membership). If Copilot returned a client matter the paralegal stated she should not have access to, this is not a Copilot malfunction—it is evidence of a **real, pre-existing access-control failure**: the paralegal's account holds permissions it should not hold.

**Why This Matters in Legal:**
This is a potential breach of attorney-client privilege and client confidentiality. Legal departments operate under strict data classification and need-to-know access controls. A paralegal accessing confidential client matters outside her assigned role creates liability, audit findings, and potential regulatory exposure (e.g., privacy/data protection obligations). The Friday DMS rollout is a likely common cause: mass permission re-inheritance, group membership sync errors, or incomplete least-privilege enforcement during application deployment can inadvertently grant broad access.

**What Copilot's Behavior Reveals:**
Copilot is acting as a permission-model auditor, surfacing access anomalies that would otherwise remain hidden in SharePoint/DMS permission lists and group membership data. The paralegal's trust in her own role boundary ("I swear I never had access") is reasonable, but her account's actual permissions tell a different story. This is exactly the kind of access-control failure that compliance auditors hunt for and the kind that creates liability for the organization.

---

## 2. WHAT YOU WOULD NOT DO (AND WHY EACH IS WRONG)

### ❌ WRONG #1: Close It as "AI Weirdness" or Copilot Hallucination
**Why this is dangerously wrong:**
- Copilot does not hallucinate access-controlled content. If it returned a real client matter (with real document metadata, file path, or case details), it is reporting actual data in the user's real access boundary.
- Dismissing it as a "one-off glitch" ignores the root cause: the paralegal's permissions are misconfigured.
- This leaves the breach open, unaudited, and undocumented—exposing the organization to unacknowledged data confidentiality risk.
- If this later comes to light via audit or discovery, the organization's response time and evidence trail will be questioned.

---

### ❌ WRONG #2: Tell the Paralegal to Ignore It / "Just Don't Open It Again"
**Why this is dangerously wrong:**
- The paralegal's access to the document is **already granted at the file-system level**, independent of Copilot. If she searches or navigates directly in SharePoint/DMS, she will still see it.
- Telling her to ignore it does not fix the permissions; it only hides the symptom from organizational awareness.
- She could accidentally access and share the restricted matter (creating a new breach vector), or intentionally access it (if not properly warned it is outside her role). Either way, it is a liability if the organization knowingly allowed the access without remediation.
- If she later faces a compliance or ethical inquiry about why she accessed the matter, the organization's non-response looks negligent.

---

### ❌ WRONG #3: Delete, Move, or Edit the Matter; Wipe Copilot Chat History
**Why this is dangerously wrong:**
- **Destroys evidence:** Deleting or modifying the document destroys the audit trail showing what was exposed and to whom. Compliance and legal discovery require an intact, time-stamped record.
- **Covers up the breach:** In litigation or regulatory investigation, evidence tampering is worse than the original data incident. It creates separate liability (obstruction, spoliation).
- **Wiping Copilot chat history:** The chat log is an audit record showing exactly when the data was surfaced, what the user searched for, and what was returned. This is critical evidence for scope (how many sessions? other users?) and legal holds.
- **Damages investigation:** The permissions failure is still present; obscuring evidence does not fix it.

---

### ❌ WRONG #4: Make Broad Permission Changes Before Scoping Who Else Is Affected
**Why this is dangerously wrong:**
- If you revoke the paralegal's access immediately without understanding why it was granted, you risk:
  - Disrupting her actual work (she may have legitimate access to 99% of what she's now blocked from).
  - Creating a false remediation story ("we fixed it") when the root cause is still present.
  - Affecting other users if the over-provisioning is systemic (you fix one person; the problem spreads to others).
- **Correct approach:** Understand the root cause first (DMS rollout? Azure AD group sync? Legacy permission inheritance?). Then remediate systematically for all affected users, not reactively for one.

---

### ❌ WRONG #5: Handle It Purely as a Helpdesk / Desktop Support Ticket
**Why this is dangerously wrong:**
- This is not a technical support issue; it is a **data governance and legal compliance incident**.
- A helpdesk ticket has no visibility to Security, Data Protection, Legal, or Compliance. The incident remains unlogged, unescalated, and unaudited.
- If the organization later discovers unauthorized access to legal matters, and the security/legal teams never knew about the Copilot report, the incident response timeline will be indefensible.
- Correct owners are: Information Security, Data Protection Officer (DPO), Legal/Compliance counsel—not Desktop Support.

---

## 3. PRESERVE & SCOPE — Evidence Capture and Blast Radius Assessment (Read-Only First)

### Phase 1: Immediate Evidence Preservation (Do Not Alter)

**Step 1A: Preserve Copilot Interaction Log (READ-ONLY)**
- **What to capture:** The Copilot conversation thread in which the client matter was surfaced.
  - Exact search query or prompt the user submitted.
  - Exact document/matter name, file path, or metadata returned by Copilot.
  - Timestamp of the interaction.
  - Any follow-up interactions (did the user open the document? Copy content?).
- **Where:** Microsoft 365 Copilot activity logs (Microsoft 365 admin portal → Reports → Copilot → User interactions, or Copilot chat history in Teams/Word/Outlook).
- **Why:** Audit trail showing what was exposed, when, and whether the exposure continued.
- **Non-destructive:** Read-only query of admin logs; no changes to Copilot history.

**Step 1B: Preserve Document Permissions & Sharing History (READ-ONLY)**
- **What to capture:** The client matter document's current and historical permissions.
  - Current ACL (who has read/edit/owner access).
  - Sharing history: who shared it with whom, when, and what level of access was granted.
  - Permission inheritance settings (inherits from parent folder? or explicitly set?).
  - Recent permission changes in the last 7 days (overlapping with DMS rollout window).
- **Where:** SharePoint/OneDrive admin center → Document details → Sharing & permissions → Audit history (if available); or DMS admin console (if DMS controls permissions).
- **Why:** Determines whether the paralegal was granted access explicitly (intentional misconfiguration) or inherited it unintentionally (permissions leak during migration/rollout).
- **Non-destructive:** Read-only audit; no changes to permissions.

**Step 1C: Preserve Paralegal's Permission Trail (READ-ONLY)**
- **What to capture:** Her current access scope and recent changes.
  - Azure AD group memberships (which groups is she a member of?).
  - Group membership changes in the last 7 days (overlapping with Win11 migration + DMS rollout).
  - SharePoint sites/libraries she can access and why.
  - DMS role/permission tier.
  - Recent access/sign-in activity to SharePoint, OneDrive, Copilot.
- **Where:** Azure AD / Entra ID admin center → Users → Group memberships + Change history; SharePoint admin → User permissions audit.
- **Why:** Traces how she acquired the over-broad permissions (group membership sync error? role misconfiguration? inheritance issue?).
- **Non-destructive:** Read-only audit queries.

---

### Phase 2: Blast Radius Assessment (Read-Only, No Changes)

**Step 2A: Scope All Legal Users Against This Client Matter**
- **Query:** Which users/groups have access to this client matter document?
  - List all users/groups in the document's ACL.
  - For each group, enumerate membership.
  - Flag which users have access but should NOT (based on their stated role).
- **Why:** Determines if this is a single-user anomaly or a systemic over-sharing issue affecting multiple users.
- **Non-destructive:** Read-only permission audit.

**Step 2B: Scope the Paralegal's Other Access Anomalies**
- **Query:** Does the paralegal have access to OTHER client matters she should not see?
  - Run a permissions audit across all legal matter documents in SharePoint/DMS.
  - Flag documents where her access is not aligned with her role.
- **Why:** Single document breach suggests possible deeper pattern (group over-provisioning, inheritance misconfiguration affecting her entire role tier).
- **Non-destructive:** Read-only permission audit.

**Step 2C: Scope the DMS Rollout Impact**
- **Query:** Did the Friday DMS rollout change permission inheritance, group membership, or access control for any Legal users?
  - Check DMS deployment logs for permission/RBAC changes.
  - Compare Legal users' permission scope before/after DMS rollout (if versioning available).
  - Check if DMS installer modified SharePoint group membership or permission inheritance settings.
- **Why:** Friday DMS rollout is the likely common cause; understanding its permission impact determines remediation scope.
- **Non-destructive:** Read-only deployment and audit logs.

**Step 2D: Assess Microsoft 365 Audit Log Coverage**
- **Query:** Are Microsoft 365 audit logs enabled and capturing:
  - File access events (SharePoint/OneDrive).
  - Permission changes.
  - Group membership changes.
  - Copilot interactions.
- **Why:** Determines how much audit trail is available for investigation and remediation validation.
- **Non-destructive:** Read-only audit configuration check.

---

### Phase 3: Documentation (Before Any Remediation)

**Step 3A: Create Incident Record**
- Document:
  - Paralegal name and user ID.
  - Client matter name, document ID, SharePoint site/DMS location.
  - Date/time Copilot surfaced it.
  - Current permissions (who can access, why they have access).
  - Screenshots of Copilot chat, document ACL, user group membership (for evidence preservation).
  - Hypothesis: root cause (DMS rollout? Group sync? Inheritance?).
- **Non-destructive:** Administrative documentation; no system changes.

---

## 4. ESCALATION STATEMENT

**Route to:** Chief Information Security Officer (CISO) / Information Security team + Data Protection Officer (DPO) / Compliance owner

---

### **ESCALATION MESSAGE (Exactly 2 Sentences)**

**Sentence 1 (Observation & Potential Risk):**
A Legal department paralegal reported that Copilot surfaced a confidential client matter to which she stated she has no assigned access; cross-reference of her account permissions and the document's ACL confirms she holds read access, indicating a potential breach of attorney-client privilege and data confidentiality controls, likely introduced by Friday's DMS deployment or the Win11 migration's permission re-inheritance.

**Sentence 2 (Action & Timeline):**
Please initiate a read-only audit of the affected document's permissions history, the paralegal's group memberships and recent access changes, and the DMS rollout's impact on Legal department permission scope, with findings and remediation recommendation within 24 hours; separately, preserve all Copilot interaction logs and Microsoft 365 audit trails related to this matter pending legal hold determination.

---

## 5. SUPPORTING CONTEXT FOR ESCALATION

### Why This Escalation Is Framed This Way

**Sentence 1 Includes:**
- The factual observation (Copilot surfaced; paralegal reported undisclosed access).
- The confirmation that this is a real permissions issue, not hallucination (ACL confirms access).
- The legal/compliance risk (attorney-client privilege, data confidentiality).
- The likely root cause (DMS deployment, Win11 migration).
- **No speculation as fact** ("likely introduced" = hypothesis based on timing, not unproven claim).

**Sentence 2 Includes:**
- Clear, actionable next steps (audit, findings, remediation recommendation).
- Timeline (24 hours = urgent but not panicked).
- Evidence preservation requirement (audit logs, legal hold).
- Assignment (escalated to appropriate team: CISO/DPO, not helpdesk).

### Why This Routing

**CISO / Information Security:**
- Owns data access controls and breach response.
- Has authority to escalate to Legal counsel and initiate incident response.
- Has access to Microsoft 365 audit logs and SharePoint permission audits.

**DPO / Compliance Owner:**
- Owns legal compliance and regulatory obligations.
- Can advise on reportability (is this a breach? Does GDPR/other regulation apply?).
- Coordinates with Legal counsel on privilege and attorney-client confidentiality.

---

## 6. WHAT HAPPENS NEXT (Post-Escalation)

### Immediate (2–4 Hours)
1. Security team confirms Copilot interaction logs are preserved (legal hold placed on all related Copilot, SharePoint, and audit logs).
2. Permission audit begins (Steps 2A–2D above).
3. Paralegal is briefed (by appropriate manager/Legal) on the anomaly and asked to take no further action on the document pending investigation.

### Near-Term (24 Hours)
1. Audit findings returned with:
   - Root cause confirmation (DMS rollout? Group sync? Inheritance?).
   - Blast radius (how many users? how many documents?).
   - Remediation recommendation (revoke access? fix group membership? audit other floors?).
2. DPO advises on reportability (internal incident? Regulatory notification required?).
3. Decision: is remediation localized (one user, one document) or systemic (all Legal users, all DMS documents)?

### Longer-Term (3–7 Days)
1. Remediation applied (permissions revoked, groups corrected, DMS rollout reviewed).
2. Verification audit (confirm paralegal and other affected users no longer see undisclosed content).
3. Post-incident review (why did this happen? DMS vendor response? Win11 migration re-permissioning review?).

---

**Document prepared by:** DWP Senior Security Analyst  
**Document date:** 2026-08-14  
**Classification:** Internal — Security Incident Report  
**Version:** 1.0
