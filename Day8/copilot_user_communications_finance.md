# Microsoft 365 Copilot — User Communications
**From:** IT Support / DWP Engineering Team  
**Department:** Finance  
**Date:** 2026-08-12  

---

> These messages are ready to send individually to each affected user. Each one is written in plain English, avoids technical jargon, and tells the user exactly what to do next.

---

## Ticket 1 — Finance Lead: Copilot won't summarise the Q3 Board Pack

**To:** [Finance Lead]  
**Subject:** Copilot and your Q3 Board Pack — what's happening and what to do

Hi [Name],

Thanks for getting in touch. We've looked into why Copilot can't summarise the Q3 board pack and we have a likely explanation.

The file has a security label applied to it that encrypts the content — this is intentional and means the document is protected, even from automated tools like Copilot. You can open it yourself because your account has been granted access to read it directly. Copilot works slightly differently and needs an additional permission to read encrypted files on your behalf, which hasn't been set up for this document yet.

**What happens next:**  
You don't need to do anything. The IT team will check the security settings on the file and confirm whether Copilot can be granted access to it safely. Because board packs contain sensitive information, we need to make sure this is done correctly rather than quickly. We'll come back to you within 2 working days.

In the meantime, you can still open and read the document yourself as normal.

Thanks,  
IT Support

---

## Ticket 2 — New Hire: Copilot doesn't know about recent emails

**To:** [New Hire]  
**Subject:** Copilot in Outlook — why it's quiet right now

Hi [Name],

Welcome to the team! Thanks for flagging this.

What you're seeing is completely normal for a brand-new account. When a new mailbox is created, Microsoft 365 needs a day or two to index all your emails before Copilot can start using them. Think of it like a search engine that needs time to scan your inbox before it can answer questions about it. Your account was only set up yesterday, so Copilot simply hasn't had enough time to catch up yet.

**What happens next:**  
No action needed from you. Please try Copilot again in 24–48 hours and you should find it works as expected, referencing your emails and calendar correctly. If it's still not working by [date 3 working days from now], please reply to this message and we'll investigate further.

Thanks,  
IT Support

---

## Ticket 3 — HR Manager: Copilot says it can't access a salary review spreadsheet

**To:** [HR Manager]  
**Subject:** Copilot and the salary review file — explanation and next steps

Hi [Name],

Thanks for raising this. The message you received — "I don't have access to that content" — is actually Copilot working correctly, not an error.

The salary review spreadsheet has a high-level security label applied to it that encrypts the file. This is a deliberate protection to ensure salary data can't be read by automated tools or shared accidentally. Copilot is respecting that restriction. This is the right behaviour for a file of this sensitivity.

**What happens next:**  
We need to check whether Copilot is supposed to be able to access this file at all, and if so, whether the security settings need to be updated. Because this file contains salary information, any change needs to be reviewed carefully and approved by Information Security before we proceed.

We'll assess this and get back to you within 3 working days. If your request is time-sensitive, please let us know and we'll prioritise accordingly.

Thanks,  
IT Support

---

## Ticket 4 — Sales Rep: Copilot can't find a client contract shared via a link from another company

**To:** [Sales Rep]  
**Subject:** Why Copilot can't find that client contract

Hi [Name],

Thanks for getting in touch. We've found the reason Copilot can't locate this contract, and unfortunately it's a current limitation rather than something we can fix with a setting change.

Copilot can only search content that is stored within our own company's Microsoft 365 environment. The contract you're looking for was shared with you via a link from the client's own system — it lives in their Microsoft 365 account, not ours. Copilot has no way to reach across into another company's environment, even if you have been given a link to access it.

**What you can do:**  
The simplest workaround is to download a copy of the contract and save it to your own OneDrive or a relevant SharePoint folder in our environment. Once it's stored here, Copilot will be able to find and reference it. Please make sure you have permission from the client to store a copy internally, and apply the appropriate sensitivity label when saving it.

If you're unsure which folder to save it to, your line manager or the IT team can advise.

Thanks,  
IT Support

---

