<#
.SYNOPSIS
    Remove a tenant from monitoring

.DESCRIPTION
    Removes an Azure AD tenant from the monitoring configuration

.PARAMETER Name
    The friendly name of the tenant to remove

.PARAMETER TenantId
    The Azure AD tenant ID to remove

.EXAMPLE
    Remove-MonitorTenant -Name "Production"

.EXAMPLE
    Remove-MonitorTenant -TenantId "12345678-1234-1234-1234-123456789abc"
#>
function Remove-MonitorTenant {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]$Name,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [string]$TenantId
    )
    
    $config = Get-StoredConfig
    if (-not $config -or $config.Tenants.Count -eq 0) {
        Write-Warning "No tenants configured"
        return
    }
    
    $tenant = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $config.Tenants | Where-Object { $_.Name -eq $Name }
    } else {
        $config.Tenants | Where-Object { $_.TenantId -eq $TenantId }
    }
    
    if (-not $tenant) {
        Write-Error "Tenant not found"
        return
    }
    
    $config.Tenants = @($config.Tenants | Where-Object { 
        $_.TenantId -ne $tenant.TenantId 
    })
    
    if (Save-Config -Config $config) {
        Write-Host "Successfully removed tenant '$($tenant.Name)' ($($tenant.TenantId))" -ForegroundColor Green
    }
}
