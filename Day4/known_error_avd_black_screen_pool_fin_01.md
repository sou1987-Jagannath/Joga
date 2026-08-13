Symptom: Users can sign in to AVD and then see a black screen; for some users it clears after about 30 seconds, while others are disconnected and reconnect repeatedly. On affected hosts, the session may show successful logon followed by immediate disconnect.

Cause: Verified root cause is a display stack regression introduced by the overnight POOL-FIN-01 image update. Desktop Window Manager (dwm.exe) crashed in module igdumd64.dll with exception 0xc0000005.

Scope: Approximately 40% of users in POOL-FIN-01 were affected starting around 07:00 on 2024-03-15. POOL-FIN-02 was unaffected during the same window.

Workaround: Immediately isolate unstable POOL-FIN-01 hosts from new session assignments (drain/remove from new connections). Redirect users to healthy capacity while affected hosts are remediated.

Permanent fix: Roll back affected hosts to a known-good image/graphics driver state and reintroduce hosts in controlled batches after validation. Add preventive controls by pinning approved graphics drivers and enforcing canary-first rollout gates for the DWM crash signature.

How to spot it: Look for Application Error Event 1000 showing dwm.exe faulting in igdumd64.dll with exception 0xc0000005, along with Desktop Window Manager Event 9009 and TerminalServices-LocalSessionManager Event 40 after Event 21 logon success. In unaffected control hosts, DWM Event 9011 appears and matching Event 1000 is absent in the comparison window.
