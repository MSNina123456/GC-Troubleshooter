
<#PSScriptInfo

.VERSION 1.1

.GUID 2ee13691-ae21-4ddb-b40e-d3d14e7da49b

.AUTHOR nali2@microsoft.com

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#> 



<# 

.DESCRIPTION 
Guest Configuration log collector tool

#> 

Param()


# Guest Configuration log collector tool

###########################################################
#                                                         #
#    Copyright (C) Microsoft. All rights reserved.        #
#                                                         #
###########################################################

$ErrorActionPreference = "SilentlyContinue"
$global:useLogFile = $true
$global:logFile = ""

[string]$global:defaultOutputDir = ""

Set-Variable REGEXE -Value ([string] "$($env:systemroot)\system32\reg.exe")
Set-Variable REGEDIT -Value ([string] "$($env:systemroot)\regedit.exe")

function enableScriptExecution
{
    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Setting script execution policy to unrestricted."

    try
    {
        Set-ExecutionPolicy Unrestricted
    }
    catch 
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Failed to set script's execution policy."
    }
}

function Get-Timestamp
{
    $timestamp = (Get-Date).ToString("hh_mm_MM_dd_yyyy")
    return $timestamp
}

function Get-TemporaryDirectoryLocation
{
    [OutputType([String])]
    Param ($tempPath)

    $dirName = $env:computername
    $dirName += "_"
    $dirName += Get-Timestamp
    $path = ""

    try 
    {
        $path = [System.IO.Path]::GetTempPath() + $dirName    
    }
    catch 
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
    }

    return $path    
}

Function Write-Log
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory=$True)]
        [String]
        $FunctionName,

        [Parameter(Mandatory=$True)]
        [AllowEmptyString()]
        [String]
        $Message
    )

    $timestamp = Get-Timestamp
    $log = "$timestamp || $Level || $FunctionName || $Message"
    if($global:uselogfile)
    {
        Add-Content $global:logfile -Value $log
        Write-Output $log
    }
    else 
    {
        Write-Output $log
    }
}
function init
{
    enableScriptExecution

    $global:defaultOutputDir = (Get-TemporaryDirectoryLocation).ToString()
    if($true -eq [string]::IsNullOrEmpty($global:defaultOutputDir))
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Default output dir empty: $global:defaultOutputDir"
        throw 'init failed'
    }
    New-Item -Path $global:defaultOutputDir -ItemType "directory" -Force | Out-Null
    $global:logFile = $global:defaultOutputDir + "\..\tool.log"

    if (Test-Path $global:logFile)
    {
        Write-Output "Removing tool's old log file."
        Remove-Item $global:logFile -Force
    }
    
    if($True -eq $global:useLogFile)
    {
        Write-Output "Tool's log data is being redirected to $global:logFile"
    }    

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Starting data collection."
}

function Get-SystemData
{   
   Write-Log -FunctionName $MyInvocation.MyCommand -Message "Collecting system information..."

   $SysInfoDestination = "$global:defaultOutputDir\sysinfo.log"
   try
   {
        systeminfo | Out-File $SysInfoDestination
        Write-Log -FunctionName $MyInvocation.MyCommand -Message "System information collected."
   }
   catch 
   {
        Write-Log -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
        Write-Log -FunctionName $MyInvocation.MyCommand -Message "Failed to collect system information."
   }
}

function CollectSystemData
{    
    Get-SystemData
}

function CollectExtensionLogs
{ 

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Collecting extension logs"

    try
    {
        $extensionLogsDestination = "$global:defaultOutputDir\ExtensionLogs"

        New-Item -Path $extensionLogsDestination -ItemType "directory" -Force | Out-Null

        $path1 = "C:\WindowsAzure\Logs\Plugins\Microsoft.GuestConfiguration.ConfigurationforWindows"
        Copy-Item $path1 -Destination $extensionLogsDestination -Recurse | Out-Null

        $path2 = Get-ChildItem -Path 'C:\Packages\Plugins\Microsoft.GuestConfiguration.ConfigurationforWindows\*\Status' -recurse
        Copy-Item -Path $path2 -Destination $extensionLogsDestination -Recurse

        $path3 = Get-ChildItem -Path 'C:\Packages\Plugins\Microsoft.GuestConfiguration.ConfigurationforWindows\*\RuntimeSettings' -recurse
        Copy-Item -Path $path3 -Destination $extensionLogsDestination -Recurse

        $path4 = Get-ChildItem -Path 'C:\Packages\Plugins\Microsoft.GuestConfiguration.ConfigurationforWindows\*\*.json'
        Copy-Item -Path $path4 -Destination $extensionLogsDestination -Recurse

        $path5 = Get-ChildItem -Path 'C:\Packages\Plugins\Microsoft.GuestConfiguration.ConfigurationforWindows\*\*.xml'
        Copy-Item -Path $path5 -Destination $extensionLogsDestination -Recurse

        $vmAgentLogFile = "C:\WindowsAzure\logs\WaAppAgent.log"
        if(!(Test-Path -Path $vmAgentLogFile))
        {
            Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "VM agent log file does not exist. Path: $vmAgentLogFile"
        }
        else 
        {
            Copy-item $vmAgentLogFile $extensionLogsDestination | Out-Null
        }
    }
    catch 
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Failed to collect installer logs from: $extensionLogsDestination"
    }
}

function Get-EventViewerLogs
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [String]
        $Source,

        [Parameter(Mandatory=$True)]
        [String]
        $OutputFile
    )

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Collecting event logs from: $Source"

    try 
    {
        $log = Get-WmiObject Win32_NTEventlogFile -Filter "LogFileName = ""$Source"""
        $log.BackupEventLog($OutputFile) | Out-Null
        if($True -eq $?)
        {
            Write-Log -FunctionName $MyInvocation.MyCommand -Message "Logs from source: $Source, stored at: $OutputFile"
        }
    }
    catch 
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Failed to collect event logs from: $Source"
    }
}

