# Copilot Support Ticket Triage — Finance Department
**Prepared by:** DWP Engineer  
**Date:** 2026-08-12  
**Triage principle:** Default to non-Copilot causes. "Genuine Copilot fault" is last resort only — ranked after all plausible platform, permissions, and configuration causes are eliminated.

---

## Ticket 1
**Reporter:** Finance lead  
**Issue:** Copilot won't summarise the Q3 board pack in SharePoint. *"It's right there, I can see it myself."*

**Likely Cause (ranked, most probable first)**
1. **Sensitivity label restriction** — Board packs in this department are expected to carry a `Highly Confidential – Finance` label with RMS encryption. Copilot cannot read encrypted content unless the label explicitly grants the Copilot service access. The user can open it because they hold the decrypt right personally; Copilot does not inherit that right.
2. **Permissions/access boundary** — Less likely given the user can see the file, but worth checking if the file was recently moved to a different library with unique permissions that the SharePoint Search crawler has not fully resolved.
3. **Data indexing lag** — If the document was uploaded or modified recently, it may not yet be fully indexed for Copilot retrieval.
4. **Genuine Copilot fault** — No evidence for this.

**Fastest Check**  
Open the file in SharePoint and inspect the sensitivity label in the ribbon (Word/Excel) or the file details panel. If a `Confidential` or `Highly Confidential` label with encryption is present, that is the cause — the fix is to confirm whether Copilot is configured as an authorised service in the label's protection settings.

**Is This Actually a Copilot Bug?**  
**No.** Copilot respecting encryption applied by a sensitivity label is the correct and intended behaviour. This is a label configuration question, not a product defect.

---

## Ticket 2
**Reporter:** New hire (started yesterday)  
**Issue:** Copilot in Outlook seems to know nothing about my recent emails.

**Likely Cause (ranked, most probable first)**
1. **Data indexing lag** — Microsoft 365 indexing for a newly provisioned mailbox typically takes 24–72 hours before Copilot has sufficient content to reason over. A one-day-old mailbox with a small number of emails is the textbook scenario for this behaviour.
2. **Licence/client prerequisite issue** — The Copilot licence may have been assigned but the underlying Exchange Online mailbox may not yet be fully provisioned or attached to the user's Entra ID identity if there was any provisioning delay.
3. **Genuine Copilot fault** — No evidence for this.

**Fastest Check**  
Confirm in M365 Admin Centre that the Copilot licence is assigned and that Exchange Online shows the mailbox as active. Then check the account creation timestamp — if the account is less than 48 hours old, advise the user to wait and re-test.

**Is This Actually a Copilot Bug?**  
**No.** New mailbox indexing lag is a documented and expected platform behaviour. Copilot cannot summarise content that has not yet been indexed.

---

## Ticket 3
**Reporter:** HR manager  
**Issue:** Asked Copilot in Word to pull data from a sensitive salary review spreadsheet. Response: *"I don't have access to that content."*

**Likely Cause (ranked, most probable first)**
1. **Sensitivity label restriction** — The explicit "I don't have access to that content" message is the standard Copilot response when a file is encrypted by a sensitivity label and the service cannot decrypt it. A salary review spreadsheet in a Finance department is exactly the type of file expected to carry a `Highly Confidential` label with encryption scoped to a specific security group.
2. **Permissions/access boundary** — If the file sits in a library where the HR manager has read access but the file itself has broken inheritance with unique permissions (plausible given the 2019 migration), Copilot may be resolving permissions differently to the user's browser session.
3. **Genuine Copilot fault** — No evidence. The response message is specific and diagnostic, not a generic error.

**Fastest Check**  
Check the sensitivity label on the spreadsheet directly. If encrypted, verify whether the HR manager's account is in the label's authorised user scope — it is possible they have SharePoint read access to the file but do not hold the RMS decrypt right, which would produce exactly this behaviour.

**Is This Actually a Copilot Bug?**  
**No.** Copilot is working as designed. Returning "I don't have access" when encountering encrypted content it cannot read is the correct security behaviour. This is a label access scope question.

---

