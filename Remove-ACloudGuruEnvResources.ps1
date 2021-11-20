# Stop backups
Get-AzRecoveryServicesVault | ForEach-Object -Parallel {
    $vault = $_
    $resourceGroup = Get-AzResourceGroup
    $containerList = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM `
        -ResourceGroupName $resourceGroup.ResourceGroupName `
        -VaultId $vault.Id
    foreach ($container in $containerList) {
        $container | Add-Member `
            -MemberType NoteProperty `
            -Name RecoveryVault `
            -Value $vault
    }
    $containerList | ForEach-Object -Parallel {
            $container = $_
            $itemList = Get-AzRecoveryServicesBackupItem `
                -Container $container `
                -WorkloadType AzureVM `
                -VaultId $container.RecoveryVault.Id
            foreach ($item in $itemList) {
                $item | Add-Member `
                    -MemberType NoteProperty `
                    -Name RecoveryVault `
                    -Value $container.RecoveryVault
            }
            $itemList | ForEach-Object -Parallel {
                $item = $_
                Write-Host "Disabling backup item:"
                $item
                Disable-AzRecoveryServicesBackupProtection `
                    -Item $item `
                    -VaultId $item.RecoveryVault.Id `
                    -Force `
                    -RemoveRecoveryPoints `
                    -ErrorAction SilentlyContinue | Out-Null
            }
        }
}

# TODO Remove resources in order by type to save some time

# TODO Getting errors:
# {"code":"NotFound","message":"{\"Message\":\"Could not find the account. SubscriptionId: 964df7ca-3ba4-48b6-a695-1ed9db5723f8 AccountName: AutomationAccount\"}"}
# First removing runbooks and then automation accounts might help

# Remove the rest of the resources
while (Get-AzResource) { Get-AzResource | Remove-AzResource -Force }