function Get-AllDscEvents
{
    param
    (
        [string[]]$ChannelType = @("Debug" , "Analytic" , "Operational") ,
        $OtherParameters = @{ }
    )

    if ($ChannelType.ToLower().Contains("operational"))
    {
        $operationalEvents = Get-WinEvent -LogName "Microsoft-Windows-DSC/operational"  @OtherParameters -ea Ignore
        $allEvents = $operationalEvents
    }

    if ($ChannelType.ToLower().Contains("analytic"))
    {
        $analyticEvents = Get-WinEvent -LogName "Microsoft-Windows-DSC/analytic" -Oldest  -ea Ignore @OtherParameters
        if ($analyticEvents -ne $null)
        {
            #Convert to an array type before adding another type - to avoid the error "Method invocation failed with no op_addition operator"
            $allEvents = [System.Array]$allEvents + $analyticEvents
        }
    }

    if ($ChannelType.ToLower().Contains("debug"))
    {
        $debugEvents = Get-WinEvent -LogName "Microsoft-Windows-DSC/debug" -Oldest -ea Ignore @OtherParameters
        if ($debugEvents -ne $null)
        {
            $allEvents = [System.Array]$allEvents + $debugEvents

        }
    }

    return $allEvents
}

function CollectAllDSCEvents
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [String]
        $Source,

        [Parameter(Mandatory=$True)]
        [String]
        $OutputFile
    )

    #$DSCLogsDestination = "$global:defaultOutputDir\DSC.log"
    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Collecting DSC event logs from: $Source"

    try
    {
        $allEvents = Get-AllDscEvents
        if (!$allEvents)
        {
            Write-Output "Error : Could not find any events. Either a DSC operation has not been run, or the event logs are turned off . Please ensure the event logs are turned on in DSC. To set an event log, run the command wevtutil Set-Log <channelName> /e:true, example: wevtutil set-log 'Microsoft-Windows-Dsc/Operational' /e:true /q:true"
            return
        }
        $groupedEvents = $allEvents | Group-Object {
            $_.Properties[0].Value
        }

        for([int] $i = 0; $i -lt $groupedEvents.Count; ++$i)
        {
            $groupedEvents[$i].Group | Format-List TimeCreated, Id, LevelDisplayName, MachineName, ActivityId, Message | Out-File $OutputFile
        }

        if($True -eq $?)
        {
            Write-Log -FunctionName $MyInvocation.MyCommand -Message "Logs from source: $Source, stored at: $OutputFile, run this command if you would more logs of DSC: Find-Module xDSCDiagnostics | Install-Module; New-xDscDiagnosticsZip"
        }
    }
    catch 
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Failed to collect event logs from: $Source"
    }
    
}

function CollectEventLogs
{
    $eventsDirectory = "$global:defaultOutputDir\Event Logs"
    if ($False -eq (Test-Path $eventsDirectory) )
    {
        New-Item -Path $eventsDirectory -ItemType "directory" -Force | Out-Null
    }    

    $eventsSource = "Application"
    Get-EventViewerLogs -Source $eventsSource -OutputFile $eventsDirectory\$eventsSource.evtx

    $eventsSource = "System"
    Get-EventViewerLogs -Source $eventsSource -OutputFile $eventsDirectory\$eventsSource.evtx

    $eventsSource = "Microsoft-Windows-Dsc"
    CollectAllDSCEvents -Source $eventsSource -OutputFile $eventsDirectory\$eventsSource.log
}

function CheckLogsForErrors
{
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $OutputFile
    )

    try
    {
        Get-ChildItem -Path $global:defaultOutputDir\* -recurse -exclude *.dmp,*.exe,*.etl, *.dll | Select-String -List error | Format-List * | Out-File -FilePath $OutputFile
    }
    catch
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Failed to CheckLogsForErrors."
        Write-Log -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
    }
}

function Create-Zip
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [String]
        $Source,

        [Parameter(Mandatory=$True)]
        [String]
        $Destination
    )

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Compressing logs collected in folder: $Source"
    
    try 
    {
        Add-Type -Path "C:\Windows\Microsoft.Net\assembly\GAC_MSIL\System.IO.Compression.FileSystem\v4.0_4.0.0.0__b77a5c561934e089\System.IO.Compression.FileSystem.dll"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Source, $Destination, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    }
    catch 
    {
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Exception: $_.Exception.Message"
        Write-Log -Level "Error" -FunctionName $MyInvocation.MyCommand -Message "Failed to create zip with path: $Destination"
        Write-Log -FunctionName $MyInvocation.MyCommand -Message "Collected logs are stored at: $Source. Please manually zip the folder."
        exit
    }    
}

function archiveLogs
{
    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Data collection completed."

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Analyzing collected logs for errors."
    $analysisResultsFile = "$global:defaultOutputDir\errors.txt"
    CheckLogsForErrors -OutputFile $analysisResultsFile

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Analysis completed and written to file: $analysisResultsFile"

    Copy-Item "$global:defaultOutputDir\..\tool.log" -Destination $global:defaultOutputDir

    Create-Zip -Source "$global:defaultOutputDir" -Destination "$global:defaultOutputDir.zip"

    Remove-Item -Recurse -Force -Path $global:defaultOutputDir

    Write-Log -FunctionName $MyInvocation.MyCommand -Message "Collected logs available at: $global:defaultOutputDir.zip"

    Invoke-Expression "explorer '/select,$global:defaultOutputDir.zip'"
}

function main
{
    init
    CollectSystemData
    CollectExtensionLogs
    CollectEventLogs
    archiveLogs
}

main
