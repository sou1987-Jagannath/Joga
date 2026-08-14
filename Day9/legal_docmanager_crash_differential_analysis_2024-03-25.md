# Legal Floor Document Manager Crash — Differential Analysis & Correlation Study
**Date:** 2024-03-25  
**Analyst:** DWP Support Engineering  
**Purpose:** Cross-source data correlation to eliminate alternative hypotheses

---

## Two-Source Analysis: Why Each Alone Is Incomplete

### SCCM Logs in Isolation
**If we only had SCCM data, we would conclude:**
- ✓ "Deployment succeeded cleanly"
- ✓ "Zero installation failures"
- ✗ **We would miss:** The fact that the application crashes *after* installation completes

**Why SCCM data is insufficient:**
- SCCM monitors MSI extraction, registry writes, file copies
- SCCM does NOT monitor post-installation application behavior
- SCCM does NOT monitor long-running initialization processes that begin *after* the installer completes

---

### Nexthink DEX in Isolation
**If we only had Nexthink DEX data, we would conclude:**
- ✓ "DocManager.exe is crashing at a 6.2% rate"
- ✓ "Disk I/O is elevated during the crash window"
- ✗ **We would miss:** What triggered it? A system update? Disk failure? User error?
- ✗ **We would not know:** This is a *deployment-induced* problem, not a systemic hardware failure

**Why DEX data alone is insufficient:**
- DEX shows *what* is happening, not *why*
- DEX shows symptoms, not root cause
- DEX does not capture deployment events

---

## Correlation: When Both Sources Align

### Timeline Overlap Analysis

```
SCCM Timeline          DEX Telemetry Timeline
─────────────────────  ──────────────────────────────

09:38 Deploy start
  |
09:44 Deploy end ───────→ (16-minute delay) ───→ 10:00 DEX alerts
       (no failures      
        reported)           Crashes detected
                            High disk I/O observed
                            DocManager.exe: 74% of crashes
```

**Key inference:** The 16-minute gap between deployment completion and crash visibility indicates:
1. **Installation phase completed successfully** (SCCM correct: 0 failures)
2. **Post-installation initialization began** (auto-save indexing process)
3. **Resource contention emerged during initialization** (high disk I/O visible to DEX)
4. **DocManager.exe crashed as a result** (visible in DEX, not in SCCM)

---

## Alternative Hypotheses & Elimination

### Hypothesis 1: Pre-existing hardware failure
**Claim:** The devices were already failing; deployment just coincided.

**Evidence against:**
- DEX Score was 91 at 08:00–09:00 (healthy baseline)
- No disk I/O elevation before 10:00
- Crash rate was 0.1–0.2% (normal)
- **Conclusion:** Hardware was stable before 10:00. ❌ Hypothesis eliminated.

---

### Hypothesis 2: Deployment failed but SCCM reported false success
**Claim:** The MSI deployment actually failed on 18 devices; they're running an incomplete version.

**Evidence against:**
- SCCM explicitly reports "45 of 45 devices — Success"
- The 27 unaffected devices are also part of the same deployment and are running stably
- If deployment had failed, we would expect cascading failures (missing DLLs, registry issues, file errors)
- The crashes are not system-level, they're application-level (DocManager.exe crashing, not OS blue screen)
- **Conclusion:** Deployment succeeded as reported. ❌ Hypothesis eliminated.

---

### Hypothesis 3: Network saturation caused by deployment process
**Claim:** The SCCM deployment process itself consumed all bandwidth, degrading performance.

**Evidence against:**
- Deployment completed at 09:44
- Crashes began at 10:00 (16 minutes later, well after deployment process ended)
- Network bandwidth constraints would show recovery immediately after deployment ends
- Nexthink DEX metric is **high disk I/O**, not network I/O
- **Conclusion:** Network saturation would not explain the 16-minute delay or disk I/O pattern. ❌ Hypothesis eliminated.

---

### Hypothesis 4: Standard post-deployment auto-restart behavior
**Claim:** Devices restarted after deployment; crashes are just startup noise.

**Evidence against:**
- If devices restarted at 09:44, crashes would appear ~10–15 minutes later (~09:54–10:00), which is visible in DEX
- However, the sustained 6.2–6.8% crash rate for the full hour (10:00–11:00) suggests ongoing crashes, not a one-time startup transient
- SCCM logs would show restart events if this were the cause
- **Partial correlation but incomplete explanation:** Devices may have restarted, but the sustained crash rate indicates a process that continues to crash repeatedly. 🟡 Hypothesis partially supported; severity driven by v2.1 indexing process, not restart alone.

---

### Hypothesis 5: A different process caused the crashes (not DocManager.exe)
**Claim:** DocManager.exe is crashing due to high disk I/O, but the root cause is some other process consuming disk I/O.

**Evidence against:**
- v2.1 release notes explicitly state the auto-save indexing process can cause crashes on low-RAM devices
- The indexing process is part of Document Manager (internal service/component)
- DocManager.exe is the documented process that crashes in the vendor documentation
- **Conclusion:** The vendor themselves identify DocManager.exe as the crashing process in their known limitation. ✓ This is the most likely explanation.

---

### Hypothesis 6: RAM was already degraded on 4GB devices
**Claim:** The 4GB RAM devices didn't have a full 4GB available; they had less, triggering crashes regardless of v2.1.

