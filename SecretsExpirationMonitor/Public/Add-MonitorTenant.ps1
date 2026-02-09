<#
.SYNOPSIS
    Add a tenant to monitor

.DESCRIPTION
    Adds a new Azure AD tenant to the monitoring configuration

.PARAMETER TenantId
    The Azure AD tenant ID

.PARAMETER Name
    A friendly name for the tenant

.PARAMETER DaysThreshold
    Number of days threshold for this tenant. If not specified, uses the default.

.EXAMPLE
    Add-MonitorTenant -TenantId "12345678-1234-1234-1234-123456789abc" -Name "Production"

.EXAMPLE
    Add-MonitorTenant -TenantId "87654321-4321-4321-4321-cba987654321" -Name "Development" -DaysThreshold 30
#>
function Add-MonitorTenant {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysThreshold
    )
    
    $config = Get-StoredConfig
    if (-not $config) {
        $config = Initialize-DefaultConfig
    }
    
    # Check if tenant already exists
    $existingTenant = $config.Tenants | Where-Object { $_.TenantId -eq $TenantId -or $_.Name -eq $Name }
    if ($existingTenant) {
        Write-Error "A tenant with ID '$TenantId' or name '$Name' already exists"
        return
    }
    
    $tenant = [PSCustomObject]@{
        TenantId = $TenantId
        Name = $Name
        DaysThreshold = if ($DaysThreshold) { $DaysThreshold } else { $config.DefaultDaysThreshold }
        AddedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $config.Tenants += $tenant
    
    if (Save-Config -Config $config) {
        Write-Host "Successfully added tenant '$Name' ($TenantId)" -ForegroundColor Green
    }
}
