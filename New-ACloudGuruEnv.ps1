# TODO Inspect the ARM .json templates and add variables for any statically set values
# TODO Try to find "cheat sheets" for valid "resources" in templates
# TODO Make sure parameters are "inherited" from the correct components
# TODO Try to think of a way to create the defitions first and then create them all in a loop
# at the end instead of creating each resource right after defining it
# TODO Change the naming of the variables at the beginning to reflect that they are default values
# TODO Maybe remove 0's from the ends of default names and such (like Vnet0) and add them
# programmatically instead
# TODO Add logging

$aRMTemplatesDir = '.\ARMTemplates'

$resourceGroup = Get-AzResourceGroup

# Default Shared variables
$location = $resourceGroup.location
$resourceGroupName = $resourceGroup.ResourceGroupName

# Default Network security group variables
$networkSecurityGroup0Name = 'NetworkSecurityGroup0'

# Default Virtual network variables
$vNetName = 'VNet0'
$vNetAddressSpaces = @('192.168.0.0/16')
$vNetSubnet0Name = 'VNet0Subnet0'
$vNetSubnet0AddressPrefix = '192.168.0.0/24'

# Default Public IP address variables
$pubIPAddress0Name = 'PublicIP0'
$pubIPAddress0SKU = 'Standard'
$pubIPAddress0AllocationMethod = 'Static'
$pubIPAddress0IdleTimeoutInMinutes = 4
$pubIPAddress0Version = 'IPv4'
$pubIPAddress0Tier = 'Regional'
#$pubIPAddress0Zones = 3, 2, 1 # NOTE Not all locations support availability zones so, commented out

# Default Network interface variables
$netIfName = 'If0'
$netIfIpConfig0Name = 'IpConfig0'
$netIfPrivateIPAddress = '10.0.0.4'
$netIfPrivateIPAllocationmethod = 'Dynamic'
$netIfPrivateIPrimary = $true
$netIfPrivateIVersion = 'IPv4'
$netIfPublicIPName = $pubIPAddress0Name
$netIfVNetName = $vNetName
$netIfSecGroupName = $netWorkSecurityGroup0Name
$netIfSubnetName = $vNetSubnet0Name
$netIfdnsSettings = @()
$netIfenableAcceleratedNetworking = $true
$netIfenableIPForwarding = $false

