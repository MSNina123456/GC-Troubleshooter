# GC-Troubleshooter
Guest configuration troubleshooter tool including log collection

## Overview
This tool will help you to identify some Azure Guest Configuration policy deployment issues.

In this tool, we have below options to select:
1: Check RP Microsoft.GuestConfiguration registration
2: Check Guest configuration extension
3: Check managed identity
4: Check Guest configuration policy errors
5: Check Non compliant policies on a given VM
6: Check above all
7: Collect logs
Q: Press 'Q' to quit.

### Note: 
With option 6, we will check:
* Microsoft.GuestConfiguration registration
* Guest configuration extension provisioning status
* Managed identity enabled
* Policy assignment permission if its effect is 'DeployIfNotExists'
* Custom OS image template
* Non compliant policies with reason

## Usage
Sample 1 (recommended):
```
.\GuestConfigurationTroubleshooter.ps1 -ResourceGroupName <resource group name of VM> -VMName <VM name>
```
  
Sample 2:
```
$myVM = Get-AzVM -ResourceGroupName <resource group name of VM> -Name <VM name>
.\GuestConfigurationTroubleshooter.ps1 -VM $myVM
```

Sample output:
```
=====================================================================
Please select an option: 6
You selected option #6
Microsoft.GuestConfiguration is registered under current subscription
MSI is enabled on this VM
Checking for extension "AzurePolicyForWindows"...
The extension "AzurePolicyForWindows" was deployed successfully
Provisioning succeeded
===Non Compliant policy checking===
Would you still like to continue?
There are 11 policies assigned to this scope, so this test will take some time.
[Y] Yes [N] No [S] Suspend [?] Help (default is "Yes"):
Found Guest Configuration policy : Audit Windows machines on which the DSC configuration is not compliant
All VMs images are applicable to custom OS template
Found Guest Configuration policy : Deploy prerequisites to enable Guest Configuration policies on virtual machines
Policy was in an initiative
Checking permission of policy effect DeployIfNotExists for assignment ***
/subscriptions/***/resourceGroups/***/providers/Microsoft.Authorization/roleAssignments/*** has permission of Contributoron scope /subscriptions/***/resourceGroups/***
All VMs images are applicable to custom OS template
The policy "Audit Windows machines on which the DSC configuration is not compliant" is not in an initiative


Name                           Value
----                           -----
OverallStatus                  False
CheckResults                   {True, @{Status=True; Name=MSI}, @{Status=True; Name=GuestConfigurationExtension; Details=System.Collections.Hashtable}, False…}
Messages                       {}
```

## Log collection
select option #7
```
================ Please select troubleshoot scenario ================

1: Check RP Microsoft.GuestConfiguration registration
2: Check Guest configuration extension
3: Check managed identity
4: Check Guest configuration policy errors
5: Check Non compliant policies on a given VM
=====================================================================
6: Check above all
7: Collect logs
Q: Press 'Q' to quit.
=====================================================================
Please select an option: 7
You selected option #7
For windows, install and run this script to collect logs: Install-Script -Name GCLogCollection
Incoming: linux collector
```

### Windows platform
1. open powershell window and run this command to download log collector tool: `Install-Script -Name GCLogCollection`
2. find script location with this command: `Get-Command -Name GCLogCollection | Format-List Path`
3. move to script folder and run `.\GCGCLogCollection.ps1`

Sample
```
PS C:\tester> Install-Script -Name GCLogCollection

PS C:\tester> Get-Command -Name GCLogCollection | Format-List Path

Path : C:\Program Files\WindowsPowerShell\Scripts\GCLogCollection.ps1

PS C:\tester> cd "C:\Program Files\WindowsPowerShell\Scripts"

PS C:\Program Files\WindowsPowerShell\Scripts> .\GCLogCollection.ps1
```

Output
```
10_23_02_11_2022 || INFO || enableScriptExecution || Setting script execution policy to unrestricted.
Removing tool's old log file.
Tool's log data is being redirected to C:\Users\tester\AppData\Local\Temp\2\Nina1-win2012R2_10_23_02_11_2022\..\tool.lo
g
10_23_02_11_2022 || INFO || init || Starting data collection.
10_23_02_11_2022 || INFO || Get-SystemData || Collecting system information...
10_23_02_11_2022 || INFO || Get-SystemData || System information collected.
10_23_02_11_2022 || INFO || CollectExtensionLogs || Collecting extension logs
10_23_02_11_2022 || INFO || Get-EventViewerLogs || Collecting event logs from: Application
10_23_02_11_2022 || INFO || Get-EventViewerLogs || Logs from source: Application, stored at: C:\Users\tester\AppData\Lo
cal\Temp\2\Nina1-win2012R2_10_23_02_11_2022\Event Logs\Application.evtx
10_23_02_11_2022 || INFO || Get-EventViewerLogs || Collecting event logs from: System
10_23_02_11_2022 || INFO || Get-EventViewerLogs || Logs from source: System, stored at: C:\Users\tester\AppData\Local\T
emp\2\Nina1-win2012R2_10_23_02_11_2022\Event Logs\System.evtx
10_23_02_11_2022 || INFO || CollectAllDSCEvents || Collecting DSC event logs from: Microsoft-Windows-Dsc
10_23_02_11_2022 || INFO || CollectAllDSCEvents || Logs from source: Microsoft-Windows-Dsc, stored at: C:\Users\tester\
AppData\Local\Temp\2\Nina1-win2012R2_10_23_02_11_2022\Event Logs\Microsoft-Windows-Dsc.log, run this command if you wou
ld more logs of DSC: Find-Module xDSCDiagnostics | Install-Module; New-xDscDiagnosticsZip
10_23_02_11_2022 || INFO || archiveLogs || Data collection completed.
10_23_02_11_2022 || INFO || archiveLogs || Analyzing collected logs for errors.
10_23_02_11_2022 || INFO || archiveLogs || Analysis completed and written to file: C:\Users\tester\AppData\Local\Temp\2
\Nina1-win2012R2_10_23_02_11_2022\errors.txt
10_23_02_11_2022 || INFO || Create-Zip || Compressing logs collected in folder: C:\Users\tester\AppData\Local\Temp\2\Ni
na1-win2012R2_10_23_02_11_2022
10_23_02_11_2022 || INFO || archiveLogs || Collected logs available at: C:\Users\tester\AppData\Local\Temp\2\Nina1-win2
012R2_10_23_02_11_2022.zip
```

### Linux platform
incoming

