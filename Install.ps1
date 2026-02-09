<#
.SYNOPSIS
    Installation script for Secrets Expiration Monitor

.DESCRIPTION
    Installs the Secrets Expiration Monitor module to the user's PowerShell modules directory

.EXAMPLE
    .\Install.ps1

.EXAMPLE
    # Install from the web
    Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/basmulder03/secrets-expiration-monitor/main/Install.ps1").Content
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Secrets Expiration Monitor - Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine PowerShell modules path
$modulePath = if ($PSVersionTable.PSVersion.Major -ge 6) {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules"
} else {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules"
}

$targetPath = Join-Path $modulePath "SecretsExpirationMonitor"

Write-Host "Installation path: $targetPath" -ForegroundColor White

# Check if module is already installed
if (Test-Path $targetPath) {
    Write-Host "`nModule is already installed." -ForegroundColor Yellow
    $response = Read-Host "Do you want to reinstall/update? (Y/N)"
    
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Removing existing installation..." -ForegroundColor Cyan
    Remove-Item $targetPath -Recurse -Force
}

# Create modules directory if it doesn't exist
if (-not (Test-Path $modulePath)) {
    Write-Host "Creating modules directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
}

# Copy module files
Write-Host "Installing module..." -ForegroundColor Cyan
$sourcePath = Join-Path $PSScriptRoot "SecretsExpirationMonitor"

if (-not (Test-Path $sourcePath)) {
    Write-Error "Module source not found at: $sourcePath"
    exit 1
}

Copy-Item $sourcePath -Destination $targetPath -Recurse -Force

Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host ""

# Import the module
Write-Host "Importing module..." -ForegroundColor Cyan
try {
    Import-Module SecretsExpirationMonitor -Force
    Write-Host "Module imported successfully!" -ForegroundColor Green
}
catch {
    Write-Warning "Module installed but could not be imported automatically: $_"
    Write-Host "Please restart your PowerShell session and run: Import-Module SecretsExpirationMonitor" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Getting Started" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. View available commands:" -ForegroundColor White
Write-Host "   Get-Command -Module SecretsExpirationMonitor" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Add a tenant to monitor:" -ForegroundColor White
Write-Host "   Add-MonitorTenant -TenantId 'your-tenant-id' -Name 'Production'" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Run the monitor:" -ForegroundColor White
Write-Host "   Invoke-SecretsMonitor -All" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. View configuration:" -ForegroundColor White
Write-Host "   Get-MonitorConfig" -ForegroundColor Cyan
Write-Host ""
Write-Host "For more information, visit:" -ForegroundColor White
Write-Host "https://github.com/basmulder03/secrets-expiration-monitor" -ForegroundColor Cyan
Write-Host ""
