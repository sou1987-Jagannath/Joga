Summary: OneDrive is stuck on "processing changes" since migration and files are missing locally.

Impact:
- Affected user(s): 1 known user; to-verify if additional migrated users show the same sync issue.
- Service impact: Local file availability is reduced and user confidence in data sync is impacted.
- Business urgency: High due to potential data access risk and workflow disruption.

Known facts:
- Ticket ID: T-1007.
- Application: OneDrive.
- Reported issue: Status stuck on "processing changes".
- Additional symptom: Files are missing locally.
- Context: Since migration.

Missing information to gather:
- Whether missing files are present in OneDrive web (critical data-presence check).
- Which folders/files are missing locally and approximate volume.
- OneDrive client version and account sign-in state.
- Available local disk space and Files On-Demand settings (to-verify).
- Whether sync issue started immediately post-migration or later (to-verify).
- Any sync conflict messages or specific file-type/path anomalies (to-verify).
- Whether issue reproduces on another device signed in as same user (to-verify).

Likely category:
- M365 OneDrive - Sync / Post-migration File Availability (to-verify).

First diagnostic step:
- Confirm data presence in OneDrive web first, then review local OneDrive sync health/status for the affected account before resetting or re-syncing.