[GC-Troubleshooter](#gc-troubleshooter)
  * [Overview](#overview)
    + [Note:](#note-)
  * [Usage](#usage)
  * [Log collection](#log-collection)
    + [Windows platform (support Arc servers)](#windows-platform--support-arc-servers-)
    + [Linux platform (support Arc servers)](#linux-platform--support-arc-servers-)

# GC-Troubleshooter
Guest configuration troubleshooter tool including log collection

## Overview
This tool will help you to identify some Azure Guest Configuration policy deployment issues.

In this tool, we have below options to select:
```
1: Check RP Microsoft.GuestConfiguration registration
2: Check Guest configuration extension
3: Check managed identity
4: Check Guest configuration policy errors
5: Check Non compliant policies on a given VM
6: Check above all
7: Collect logs
Q: Press 'Q' to quit.
```

### Note: 
With option 6, we will check:
* Microsoft.GuestConfiguration registration
* Guest configuration extension provisioning status
* Managed identity enabled
* Policy assignment permission if its effect is 'DeployIfNotExists'
* Policy rule OS image template (just for reference)
* Non compliant policies with reason

## Usage
Sample 1 (recommended):
```
.\GCTroubleshooter.ps1 -ResourceGroupName <resource group name of VM> -VMName <VM name>
```
  
Sample 2:
```
$myVM = Get-AzVM -ResourceGroupName <resource group name of VM> -Name <VM name>
.\GCTroubleshooter.ps1 -VM $myVM
```

Sample output:
```
=====================================================================
Please select an option: 6
You selected option #6
Microsoft.GuestConfiguration is registered under current subscription
MSI is enabled on this VM
Checking for extension "AzurePolicyForWindows"...
The extension "AzurePolicyForWindows" was not deployed successfully or was not deployed at all, reference: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/guest-configuration
===Non Compliant policy checking===
Would you still like to continue?
There are 13 non compliant policies assigned to this scope, so this test will take some time.
[Y] Yes [N] No [S] Suspend [?] Help (default is "Yes"): 
Found Guest Configuration policy : Deploy the Windows Guest Configuration extension to enable Guest Configuration assignments on Windows VMs
Assignment name: xxx
Assignment Id: /subscriptions/xxx/resourcegroups/test-rg/providers/microsoft.authorization/policyassignments/xxx
Definition Id: /providers/microsoft.authorization/policydefinitions/xxx
Applies to : /subscriptions/xxx/resourcegroups/test-rg/providers/microsoft.compute/virtualmachines/2016core
Non compliant reason : ResourceNotFound
......
Found Guest Configuration policy : Windows web servers should be configured to use secure communication protocols
Assignment name: SecurityCenterBuiltIn
Assignment Id: /subscriptions/xxx/providers/microsoft.authorization/policyassignments/securitycenterbuiltin
Definition Id: /providers/microsoft.authorization/policydefinitions/xxx
Applies to : /subscriptions/xxx/resourcegroups/test-rg/providers/microsoft.compute/virtualmachines/2016core
Non compliant reason : GCExtensionInstalled=False;MSIEnabled=True;UserIdentityEnabled=False
......
Would you still like to continue?
There are 14 policies assigned to this scope, so this test will take some time.
[Y] Yes [N] No [S] Suspend [?] Help (default is "Yes"):
Found Guest Configuration policy : Add system-assigned managed identity to enable Guest Configuration assignments on virtual machines with no identities
Below VMs are not applicable to this definition 3cf2ab00-13f1-4d0c-8971-2ac904541a7e : 2016core suse15 , so they may be non-compliant after assignment
Found Guest Configuration policy : Deploy prerequisites to enable Guest Configuration policies on virtual machines
Policy was in an initiative
Checking permission of policy effect DeployIfNotExists for assignment 9d055037ceaa4b6791d1b02f
/subscriptions/xxx/resourceGroups/test-rg/providers/Microsoft.Authorization/roleAssignments/xxx has permission of Contributoron scope /subscriptions/xxx/resourceGroups/test-rg
/subscriptions/xxx/resourceGroups/test-rg/providers/Microsoft.Authorization/roleAssignments/xxx has permission of Contributoron scope /subscriptions/xxx/resourceGroups/test-rg
Below VMs are not applicable to one of this initiative defintions xxx : 2016core suse15 , so they may be non-compliant after assignment    
Found Guest Configuration policy : Add system-assigned managed identity to enable Guest Configuration assignments on virtual machines with no identities
Below VMs are not applicable to this definition xxx : 2016core suse15 , so they may be non-compliant after assignment
The policy "Add system-assigned managed identity to enable Guest Configuration assignments on virtual machines with no identities" is not in an initiative

Name                           Value
----                           -----
CheckResults                   {True, @{Status=True; Name=MSI}, @{Status=False; Name=GuestConfigurationExtension; Details=System.Collections.Hashtable; Errors=System.Obje… 
Messages                       {The Guest Configuration Extension on this machine is not healthy, There is non-compliant policy on this VM}
OverallStatus                  False
```

## Log collection

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
For linux, run this command to collect logs: wget https://raw.githubusercontent.com/MSNina123456/GC-Troubleshooter/main/GCLogCollection.sh&& bash ./GCLogCollection.sh
```
If you select option #7, it will print out command for log collection. Of course, you can run command directly in OS as below.

### Windows platform (support Arc servers)
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

### Linux platform (support Arc servers)
login linux OS and run this command: 
```
wget https://raw.githubusercontent.com/MSNina123456/GC-Troubleshooter/main/GCLogCollection.sh&& bash ./GCLogCollection.sh
```

Output 
1. dowonload:
```
--2022-02-23 13:58:32--  https://raw.githubusercontent.com/MSNina123456/GC-Troubleshooter/main/GCLogCollection.sh
Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 2606:50c0:8000::154, 2606:50c0:8001::154, 2606:50c0:8002::154, ...
Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|2606:50c0:8000::154|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 6623 (6.5K) [text/plain]
Saving to: ‘GCLogCollection.sh’

      GCLog   0%       0  --.-KB/s              GCLogCollec 100%   6.47K  --.-KB/s    in 0s     

2022-02-23 13:58:32 (28.4 MB/s) - ‘GCLogCollection.sh’ saved [6623/6623]
```
2. log collection:
```
=================================================
Tool log data is being redirecting to /tmp/GCLogCollector.1645595912.nina-ubuntu16
23-02-2022T13:58:32 +08 || INFO || python_prereq_check || Checking Python version and module
23-02-2022T13:58:34 +08 || INFO || isArc || This is Arc server, will collect Arc GC logs
23-02-2022T13:58:34 +08 || INFO || CollectExtensionLogs || Collecting arc agent logs
23-02-2022T13:58:34 +08 || INFO || CollectExtensionLogs || Collecting guest configuration extension logs
23-02-2022T13:58:49 +08 || INFO || ArchiveLogs || Data collection completed
23-02-2022T13:58:50 +08 || INFO || ArchiveLogs || Analyzing collected logs for errors
23-02-2022T13:58:53 +08 || WARN || CheckLogsForErrors || Found errors in logs, stored all error messages under path: /GCLogCollector.1645595912.nina-ubuntu16/error.log
23-02-2022T13:59:03 +08 || INFO || ArchiveLogs || Collected logs available at: /tmp/GCLogCollector.1645595912.nina-ubuntu16.tgz
```
