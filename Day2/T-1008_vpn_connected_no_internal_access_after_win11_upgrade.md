Summary: VPN connects but internal resources are unreachable after Windows 11 upgrade.

Impact:
- Affected user(s): 1 known user; to-verify if this affects additional upgraded users.
- Service impact: Remote access to internal systems is effectively unavailable despite VPN connection.
- Business urgency: High for remote work continuity and access to business services.

Known facts:
- Ticket ID: T-1008.
- Reported behavior: VPN shows connected state.
- Reported symptom: No internal resources reachable.
- Context: After Windows 11 upgrade.

Missing information to gather:
- VPN client name/version and profile used.
- Which internal resources fail (DNS names, IP targets, specific apps).
- Whether failures occur for all internal resources or a subset (to-verify).
- IP configuration, DNS servers, and route table while VPN is connected.
- Whether internal access works by IP but not hostname (to-verify).
- Any firewall or endpoint security policy changes post-upgrade (to-verify).
- Whether same user can access internally from another device/network.

Likely category:
- Network Access - VPN Routing/DNS Post-Win11 Upgrade (to-verify).

First diagnostic step:
- While VPN is connected, capture IP/DNS/route state and test internal DNS resolution plus direct IP reachability to identify whether the break is DNS, routing, or policy related.