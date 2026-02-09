<#
.SYNOPSIS
    List all configured tenants

.DESCRIPTION
    Displays all Azure AD tenants configured for monitoring

.EXAMPLE
    Get-MonitorTenants
#>
function Get-MonitorTenants {
    [CmdletBinding()]
    param()
    
    $config = Get-StoredConfig
    if (-not $config -or $config.Tenants.Count -eq 0) {
        Write-Host "No tenants configured. Use Add-MonitorTenant to add a tenant." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nConfigured Tenants:" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Gray
    
    $config.Tenants | ForEach-Object {
        Write-Host "Name: " -NoNewline -ForegroundColor White
        Write-Host $_.Name -ForegroundColor Cyan
        Write-Host "Tenant ID: " -NoNewline -ForegroundColor White
        Write-Host $_.TenantId -ForegroundColor Gray
        Write-Host "Days Threshold: " -NoNewline -ForegroundColor White
        Write-Host $_.DaysThreshold -ForegroundColor White
        Write-Host "Added: " -NoNewline -ForegroundColor White
        Write-Host $_.AddedDate -ForegroundColor Gray
        Write-Host ("-" * 100) -ForegroundColor Gray
    }
    
    Write-Host "`nTotal: $($config.Tenants.Count) tenant(s)" -ForegroundColor Cyan
}
