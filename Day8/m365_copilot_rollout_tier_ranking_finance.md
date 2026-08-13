# Microsoft 365 Copilot Rollout — Tiered Readiness Ranking
**Organisation:** Financial Services  
**Department:** Finance (~200 users)  
**Prepared by:** DWP Engineer  
**Date:** 2026-08-12  
**Reference document:** `m365_copilot_readiness_checklist_finance.md`

---

## Why This Ranking Exists

Not all readiness items carry equal risk. This document ranks every checklist item across three tiers to give the project team a clear sequencing model — what must be done, what should be done, and what can follow post-launch without blocking go-live. Tier assignment is based on **consequence of failure in this specific Finance context**, not on technical complexity.

---

## Tier Definitions

| Tier | Label | Meaning |
|---|---|---|
| **MUST** | Blocking — do not roll out until complete | Failure creates an immediate, material risk: data breach, regulatory breach, or Copilot technically non-functional |
| **SHOULD** | High risk if skipped | Failure significantly degrades security posture or user experience; should be complete before go-live but a documented exception with mitigations is acceptable in limited cases |
| **CAN** | Lower risk — can complete during or after rollout | Failure has manageable consequences; can proceed in parallel with live Copilot usage |

---

## TIER 1 — MUST Complete Before Rollout (Blocking)

### From Section 1 — Permissions & Oversharing Remediation

| # | Item | Why It Is Blocking |
|---|---|---|
| 1.1a | Remove "Everyone" / "Everyone except external users" / "All Company" from all Finance SharePoint sites | Copilot will surface content to any user who has access. Broad group membership means payroll or M&A data could be returned in Copilot responses to users with no legitimate need. No technical safeguard overrides this once Copilot is live. |
| 1.1b | Identify and remove broken permission inheritance from the 2019 migration | Undocumented unique permissions are the highest-probability source of accidental overexposure. These cannot be assessed without explicit audit — they are invisible in normal site navigation. |
| 1.1c | Restrict payroll libraries to HR, Finance leadership, and Payroll team only | Payroll data is the single highest-sensitivity dataset in the department. Any oversharing here is a direct UK GDPR Article 5 breach risk (data minimisation) and an employment law confidentiality risk. |
| 1.1d | Restrict board pack libraries to ExCo/Board and designated Finance leads | Board packs contain price-sensitive information. Broad internal access creates insider trading risk under MAR (Market Abuse Regulation). Copilot summarising a board pack to an ineligible user is a regulatory event, not just an IT incident. |
| 1.1e | Restrict M&A libraries to deal-team members with a documented access list | M&A data is among the most legally sensitive content a financial services firm holds. Accidental disclosure via Copilot could constitute a breach of confidentiality obligations, NDA terms, or FCA notification thresholds. |
| 1.1f | Section 1 sign-off from Finance Director and CISO | Without formal data owner and security sign-off, the IT team has no mandate to proceed. If an incident occurs post-rollout without this gate, accountability is unclear and regulatory defence is weakened. |
| 1.2a | Disable "Anyone with the link" sharing for Finance OneDrive | Copilot can reference and summarise shared files. Anonymous links in a Finance context represent an uncontrolled external disclosure channel. |
| 1.2b | Review and revoke "People in Organisation" links on payroll/M&A/board content | Same principle as above — Copilot does not distinguish between a link shared for a business purpose and one shared accidentally. Scope is the only control. |
| 1.3b | Run SharePoint Advanced Management DAG reports before go-live | This is the mechanism that makes the above items auditable at scale. Without it, the audit is manual, incomplete, and unverifiable. |

### From Section 4 — Identity & MFA

| # | Item | Why It Is Blocking |
|---|---|---|
| 4.2 | MFA enforced for all Finance users | Copilot operates on the authenticated user's identity and access token. An account without MFA is trivially compromised; a compromised account with a Copilot licence becomes a high-value exfiltration vector across all Finance content. |
| 4.3 | Finance users not excluded from Conditional Access MFA policies | Exclusions are the most common MFA gap in mature tenants. An excluded Finance account is a worse risk than no MFA policy at all, because it creates a false assurance. |
| 4.4 | Legacy authentication blocked for Finance users | Legacy auth bypasses MFA entirely. If any Finance user authenticates via legacy protocols, the MFA control is nullified for that account. |
| 4.5 | All Finance accounts have a registered MFA method | A policy without registered methods fails silently — users cannot authenticate and Copilot cannot function, but more importantly, accounts with no registered method may fall through to weaker auth. Verify completion, not just policy assignment. |

### From Section 2 — Licensing

