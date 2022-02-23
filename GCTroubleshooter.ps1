[CmdletBinding(DefaultParameterSetName = "Default")]
param(
    [parameter(ParameterSetName = "Scoped", Mandatory = $true)][ValidateNotNullOrEmpty()][String]$ResourceGroupName,
    [parameter(ParameterSetName = "Scoped", Mandatory = $true)][ValidateNotNullOrEmpty()][String]$VMName,
    [parameter(ParameterSetName = "Default", Mandatory = $true)][ValidateNotNullOrEmpty()]$VM,
    [parameter(Mandatory=$false)][switch]$ComplianceCheck,
    [parameter(Mandatory=$false)][switch]$Force
)

<#
.SYNOPSIS

Check if RP Microsoft.GuestConfiguration is registered
    
.DESCRIPTION

This script gets and prints if RP Microsoft.GuestConfiguration is registered. 

.EXAMPLE

PS> Get-RPRegister
#>
function Get-RPRegister
{
    $success = $true
    $reg = Get-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration | Where-Object {$_.RegistrationState -notlike "Registered"}

    if(-not([string]::IsNullOrEmpty($reg)))
    {
        Write-Host "Microsoft.GuestConfiguration is not registered under current subscription, please register it firstly. Reference: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider"
        $success = $false
        return $success
    }
    else
    {
        Write-Host "Microsoft.GuestConfiguration is registered under current subscription"
    }
    return $success
}

<#
.SYNOPSIS

Gets the properties of the GuestConfig Extension on a specified VM
    
.DESCRIPTION

This script gets and prints the properties of the GuestConfig Extension on a specified windows
or linux vm. 

.PARAMETER ResourceGroupName
The Resource Group the VM is in

.PARAMETER VMName
The VM to get the GuestConfig Extension from

.EXAMPLE

