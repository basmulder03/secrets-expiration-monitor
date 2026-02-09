<#
.SYNOPSIS
    Set global configuration

.DESCRIPTION
    Updates global configuration options

.PARAMETER DefaultDaysThreshold
    Set the default days threshold for new tenants

.PARAMETER AutoUpdate
    Enable or disable automatic update checks

.EXAMPLE
    Set-MonitorConfig -DefaultDaysThreshold 60

.EXAMPLE
    Set-MonitorConfig -AutoUpdate $false
#>
function Set-MonitorConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$DefaultDaysThreshold,
        
        [Parameter(Mandatory = $false)]
        [bool]$AutoUpdate
    )
    
    $config = Get-StoredConfig
    if (-not $config) {
        $config = Initialize-DefaultConfig
    }
    
    if ($PSBoundParameters.ContainsKey('DefaultDaysThreshold')) {
        $config.DefaultDaysThreshold = $DefaultDaysThreshold
        Write-Host "Default days threshold set to $DefaultDaysThreshold" -ForegroundColor Green
    }
    
    if ($PSBoundParameters.ContainsKey('AutoUpdate')) {
        $config.AutoUpdate = $AutoUpdate
        Write-Host "Auto update $(if ($AutoUpdate) { 'enabled' } else { 'disabled' })" -ForegroundColor Green
    }
    
    Save-Config -Config $config | Out-Null
}
