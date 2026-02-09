<#
.SYNOPSIS
    Monitor Azure AD App Registration secrets expiration with config file support.

.DESCRIPTION
    This is a wrapper script that loads configuration from config.json if it exists,
    then calls Get-AppRegistrationSecrets.ps1 with the appropriate parameters.

.PARAMETER ConfigPath
    Path to the configuration file. Default is "./config.json"

.EXAMPLE
    .\Start-Monitor.ps1
    
.EXAMPLE
    .\Start-Monitor.ps1 -ConfigPath ".\my-config.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "./config.json"
)

$scriptDir = $PSScriptRoot
$mainScript = Join-Path $scriptDir "Get-AppRegistrationSecrets.ps1"

# Check if main script exists
if (-not (Test-Path $mainScript)) {
    Write-Error "Main script not found at: $mainScript"
    exit 1
}

# Initialize parameters
$params = @{}

# Load config if it exists
if (Test-Path $ConfigPath) {
    Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Cyan
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        if ($config.TenantId) {
            $params['TenantId'] = $config.TenantId
        }
        
        if ($config.DaysThreshold) {
            $params['DaysThreshold'] = $config.DaysThreshold
        }
        
        Write-Host "Configuration loaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to load configuration file: $_"
        Write-Host "Proceeding with default settings..." -ForegroundColor Yellow
    }
}
else {
    Write-Host "No configuration file found. Using default settings." -ForegroundColor Yellow
    Write-Host "You can create a config.json file based on config.example.json" -ForegroundColor Cyan
}

# Run the main script
Write-Host "`nStarting Secrets Expiration Monitor..." -ForegroundColor Cyan
& $mainScript @params
