# DEX Startup Performance Drop — Probable Cause Analysis
**Date:** 2026-08-12
**Device group:** Finance-Win11 (215 devices)
**Trigger event:** Security baseline config profile deployed 2026-08-04 02:00
**Observed impact:** Startup time +23.8 sec, DEX score 84 → 61, sustained 3 days

---

## Analytical Basis

The timing (degradation starts on exactly the first boot after the 02:00 deployment), the consistency of the delay (+23–26 seconds each day), and the flat IT-Win11 comparison group (no config change, no degradation) together make the config change the near-certain origin. The three causes below are ranked by how directly each component of that config change explains the evidence.

---

## Rank 1 — Compliance Logging Startup Script Running Synchronously or Hitting a Network Timeout

**Why it fits the evidence:**
The config change explicitly added a startup script for compliance logging. If that script runs synchronously at login — meaning the desktop waits for it to complete before becoming usable — it directly explains the delay. The consistency of the added time (~23–26 seconds across all three days) is particularly telling: variable resource contention would produce variable delays, but a fixed network timeout (e.g. the script trying to reach a logging server and waiting 30 seconds before giving up) would produce a near-constant delay exactly like this. The comparison group (IT-Win11) had no script deployed and shows zero degradation, which is the cleanest possible confirmation that the script is the source.

**Fastest check to confirm or eliminate:**
Review the Group Policy or Intune startup script settings for Finance-Win11 and check whether the script is configured as synchronous or asynchronous. Then check the compliance logging endpoint — run the script manually on one affected device while monitoring network traffic (e.g. Wireshark or Fiddler) to see if it is waiting on a connection. If a timeout is present, it will appear as a consistent ~N-second pause in the trace.

---

## Rank 2 — Defender Scan Policy Triggering an Intensive Scan at Every Login

**Why it fits the evidence:**
The second component of the config change was an additional Defender scan policy. If this policy is configured to run a scan at user login (rather than on a schedule), it would consume CPU and disk I/O at the exact moment the user is trying to reach a usable desktop, directly delaying login completion. The degradation appearing on the first boot after deployment and not appearing in IT-Win11 (which did not receive the policy) matches this cause cleanly. The slightly varying startup times day-to-day (41.3 → 43.8 → 42.1 sec) could reflect variable scan duration depending on file activity since the last scan.

**Fastest check to confirm or eliminate:**
On an affected Finance-Win11 device, open Windows Security > Virus & threat protection > Protection history immediately after login and check whether a scan ran at that time. In Intune, review the Defender policy assigned to Finance-Win11 and look for a scan trigger configured as "At log on" or "At startup". Temporarily setting the trigger to scheduled (off-login) on a test device and measuring startup time would confirm or eliminate this quickly.

---

## Rank 3 — Combined Resource Contention from Both New Components Running Simultaneously at Login

**Why it fits the evidence:**
Both the compliance script and the Defender scan policy were deployed together and both execute in the login window. If they run concurrently rather than sequentially, the CPU and disk I/O load at startup doubles. Neither component alone may account for the full 23-second increase, but the two together could. This cause is ranked third because it depends on Ranks 1 and 2 both being true simultaneously — it is less likely as a standalone explanation, but important to consider if individual component tests (above) each show only a partial delay.

**Fastest check to confirm or eliminate:**
On an affected device, use Task Manager or Resource Monitor immediately after login to capture CPU and disk activity during the slow window. If both MpCmdRun.exe (Defender) and the compliance script process are active at the same time with high resource usage, contention is confirmed. Staggering the two policies — delaying the Defender scan trigger by 5 minutes post-login — on a test device would show whether separating them restores startup performance.

---

## Summary Table

| Rank | Cause | Key evidence fit | Fastest check |
|---|---|---|---|
| 1 | Compliance script — synchronous or network timeout | Consistent fixed delay, timing exact, comparison group clean | Check sync/async config; trace network calls from script |
| 2 | Defender scan policy triggering at login | Login-time disk/CPU load, variable daily duration, comparison group clean | Check Protection history post-login; review Intune policy trigger setting |
| 3 | Both policies causing concurrent resource contention | Cumulative load from two simultaneous login-time processes | Resource Monitor at login; stagger policy triggers on test device |
