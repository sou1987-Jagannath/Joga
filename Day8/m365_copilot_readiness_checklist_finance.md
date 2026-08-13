# Microsoft 365 Copilot Readiness Checklist — Finance Department
**Organisation:** Financial Services  
**Department:** Finance (~200 users)  
**Prepared by:** DWP Engineer  
**Date:** 2026-08-12  
**Licence baseline:** M365 E5 | Copilot add-on: NOT YET ASSIGNED

---

> **Risk Note:** SharePoint permissions in this department were inherited from a 2019 migration and have never been audited. The Finance department holds payroll data, board packs, M&A documents, and client financial data. Copilot surfaces content users have access to — **overpermissioned content becomes a Copilot disclosure risk on day one of enablement.** Permissions and oversharing remediation MUST be completed and signed off before any Copilot licence is assigned.

---

## SECTION 1 — Permissions & Oversharing Remediation
### ⚠️ HIGHEST PRIORITY — Do not proceed to Section 2 until all items here are complete

### 1.1 SharePoint Site & Library Audit
- [ ] Generate a full permissions report for all SharePoint sites used by Finance (use Microsoft 365 SharePoint Admin Centre > Active Sites > Export, or run `Get-SPOSiteGroup` / `Get-SPOUser` via PnP PowerShell)
- [ ] Identify all sites where Finance data resides that have **"Everyone"**, **"Everyone except external users"**, or **"All Company"** in any permission group — remove immediately
- [ ] Review and remove any **broken inheritance** left over from the 2019 migration (sites/libraries/folders with unique permissions that were never documented)
- [ ] Confirm no Finance SharePoint site is accessible to users outside the Finance department without explicit documented business justification
- [ ] Validate that **payroll libraries** are restricted to HR, Finance leadership, and Payroll team only — no broader Finance read access
- [ ] Validate that **board pack libraries** are restricted to ExCo/Board members and designated Finance leads only
- [ ] Validate that **M&A document libraries** are restricted to deal-team members and have a documented access list reviewed by the CISO or General Counsel
- [ ] Validate that **client financial data** libraries comply with contractual and regulatory access controls — spot-check at least 10 sites/libraries

### 1.2 OneDrive Oversharing
- [ ] Run a **Sharing Report** from SharePoint Admin Centre (Reports > Sharing) for Finance users' OneDrive accounts
- [ ] Identify and remediate any files shared via **"Anyone with the link"** links — disable this link type for the Finance OU if not already done
- [ ] Identify files shared with **"People in [Organisation]"** links that contain payroll, M&A, or board-level content — revoke and reissue with specific-person links
- [ ] Review any OneDrive content synced locally from pre-migration network drives that was migrated to OneDrive in 2019 without a permissions review — treat as untrusted until verified

### 1.3 SharePoint Search & Copilot Scope Controls
- [ ] Confirm that **restricted SharePoint sites** (payroll, M&A, board packs) are excluded from organisation-wide search using Search schema restrictions or sensitivity label-based access controls — do not rely on Copilot not surfacing them
- [ ] Enable **SharePoint Advanced Management** (included in M365 E5) and run **Data Access Governance (DAG) reports** to identify overshared files before Copilot go-live
- [ ] Review any **SharePoint Hub Site** associations — confirm Finance hub does not inherit open permissions from a broader corporate hub

### 1.4 Sign-Off Gate
- [ ] Permissions remediation reviewed and approved by: **Finance Director / Data Owner**
- [ ] Permissions remediation reviewed and approved by: **Information Security / CISO**
- [ ] Written sign-off stored in the project record before any Copilot licence assignment proceeds

---

## SECTION 2 — Licensing Prerequisites

- [ ] Confirm all ~200 Finance users have an active **Microsoft 365 E5** licence assigned (verify in Entra ID > Licences or M365 Admin Centre > Billing > Licences)
- [ ] Confirm Microsoft 365 E5 licences include: Exchange Online Plan 2, SharePoint Online Plan 2, Microsoft Teams — these are Copilot dependencies
- [ ] Procure **Microsoft 365 Copilot add-on licences** for the Finance department (~200 seats) — do NOT assign until Section 1 sign-off is complete
- [ ] Confirm licence assignment will be done via a **Finance Entra ID group** (not individually) to enable group-based licence management and easy rollback
- [ ] Verify there are no conflicting or duplicate E3/E5 licences on user accounts from the 2019 migration that may block Copilot assignment

---

## SECTION 3 — Microsoft 365 Apps Client Version Requirements

- [ ] Confirm all Finance endpoints are running **Microsoft 365 Apps (Current Channel or Monthly Enterprise Channel)** — Copilot requires version **16.0.16227** or later (Microsoft 365 Apps for Enterprise)
- [ ] Run an Apps health report from **Microsoft 365 Apps Admin Centre** (config.office.com) to identify any Finance devices running Semi-Annual Channel or older build versions
- [ ] Update any devices below the minimum build — coordinate with endpoint team if managed via Intune or SCCM
- [ ] Confirm **Microsoft Teams** is on a supported version for Copilot in Teams (Teams desktop app version 23225.807 or later — verify via Teams Admin Centre > Devices or Intune device inventory)
- [ ] Confirm **Outlook** (desktop or new Outlook) meets Copilot support requirements — classic Outlook requires Current Channel build; confirm new Outlook is not blocked by policy on Finance devices
- [ ] Verify that no Finance users are on **perpetual Office 2019/2021** — these do not support Copilot; identify exceptions and plan remediation or exclusion from rollout