**Evidence against:**
- If RAM was degraded, crashes would have been occurring before 10:00 (we have baseline DEX data from 08:00, 09:00 showing no issues)
- The crash rate delta (0.1% → 6.2%) is precisely aligned with deployment timing
- The stratification (40% of devices crash, 60% don't) perfectly matches the RAM distribution
- **Conclusion:** RAM was sufficient before v2.1 deployment; the new feature broke the budget. ❌ Hypothesis eliminated.

---

### Hypothesis 7: Vendor release notes are misleading; v2.1 has a wider incompatibility
**Claim:** v2.1 crashes on devices regardless of RAM; the 4GB devices just crash first.

**Evidence against:**
- 27 devices with 8GB RAM received the same v2.1 deployment and remained stable (DEX Score 85+)
- If v2.1 were broadly incompatible, all 45 devices would crash
- The vendor specifically tests and documents the 8GB boundary; they wouldn't release a feature with a wider incompatibility
- **Conclusion:** v2.1 works as documented; the incompatibility is specific to <8GB threshold. ❌ Hypothesis eliminated.

---

## Hardware Stratification Validation

### Device Population Split

```
Legal-Win11 Fleet (45 devices)
│
├─ 8GB RAM: 27 devices (60%)
│  └─ DEX Status: Stable (Score 85+, crash rate < 0.5%)
│  └─ v2.1 Status: Running without incident
│  └─ Vendor compatibility: ✓ Above 8GB threshold
│
└─ 4GB RAM: 18 devices (40%)
   └─ DEX Status: Degraded (Score 55–58, crash rate 6.2–6.8%)
   └─ v2.1 Status: Crashing (74% of incidents = DocManager.exe)
   └─ Vendor compatibility: ✗ Below 8GB threshold
```

### Statistical Alignment

| Metric | Observed (4GB devices) | Vendor Limitation | Alignment |
|---|---|---|---|
| RAM threshold | 4GB | "under 8GB RAM" | ✓ Match |
| Impact: High disk I/O | Yes, observed 10:00–11:00 | "cause high disk I/O" | ✓ Match |
| Process: DocManager.exe | Yes, 74% of crashes | "auto-save indexing process" in DocManager | ✓ Match |
| Timing: Post-install | Yes, +16 minutes after deploy | "during first few hours after installation" | ✓ Match |
| Duration: Hours | ~2 hours observed (10:00–12:00) | "during the first few hours" | ✓ Match |

**Conclusion:** Observed behavior precisely aligns with vendor documented limitation. No alternative explanation accounts for all observed data points.

---

## Why the Dual-Source Approach Works

### Narrative Construction from Two Sources

| Question | SCCM Answers | DEX Answers | Combined Insight |
|---|---|---|---|
| Did the deployment execute? | Yes (0 failures) | — | ✓ Installation succeeded |
| When did crashes start? | — | 10:00 (16 min after deploy) | ✓ Post-installation event |
| What process crashed? | — | DocManager.exe (74%) | ✓ Specific process identified |
| What resource was constrained? | — | Disk I/O (High) | ✓ Resource bottleneck |
| What version was deployed? | v2.1 | — | ✓ Feature identification |
| Which devices affected? | All 45 | But only 18 reported issues | ⚠️ Hardware stratification |
| Why only some devices? | — | — | Vendor release notes: "under 8GB RAM" |

### The Missing Layer
Neither SCCM nor DEX alone could answer: **"Why did the deployment succeed according to SCCM, but the application crashes according to DEX?"**

**Answer:** Deployment success ≠ application stability. Only by correlating both sources can we identify that:
- Deployment success = MSI installed correctly
- Application crashes = Post-install initialization failed on low-RAM devices

---

## Risk of Single-Source Reliance

### If Support Had Only SCCM Data
**Action taken:** None. "Deployment succeeded; ticket closed."  
**User experience:** Legal team frustrated for 2+ hours. Escalation to management.

### If Support Had Only DEX Data
**Action taken:** Generic troubleshooting—restart devices, check for viruses, reimage suspected devices.  
**User experience:** Time wasted on wrong fixes; delayed actual resolution.

### With Both Sources
**Action taken:** Targeted rollback of v2.1 to v2.0 on 4GB devices, or rollback across entire fleet.  
**User experience:** 20–30 minute resolution; root cause documented; process improved.

---

## Key Takeaway for DWP Operations

**The incident was determined and resolved through correlation, not isolation.**

Establishing a culture of multi-source correlation—especially correlating deployment events (SCCM) with performance data (Nexthink DEX)—enables:
- ✓ Faster root cause isolation
- ✓ Elimination of false leads
- ✓ Confident remediation decisions
- ✓ Prevention of recurrence through process improvements

---

## Recommended Post-Incident Practices

1. **Deploy first, validate with DEX second**
   - After any non-patch deployment, wait 30 minutes and confirm DEX scores are healthy
   - Automate DEX score validation as a deployment gate

2. **Segment collections by hardware**
   - Create separate SCCM device collections for each hardware configuration
   - Tag deployments with hardware requirements in deployment notes

3. **Review vendor release notes as part of change control**
   - Vendor-documented limitations must be reviewed by change management before approval
   - Create a pre-deployment checklist that includes "vendor release notes reviewed for known issues"

4. **Monitor for 16-minute post-deployment window**
   - Many applications perform post-install initialization
   - Establish SLA that application behavior must stabilize within 30 minutes of deployment completion