## Ticket 4
**Reporter:** Sales rep  
**Issue:** Copilot in Teams can't find a client contract that was shared with her via a guest link from another organisation.

**Likely Cause (ranked, most probable first)**
1. **Guest/external sharing limitation** — Copilot only indexes and retrieves content from the user's home tenant. A file shared via a guest link from another organisation's SharePoint lives in that external tenant. Copilot has no index access to a foreign tenant, regardless of the user's guest permissions. This is by design.
2. **Permissions/access boundary** — If the contract was supposed to have been copied into the home tenant but hasn't been, the user may believe it is accessible locally when it is not.
3. **Genuine Copilot fault** — No evidence.

**Fastest Check**  
Ask the user to confirm where the contract actually lives — open the sharing link and check the URL domain. If the URL contains a different organisation's SharePoint domain (e.g. `clientcompany.sharepoint.com`), the content is in the external tenant and Copilot cannot access it. This is not fixable — the contract would need to be downloaded and stored in the home tenant.

**Is This Actually a Copilot Bug?**  
**No.** Cross-tenant content access via guest links is an explicitly documented Copilot limitation. Copilot is scoped to the user's home tenant Microsoft 365 index.

---

## Ticket 5
**Reporter:** IT admin  
**Issue:** Copilot suddenly stopped working for the whole Finance team this morning — was fine yesterday.

**Likely Cause (ranked, most probable first)**
1. **Licence/client prerequisite issue** — A whole-team, sudden failure that was working the previous day is the signature pattern of a licence assignment change: a group-based licence assignment modified or revoked, a licence subscription lapsed, or an Entra ID group membership change that removed Finance users from the Copilot-licensed group. This is the most common cause of simultaneous failure across a cohort.
2. **Genuine Copilot fault / service outage** — A Microsoft-side service degradation affecting a single tenant or region is possible and would produce the same symptom. This is the one scenario where a platform issue moves up the ranking — but it should still be checked after licences.
3. **Permissions/access boundary** — Unlikely to cause total failure across all features simultaneously.

**Fastest Check**  
Check M365 Admin Centre > Billing > Licences to confirm Copilot licences are still assigned to the Finance group. Simultaneously check the **Microsoft 365 Service Health dashboard** (Admin Centre > Health > Service Health) for any active Copilot incidents. Run both checks in parallel — whichever returns a finding first is likely the cause.

**Is This Actually a Copilot Bug?**  
**Unclear.** A service-side incident cannot be ruled out for a simultaneous whole-team failure. However, licence revocation is more common and faster to verify. Confirm service health before escalating to Microsoft as a product fault.

---

## Ticket 6
**Reporter:** Manager  
**Issue:** Copilot found and summarised a file the manager doesn't remember ever opening, from a folder they forgot they had access to.

**Likely Cause (ranked, most probable first)**
1. **Permissions/access boundary** — This is not a fault. Copilot surfaces content the user has permission to access — not just recently viewed files. The user has legitimate (if forgotten) permissions to that folder. Copilot has made a previously obscure permission visible. This is the oversharing risk the readiness checklist was designed to prevent.
2. **Genuine Copilot fault** — No evidence. Copilot returning content a user has access to is correct behaviour by definition.

**Fastest Check**  
Verify the manager's permissions on the folder in SharePoint. If they have access (even via a broad group from the 2019 migration), Copilot retrieving that content is correct. The question to raise is: *should* they have access to that folder? If not, this is a permissions remediation item, not a support ticket.

**Is This Actually a Copilot Bug?**  
**No.** This ticket is a permissions governance finding, not a product defect. Copilot is functioning correctly — it is the access model that needs attention. Escalate to the Information Security team and log against the outstanding SharePoint permissions audit. This is precisely the disclosure risk that motivated the MUST-tier permissions remediation in the readiness checklist.

> **Action required:** Log this as evidence for the permissions audit. Identify which group grants the manager access to this folder and assess whether that group membership is still appropriate.

---

## Ticket 7
**Reporter:** Analyst  
**Issue:** Copilot gives generic answers and doesn't seem to use any internal SharePoint content.

