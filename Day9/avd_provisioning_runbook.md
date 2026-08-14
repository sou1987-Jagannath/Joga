# Azure Virtual Desktop — End-to-End Provisioning Runbook
**Project:** DWP Windows 11 Workplace Migration  
**Date:** 2026-08-13  
**Engineer:** p30@zippyops.in  

---

## Environment

| Parameter | Value |
|---|---|
| Subscription ID | `9a89dd7c-2c36-41b4-9f7a-b7f73e94be56` |
| Subscription Name | labs32 |
| Resource Group | `dwp-lab-rg` |
| Region | Central US |
| M365 Tenant | `zippyops.in` |
| M365 / Entra Account | `p30@zippyops.in` |
| Account Object ID | `cf1949cd-1ad9-499e-83f5-2e9fd3fd0893` |

---

## Provisioned Resources Summary

| Resource | Name | Type |
|---|---|---|
| Host Pool | `POOL-FIN-01` | Pooled, BreadthFirst, max 5 sessions |
| Application Group | `POOL-FIN-01-DAG` | Desktop |
| Workspace | `FinBridge-Workspace` | Registered to POOL-FIN-01-DAG |
| Session Host VM | `sh-fin-01` | Standard_B2ms, Win11 24H2 AVD, TrustedLaunch |

---

## Step-by-Step Provisioning

### Step 1 — Pre-flight: Verify CLI Account and Permissions

```powershell
# Confirm active subscription and signed-in account
az account show --query "{subscriptionId:id, name:name, tenantId:tenantId, user:user.name}" -o table

# Get signed-in user's Object ID
az ad signed-in-user show --query "id" -o tsv

# List all RBAC role assignments for the account
az role assignment list `
  --assignee cf1949cd-1ad9-499e-83f5-2e9fd3fd0893 `
  --all `
  --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

**Result:** No roles found for `p30@zippyops.in` at subscription or resource group scope. A privileged account (Owner / User Access Administrator on `dwp-lab-rg`) was required before proceeding. The user re-authenticated with an account that held the necessary rights.

---

### Step 2 — Install Azure CLI Desktop Virtualization Extension

```powershell
# Allow preview extension installation
az config set extension.dynamic_install_allow_preview=true

# Install the desktopvirtualization extension
az extension add --name desktopvirtualization --yes

# Verify installation
az extension list --query "[?name=='desktopvirtualization'].{Name:name, Version:version}" -o table
```

**Result:** Extension `desktopvirtualization` v1.0.0 installed successfully.

---

### Step 3 — Create the Host Pool

```powershell
az desktopvirtualization hostpool create `
  --name "POOL-FIN-01" `
  --resource-group dwp-lab-rg `
  --subscription 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56 `
  --location centralus `
  --host-pool-type Pooled `
  --load-balancer-type BreadthFirst `
  --max-session-limit 5 `
  --preferred-app-group-type Desktop `
  -o table
```

**Result:**

| Name | Type | Load Balancer | Max Sessions | Location |
|---|---|---|---|---|
| POOL-FIN-01 | Pooled | BreadthFirst | 5 | centralus |

---

### Step 4 — Create the Desktop Application Group

```powershell
az desktopvirtualization applicationgroup create `
  --name "POOL-FIN-01-DAG" `
  --resource-group dwp-lab-rg `
  --subscription 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56 `
  --location centralus `
  --application-group-type Desktop `
  --host-pool-arm-path "/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostpools/POOL-FIN-01" `
  -o table
```

**Result:** Application group `POOL-FIN-01-DAG` (Desktop type) created and linked to `POOL-FIN-01`.

---

### Step 5 — Create the Workspace and Register the App Group

```powershell
# Create the workspace
az desktopvirtualization workspace create `
  --name "FinBridge-Workspace" `
  --resource-group dwp-lab-rg `
  --subscription 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56 `
  --location centralus `
  -o table

# Register the app group to the workspace
az desktopvirtualization workspace update `
  --name "FinBridge-Workspace" `
  --resource-group dwp-lab-rg `
  --subscription 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56 `
  --application-group-references `
    "/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationgroups/POOL-FIN-01-DAG"
```

**Result:** Workspace `FinBridge-Workspace` created; `POOL-FIN-01-DAG` registered to it.

---

### Step 6 — Create the Session Host VM

```powershell
# Create the VM — Windows 11 24H2 AVD-optimised image, Standard_B2ms, TrustedLaunch
az vm create `
  --name sh-fin-01 `
  --resource-group dwp-lab-rg `
  --subscription 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56 `
  --location centralus `
  --image MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest `
  --size Standard_B2ms `
  --security-type TrustedLaunch `
  --enable-secure-boot true `
  --enable-vtpm true `
  --admin-username avdadmin `
  --admin-password "<redacted>" `
  --vnet-name <existing-vnet> `
  --subnet <existing-subnet> `
  --public-ip-address "" `
  -o table