## Ticket 5 — IT Admin: Copilot stopped working for the whole Finance team

**To:** [IT Admin]  
**Subject:** Finance team Copilot outage — update

Hi [Name],

Thanks for flagging this promptly. A sudden loss of Copilot across the whole Finance team at the same time is something we're treating as a priority.

Our initial checks are focused on two things: whether the Copilot licences for Finance users are still correctly assigned, and whether Microsoft has reported any service issues on their end. Either of these could explain a whole-team failure that appeared overnight.

**What we're doing:**  
We're checking the licence assignments in the admin centre and reviewing the Microsoft 365 Service Health dashboard right now. We'll update you as soon as we have a finding, and aim to have an initial diagnosis within 2 hours.

If you have already checked service health your end and found something, please reply with the details — it will help us move faster.

We'll keep you posted.

Thanks,  
IT Support

---

## Ticket 6 — Manager: Copilot surfaced a file from a folder you didn't realise you had access to

**To:** [Manager]  
**Subject:** About the file Copilot found — important follow-up

Hi [Name],

Thanks for letting us know about this. It's actually a useful thing to have flagged, and we want to explain what happened and what we're doing about it.

Copilot works by looking across everything you have permission to access in Microsoft 365 — not just files you've recently opened, but any file you could open if you navigated to it. In this case, it found a file in a folder where your account has been given access, possibly going back some time. Copilot did exactly what it's designed to do.

The question this raises is: *should* your account still have access to that folder? Given that the permissions in parts of our SharePoint environment haven't been reviewed since a migration a few years ago, there's a chance some access was granted that was never intended to stay in place permanently.

**What happens next:**  
You don't need to do anything right now. We're logging this with our Information Security team as part of an ongoing permissions review. They may come back to you to confirm whether your access to that folder is still needed. If you believe you shouldn't have access to it, please let us know and we'll arrange for it to be removed.

Thank you for raising this — it's exactly the kind of thing that helps us keep our data environment secure.

Thanks,  
IT Support

---

## Ticket 7 — Analyst: Copilot gives generic answers and doesn't use internal content

**To:** [Analyst]  
**Subject:** Copilot not using your SharePoint content — we're looking into it

Hi [Name],

Thanks for getting in touch. What you're describing — Copilot giving general answers rather than ones based on our internal documents — suggests it may not be connecting to your SharePoint content properly. We want to get this sorted for you.

Before we dig deeper, we'd like to do a quick test to help narrow down the cause.

**What we'd like you to try:**  
Open the search bar at the top of the SharePoint homepage (or go to Office.com and use the search bar there) and search for a document you know exists internally — something you've worked on recently. Let us know whether it appears in those search results.

- If the document **does** appear in search but Copilot still can't use it, that tells us something specific about how Copilot is configured for your account.  
- If the document **doesn't** appear in search either, the issue is broader and we'll need to look at your account setup.

Please reply with what you find and we'll take it from there. This should only take a couple of minutes.

Thanks,  
IT Support

---

## Ticket 8 — Executive Assistant: Copilot can't see the director's shared mailbox calendar

**To:** [Executive Assistant]  
**Subject:** Copilot and the shared calendar — what's possible right now

Hi [Name],

Thanks for raising this. We've looked into it and want to give you an honest explanation of where things stand.

Copilot in Outlook currently works with your own mailbox and calendar — the one signed in as you. When you access the director's calendar through a shared mailbox, you're accessing it as a delegate, which is a different type of access. At the moment, Copilot isn't able to read calendars that you access this way on someone else's behalf. This is a current limitation of how Copilot works, and not something we can change with a configuration update right now.

**What you can do in the meantime:**  
The most practical workaround is to ask the director to forward key meeting invites directly to your inbox. Once those invites are in your own calendar, Copilot will be able to see them and help you prepare, schedule around them, or draft related communications.

We know this isn't the full solution you were hoping for. Microsoft is continuing to develop Copilot's capability around delegated and shared mailboxes, and we'll let you know if this changes.

If you'd like help setting up the forwarding arrangement with the director, please let us know and we can assist.

Thanks,  
IT Support