| # | Item | Why It Is Blocking |
|---|---|---|
| 2.1 | Confirm active M365 E5 licences for all ~200 users | Copilot cannot be assigned without the underlying E5 entitlements. This is a hard technical dependency. |
| 2.3 | Do NOT assign Copilot licences until Section 1 sign-off is complete | This is a process control, not a technical one. Assigning licences before permissions remediation is the exact failure mode that causes data incidents at rollout. Listed here to make the dependency explicit. |

### From Section 5 — Sensitivity Labelling

| # | Item | Why It Is Blocking |
|---|---|---|
| 5.3 | Mandatory labelling enforced for Finance users | Without mandatory labelling, Copilot-generated outputs can leave the environment unlabelled, unencrypted, and untracked. In a Finance context this is not a theoretical risk — staff will copy Copilot summaries into emails or Teams messages. |
| 5.4 | Highly Confidential – Finance label applies encryption | Label-based encryption is the last-resort access control. If permissions are misconfigured and a user gains access to an M&A or payroll document, encryption ensures Copilot cannot read and surface its contents to them. This is the backstop that makes the permissions audit recoverable rather than catastrophic. |

---

## TIER 2 — SHOULD Complete Before Rollout (High Risk if Skipped)

### From Section 1 — Permissions & Oversharing

| # | Item | Risk if Skipped |
|---|---|---|
| 1.1g | Validate client financial data libraries against contractual/regulatory access controls | High — contractual breach risk with clients. Spot-check of 10 sites is the minimum; full audit is preferable but acceptable as a post-launch tracked action if contractual review confirms no "Anyone" links exist. |
| 1.3a | Restrict Finance restricted sites from org-wide Search scope | Copilot uses the same index as Search. Overshared content surfaced via Search is the same risk via Copilot. Should be in place before launch; can be mitigated short-term by label-based encryption if delayed. |
| 1.3c | Review SharePoint Hub Site permission inheritance | Hub associations can silently expand access scope. Risk is high but requires hub architecture review which may take longer — acceptable with a documented exception if items 1.1a–1.1f are complete. |

### From Section 3 — M365 Apps Client Versions

| # | Item | Risk if Skipped |
|---|---|---|
| 3.1 | All Finance endpoints on Current Channel / Monthly Enterprise Channel at minimum build | Copilot will not function on older builds — but the consequence is user-facing failure rather than a data risk. High priority for adoption, acceptable as a phased rollout dependency rather than an all-or-nothing blocker if most devices are compliant. |
| 3.2 | Devices on Semi-Annual Channel identified and updated | Same as above. Devices not meeting minimum build are simply excluded from Copilot functionality — no security consequence, but significant adoption impact. |
| 3.5 | Verify Outlook meets Copilot support requirements | Outlook is a primary Copilot surface. Non-compliant Outlook means a core use case is unavailable at launch. High nuisance risk; not a data risk. |

### From Section 4 — Identity

| # | Item | Risk if Skipped |
|---|---|---|
| 4.6 | Identify and document shared/generic Finance accounts | Shared accounts create audit trail gaps and Copilot licence waste. Should be resolved before go-live; acceptable with documented exceptions where the business case is approved and the account is excluded from Copilot assignment. |

### From Section 5 — Sensitivity Labelling

| # | Item | Risk if Skipped |
|---|---|---|
| 5.1 | Sensitivity labels deployed and labelling policy published to Finance | Technically a MUST for items 5.3 and 5.4 — but listed here separately for teams where label taxonomy exists but Finance-specific sub-labels are still being approved. Do not proceed without at least a `Confidential` / `Highly Confidential` baseline. |
| 5.2 | Finance-specific sub-label exists in taxonomy | High risk — generic labels may not restrict access correctly or apply the right encryption scope. Acceptable short-term if the broader `Highly Confidential` label applies encryption with Finance group scope. |
| 5.5 | Purview Content Explorer audit of unlabelled Finance files | Important for understanding legacy exposure. Can run in parallel with go-live preparation but results must be reviewed before licences are assigned. |

### From Section 6 — Comms & Enablement

| # | Item | Risk if Skipped |
|---|---|---|
| 6.1 | Finance Copilot Champions designated | Adoption risk without champions, not a data risk. High value for rollout success. |
| 6.2 | Finance leadership briefed and sponsorship confirmed | Without visible leadership sponsorship, adoption stalls and staff may use Copilot in unsanctioned ways without understanding the boundaries. |
| 6.3 | Pre-launch communication sent 5 days before licence assignment | High risk if skipped — Finance staff using Copilot without understanding data handling responsibilities is a behavioural risk even with all technical controls in place. |
| 6.5 | 30-minute Copilot orientation session delivered | Significant adoption and misuse risk if skipped. Staff without prompt guidance are more likely to input sensitive data into prompts inappropriately. |

---

## TIER 3 — CAN Complete During or After Rollout (Lower Risk)