# Default virtual machine variables
$vmLocalAdminSecurePassword = ConvertTo-SecureString "Ricketracketrunningfox123!" -AsPlainText -Force
$vmCredential = New-Object System.Management.Automation.PSCredential `
    ('-', $vmLocalAdminSecurePassword);

$vmName = "VM0"
$vmComputerName = "VM0"
$vmIf0Name = $netIfName
$vmAcceleratedNetworking = $true
$vmNetworkSecurityGroupName = $netWorkSecurityGroup0Name
$vmSubnetName = $netIfSubnetName
$vmVNetname = $vNetName
$vmIpConfig0Name = $netIfIpConfig0Name
$vmPublicIPAddressName = $pubIPAddress0Name
$vmPublicIPAddressType = $pubIPAddress0AllocationMethod
$vmPublicIPAddressSku = $pubIPAddress0SKU
$vmOSDiskType = 'Premium_LRS'
$vmVirtualMachineSize = 'Standard_D2s_v3'
$vmAdminUserName = 'VMBoss'
$vmAdminPassword = $vmCredential.Password
$vmPatchMode = 'AutomaticByOS'
$vmEnableHotPatching = $false

# Default Recovery vault variables
$recVaultName = 'RecoveryVault0'

# Default Backup policy variables
$backPolVaultSubscriptionID = $recVaultName # TODO Might not be the correct value, remove this comment if not causing issues
$backPolVaultResourceGroup = $resourceGroupName
$backPolVaultName = $recVaultName
$backPolBackupManagementType = 'AzureIaasVM'
$backPolPolicyName = 'vmBackup0'
$backPolInstantRpRetentionRangeInDays = 1
$backPolSchedule = @{
    schedulePolicyType = 'SimpleSchedulePolicy'
    scheduleRunFrequency = 'Daily'
    scheduleRunTimes = @(
        "2021-11-11T21:30:00Z"
    )
}
$backPolTimeZone = 'UTC'
$backPolRetention = @{
    retentionPolicyType = 'LongTermRetentionPolicy'
    dailySchedule = @{
        retentionTimes = @(
            "2021-11-11T21:30:00Z"
        )
        retentionDuration = @{
            count = 180
            durationType = 'Days'
        }
    }
}
$backPolInstantRPDetails = @{}

# Default Automation account variables
$automAccName = 'AutomationAccount'
$runbookName = 'Hello world'
$runbookDescription = 'Hello world'
$runbookScriptPath = '.\RunbookScripts\Powershell\HelloWorld.ps1'
$runbookType = 'PowerShell'
$runbookAutomationAccountName = $automAccName

# FUNCTIONS

function Get-ARMTemplateObject
{
    Param(
        [Parameter(Mandatory=$true)][String]$TemplateName
    )
    (Get-Content -Path "$aRMTemplatesDir\$TemplateName.json" | ConvertFrom-Json -AsHashtable)
}

function New-AzResourceGroupDeploymentFrom
{
    Param(
        [Parameter(Mandatory=$true)][PSCustomObject]$Definition
    )
    $parameters = $Definition.templateParameterObject

    Write-Host "Creating a $($Definition.templateName) $($parameters.name)"

    if ($parameters.publicIPAddressId) {
        # TODO Definition should include .publicIPAddressName instead which will then be replace 
        # with .publicIPAddressId here instead
        $parameters.publicIPAddressId = `
            (Get-AzPublicIpAddress -Name $parameters.publicIPAddressId).Id
    }

    if ($parameters.virtualNetworkId) {
        $parameters.virtualNetworkId = `
            (Get-AzVirtualNetwork -Name $parameters.virtualNetworkId).Id
    }

    if ($parameters.networkSecurityGroupId) {
        $parameters.networkSecurityGroupId = `
            (Get-AzNetworkSecurityGroup -Name $parameters.networkSecurityGroupId).Id
    }

    if ($parameters.vaultSubscriptionID) {
        $parameters.vaultSubscriptionID = `
            (Get-AZRecoveryServicesVault -Name $parameters.vaultSubscriptionID).ID
    }

    $result = New-AzResourceGroupDeployment `
        -TemplateParameterObject $parameters `
        -TemplateObject $Definition.templateObject `
        -ResourceGroupName $resourceGroupName
    $result | Out-Null # TODO Check whether the operation was successful
}

$Script:definitions = @()

function Add-NetworkSecurityGroup
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )

    $templateName = 'networkSecurityGroup'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            name = $netWorkSecurityGroup0Name
            location = $location
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-VirtualNetwork
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )

    $templateName = 'virtualNetwork'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            name = $vNetName
            location = $location
            extendedLocation = @{}
            resourceGroup = $resourceGroupName
            addressSpaces = $vNetAddressSpaces
            ipv6Enabled = $false
            subnetCount = 1
            subnet0_name = $vNetSubnet0Name
            subnet0_addressRange = $vNetSubnet0AddressPrefix
            ddosProtectionPlanEnabled = $false
            firewallEnabled = $false
            bastionEnabled = $false
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-PublicIPAddress
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )

    $templateName = 'publicIPAddress'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            name = $pubIPAddress0Name
            location = $location
            #zones = $pubIPAddress0Zones
            sku = $pubIPAddress0SKU
            publicIPAllocationMethod = $pubIPAddress0AllocationMethod
            idleTimeoutInMinutes = $pubIPAddress0IdleTimeoutInMinutes
            publicIpAddressVersion = $pubIPAddress0Version
            tier = $pubIPAddress0Tier
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-NetworkInterface
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )

    $templateName = 'networkInterface'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            location = $location
            name = $netIfName
            ipConfig0Name = $netIfIpConfig0Name
            ipConfig0PrivateIPAddress = $netIfPrivateIPAddress
            ipConfig0PrivateIPAllocationMethod = $netIfPrivateIPAllocationmethod
            ipConfig0PrivateIPPrimary = $netIfPrivateIPrimary
            ipConfig0PrivateIPAddressVersion = $netIfPrivateIVersion
            publicIPAddressId = $netIfPublicIPName
            virtualNetworkId = $netIfVNetName
            networkSecurityGroupId = $netIfSecGroupName
            subnetName = $netIfSubnetName
            dnsSettings = $netIfdnsSettings
            enableAcceleratedNetworking = $netIfenableAcceleratedNetworking
            enableIPForwarding = $netIfenableIPForwarding
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-VirtualMachine
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )
    $templateName = 'virtualMachine'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            name = $vmName
            location = $location
            virtualMachineComputerName = $vmComputerName
            networkInterfaceName = $vmIf0Name
            enableAcceleratedNetworking = $vmAcceleratedNetworking
            networkSecurityGroupName = $vmNetworkSecurityGroupName
            subnetName = $vmSubnetName
            virtualNetworkId = $vmVNetname
            ipConfig0Name = $vmIpConfig0Name
            publicIpAddressName = $vmPublicIPAddressName
            publicIpAddressType = $vmPublicIPAddressType
            publicIpAddressSku = $vmPublicIPAddressSku
            virtualMachineRG = $resourceGroupName
            osDiskType = $vmOSDiskType
            virtualMachineSize = $vmVirtualMachineSize
            adminUsername = $vmAdminUserName
            adminPassword = $vmAdminPassword
            patchMode = $vmPatchMode
            enableHotpatching = $vmEnableHotPatching
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-VirtualMachines
{
    Param(
        [Parameter(Mandatory=$false)][Int]$Count
    )

    # TODO Add a counter like X/10 VM's being created

    foreach ($number in 0..($Count - 1)) {
        $publicIPName = "PublicIP$number"

        $ifName = "If$number"
        $ifIPConfigName = "IPConfig$number"
        $ifPublicIPAddressId = "PublicIP$number"

        $vmName = "VM$number"
        $vmIfName = $ifName
        $vmPublicIPName = $publicIPName
        $vmIPConfigName = $ifIPConfigName

        Add-PublicIPAddress -Parameters @{ name = $publicIPName }

        Add-NetworkInterface -Parameters @{ 
            name = $ifName
            ipConfig0Name = $ifIPConfigName
            publicIPAddressId = $ifPublicIPAddressId
        }

        Add-VirtualMachine -Parameters @{
            name = $vmName
            virtualMachineComputerName = $vmName
            networkInterfaceName = $vmIfName
            publicIPAddressName = $vmPublicIPName
            ipConfig0Name = $vmIPConfigName
        }
    }
}

