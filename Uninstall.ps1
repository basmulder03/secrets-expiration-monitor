<#
.SYNOPSIS
    Uninstallation script for Secrets Expiration Monitor

.DESCRIPTION
    Removes the Secrets Expiration Monitor module from the user's PowerShell modules directory

.PARAMETER RemoveConfig
    Also remove the configuration file

.EXAMPLE
    .\Uninstall.ps1

.EXAMPLE
    .\Uninstall.ps1 -RemoveConfig
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$RemoveConfig
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Secrets Expiration Monitor - Uninstaller" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine PowerShell modules path
$modulePath = if ($PSVersionTable.PSVersion.Major -ge 6) {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules\SecretsExpirationMonitor"
} else {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules\SecretsExpirationMonitor"
}

# Check if module is installed
if (-not (Test-Path $modulePath)) {
    Write-Host "Module is not installed at: $modulePath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Module found at: $modulePath" -ForegroundColor White

$response = Read-Host "`nAre you sure you want to uninstall? (Y/N)"

if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
    exit 0
}

# Remove module
Write-Host "`nRemoving module..." -ForegroundColor Cyan
try {
    Remove-Module SecretsExpirationMonitor -Force -ErrorAction SilentlyContinue
    Remove-Item $modulePath -Recurse -Force
    Write-Host "Module removed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to remove module: $_"
    exit 1
}

# Remove configuration if requested
if ($RemoveConfig) {
    Write-Host "`nRemoving configuration..." -ForegroundColor Cyan
    
    $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        Join-Path $env:APPDATA "SecretsExpirationMonitor"
    } elseif ($IsMacOS) {
        Join-Path $HOME "Library/Application Support/SecretsExpirationMonitor"
    } else {
        Join-Path $HOME ".config/SecretsExpirationMonitor"
    }
    
    if (Test-Path $configDir) {
        try {
            Remove-Item $configDir -Recurse -Force
            Write-Host "Configuration removed successfully!" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to remove configuration: $_"
        }
    }
    else {
        Write-Host "No configuration found." -ForegroundColor Yellow
    }
}
else {
    Write-Host "`nConfiguration was preserved. Use -RemoveConfig to remove it." -ForegroundColor Cyan
}

Write-Host "`nUninstallation completed!" -ForegroundColor Green
Write-Host "Thank you for using Secrets Expiration Monitor." -ForegroundColor Cyan
Write-Host ""