| # | Item | Notes |
|---|---|---|
| 3.3 | Update non-compliant devices below minimum build | Devices that cannot run Copilot are simply excluded; no security consequence. Remediate as a tracked action post-launch. |
| 3.6 | Identify and remediate perpetual Office 2019/2021 users | Small number expected. Exclude from Copilot rollout; plan device refresh separately. |
| 5.6 | Auto-labelling policies activated for Finance SharePoint sites | Simulation mode should run pre-launch; activation can follow once results are reviewed. Low risk to activate post-launch if encryption is already applied to new content via mandatory labelling. |
| 5.7 | Confirm Copilot interaction data is covered by Purview audit retention | Important for compliance posture but does not change day-one data access risk. Complete within 30 days of go-live. |
| 6.4 | Finance-specific Copilot use case guidance published | Adoption enabler. Can be published at launch or shortly after. |
| 6.6 | Acceptable use boundaries communicated | Can be included in the pre-launch comms or issued as a follow-up in week one. |
| 6.7 | Feedback and issue reporting channel established | Should exist at launch but a temporary shared inbox is an acceptable interim measure. |
| 6.8 | 2-week post-launch review scheduled with Finance champions | By definition post-launch. Schedule before go-live, execute after. |
| 2.4 | Licence assignment via Entra ID group confirmed | Good practice governance item. Manual assignment is a valid short-term alternative without meaningful risk increase. |
| 2.5 | Duplicate/conflicting licence checks from 2019 migration | Low probability of blocking Copilot assignment; verify but not a go-live dependency. |
| 4.1 | Confirm all accounts are cloud-only or hybrid-synced | Expected to be correct in an E5 tenant; verification is a sense-check, not a likely blocker. |
| 1.2c | OneDrive content synced from pre-migration network drives reviewed | Broad item that overlaps with the SharePoint audit. Complete for high-sensitivity folders pre-launch; remainder can be a tracked remediation action. |

---

## Why Permissions/Oversharing Is MUST — Not Just "Also Important"

Licensing and client version checks are **technically simpler** to verify and easier to reason about: a licence is either assigned or it is not; a build number either meets the threshold or it does not. They are binary states with deterministic outcomes. If a licence is missing, Copilot does not activate. If a build is too old, the feature does not render. **These failures are self-contained and visible.**

Permissions and oversharing carry a fundamentally different risk profile for the following reasons:

**1. The failure mode is silent and immediate.**
An unlicensed user cannot use Copilot — the harm is zero. An overpermissioned user with a Copilot licence gets accurate, synthesised responses drawn from content they were never meant to see, with no error, no warning, and no audit trail that the access was unintended. The system behaves correctly by design — it is the permissions that are wrong, and Copilot has no way to know that.

**2. The 2019 migration debt is a known, unquantified liability.**
This department's SharePoint permissions were set during a migration seven years ago and have never been reviewed. In that time: staff have joined, left, and changed roles; projects have closed; document libraries have been repurposed. The probability that permission assignments still accurately reflect current need-to-know is very low. Copilot activating on top of this debt does not create new permissions — it creates new, efficient access to content that was already technically accessible but practically obscured by volume. Copilot removes that obscurity.

**3. The data involved has specific legal and regulatory consequences.**
- **Payroll data** — UK GDPR special category adjacent; disclosure to non-authorised staff is a data protection breach reportable to the ICO.
- **M&A documents** — price-sensitive; disclosure to non-deal-team staff is a potential FCA Market Abuse Regulation breach.
- **Board packs** — same MAR exposure; additionally, disclosure to the wrong parties could constitute a breach of directors' duties.
- **Client financial data** — contractual confidentiality obligations with clients; breach could trigger client notification requirements and contractual liability.

None of these risks exist in the licensing or client version tiers. A missing licence delays adoption. An oversharing failure in this specific dataset mix could trigger a regulatory investigation, a contractual dispute, or an employment law claim — in the same week Copilot goes live.

**4. Remediation after the fact is harder than remediation before.**
Removing permissions after Copilot has been live for two weeks means the access has already occurred. Unlike revoking a licence (which is immediate and complete), there is no way to un-surface a Copilot response that was already delivered, no way to confirm what content a user has already seen, and no way to demonstrate to a regulator that the exposure was contained. Pre-launch remediation is the only point at which this risk can be closed cleanly.

**5. Licensing and client version can be completed in parallel — permissions cannot be rushed.**
Licence procurement and build updates can run simultaneously and independently of each other. The permissions audit requires human review, stakeholder decisions about access scope, and formal sign-off from data owners. It is the longest-lead item and the one most likely to uncover decisions that require escalation. It must start first, not last.

---

*Tier assignments should be reviewed with the Information Security team and Finance Data Owner before the project plan is finalised. This ranking reflects the risk profile of this specific department and data context — it is not a generic Microsoft 365 Copilot deployment template.*