**Likely Cause (ranked, most probable first)**
1. **Licence/client prerequisite issue** — If the analyst's Copilot licence was assigned but the Microsoft 365 Apps client is below the minimum supported build, or if the Microsoft Search connector for SharePoint is not enabled for their account, Copilot will fall back to web-grounded or generic responses and silently fail to retrieve internal content.
2. **Permissions/access boundary** — If the analyst has been placed in a security group with overly restrictive SharePoint permissions (possible in a post-audit tightening), they may simply not have access to the content they expect Copilot to use — Copilot cannot surface what the user cannot access.
3. **Data indexing lag** — If the analyst is new or their SharePoint access was recently granted, the index may not have caught up.
4. **Genuine Copilot fault** — Possible but should be ruled out after the above.

**Fastest Check**  
Ask the analyst to search for a known internal SharePoint document directly via Microsoft Search (search bar in SharePoint or Office.com). If that search also returns no internal results, the problem is with the user's Microsoft Search index or permissions — not Copilot specifically. If Search finds the document but Copilot doesn't, the issue narrows to the Copilot integration layer.

**Is This Actually a Copilot Bug?**  
**Unclear.** The symptom is consistent with a configuration or permission issue, but if Search works and Copilot still returns only generic answers, a Copilot-specific configuration fault (e.g. Graph connector misconfiguration, Copilot not associated with the correct tenant index) becomes more plausible. Resolve the Search test first before classifying.

---

## Ticket 8
**Reporter:** Executive assistant  
**Issue:** Copilot in Outlook can't see a shared mailbox's calendar that they manage on behalf of the director.

**Likely Cause (ranked, most probable first)**
1. **Permissions/access boundary** — Copilot in Outlook operates on the signed-in user's primary mailbox identity. Delegate access to a shared mailbox calendar is a different permission model — the EA accesses it via a delegated Exchange permission, not as an Entra ID resource scoped to their account. Copilot does not automatically inherit delegate calendar permissions.
2. **Licence/client prerequisite issue** — Shared mailboxes do not hold individual Copilot licences. If the EA is trying to reference the shared mailbox calendar as if it were their own, Copilot has no index entry for that mailbox's calendar because it is not a licensed user account.
3. **Genuine Copilot fault** — No evidence.

**Fastest Check**  
Check whether the shared mailbox appears as a separate calendar in the EA's Outlook alongside their primary calendar. Then test whether Copilot can reference events from the EA's *own* primary calendar — if it can, the issue is confined to the shared mailbox scope. Confirm with Microsoft documentation whether delegated shared mailbox calendar access is in Copilot's supported scope (as of mid-2026, shared mailbox calendar access via Copilot is limited and requires the mailbox to be licensed or accessed via specific Graph permissions).

**Is This Actually a Copilot Bug?**  
**No.** Shared/delegated mailbox calendar access is a known Copilot scope limitation, not a defect. Advise the EA that Copilot in Outlook currently works against their primary identity's calendar. Workaround: ask the director to forward relevant calendar invites to the EA's primary mailbox so Copilot can reference them.

---

## Triage Summary Table

| Ticket | Reporter | Primary Cause | Copilot Bug? |
|---|---|---|---|
| 1 | Finance lead — board pack | Sensitivity label restriction (encryption) | No |
| 2 | New hire — no email context | Data indexing lag (new mailbox) | No |
| 3 | HR manager — salary spreadsheet | Sensitivity label restriction (encryption) | No |
| 4 | Sales rep — guest link contract | Guest/external sharing limitation | No |
| 5 | IT admin — whole team outage | Licence assignment change / service outage | Unclear |
| 6 | Manager — unknown file surfaced | Permissions/access boundary (oversharing) | No — governance finding |
| 7 | Analyst — generic answers only | Licence/client prerequisite or permissions | Unclear |
| 8 | EA — shared mailbox calendar | Permissions/access boundary (delegate scope) | No |

**Pattern across this ticket set:** Six of eight tickets are explained by permissions, label, or licence causes. Zero tickets have confirmed Copilot product faults. Ticket 6 should be escalated to the Information Security team as a permissions audit finding, not closed as a support ticket.