PS> Get-VmGuestConfigExtensionProperties -ResourceGroupName "MyResourceGroup" -VMName "MyVM"
#>
function Get-VmGuestConfigExtensionProperties
{
    [CmdletBinding()]
    param(
        [parameter(ParameterSetName = "Scoped", Mandatory=$true)][ValidateNotNullOrEmpty()][String]$ResourceGroupName,
        [parameter(ParameterSetName = "Scoped", Mandatory=$true)][ValidateNotNullOrEmpty()][String]$VMName,
        [parameter(ParameterSetName = "NonScoped", Mandatory=$true)][ValidateNotNullOrEmpty()]$VM
    )

    $returnObject = [PSCustomObject](@{Name = "GuestConfigurationExtension"; Status = $true})

    #Check if the resource group exists
    if($ResourceGroupName -and -not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue))
    {
        throw "The given Resource Group could not be found"
    }

    #Get the VM to check whether it is linux or windows
    if(-not($VM))
    {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    }
    else
    {
        $ResourceGroupName = $VM.ResourceGroupName
        $VMName = $VM.Name
    }
    $name = "AzurePolicyForWindows"

    if(-not($vm))
    {
        throw "The given VM could not be found in that Resource Group"
    }

    #If it is a windows machine
    if($vm.OSProfile.WindowsConfiguration)
    {
        #Get the extension
        $ext = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "AzurePolicyforWindows" -ErrorAction SilentlyContinue
        $testExt = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "AzurePolicyforLinux" -ErrorAction SilentlyContinue
        if($testExt)
        {
            Write-Host "This Linux VM has the Windows version of the Guest Configuration Extension installed"
            $returnObject | Add-Member -NotePropertyName "Errors" -NotePropertyValue @()
            $returnObject.Errors += "That Windows VM has the Linux version of the Guest Configuration Extension installed"
            $returnObject.Status = $false
            return $returnTable
        }
    }
    #Otherwise if it is a linux machine
    elseif($vm.OSProfile.LinuxConfiguration)
    {
        #Get the extension
        $ext = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "AzurePolicyforLinux" -ErrorAction SilentlyContinue
        $name = "AzurePolicyForLinux"
        $testExt = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "AzurePolicyforWindows" -ErrorAction SilentlyContinue
        if($testExt)
        {
            Write-Host "This Linux VM has the Windows version of the Guest Configuration Extension installed"
            $returnObject | Add-Member -NotePropertyName "Errors" -NotePropertyValue @()
            $returnObject.Errors += "That Linux VM has the Windows version of the Guest Configuration Extension installed"
            $returnObject.Status = $false
            return $returnObject
        }
    }
    else
    {
        Write-Host "That VM's OS is not supported by Guest Configuration, reference: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/guest-configuration#supported-client-types"
        $returnObject | Add-Member -NotePropertyName "Errors" -NotePropertyValue @()
        $returnObject.Errors += "That VM's OS is not supported by Guest Configuration"
        $returnObject.Status = $false
        return $returnObject
    }

    $returnObject | Add-Member -NotePropertyName "Details" -NotePropertyValue @{}

    $returnObject.Details['Extension'] = $ext

    Write-Host ("Checking for extension `"" + $name + "`"...")

    #If the extension is deployed
    if($ext)
    {
        Write-Host ("The extension `"" + $name + "`" was deployed successfully")

        #Check the provisioning state
        if($ext.ProvisioningState -eq "Succeeded")
        {
            Write-Host "Provisioning succeeded"
        }
        else
        {
            $warningString = "Provisioning did not succeed, provisioning state is: " + $ext.ProvisioningState
            Write-Host $warningString
            $returnObject.Status = $false

            if($ext.ProvisioningState -eq "Not Started" -or $ext.ProvisioningState -eq "In Progress" -or $ext.ProvisioningState -eq "Updating")
            {
                $returnObject | Add-Member -NotePropertyName "Warnings" -NotePropertyValue @()

                $returnObject.Warnings += "Deployment for this extension is still in progress, wait for a couple minutes"
            }
            elseif($ext.ProvisioningState -eq "Failed")
            {
                $returnObject | Add-Member -NotePropertyName "Errors" -NotePropertyValue @()

                $returnObject.Errors += "Provisioning for this extension has failed, try running a remediation task"
            }
        }


    }
    else
    {
        $warningString = "The extension `"" + $name + "`" was not deployed successfully or was not deployed at all, reference: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/guest-configuration"
        Write-Host $warningString
        $returnObject | Add-Member -NotePropertyName "Errors" -NotePropertyValue @()

        $returnObject.Errors += $warningString
        $returnObject.Status = $false
    }

    return $returnObject

}

<#
.SYNOPSIS

Gets the MSI Status of a VM
    
.DESCRIPTION

This script gets and returns the MSI Status of a specified VM in a specified Resource Group

.PARAMETER ResourceGroupName
The Resource Group the VM is in

.PARAMETER VMName
The VM to check the MSI status of

.EXAMPLE

PS> Test-VmMSIEnabled -ResourceGroupName "MyResourceGroup" -VMName "MyVM"
#>
function Get-VmMSIEnabled
{
    [CmdletBinding()]
    param(
        [parameter(ParameterSetName = "Scoped", Mandatory=$true)][ValidateNotNullOrEmpty()][String]$ResourceGroupName,
        [parameter(ParameterSetName = "Scoped", Mandatory=$true)][ValidateNotNullOrEmpty()][String]$VMName,
        [parameter(ParameterSetName = "NonScoped", Mandatory=$true)][ValidateNotNullOrEmpty()]$VM
    )

    $returnObj = [PSCustomObject](@{
                        Name = "MSI"
                        Status = $true
                 })

    #Check if the resource group exists
    if($ResourceGroupName -and -not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue))
    {
        throw "The given Resource Group could not be found"
    }

    #Get the VM to check MSI status
    if(-not($VM))
    {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    }

    #Check if the VM was found
    if(-not($vm))
    {
        throw "The given VM could not be found in that Resource Group"
    }

    if($vm.Identity.Type -eq "SystemAssigned")
    {
        Write-Host "MSI is enabled on this VM"
    }
    else
    {
        Write-Host "MSI is not enabled on this VM"
        Write-Host "Enabling System Managed Identity is needed for Guest Configuration Policy scenarios"
        $returnObj | Add-Member -NotePropertyName "Errors" -NotePropertyValue @()
        $returnObj.Errors += "MSI is not enabled on this VM"
        $returnObj.Errors += "Enabling System Managed Identity is needed for Guest Configuration Policy scenarios"
        $returnObj.Status = $false
    }

    return $returnObj
}

function CheckAssignmentPermissions
{
    param([parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$assignment,
          [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$definition,
          [parameter(Mandatory = $false)][switch]$initiative)


    
    $roleIds = @()

    #If it's an initiative, get the role definition ids from each DINE policy in the initiative and store them in the roleIds array
    if($initiative)
    {
        for([int] $i = 0; $i -lt $definition.Properties.policyDefinitions.Count; ++$i)
        {
            $def = Get-AzPolicyDefinition -Id $definition.Properties.policyDefinitions[$i].policyDefinitionId

            if($def.Properties.policyRule.then.effect -eq "DeployIfNotExists")
            {
                foreach($id in $def.Properties.policyRule.then.details.roleDefinitionIds)
                {
                    $roleIds += $id
                }
            }
        }
    }
    else
    {
        if($definition.Properties.policyRule.then.effect -eq "DeployIfNotExists")
        {
            foreach($id in $definition.Properties.policyRule.then.details.roleDefinitionIds)
            {
                $roleIds += $id
            }
        }
    }

    #Get all role assignments linked to this policy assignment
    $roleAssignments = Get-AzRoleAssignment -ObjectId $assignment.Identity.principalId -ErrorAction SilentlyContinue

    Write-Host ("Checking permission of policy effect DeployIfNotExists for assignment " + $roleAssignments.DisplayName)
    if($roleAssignments)
    {
        if($roleIds.Count -gt 0)
        {
            $success = $false
            $safeIndeces = @()
            if($roleAssignments.Count -gt 1)
            {
                for($i = 0; $i -lt $roleAssignments.Count; ++$i)
                {
                    for($j = 0; $j -lt $roleIds.Count; ++$j)
                    {
                        #if they do match
                        if($roleIds[$j].Contains($roleAssignments[$i].RoleDefinitionId))
                        {
                            Write-Host ($roleAssignments[$i].RoleAssignmentId + " has permission of " + $roleAssignments[$i].RoleDefinitionName + " on scope " + $roleAssignments[$i].Scope)
                            $safeIndeces += $i
                        }
                    } 
                }

                if($safeIndeces.Count -eq $roleAssignments.Count)
                {
                    $success = $true
                }
            }
            else
            {
                $success = $false
                for($i = 0; $i -lt $roleIds.Count; ++$i)
                {
                    if($roleIds[$i].Contains($roleAssignments.RoleDefinitionId))
                    {
                        Write-Host ($roleAssignments.RoleAssignmentId + " has permission of " + $roleAssignments.RoleDefinitionName + "on scope " + $roleAssignments.Scope)
                        $success = $true
                    }
                }
            }

            if(-not($success))
            {
                Write-Host ("The policy `"" + $definition.Properties.displayName + "`" does not have the correct roles assigned to it")
               return ("This policy does not have the correct roles assigned to it")
            }
        }
        <#
        else 
        {
            Write-Host "There is not assignment with policy effect DeployIfNotExists, skipping permission check"
        }
        #>
    }
    else
    {
        Write-Host ("The policy `"" + $definition.Properties.displayName + "`" does not have any roles assigned to it")
        return "This policy does not have any roles assigned to it"
    }

    return

}

#Check a policy condition template against a VM's image reference
function CheckConditions
{
    param(
        [parameter(Mandatory = $true)]$ImageRef,
        [parameter(Mandatory = $true)]$conditionTemplate
    )

    #Get the anyOf to compare stuff with
    if($conditionTemplate.if.anyOf)
    {
        $toCheck = $conditionTemplate.if.anyOf
    }
    elseif($conditionTemplate.if.allOf)
    {
        foreach($condition in $conditionTemplate.if.allOf)
        {
            if($condition.anyOf)
            {
                $toCheck = $condition.anyOf
                break
            }
        }
    }

    foreach($condition in $toCheck)
    {

        if($condition.allOf)
        {
            $allOfStatus = $true
            foreach($condition2 in $condition.allOf)
            {
                #Write-Host $condition2.field
                #set a compare property based on the field
                if($condition2.field -eq "Microsoft.Compute/imageSKU")
                {
                    $compareProperty = $ImageRef.SKU
                }
                elseif($condition2.field -eq "Microsoft.Compute/imagePublisher")
                {
                    $compareProperty = $ImageRef.Publisher
                }
                elseif($condition2.field -eq "Microsoft.Compute/imageOffer")
                {
                    $compareProperty = $ImageRef.Offer
                }

                #Check all the possible conditions
                if($condition2.in)
                {
                    #Write-Host "in"
                    if(-not($condition2.in.contains($compareProperty)))
                    {
                        $allOfStatus = $false
                    }
                }
                elseif($condition2.notlike)
                {
                    #Write-Host "notlike"
                    if($condition2.notLike -like $compareProperty)
                    {
                        $allOfStatus = $false
                    }
                }
                elseif($condition2.notEquals)
                {
                    #Write-Host "notEquals"
                    if($condition2.notEquals -eq $compareProperty)
                    {
                        $allOfStatus = $false
                    }
                }
                elseif($condition2.like)
                {
                    #Write-Host "like"
                    if($condition2.like -notlike $compareProperty)
                    {
                        $allOfStatus = $false
                    }
                }
                elseif($condition2.equals)
                {
                    #Write-Host "equals"
                    if($condition2.equals -ne $compareProperty)
                    {
                        $allOfStatus = $false
                    }
                }
            }

            if($allOfStatus)
            {
                return $true
            }
        }        
        else
        {
            if($condition.field -eq "Microsoft.Compute/imageSKU")
            {
                $compareProperty = $ImageRef.SKU
            }
            elseif($condition.field -eq "Microsoft.Compute/imagePublisher")
            {
                $compareProperty = $ImageRef.Publisher
            }
            elseif($condition.field -eq "Microsoft.Compute/imageOffer")
            {
                $compareProperty = $ImageRef.Offer
            }

            #Check all the possible conditions
            if($condition2.in)
            {
                #Write-Host "in"
                if($condition2.in.contains($compareProperty))
                {
                    return $true
                }
            }
            elseif($condition2.notlike)
            {
                #Write-Host "notlike"
                if($condition2.notLike -notlike $compareProperty)
                {
                    return $true
                }
            }
            elseif($condition2.notEquals)
            {
                #Write-Host "notEquals"
                if($condition2.notEquals -ne $compareProperty)
                {
                    return $true
                }
            }
            elseif($condition2.like)
            {
                #Write-Host "like"
                if($condition2.like -like $compareProperty)
                {
                    return $true
                }
            }
            elseif($condition2.equals)
            {
                #Write-Host "equals"
                if($condition2.equals -eq $compareProperty)
                {
                    return $true
                }
            }
        }
    }

    return $false
   

}

<#
.SYNOPSIS

Returns a list of VM's that the passed definition (or any built-in Guest Configuration policies) could not be applied to
    
.DESCRIPTION

This cmdlet gets checks all of the imaging conditions of a windows and linux built-in Guest Configuration policies (or a passed policy definition)
against a list of given VMs, and returns any VMs that did not pass the check

.PARAMETER VMList
The list of VMs to check (this should be a list of VM objects, not names)

.PARAMETER PolicyDefinition
This parameter allows you to check the imaging conditions of a specific policy instead of built-in in-guest policies

.EXAMPLE

PS> $vms = Get-AzVM -ResourceGroupName "MyResourceGroup"
Get-NonApplicableVMs -VMList $vms

.EXAMPLE

PS> $vms = Get-AzVM -ResourceGroupName "MyResourceGroup"
$def = Get-AzPolicyDefinition -Id "PolicyDefinitionGUID"
Get-NonApplicableVMs -VMList $vms -PolicyDefinition $def
#>
function Get-NonApplicableVMs
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$VMList,
        [parameter()][ValidateNotNullOrEmpty()]$PolicyDefinition)


    $unapplicableList = @()

    #Use built-in definiton requirements

    $winfile = Test-Path -Path ($PSScriptRoot + "\WindowsConditionTemplate.json")
    $linuxfile = Test-Path -Path ($PSScriptRoot + "\LinuxConditionTemplate.json")

    if($winfile -and $linuxfile)
    {
        $windowsTemplate = Get-Content -Path ($PSScriptRoot + "\WindowsConditionTemplate.json") | ConvertFrom-Json -ErrorAction Stop
        $linuxTemplate = Get-Content -Path ($PSScriptRoot + "\LinuxConditionTemplate.json") | ConvertFrom-Json -ErrorAction Stop
    }
    else
    {
        Write-Host "default template files don't exist, please donwload them (.json) firstly, skip OS template check"
        return $false
    }

    #Check using windows template
    foreach($vm in $VMList)
    {

        #Write-Host $vm.Name

        $currStatus = $false

        $imgRef = $vm.StorageProfile.ImageReference

        if($PolicyDefinition)
        {
            if($PolicyDefinition.Properties.policyRule)
            {
                $currStatus = CheckConditions -ImageRef $imgRef -conditionTemplate $PolicyDefinition.Properties.policyRule -ErrorAction SilentlyContinue
            }
        }
        else
        {
            $currStatus = (CheckConditions -ImageRef $imgRef -conditionTemplate $windowsTemplate) -or (CheckConditions -ImageRef $imgRef -conditionTemplate $linuxTemplate)
        }
        if($currStatus -eq $false)
        {
            $unapplicableList += $vm.Name
                
        }
        

    }

    return $unapplicableList

}

<#
.SYNOPSIS

Check Non-compliant Guest Configuration policy and prints reasons
    
.DESCRIPTION

This script checks all Guest Configuration policies in a given VM
and prints Non-compliant reasons of its Guest Configuration policy

.PARAMETER ResourceGroupName
The Resource Group to run tests in

.PARAMETER VMName
The VM to run tests on

.PARAMETER VM
VM to check (this will also let the cmdlet automatically get the resource group from the VM)

.EXAMPLE

PS> Get-Compliance -ResourceGroupName "MyResourceGroup" -VMName "MyVM"

.EXAMPLE

PS> $myVM = Get-AzVM -ResourceGroupName "MyResourceGroup" -Name "MyVM"
Get-Compliance -VM $myVM
#>
function Get-Compliance
{
    #this function is an abomination
    [CmdletBinding()]
    param(
        [parameter(ParameterSetName = "Scoped", Mandatory = $true)][ValidateNotNullOrEmpty()][String]$ResourceGroupName,
        [parameter(ParameterSetName = "Scoped", Mandatory = $true)][ValidateNotNullOrEmpty()][String]$VMName,
        [parameter(ParameterSetName = "NotScoped", Mandatory = $true)][ValidateNotNullOrEmpty()]$VM,
        [parameter(Mandatory=$false, position = 1)][switch]$ComplianceCheck
    )

    #Check if the resource group exists (MSIEnabled and ExtensionProperties will check the VM)
    if($ResourceGroupName -and -not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue))
    {
        throw "The given Resource Group could not be found"
    }

    Write-Host "===Non Compliant policy checking==="
    if(-not($VM))
    {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    }

    if(-not($vm))
    {
        throw "The given VM could not be found in that Resource Group"
    }

    $success = $false
    $res = Get-AzPolicyState -ResourceId $vm.Id -Filter "ComplianceState eq 'NonCompliant'"

    if($res.Count -gt 10)
    { 
        if(-not($ComplianceCheck) -and -not($PSCmdlet.ShouldContinue(("There are " + $res.Count + " non compliant policies assigned to this scope, so this test will take some time."), "Would you still like to continue?")))
        {
            Write-Host "User has chosen to skip this check"
            return @{Status = $false}
        }
    }

    foreach ($p in $res)
    {
        $reason = $p.AdditionalProperties.Values

        if(-not [string]::IsNullOrEmpty($reason))
        {
            $id = $p.PolicyDefinitionId
            $defN = Get-AzPolicyDefinition -Id $id -ErrorAction SilentlyContinue
            $def = Get-AzPolicySetDefinition -Id $id -ErrorAction SilentlyContinue
            #Check if it is a Guest Configuration Policy
            if($defN.Properties.metadata.category -eq "Guest Configuration" -or $def.Properties.metadata.category -eq "Guest Configuration")
            {
                Write-Host ("Found Guest Configuration policy : " + $def.Properties.DisplayName + $defN.Properties.DisplayName)
                Write-Host ("Assignment name: " + $p.PolicyAssignmentName)
                Write-Host ("Assignment Id: " + $p.PolicyAssignmentId)
                Write-Host ("Definition Id: " + $id)
                Write-Host ("Applies to : " + $p.ResourceId)
                Write-Host ("Non compliant reason : " + $p.AdditionalProperties.Values)
                Write-Host "......"
                $success = $true
            }

        }
    }
    return $success
}



<#
.SYNOPSIS

Prints warnings and errors for any Guest Configuration policies that were assigned incorrectly
    
.DESCRIPTION

This script checks all Guest Configuration policies in a given resource group or subscription
and prints warnings and errors if any of them were assigned incorrectly

.PARAMETER ResourceGroupName
The Resource Group to check policies in

.PARAMETER Subscription
Switch parameter that allows you to check the policy assignments in the current subscription
(Context based)

.PARAMETER Force
Switch parameter that allows you to skip any required input

.EXAMPLE

PS> Get-GuestConfigPolicyErrors -ResourceGroupName "MyResourceGroup"

.EXAMPLE

PS> Get-GuestConfigPolicyErrors -Subscription
#>
function Get-GuestConfigPolicyErrors
{
    [CmdletBinding()]
    param(
        [parameter(ParameterSetName = "ResourceGroup", Mandatory=$true)]
        [ValidateNotNullOrEmpty()][String]$ResourceGroupName,
        [parameter(ParameterSetName = "Subscription", Mandatory=$true)][Switch]$CurrentSubscription,
        [parameter(Mandatory = $false, position = 1)][Switch]$Force
    )

    #Check if the resource group exists (MSIEnabled and ExtensionProperties will check the VM)
    if($ResourceGroupName -and -not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue))
    {
        throw "The given Resource Group could not be found"
    }

    if(-not($CurrentSubscription))
    {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if(-not($rg))
        {
            throw "The given Resource Group could not be found"
        }

        #Get all policies in the resource group
        $assignments = Get-AzPolicyAssignment -Scope $rg.ResourceId
        $VMs = Get-AzVM -ResourceGroupName $rg.ResourceGroupName
    }
    else
    {
        $assignments = Get-AzPolicyAssignment
        $VMs = Get-AzVM
    }

    #Display time estimate, give option to continue/skip this test if there are at least 10 policies assigned
    #(Otherwise it should be short enough)
    if($assignments.Count -gt 10)
    {   
        if(-not($Force) -and -not($PSCmdlet.ShouldContinue(("There are " + $assignments.Count + " policies assigned to this scope, so this test will take some time."), "Would you still like to continue?")))
        {
            Write-Host "User has chosen to skip this test"
            return @{Status = $false}
        }

    }


    #for tracking status
    $success = $true
    $totalErrors = 0
    $guestConfigArray = @()
    $currGCCount = 0
    $returnTable = @{}

    #If there are any policies
    if($assignments.Count -gt 0)
    {
        #Loop through each policy
        foreach($assignment in $assignments)
        {
            #Get the policies definition
            $id = $assignment.Properties.policyDefinitionId

            #$verboseMessage = "Checking policy assignment `"" + $assignment.Properties.displayName + "`""

            #Write-Host $verboseMessage

            #Check if there is an id
            if($id)
            {
                $defN = Get-AzPolicyDefinition -Id $id -ErrorAction SilentlyContinue
                $def = Get-AzPolicySetDefinition -Id $id -ErrorAction SilentlyContinue

                #Check if it is a Guest Configuration Policy
                if($defN.Properties.metadata.category -eq "Guest Configuration" -or $def.Properties.metadata.category -eq "Guest Configuration")
                {
                    Write-Host ("Found Guest Configuration policy : " + $def.Properties.DisplayName + $defN.Properties.DisplayName)
                    $guestConfigCount += 1
                    $alreadyAdded = $false

                    #Check if the policy is in an initiative
                    if($def.Properties.policyDefinitions)
                    {
                        Write-Host "Policy was in an initiative"
                        #$nonappVMs = @{}
                        $permissionError = CheckAssignmentPermissions -assignment $assignment -definition $def -initiative

                        foreach($subdef in $def.Properties.policyDefinitions.policyDefinitionId)
                        {
                            if($nonappVMs){break}
                            $nonappVMs += Get-NonApplicableVMs -VMList $VMs -PolicyDefinition $subdef                            
                        }

                        if($permissionError)
                        {
                            ++$currGCCount
                            $alreadyAdded = $true
                            
                            $guestConfigArray += ([PSCustomObject]@{
                                    Name = $assignment.Properties.displayName
                                    Status = $false
                                    Warnings = @()
                                    Errors = @($permissionError)
                                    Details = @{
                                        Assignment = $assignment
                                        Definition = $def
                                        Initiative = $true
                                    }
                            })
                        }

                        if($nonappVMs)
                        {
                            Write-Host ("Below VMs are not applicable to one of this initiative defintions " + $def.Name + " : " + $nonappVMs + " , so they may be non-compliant after assignment")
                        }
                        else 
                        {
                            Write-Host "All VMs images are applicable to policy/default OS template"
                        }

                        #Check to see if this initiative was assigned correctly if it is custom
                        if($def.Properties.policyType -ne "BuiltIn")
                        {
                            $safeIndexes = @()
                            #Nested for loop to compare each policy within the set
                            for([int]$i = 0; $i -lt $def.Properties.policyDefinitions.Count; ++$i)
                            {
                                #status for current policy (starts as false, turns true when a match is found)
                                $currentStatus = $false

                                $iDef = Get-AzPolicyDefinition -Id $def.Properties.policyDefinitions[$i].policyDefinitionId

                                for([int]$j = $i + 1; $j -lt $def.Properties.policyDefinitions.Count; ++$j)
                                {
                                    $jDef = Get-AzPolicyDefinition -Id $def.Properties.policyDefinitions[$j].policyDefinitionId
                                    
                                    $effect1 = $iDef.Properties.policyRule.then.effect
                                    $effect2 = $jDef.Properties.policyRule.then.effect
                                    if($effect1 -eq "deployIfNotExists" -and ($effect2 -eq "audit" -or $effect2 -eq "auditIfNotExists"))
                                    {
                                        if($effect2 -eq "audit")
                                        {
                                            #loop through audit conditions to find name
                                            $auditAllOf = $jDef.Properties.policyRule.if.allOf
                                            foreach($condition in $auditAllOf)
                                            {

                                                if($condition.field -eq "name")
                                                {
                                                    $auditName = $condition.equals
                                                    break
                                                }
                                            }
                                        }
                                        else
                                        {
                                            $auditName = $jDef.Properties.policyRule.then.details.name
                                        }

                                        #compare names
                                        if($iDef.Properties.policyRule.then.details.name -eq $auditName)
                                        {
                                            $currentStatus = $true
                                            $safeIndexes += $j
                                            $safeIndexes += $i
                                        }
                                    }
                                    elseif(($effect1 -eq "audit" -or $effect1 -eq "auditIfNotExists") -and $effect2 -eq "deployIfNotExists")
                                    {
                                        if($effect1 -eq "audit")
                                        {
                                            #loop through audit conditions to find name
                                            $auditAllOf = $iDef.Properties.policyRule.if.allOf
                                            foreach($condition in $auditAllOf)
                                            {

                                                if($condition.field -eq "name")
                                                {
                                                    $auditName = $condition.equals
                                                    break
                                                }
                                            }
                                        }
                                        else
                                        {
                                            $auditName = $iDef.Properties.policyRule.then.details.name
                                        }

                                        #compare names
                                        if($jDef.Properties.policyRule.then.details.name -eq $auditName)
                                        {
                                            $currentStatus = $true
                                            $safeIndexes += $j
                                            $safeIndexes += $i
                                        }
                                    }
                                }

                                for($k = 0; $k -lt $safeIndexes.Count; ++$k)
                                {
                                    if($i -eq $safeIndexes[$k])
                                    {
                                        $currentStatus = $true
                                        break
                                    }
                                }

                                if($currentStatus -eq $false)
                                {
                                    if($alreadyAdded)
                                    {
                                        $guestConfigArray[$currGCCount - 1].Errors += ("The policy `"" + $iDef.Properties.displayName + "`" does not have a matching policy in this initiative.")
                                        Write-Host ("The policy `"" + $iDef.Properties.displayName + "`" does not have a matching policy in its initiative, `"" + $def.Properties.displayName + "`".")
                                    }
                                    else
                                    {
                                        $guestConfigArray += ([PSCustomObject]@{
                                            Name = $assignment.Properties.displayName
                                            Status = $false
                                            Warnings = @()
                                            Errors = @(("The policy `"" + $iDef.Properties.displayName + "`" does not have a matching policy in this initiative."))
                                            Details = @{
                                                Assignment = $assignment
                                                Definition = $def
                                                Initiative = $true
                                            }
                                        })
                                        $alreadyAdded = $true
                                        $currGCCount += 1

                                    }
                                    Write-Host ""
                                    $totalErrors += 1
                                    $success = $false

                                }
                            }
                        }
                    }
                    else
                    {
                        #If it's not in an initiative, add it to the array
                        $guestConfigArray += ([PSCustomObject]@{
                            Name = $assignment.Properties.displayName
                            Status = $false
                            Warnings = @("This policy is not in an initiative")
                            Errors = @()
                            Details = @{
                                Assignment = $assignment
                                Definition = $defN
                                Initiative = $false
                            }
                        })

                        $currGCCount += 1

                        if($defN.Properties.policyRule.then.effect -eq "DeployIfNotExists")
                        {
                            $permissionError = CheckAssignmentPermissions -definition $defN -assignment $assignment

                            if($permissionError)
                            {
                                $guestConfigArray[$currGCCount - 1].Errors += $permissionError
                            }
                        }
                        <#
                        else 
                        {
                            Write-Host "There is not assignment with non-initiative policy effect DeployIfNotExists, skipping permission check"
                        }
                        #>
                        $nonappVMs = Get-NonApplicableVMs -VMList $VMs -PolicyDefinition $defN

                        if($nonappVMs)
                        {
                            Write-Host ("Below VMs are not applicable to this definition " + $defN.Name + " : " + $nonappVMs + " , so they may be non-compliant after assignment")
                        }
                        else 
                        {
                            Write-Host "All VMs images are applicable to custom OS template"
                        }
                    }
                }
            }
        }
    }

    if($guestConfigCount -eq 0)
    {
        Write-Host "There are no Guest Configuration Policies assigned to this scope"
    }
    else
    {
        #Used to make sure we don't use the same policy in 2 different pairs (also lets us be a bit more efficient by skipping already safe policies)
        $safeIndeces = @()
        
        #Matchmaking loop
        for([int]$i = 0; $i -lt $guestConfigArray.Count - 1; ++$i)
        {

            if($safeIndeces.Contains($i) -or $guestConfigArray[$i].Details.Initiative)
            {
                continue
            }

            #Get audit name if relevant
            if($guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "audit")
            {
                foreach($condition in $guestConfigArray[$i].Details.Definition.Properties.policyRule.if.allOf)
                {
                    if($condition.field -eq "name")
                    {
                        $auditName = $condition.equals
                    }
                }
            }
            elseif($guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "auditIfNotExists")
            {
                $auditName = $guestConfigArray[$i].Details.Definition.Properties.policyRule.then.details.name
            }
            
            for([int]$j = $i + 1; $j -lt $guestConfigArray.Count; ++$j)
            {

                if($safeIndeces.Contains($j) -or $guestConfigArray[$i].Details.Initiative)
                {
                    continue
                }

                if($guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "deployIfNotExists")
                {
                    $detailsName = $guestConfigArray[$i].Details.Definition.Properties.policyRule.then.details.name

                    if($guestConfigArray[$j].Details.Definition.Properties.policyRule.then.effect -eq "audit" -or $guestConfigArray[$j].Details.Definition.Properties.policyRule.then.effect -eq "auditIfNotExists")
                    {
                        if($guestConfigArray[$j].Details.Definition.Properties.policyRule.then.effect -eq "audit")
                        {
                            foreach($condition in $guestConfigArray[$j].Details.Definition.Properties.policyRule.if.allOf)
                            {
                                if($condition.field -eq "name")
                                {
                                    $auditName = $condition.equals
                                }
                            }
                        }
                        else
                        {
                            $auditName = $guestConfigArray[$j].Details.Definition.Properties.policyRule.then.details.name
                        }

                        #Check for match
                        if($auditName -eq $detailsName)
                        {
                            #Match found - write warning about how this will work but isn't recommended
                            ##Write-Host ("The policies `"" + $guestConfigDefArray[$i].Properties.displayName + "`" and `"" + $guestConfigDefArray[$j].Properties.displayName + 
                            ##"`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            $guestConfigArray[$i].Warnings += ("This Policy and `"" + $guestConfigArray[$j].Details.Definition.Properties.displayName + 
                            "`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            $guestConfigArray[$j].Warnings += ("This Policy and `"" + $guestConfigArray[$i].Details.Definition.Properties.displayName + 
                            "`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            Write-Host ("The policies `"" + $guestConfigArray[$i].Details.Definition.Properties.displayName + "`" and `"" + $guestConfigArray[$j]["Definition"].Properties.displayName + 
                            "`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            Write-Host ""
                            #Also remove the 2 matching defs from the array
                            $safeIndeces += $i
                            $safeIndeces += $j
                            break
                        }
                    }
                }
                elseif($guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "audit" -or $guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "auditIfNotExists")
                {
                    if($guestConfigArray[$j].Details.Definition.Properties.policyRule.then.effect -eq "deployIfNotExists")
                    {
                        $detailsName = $guestConfigArray[$j].Details.Definition.Properties.policyRule.then.details.name
                        #Check for match
                        if($auditName -eq $detailsName)
                        {

                            $guestConfigArray[$i].Warnings += ("This Policy and `"" + $guestConfigArray[$j].Details.Definition.Properties.displayName + 
                            "`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            $guestConfigArray[$j].Warnings += ("This Policy and `"" + $guestConfigArray[$i].Details.Definition.Properties.displayName + 
                            "`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            Write-Host ("The policies `"" + $guestConfigArray[$i].Details.Definition.Properties.displayName + "`" and `"" + $guestConfigArray[$j].Details.Definition.Properties.displayName + 
                            "`" are a matching pair but are not assigned to an initiative. This will work but is not recommended")

                            Write-Host ""
                            #Also add the 2 matching defs to a non-check list
                            $safeIndeces += $i
                            $safeIndeces += $j
                            break
                        }
                    }
                }
            }
        }


        #Print warnings for remaining policies
        for([int]$i = 0; $i -lt $guestConfigArray.Count; ++$i)
        {
            $success = $true
            if($safeIndeces.Contains($i) -or $guestConfigArray[$i].Details.Initiative)
            {
                
                continue
            }
            
            [string]$name = $guestConfigArray[$i].Name

            Write-Host ("The policy `"" + $name + "`" is not in an initiative")

            $totalErrors += 1
            
            if($guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "deployIfNotExists")
            {
                $success = $false
                $guestConfigArray[$i].Warnings += "It is recommended that this DeployIfNotExists Policy be in an initiative with its corresponding Audit Policy"
                Write-Host "It is recommended that this DeployIfNotExists Policy be in an initiative with its corresponding Audit Policy"

                #We should be able to get the corresponding policy's name if it is Built-in
                if($guestConfigArray[$i].Details.Definition.Properties.policyType -eq "builtIn")
                {
                    $corrName = "Audit" + $name.Substring(28)
                    $guestConfigArray[$i].Errors += ("The corresponding Audit Policy, `"" + $corrName + "`" is missing")
                    $guestConfigArray[$i].Details["CorrespondingPolicyName"] = $corrName
                    Write-Host ("The corresponding Audit Policy, `"" + $corrName + "`" is missing")

                }
                else
                {
                    $guestConfigArray[$i].Errors += "The corresponding Audit Policy is missing"
                    Write-Host "The corresponding Audit Policy is missing"
                } 
            }
            elseif($guestConfigArray[$i].Details.Definition.Properties.policyRule.then.effect -eq "audit")
            {
                $success = $false
                $guestConfigArray[$i].Warnings += "It is recommended that the Audit Policy be in an initiative with its corresponding DeployIfNotExists Policy"
                Write-Host "It is recommended that the Audit Policy be in an initiative with its corresponding DeployIfNotExists Policy"
                
                if($guestConfigArray[$i].Details.Definition.Properties.policyType -eq "builtIn")
                {
                    $corrName = "Deploy requirements to audit" + $name.Substring(5)

                    $guestConfigArray[$i].Errors += ("The corresponding DeployIfNotExists Policy, `"" + $corrName + "`" is missing")
                    $guestConfigArray[$i].Details["CorrespondingPolicyName"] = $corrName
                    Write-Host ("The corresponding DeployIfNotExists Policy, `"" + $corrName + "`" is missing")

                }
                else
                {
                    $guestConfigArray[$i].Errors += "The corresponding DeployIfNotExists Policy is missing"
                    Write-Host "The corresponding DeployIfNotExists Policy is missing"
                } 
            }

            #to separate policies
            Write-Host ""
        }
    }

    $returnTable["Status"] = $success
    $returnTable["GuestConfigurationPolicyCount"] = $guestConfigCount
    $returnTable["Policies"] = $guestConfigArray

    return $returnTable

}


<#
.SYNOPSIS

Tests VM/ResourceGroup/Subscription for things related to Guest Configuration
    
.DESCRIPTION

This cmdlet gets data through ARM resource providers about Guest Configuration scenarios, then analyzes it
and returns it as a hash table

.PARAMETER ResourceGroupName
The Resource Group to run tests in

.PARAMETER VMName
The VM to run tests on

.PARAMETER VM
VM to check (this will also let the cmdlet automatically get the resource group from the VM)

.PARAMETER Force
Switch parameter that allows you to skip any required input

.EXAMPLE

PS> Get-GuestConfigurationPolicyHealth -ResourceGroupName "MyResourceGroup" -VMName "MyVM"

.EXAMPLE

PS> $myVM = Get-AzVM -ResourceGroupName "MyResourceGroup" -Name "MyVM"
Get-GuestConfigurationPolicyHealth -VM $myVM
#>
function Get-GuestConfigurationPolicyHealth
{
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param(
        [parameter(ParameterSetName = "Scoped", Mandatory = $true)][ValidateNotNullOrEmpty()][String]$ResourceGroupName,
        [parameter(ParameterSetName = "Scoped", Mandatory = $true)][ValidateNotNullOrEmpty()][String]$VMName,
        [parameter(ParameterSetName = "Default", Mandatory = $true)][ValidateNotNullOrEmpty()]$VM,
        [parameter(Mandatory=$false)][switch]$ComplianceCheck,
        [parameter(Mandatory=$false)][switch]$Force
    )

    #Check if the resource group exists (MSIEnabled and ExtensionProperties will check the VM)
    if($ResourceGroupName -and -not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue))
    {
        throw "The given Resource Group could not be found"
    }

    $masterReturnTable = @{OverallStatus = $true; CheckResults = @(); Messages = @()}

    #Check if RP Microsoft.GuestConfiguration is registered
    $rp = Get-RPRegister
    $masterReturnTable.OverallStatus = $masterReturnTable.OverallStatus -and $rp
    if($rp -eq $false)
    {
        $masterReturnTable.Messages += "Microsoft.GuestConfiguration is not registered under current subscription"
    }
    $masterReturnTable.CheckResults += $rp

    #Check MSI on the given VM
    if($VM)
    {
        $msi = Get-VmMSIEnabled -VM $VM
        $ResourceGroupName = $VM.ResourceGroupName
    }
    else
    {
        $msi = Get-VmMSIEnabled -ResourceGroupName $ResourceGroupName -VMName $VMName
    }

    $masterReturnTable.OverallStatus = $masterReturnTable.OverallStatus -and $msi.Status
    if($msi.Status -eq $false)
    {
        $masterReturnTable.Messages += "MSI is not enabled"
    }
    $masterReturnTable.CheckResults += $msi

    #Check Guest Config Extension on the given VM
    if($VM)
    {
        $gce = Get-VmGuestConfigExtensionProperties -VM $VM
    }
    else
    {
        $gce = Get-VmGuestConfigExtensionProperties -ResourceGroupName $ResourceGroupName -VMName $VMName
    }

    $masterReturnTable.OverallStatus = $masterReturnTable.OverallStatus -and $gce.Status
    if($gce.Status -eq $false)
    {
        $masterReturnTable.Messages += "The Guest Configuration Extension on this machine is not healthy"
    }
    $masterReturnTable.CheckResults += $gce

    #Check Guest Config policy compliance on the given VM
    if($VM)
    {
        $cpl = Get-Compliance -VM $VM $ComplianceCheck
    }
    else
    {
        $cpl = Get-Compliance -ResourceGroupName $ResourceGroupName -VMName $VMName $ComplianceCheck
    }

    $masterReturnTable.OverallStatus = $masterReturnTable.OverallStatus -and $cpl
    if($cpl -eq $true)
    {
        $masterReturnTable.Messages += "There is non-compliant policy on this VM"
    }
    $masterReturnTable.CheckResults += $cpl
    
    #Check assignment errors
    if($ResourceGroupName)
    {
        $perrors = Get-GuestConfigPolicyErrors -ResourceGroupName $ResourceGroupName $Force
    }
    else
    {
        $perrors = Get-GuestConfigPolicyErrors -CurrentSubscription $Force
    }

    $masterReturnTable.OverallStatus = $masterReturnTable.OverallStatus -and $perrors.Status
    if($perrors.Status -eq $false)
    {
        $masterReturnTable.Messages += "There are unhealthy policies in this scope"
    }
    
    for($i = 0; $i -lt $perrors.Policies.Count; ++$i)
    {
        $masterReturnTable.CheckResults += $perrors.Policies[$i]
    }

    if($msi.Status -eq $false -and -not($gce.Details) -and $perrors.GuestConfigurationPolicyCount -eq 0)
    {
        $masterReturnTable["Messages"] += "There are no Guest Configuration Policies assigned to this scope, which is likely the reason why MSI is not enabled and the extension is not installed"
    }

    return $masterReturnTable

}

function Collect-Logs
{
    Write-Host "For windows, install and run this script to collect logs: Install-Script -Name GCLogCollection"
    Write-Host "For linux, run this command to collect logs: wget https://raw.githubusercontent.com/MSNina123456/GC-Troubleshooter/main/GCLogCollection.sh&& bash ./GCLogCollection.sh"
}

function Show-Menu
{
    Clear-Host
    Write-Host "================ Please select troubleshoot scenario ================"
    Write-Host 
    Write-Host "1: Check RP Microsoft.GuestConfiguration registration"
    Write-Host "2: Check Guest configuration extension"
    Write-Host "3: Check managed identity"
    Write-Host "4: Check Guest configuration policy errors"
    Write-Host "5: Check Non compliant policies on a given VM"
    Write-Host "====================================================================="
    Write-Host "6: Check above all"
    Write-Host "7: Collect logs"
    Write-Host "Q: Press 'Q' to quit."
    Write-Host "====================================================================="
}

Show-Menu

$selection = Read-Host "Please select an option"
switch ($selection)
{
    '1'
    {
        'You selected option #1'
        Get-RPRegister
    }
    '2'
    {
        'You selected option #2'
        if($VM)
        {
            Get-VmGuestConfigExtensionProperties -VM $VM
        }
        else
        {
            Get-VmGuestConfigExtensionProperties -ResourceGroupName $ResourceGroupName -VMName $VMName
        }
    }
    '3'
    {
        'You selected option #3'
        if($VM)
        {
            Get-VmMSIEnabled -VM $VM
        }
        else
        {
            Get-VmMSIEnabled -ResourceGroupName $ResourceGroupName -VMName $VMName
        }
    }
    '4'
    {
        'You selected option #4'
        if($ResourceGroupName)
        {
            Get-GuestConfigPolicyErrors -ResourceGroupName $ResourceGroupName $Force
        }
        else
        {
            Get-GuestConfigPolicyErrors -CurrentSubscription $Force
        }
    }
    '5'
    {
        'You selected option #5'
        if($VM)
        {
            Get-Compliance -VM $VM $ComplianceCheck
        }
        else
        {
            Get-Compliance -ResourceGroupName $ResourceGroupName -VMName $VMName $ComplianceCheck
        }
    }
    '6'
    {
        'You selected option #6'
        if($VM)
        {
            Get-GuestConfigurationPolicyHealth -VM $VM
        }
        else
        {
            Get-GuestConfigurationPolicyHealth -ResourceGroupName $ResourceGroupName -VMName $VMName
        }
    }
    '7'
    {
        'You selected option #7'
        Collect-Logs
    }
    'q' 
    {
        return
    }
    'Q'
    {
        return
    }
}
