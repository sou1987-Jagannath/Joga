Summary: Finance user cannot open a shared mailbox after migration.

Impact:
- Affected user(s): 1 known finance user; to-verify if additional users of the same shared mailbox are affected.
- Service impact: User cannot access shared mailbox content needed for team mail handling.
- Business urgency: High for finance operations continuity; to-verify exact business deadlines impacted.

Known facts:
- Ticket ID: T-1002.
- Affected persona: Finance user.
- Reported issue: Shared mailbox cannot be opened.
- Context: Issue observed after migration.

Missing information to gather:
- Shared mailbox address/name and impacted user UPN.
- Whether access fails in Outlook, OWA, or both.
- Exact error message text/screenshot at open attempt (to-verify).
- Whether user had confirmed access before migration cutover.
- Mailbox permission status (Full Access/Send As) after migration (to-verify).
- Whether other delegated users can open the same shared mailbox.
- Outlook profile/cache state and whether issue reproduces in a fresh profile (to-verify).

Likely category:
- M365 Exchange Online - Shared Mailbox Access / Post-migration permissions (to-verify).

First diagnostic step:
- Validate shared mailbox existence and current delegate permissions for the affected user, then test mailbox access via OWA to separate client-profile issues from mailbox/permission issues.