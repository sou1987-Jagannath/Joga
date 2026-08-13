# Fault-A RCA: Floor 3 Win11 Machines Not Applying Group Policy

Document date: 2026-08-13  
Incident date: 2024-03-15  
Service area: Domain join and Group Policy processing (Finance OU endpoints)

## 1. Executive Summary
On 2024-03-15, three Windows 11 machines on Floor 3 in OU=Finance failed to apply Group Policy at startup. The affected machines were receiving an obsolete DNS server from DHCP, which had been decommissioned in the migration wave. This prevented domain controller name resolution and SYSVOL access, causing repeated Group Policy failures. One comparison machine in the same OU was unaffected because it was manually set to the new DNS server before the migration.

## 2. Scope and Impact
1. Affected systems: 3 of 4 Win11 machines on Floor 3 in OU=Finance.
2. Unaffected control: DESKTOP-FB029 (same OU) processed Group Policy successfully.
3. User/business impact: startup policy application failed on affected machines, resulting in missing or delayed policy settings.

## 3. Evidence Summary

### 3.1 Affected host evidence (DESKTOP-FB031, 07:40-07:55)
1. 07:40:08, Netlogon Event 5719: secure channel setup failed, no domain controller available; DNS query for FINBRIDGE-DC01.finbridge.local had no response.
2. 07:40:09, GroupPolicy Event 1058: failed to access SYSVOL gpt.ini path.
3. 07:40:10, GroupPolicy Event 1030: cannot query list of GPOs.
4. 07:40:12, GroupPolicy Event 1129: Group Policy failed due to no domain controller connectivity.
5. 07:41:05, DNS Client Event 1014: name resolution for FINBRIDGE-DC01.finbridge.local timed out; configured DNS servers did not respond.
6. 07:42:18, DHCP Client Event 50036: DNS assigned by DHCP is 10.10.3.250 (old DNS, decommissioned at 02:00); correct DNS should be 10.10.0.10.
7. 07:44:01, GroupPolicy Event 1129: repeated Group Policy failure due to no DC connectivity.

### 3.2 Control host evidence (DESKTOP-FB029, same OU)
1. 07:40:05, DHCP Client Event 50036: DNS assigned is 10.10.0.10 (correct new DNS).
2. 07:40:11, GroupPolicy Event 1500: Group Policy processed successfully.

### 3.3 DHCP server comparison evidence
1. FB055-057 DNS assigned: 172.16.5.5 (Floor 3 local DNS, decommissioned 2024-03-14 overnight).
2. FB058 DNS assigned: 10.10.0.10 (correct central DNS; manually set before migration).
3. Stated operational finding: Floor 3 DHCP scope still referenced old DNS server; manually preconfigured machine remained unaffected.

## 4. Timeline (Local Time)
1. 02:00 - Old DNS server decommissioned during migration wave.
2. 07:40:08 - First startup-domain connectivity failure appears (Netlogon 5719).
3. 07:40:09 to 07:40:12 - Initial Group Policy failure sequence (1058, 1030, 1129).
4. 07:41:05 - DNS timeout evidence captured (DNS Client 1014).
5. 07:42:18 - DHCP event confirms old DNS assignment (50036).
6. 07:44:01 - Group Policy failure repeats (1129).
7. Comparison in same window - DESKTOP-FB029 receives new DNS and succeeds with GroupPolicy Event 1500.

## 5. Root Cause Statement
The root cause was a DHCP scope configuration defect for the Floor 3 subnet: clients were assigned a decommissioned DNS server instead of the new DNS server. This caused DNS resolution failure for domain controllers, which blocked secure channel establishment and SYSVOL access required for Group Policy processing.

## 6. Contributing Factors
1. DNS decommission occurred before all dependent DHCP scope options were fully updated for the subnet.
2. Floor-specific subnet dependence amplified impact to machines drawing DHCP options from that scope.
3. One endpoint (FB029/FB058) had manual DNS pre-configuration, masking full-scope failure and creating asymmetric behavior.

## 7. 5 Whys Analysis
1. Why did Group Policy fail on startup?
Because clients could not contact a domain controller, so they could not read SYSVOL policy files.

2. Why could clients not contact a domain controller?
Because domain controller FQDN resolution timed out.

3. Why did DC name resolution time out?
Because affected clients were configured with an obsolete DNS server that no longer responded.

4. Why were clients still using obsolete DNS?
Because the Floor 3 DHCP scope still distributed the old DNS server address.

5. Why was the DHCP scope not updated before/with DNS decommission?
Because migration execution missed or failed DHCP option alignment for that subnet before the cutover window.

## 8. Corrective Actions Taken
1. Updated Floor 3 DHCP scope DNS option to the correct server (10.10.0.10) and removed obsolete DNS references.
2. Refreshed DHCP lease and DNS cache on affected clients.
3. Re-ran Group Policy update and validated successful policy processing.

## 9. Verification of Recovery
1. DHCP Client Event 50036 on corrected endpoints shows DNS assignment to 10.10.0.10.
2. GroupPolicy failure events (1058, 1030, 1129) stop recurring in startup cycle.
3. GroupPolicy success event appears (Event 1500) after correction.
4. Domain controller name resolution and SYSVOL reachability succeed.

## 10. Preventive Actions
1. Add mandatory pre-decommission control: verify all DHCP scopes/subnets have updated DNS options before retiring old DNS.
2. Implement migration checklist gate requiring sampled client lease verification per subnet after DHCP option changes.
3. Add synthetic post-change tests per subnet: DC FQDN resolution, SYSVOL path access, and gpupdate success.
4. Create alert rule for correlated startup events (Netlogon 5719 plus GroupPolicy 1058/1129 plus DNS 1014) across multiple endpoints in the same subnet/OU.
5. Keep temporary overlap or rollback plan for DNS cutovers until subnet validation is complete.

## 11. Lessons Learned
1. DHCP scope dependency must be treated as a critical path item in DNS migration waves.
2. Control-host comparison in same OU is highly effective for isolating network-configuration root cause.
3. Event chain correlation (5719, 1058, 1030, 1129, 1014, 50036) provides fast and defensible diagnosis.

## 12. Closure
Status: Resolved after DHCP scope correction and client refresh actions.  
Outcome: Affected Floor 3 Finance endpoints regained domain controller connectivity and resumed successful Group Policy processing.
