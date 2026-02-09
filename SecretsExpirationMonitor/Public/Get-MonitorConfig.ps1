<#
.SYNOPSIS
    Get global configuration

.DESCRIPTION
    Displays the current global configuration settings

.EXAMPLE
    Get-MonitorConfig
#>
function Get-MonitorConfig {
    [CmdletBinding()]
    param()
    
    $config = Get-StoredConfig
    if (-not $config) {
        $config = Initialize-DefaultConfig
    }
    
    Write-Host "`nCurrent Configuration:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Version: " -NoNewline -ForegroundColor White
    Write-Host $config.Version -ForegroundColor Green
    Write-Host "Default Days Threshold: " -NoNewline -ForegroundColor White
    Write-Host $config.DefaultDaysThreshold -ForegroundColor White
    Write-Host "Auto Update: " -NoNewline -ForegroundColor White
    Write-Host $config.AutoUpdate -ForegroundColor $(if ($config.AutoUpdate) { "Green" } else { "Yellow" })
    Write-Host "Last Update Check: " -NoNewline -ForegroundColor White
    Write-Host $(if ($config.LastUpdateCheck) { $config.LastUpdateCheck } else { "Never" }) -ForegroundColor Gray
    Write-Host "Configured Tenants: " -NoNewline -ForegroundColor White
    Write-Host $config.Tenants.Count -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    return $config
}
