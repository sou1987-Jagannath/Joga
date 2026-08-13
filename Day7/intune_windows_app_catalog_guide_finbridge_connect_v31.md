# Intune App Catalog Guide: Adding a Windows App Before Phased Rollout

Date: 2026-08-11
Worked example: FinBridge Connect v3.1
Package type: Windows LOB app packaged as a `.intunewin` file

## 1. Where to add an app in Intune

1. Sign in to the Intune admin center.
2. Navigate to Apps -> Windows.
3. Select Add.
4. Choose the app type that matches the package you are uploading.

5. Use these app types as the rule of thumb:
   1. Windows app (Win32) for a packaged `.intunewin` app such as FinBridge Connect v3.1.
   2. Microsoft Store app for a Store-delivered application.
   3. Web link for a URL shortcut that opens a website in the user’s browser.

6. Verify the live tenant labels before proceeding because Intune UI text commonly varies by tenant version and Microsoft service updates.
7. If the Add flow presents slightly different wording, use the closest current label in your tenant rather than relying on this document’s exact wording.

## 2. Create the LOB Windows app

1. In the Add app flow, choose Windows app (Win32).
2. Upload the `.intunewin` package for FinBridge Connect v3.1.
3. Complete the required fields carefully.

### 2.1 App information

1. Name: FinBridge Connect v3.1.
2. Description: Briefly state what the app does and who should use it.
3. Publisher: The software publisher name, for example FinBridge.
4. Version: 3.1.

### 2.2 Program

1. Install command: `FinBridgeConnect_Setup.exe /silent`.
2. Uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`.
3. Install behavior: Choose the execution context that matches how the app installs on the device.
   1. Use System when the installer must run in device context and install for all users.
   2. Use User when the installer must run in the signed-in user context and is designed only for that user.
4. For most enterprise Win32 deployments, use System unless the vendor explicitly requires User context.
5. Verify the install behavior against the vendor documentation and test device results before broad rollout.

### 2.3 Requirements

1. Architecture: Select the Windows architecture supported by the app.
   1. Use x64 if the app is 64-bit only or if your standard Windows 11 fleet is x64.
   2. Use x86 only if the app requires 32-bit installation.
   3. Use Both only when the package supports both architectures and testing confirms it.
2. Minimum OS version: Set the minimum Windows version required by the app.
3. Verify that the OS version requirement matches the actual supported baseline for the application and your device estate.

### 2.4 Detection rules

1. Configure detection so Intune knows whether the app installed successfully.
2. For FinBridge Connect v3.1, use a registry-based detection rule.
3. Detection example:
   1. Hive: HKLM
   2. Key path: `SOFTWARE\FinBridge\Connect`
   3. Value name: `Version`
   4. Expected value: `3.1`
4. Use the registry detection type when the app reliably writes a version marker to the machine.
5. If the app vendor provides an MSI product code, an MSI-based detection rule may also be valid.
6. If the app creates a stable file marker instead, a file path detection rule can be used.
7. Choose only one detection method that accurately proves the app is installed.

### 2.5 Return codes

1. Map the installer exit codes so Intune can interpret success and failure correctly.
2. Commonly accepted success codes include:
   1. `0`
   2. Any vendor-documented soft success code that still means installation completed correctly
3. Common failure codes include:
   1. Non-zero codes that the vendor documents as failure
   2. Any exit code not explicitly mapped as success or retryable in your deployment standard
4. If the vendor defines special handling for reboot-required or retryable codes, map them explicitly in Intune so the deployment behaves predictably.
5. Verify the installer’s documented return-code table before production release.

## 3. Assignment basics

1. After the app package, detection, and return codes are configured, assign the app to a group.
2. Use the correct assignment type for the business need.

3. Assignment types:
   1. Required: Intune installs the app automatically on targeted devices or users.
   2. Available: The app appears in Company Portal and users install it on demand.
   3. Uninstall: Intune removes the app from targeted devices or users.

4. Use Required when the app must be present for business operation.
5. Use Available when the app should be self-service and optional.
6. Use Uninstall when the app must be removed from the target set.

7. Do not assign a new app directly to a 10,000-device fleet on the first release.
8. Start with a small pilot or test group first so you can confirm install behavior, detection logic, return codes, and user impact before broadening scope.
9. A pilot group reduces the risk of breaking the fleet with a bad installer, wrong detection rule, incorrect architecture, or unexpected uninstall behavior.
10. Expand only after the pilot devices install and report compliance consistently.

## 4. Verification steps

1. After saving the app, verify it appears correctly in the Intune app catalog.
2. Confirm the app record shows the expected name, publisher, version, package type, and assignment.
3. Confirm the detection rule reflects the FinBridge registry version marker.
4. Confirm the install and uninstall commands are exactly as intended.

5. To check install status on a test device:
   1. Open the app record in Intune.
   2. Open Device install status or User install status, depending on how the app was assigned.
   3. Find the test device or user.
   4. Review the reported state after the device syncs.

6. Status meanings:
   1. Installed: Intune detected the app successfully and the device matches the detection rule.
   2. Failed: The install attempt did not complete successfully or the detection rule never evaluated as installed.
   3. Not applicable: The device or user is not in scope for the assignment, does not meet requirements, or is otherwise not eligible for that app deployment.

7. Validate the test device locally as well.
8. Confirm the FinBridge Connect version marker exists in the registry at `HKLM\SOFTWARE\FinBridge\Connect\Version` and shows `3.1`.
9. If the portal shows Failed, compare the local registry state with the Intune status to determine whether the issue is installer failure, detection failure, or requirement mismatch.

## 5. Worked example: FinBridge Connect v3.1

1. Open Intune admin center -> Apps -> Windows -> Add.
2. Choose Windows app (Win32).
3. Upload the FinBridge Connect v3.1 `.intunewin` package.
4. Enter the app information:
   1. Name: FinBridge Connect v3.1
   2. Description: Enterprise connection client for FinBridge services
   3. Publisher: FinBridge
   4. Version: 3.1
5. Enter the program commands:
   1. Install command: `FinBridgeConnect_Setup.exe /silent`
   2. Uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`
   3. Install behavior: System, unless vendor testing proves User is required
6. Set the requirements:
   1. Architecture: match the supported Windows architecture for the package
   2. Minimum OS version: set the supported baseline for your Windows estate
7. Add the detection rule:
   1. Registry-based detection
   2. HKLM key: `SOFTWARE\FinBridge\Connect`
   3. Value: `Version = 3.1`
8. Review return codes and ensure installer success and failure states are mapped correctly.
9. Assign the app to a pilot group as Required.
10. Save the app and wait for sync.
11. Check the device install status for the pilot device.
12. Confirm the app is Installed and the detection rule matches the registry value.

## 6. Common label variation warning

1. Intune labels can change slightly between tenant versions and admin center refreshes.
2. Common examples include navigation labels, status tab names, and the exact name of the add-app workflow.
3. Always verify the live tenant UI before making changes.
4. If this guide’s label does not match the tenant exactly, use the equivalent current label that clearly maps to the same function.

## 7. Minimum release checklist

1. Package uploaded successfully.
2. App information completed.
3. Install and uninstall commands validated.
4. Install behavior chosen correctly.
5. Requirements set correctly.
6. Detection rule proven on a test device.
7. Return codes reviewed.
8. Pilot assignment created.
9. Test device reports Installed.
10. Rollout to broader groups waits until pilot validation is complete.