---

## SECTION 4 — Identity & MFA Readiness

- [ ] Confirm all Finance user accounts are **cloud-only or hybrid-synced** to Entra ID (no on-prem-only accounts that would lack cloud auth)
- [ ] Confirm **Multi-Factor Authentication (MFA)** is enforced for all Finance users — verify via Entra ID > Security > MFA > Per-user MFA status or Conditional Access policy coverage report
- [ ] Confirm Finance users are **not excluded** from any Conditional Access policies that enforce MFA (check CA exclusion groups for Finance accounts)
- [ ] Confirm **Legacy Authentication** is blocked for Finance users — legacy auth bypasses MFA and is a Copilot prerequisite security control
- [ ] Verify all Finance accounts have a registered **MFA method** (Authenticator app preferred; SMS acceptable as fallback) — accounts without a registered method will fail Copilot sign-in
- [ ] Confirm no Finance user accounts are **shared/generic accounts** (e.g. `finance.reporting@company.com` used by multiple staff) — Copilot is per-user and shared accounts create audit and data boundary risks; document any exceptions with business justification

---

## SECTION 5 — Sensitivity Labelling

- [ ] Confirm **Microsoft Purview sensitivity labels** are deployed and a labelling policy is published to Finance users
- [ ] Confirm the label taxonomy includes labels appropriate for Finance data — at minimum: `Confidential`, `Highly Confidential`, and a **Finance-specific sub-label** (e.g. `Highly Confidential – Finance`) for payroll, M&A, and board data
- [ ] Confirm **mandatory labelling** is enforced for Finance users in the labelling policy — users cannot save or send without applying a label
- [ ] Confirm that `Highly Confidential – Finance` label applies **encryption** (via Azure Rights Management) and restricts access to the Finance security group — Copilot will respect label-based encryption and will not surface encrypted content to unlicensed or unauthorised users
- [ ] Audit existing Finance SharePoint sites and OneDrive content for **unlabelled files** — run a Purview Content Explorer report filtered to Finance locations
- [ ] Confirm **auto-labelling policies** are configured (or in simulation mode, reviewed, and ready to activate) for Finance SharePoint sites to catch legacy unlabelled content from the 2019 migration
- [ ] Confirm **Copilot interaction data** (prompts and responses) is covered by the organisation's Purview audit log retention policy — verify Data Lifecycle Management policies include Copilot interaction logs

---

## SECTION 6 — End-User Communications & Enablement

- [ ] Designate **Finance Copilot Champions** (2–3 engaged Finance staff) to act as peer advocates and first-line feedback contacts
- [ ] Brief Finance leadership (CFO / Finance Director) on Copilot capabilities and the data governance steps taken — secure their visible sponsorship for the rollout
- [ ] Send a **pre-launch communication** to all Finance users at least 5 business days before licence assignment — cover: what Copilot is, what it can access, the sensitivity label and data handling responsibilities, and who to contact with concerns
- [ ] Publish **Finance-specific Copilot use case guidance** covering practical scenarios: summarising board packs, drafting budget commentary, meeting recaps for Finance review calls — avoid generic Microsoft collateral; make it Finance-relevant
- [ ] Deliver a **30-minute live or recorded Copilot orientation session** for Finance users covering: how to write effective prompts, what Copilot can and cannot see, how to handle Copilot outputs containing sensitive data
- [ ] Communicate the **acceptable use boundaries** specific to Finance: do not use Copilot to draft communications containing unpublished M&A information, do not share Copilot-generated outputs externally without review, label all Copilot-assisted documents before sharing
- [ ] Establish a **feedback and issue reporting channel** (e.g. a Teams channel or ServiceNow queue) for Finance Copilot queries post-launch
- [ ] Schedule a **2-week post-launch review** with Finance champions and IT to assess adoption, surface any data access concerns flagged by users, and review Copilot audit logs for anomalous queries

---

## Readiness Sign-Off Summary

| Section | Owner | Status | Sign-Off Date |
|---|---|---|---|
| 1 — Permissions & Oversharing Remediation | Information Security / Finance Data Owner | ☐ Not Started | |
| 2 — Licensing Prerequisites | IT Licensing / M365 Admin | ☐ Not Started | |
| 3 — M365 Apps Client Versions | Endpoint / Intune Team | ☐ Not Started | |
| 4 — Identity & MFA | Identity & Access Management | ☐ Not Started | |
| 5 — Sensitivity Labelling | Information Security / Purview Admin | ☐ Not Started | |
| 6 — End-User Comms & Enablement | Change Management / Finance Lead | ☐ Not Started | |

**Overall Go/No-Go Decision:**  
- [ ] All sections complete and signed off  
- [ ] Section 1 (Permissions) formally approved by CISO and Finance Director  
- [ ] Copilot licences approved for assignment  

**Approved by:** ___________________________  **Date:** _______________

---

*This checklist should be reviewed against the latest Microsoft 365 Copilot prerequisites documentation before use, as requirements are subject to change with service updates.*