function Add-RecoveryVault
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )

    $templateName = 'recoveryVault'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            name = $recVaultName
            location = $location
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-BackupPolicy
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters
    )

    $templateName = 'backupPolicy'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            vaultSubscriptionID = $backPolVaultSubscriptionID
            vaultResourceGroup = $backPolVaultResourceGroup
            vaultName = $backPolVaultName
            backupManagementType = $backPolBackupManagementType
            name = $backPolPolicyName
            instantRpRetentionRangeInDays = $backPolInstantRpRetentionRangeInDays
            schedule = $backPolSchedule
            timeZone = $backPolTimeZone
            retention = $backPolRetention
            instantRPDetails = $backPolInstantRPDetails
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Add-AutomationAccount
{
    Param(
        [Parameter(Mandatory=$false)][HashTable]$Parameters,
        [Parameter(Mandatory=$false)][HashTable]$PostConfigurationParameters
    )

    $templateName = 'automationAccount'
    $definition = [PSCustomObject]@{
        templateName = $templateName
        templateObject = Get-ARMTemplateObject -TemplateName $templateName
        templateParameterObject = @{
            name = $automAccName
            location = $location
        }
        postConfigParameters = @{
            runbooks = @{
                Name = $runbookName
                Description = $runBookDescription
                Path = $runBookScriptPath
                Type = $runbookType
                AutomationAccountName = $runbookAutomationAccountName
                ResourceGroupName = $resourceGroupName
            }
        }
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.templateParameterObject.$parameterName = $Parameters.$parameterName
    }

    foreach ($parameterName in $Parameters.Keys) {
        $definition.postConfigParameters.$parameterName = $Parameters.$parameterName
    }

    $Script:definitions += $definition
}

function Deploy-Resources
{
    # TODO Deploy in parallel running groups ordered by resource type so groups of resources 
    # are deployed before ones that depend on those previous resources
    foreach ($definition in $Script:definitions) {
        New-AzResourceGroupDeploymentFrom -Definition $definition
    }
}

# BEGIN

Add-NetworkSecurityGroup

#Add-VirtualNetwork

#Add-RecoveryVault

#Add-BackupPolicy

#Add-VirtualMachines -Count 1

Add-AutomationAccount

Deploy-Resources

