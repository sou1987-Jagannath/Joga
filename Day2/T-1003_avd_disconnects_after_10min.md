Summary: AVD session disconnects after approximately 10 minutes and then reconnects.

Impact:
- Affected user(s): 1 known user; to-verify if other users in the same host pool are affected.
- Service impact: Session instability interrupts work and may cause data-entry disruption.
- Business urgency: High for user productivity and session reliability; to-verify if this is a wider service issue.

Known facts:
- Ticket ID: T-1003.
- Platform: Azure Virtual Desktop (AVD).
- Reported issue: Session disconnects after about 10 minutes.
- Behavior: Session reconnects afterward.

Missing information to gather:
- Host pool name, session host name, and affected user account.
- Whether disconnect occurs during active use, idle time, or both (to-verify).
- Approximate timestamps of recent disconnect/reconnect events.
- Network context (office/home VPN/wired/wifi) and whether issue persists across networks (to-verify).
- Whether behavior is limited to one user, one host, or multiple hosts.
- Client type/version (Remote Desktop client/web) and local endpoint OS details.
- Any recent policy or host image changes (to-verify).

Likely category:
- AVD - Session Reliability / Connectivity (to-verify).

First diagnostic step:
- Pull AVD connection diagnostics for the affected user/session around the 10-minute drop window and correlate with session host and client network events.