```

**VM Specification confirmed:**

| Property | Value |
|---|---|
| Name | sh-fin-01 |
| Size | Standard_B2ms |
| OS Image | MicrosoftWindowsDesktop / windows-11 / win11-24h2-avd |
| Image Version | 26100.9168.260809 |
| Security Type | TrustedLaunch |
| Secure Boot | Enabled |
| vTPM | Enabled |
| Location | centralus |

---

### Step 7 — Deploy DSC Extension (AVD Agent + Entra ID Join)

The DSC (Desired State Configuration) extension was deployed via the Azure portal / ARM to:
- Install the AVD agent on `sh-fin-01`
- Register the session host with host pool `POOL-FIN-01`
- Perform Microsoft Entra ID join (no on-premises AD domain exists)

```powershell
# Verify the AADLoginForWindows extension was installed successfully
az vm run-command invoke `
  --name sh-fin-01 `
  --resource-group dwp-lab-rg `
  --subscription 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56 `
  --command-id RunPowerShellScript `
  --scripts "Get-ChildItem 'C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.ActiveDirectory.AADLoginForWindows\2.2.0.0\CommandExecution_2026*' | Sort LastWriteTime -Desc | Select -First 1 | Get-Content | Select -Last 40" `
  --query "value[0].message" -o tsv
```

**Result:** AADLoginForWindows extension logs confirmed successful Entra ID join. Session host appeared as registered in POOL-FIN-01.

---

### Step 8 — Assign RBAC Roles to p30@zippyops.in

Two roles are required:
- **Desktop Virtualization User** on the app group — allows the account to connect to the published desktop via the AVD client
- **Virtual Machine User Login** on the session host VM — allows RDP/console login to the VM

```powershell
# Role 1: Desktop Virtualization User on POOL-FIN-01-DAG
az role assignment create `
  --assignee "cf1949cd-1ad9-499e-83f5-2e9fd3fd0893" `
  --role "Desktop Virtualization User" `
  --scope "/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationgroups/POOL-FIN-01-DAG"

# Role 2: Virtual Machine User Login on sh-fin-01
az role assignment create `
  --assignee "cf1949cd-1ad9-499e-83f5-2e9fd3fd0893" `
  --role "Virtual Machine User Login" `
  --scope "/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourceGroups/dwp-lab-rg/providers/Microsoft.Compute/virtualMachines/sh-fin-01"
```

---

### Step 9 — Verify Role Assignments

```powershell
# Verify Desktop Virtualization User
az role assignment list `
  --scope "/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationgroups/POOL-FIN-01-DAG" `
  --assignee "cf1949cd-1ad9-499e-83f5-2e9fd3fd0893" `
  -o json

# Verify Virtual Machine User Login
az role assignment list `
  --scope "/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourceGroups/dwp-lab-rg/providers/Microsoft.Compute/virtualMachines/sh-fin-01" `
  --assignee "cf1949cd-1ad9-499e-83f5-2e9fd3fd0893" `
  --query "[].{role:roleDefinitionName, principal:principalName}" -o table
```

**Verified role assignments:**

| Role | Principal | Scope | Created |
|---|---|---|---|
| Desktop Virtualization User | p30@zippyops.in | POOL-FIN-01-DAG | 2026-08-13T06:00:54Z |
| Virtual Machine User Login | p30@zippyops.in | sh-fin-01 | 2026-08-13T06:11:12Z |

---

## Issues Encountered

| Issue | Resolution |
|---|---|
| Initial `p30@zippyops.in` account had no RBAC roles on the subscription — all resource creation commands returned `AuthorizationFailed` | User re-authenticated with a privileged account (Owner / User Access Administrator on `dwp-lab-rg`) before proceeding with infrastructure creation |
| `az network nic show` returned `AuthorizationFailed` for the existing `dwp-p30-win` NIC — could not read subnet | Used the pre-known subnet from the existing lab VNet; networking was created alongside the VM |
| `az desktopvirtualization sessionhost list` / `session-host list` returned "misspelled or not recognized" — CLI extension v1.0.0 does not expose session-host subcommand | Used the REST API directly via `az rest --method GET` to query session hosts: `GET .../hostPools/POOL-FIN-01/sessionHosts?api-version=2022-09-09` |

---

## Connecting to the AVD Desktop

1. Download and install the **Windows App** (or Remote Desktop client) from [https://aka.ms/AVDclient](https://aka.ms/AVDclient)
2. Sign in with `p30@zippyops.in`
3. The **FinBridge-Workspace** workspace and the published **Session Desktop** from `POOL-FIN-01` will appear
4. Launch the desktop — the session host `sh-fin-01` will service the connection

For direct VM RDP (admin/troubleshooting):
```
mstsc /v:<private-IP-of-sh-fin-01>
```
Login with the Entra ID account `p30@zippyops.in` (Virtual Machine User Login role is assigned).

---

## Resource IDs

| Resource | ARM Resource ID |
|---|---|
| Host Pool | `/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostPools/POOL-FIN-01` |
| App Group | `/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationGroups/POOL-FIN-01-DAG` |
| Workspace | `/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/workspaces/FinBridge-Workspace` |
| Session Host VM | `/subscriptions/9a89dd7c-2c36-41b4-9f7a-b7f73e94be56/resourceGroups/dwp-lab-rg/providers/Microsoft.Compute/virtualMachines/sh-fin-01` |