# TODO Post-deployment should be moved inside Deploy-Resources
# TODO Perhaps add postConfigurationOptions or something to definition objects, where you 
# can set things such as backup policy names
# POST-DEPLOYMENT CONFIGURATION

# Recovery vault post-deployment configuration
$Script:definitions | Where-Object { $_.templateName -eq 'recoveryVault' } | ForEach-Object -Parallel {
    $recVaultDef = $_
    $vaultName = $recVaultDef.templateParameterObject.name
    $vault = Get-AzRecoveryServicesVault -Name $vaultName
    if ($vault) {
        try {
            Set-AzRecoveryServicesVaultProperty `
                -Vault $vault.ID `
                -SoftDeleteFeatureState Disable `
                -ErrorAction Stop | Out-Null
            Write-Host "Recovery vault $($vaultName) Soft Delete disabled"
        } catch {
            Write-Host "Error disabling Recovery vault $vaultName Soft Delete: $($_.ToString())"
        }
    } else {
        Write-Host "Unable to find Recovery vault $vaultName for post-deployment configuration"
    }
}

# TODO Add an automation account and a runbook script that set the backup policies instead

# Virtual machine post-deployment configuration
$vmDefList = $Script:definitions | Where-Object { $_.templateName -eq 'virtualMachine' } 
foreach ($vmDef in $vmDefList) {
    #Start-ThreadJob -InputObject $vmDef -ArgumentList $recVaultName, $backPolPolicyName, $resourceGroupName `
             #-StreamingHost $Host -ThrottleLimit 2 -ScriptBlock {
    Start-Job -InputObject $vmDef -ArgumentList $recVaultName, $backPolPolicyName, $resourceGroupName `
            -ScriptBlock {
        $vmDef = $input
        $vmName = $vmDef.templateParameterObject.name
        $recVaultName, $polName, $resourceGroupName = $args
        $vault = Get-AZRecoveryServicesVault -Name $recVaultName
        if ($vault) {
            # NOTE For some reason at least the first job has trouble find $pol on the first try and for 
            # example fetching $vault and $pol before starting jobs and passing them as variables at least 
            # the first job still failed.
            $found = $false
            while ($found -eq $false) {
                # TODO Add a maximum number of tries
                $pol = Get-AzRecoveryServicesBackupProtectionPolicy `
                    -Name $polName `
                    -VaultId $vault.ID
                
                if ($pol) {
                    $found = $true
                } else {
                    Write-Host "$vmName still looking for $polName..."
                    Start-Sleep -Seconds 5
                }
            }

            # TODO Catch...
            # Enable-AzRecoveryServicesBackupProtection: Discovery operation is already in progress. Please wait until the current Discovery operation has completed.
            # ...and try again until it doesn't get thrown

            $result = Enable-AzRecoveryServicesBackupProtection `
                -Policy $pol `
                -Name $vmName `
                -ResourceGroupName $resourceGroupName `
                -VaultId $vault.ID

            if ($result.Status -eq 'Completed') {
                Write-Host "Virtual machine $vmName set to use Backup policy $polName"
            } else {
                $msg = "Error setting Virtual machine $vmName to use Backup policy $($polName): "
                Write-Host $msg
                $result
            }
        } else {
            $msg = "Unable to find Recovery vault $recVaultName for "
            $msg += "Virtual machine $vmNname post-deployment configuration"
            Write-Host $msg
        }
    } | Out-Null
}

# Automation account post-deployment configuration
$automAccDefList = $Script:definitions | Where-Object { $_.templateName -eq 'automationAccount' } 
foreach ($automAccDef in $automAccDefList) {
    $automAccParam = $automAccDef.templateParameterObject
    foreach ($runbookParam in $automAccDef.postConfigParameters.runbooks) {
        try {
            $runbookParam.ErrorAction = 'Stop'
            Import-AzAutomationRunbook @runbookParam | `
                Publish-AzAutomationRunbook -ErrorAction Stop
            $msg = "Successfully imported and published automation account $($automAccParam.name) runbook "
            $msg += "$($runbookParam.Name) in resource group $($runbookParam.ResourceGroupName)"
            Write-Host $msg -ForegroundColor Green
        } catch {
            $msg = "Error trying to import and publis automation account $($automAccParam.name) runbook "
            $msg += "$($runbookParam.Name) in resource group $($runbookParam.ResourceGroupName): "
            $msg += $_.ToString()
            Write-Host $msg -ForegroundColor Red
        }
    }
}