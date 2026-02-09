#Requires -Version 5.1

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName -Alias @('Monitor-Secrets', 'Check-Secrets')

# Check for updates on module load (if enabled)
$config = Get-StoredConfig
if (-not $config) {
    Write-Host "Welcome to Secrets Expiration Monitor!" -ForegroundColor Cyan
    Write-Host "Initializing configuration..." -ForegroundColor White
    $config = Initialize-DefaultConfig
    Write-Host "Configuration initialized. Use 'Get-MonitorConfig' to view settings." -ForegroundColor Green
    Write-Host "Add a tenant with: Add-MonitorTenant -TenantId 'your-tenant-id' -Name 'TenantName'" -ForegroundColor Cyan
}
elseif ($config.AutoUpdate) {
    # Check if it's been more than 7 days since last check
    if ($config.LastUpdateCheck) {
        $lastCheck = [DateTime]::Parse($config.LastUpdateCheck)
        $daysSinceCheck = ((Get-Date) - $lastCheck).TotalDays
        
        if ($daysSinceCheck -gt 7) {
            Write-Host "Checking for updates (last check: $([Math]::Round($daysSinceCheck, 0)) days ago)..." -ForegroundColor Cyan
            try {
                Update-SecretsMonitor -ErrorAction SilentlyContinue
            }
            catch {
                # Silently fail update check on module load
            }
        }
    }
    else {
        # Never checked, do initial check
        Write-Host "Performing initial update check..." -ForegroundColor Cyan
        try {
            Update-SecretsMonitor -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail update check on module load
        }
    }
}

Write-Host "Secrets Expiration Monitor loaded. Type 'Get-Command -Module SecretsExpirationMonitor' for available commands." -ForegroundColor Green
