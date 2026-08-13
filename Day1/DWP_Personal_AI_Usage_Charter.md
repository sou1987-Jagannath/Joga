# Personal AI Usage Charter — DWP Desktop & Endpoint Engineer

**Name:** ___________________  **Date:** 03/08/2026  **Review due:** 03/02/2027

---

## Role Context

This charter applies to a DWP desktop and endpoint engineer working with managed Windows 11 devices, SCCM, Intune, Active Directory, and ITSM tooling. It governs personal use of public AI assistants (e.g. Microsoft Copilot on approved tier, ChatGPT) in day-to-day engineering work.

---

## 1. Appropriate Uses of Public AI Assistants

I may use public LLM tools for the following, provided no sensitive data is included:

- Drafting or explaining PowerShell, batch, or reg scripts using **fictional/generic device names and placeholder values only**
- Understanding error codes, Event Log IDs, and Windows 11/SCCM/Intune documentation
- Generating boilerplate for runbooks, knowledge articles, or process guides (reviewed before publishing)
- Explaining networking concepts, Group Policy settings, or registry behaviour
- Improving the clarity of technical writing or internal communications
- Brainstorming troubleshooting steps for common desktop/endpoint faults

---

## 2. Tasks I Will NOT Use Public AI Assistants For

- Any query that requires including real **usernames, staff IDs, device hostnames, asset tags, or IP addresses**
- Anything involving **DWP internal system names, domain structure, or network topology**
- Requests that reference **live incident details, ticket numbers, or user-reported symptoms** tied to a real person
- Generating or analysing **security configurations, firewall rules, or vulnerability data** for production systems
- Any task involving **credentials, certificates, API keys, or access tokens** — real or test
- Summarising or processing **end-user PII** of any kind (names, NI numbers, case references, addresses)

---

## 3. Data Handling Rule — PII and Credentials

> **Before I type anything into a public AI tool, I will ask: "Could this identify a person or grant access to a system?"**

- I will **anonymise all examples** before submitting — replace real values with `DEVICE001`, `user@example.com`, `192.168.x.x`
- I will **never paste** output from Get-ADUser, Get-MsolUser, ticket exports, or any ITSM screen into a public model
- I will **never enter passwords, hashes, tokens, or PKI material** — even expired ones
- If I accidentally submit sensitive data, I will report it to my line manager and the DWP Data Protection team the same day

---

## 4. Personal 'Generate Then Verify' Rule — Scripts and System Changes

**I will treat all AI-generated scripts and configuration changes as unreviewed drafts, not finished work.**

Before applying anything to a managed device or system:

1. **Read it line by line** — I understand every command before I run it; if I do not, I research it first
2. **Test in isolation** — run against a single test device or in a lab environment, never directly to production or a group of endpoints
3. **Check for hardcoded assumptions** — paths, registry keys, and scope (e.g. `-Force`, `-Recurse`, `*`) must be validated against the actual environment
4. **Peer review for high-risk changes** — any script that modifies security settings, removes software, or touches the registry on managed devices gets a second pair of eyes before deployment
5. **Log what I deployed and when** — note the AI tool used, the prompt intent, and the verification steps taken in the change record

---

## 5. Useful Anonymisation Substitutions (Quick Reference)

| Real value type        | Use this placeholder instead |
|------------------------|------------------------------|
| Device hostname        | `DEVICE001`, `TESTPC01`      |
| Username / UPN         | `user@example.com`           |
| Staff ID               | `12345678`                   |
| IP address             | `192.168.x.x` / `10.x.x.x`  |
| Asset tag              | `ASSET-00001`                |
| Domain name            | `corp.example.com`           |
| Share / UNC path       | `\\server\share`             |
| Any password / token   | `[REDACTED]`                 |

---

*This charter is personal and supplementary to DWP's Acceptable Use Policy and AI governance framework. Where they conflict, DWP policy takes precedence.*

**Signed:** ___________________  **Line manager aware:** Yes / No
