<#
.SYNOPSIS
    Monitor Azure AD App Registration secrets expiration.

.DESCRIPTION
    This script connects to Microsoft Graph API and retrieves all app registrations
    for a configured tenant. It checks for secrets that will expire soon and displays
    them in a formatted table with color gradient.

.PARAMETER TenantId
    The Azure AD tenant ID to connect to. If not provided, uses the default tenant.

.PARAMETER DaysThreshold
    Number of days to check for expiring secrets. Default is 90 days.

.EXAMPLE
    .\Get-AppRegistrationSecrets.ps1 -DaysThreshold 60
    
.EXAMPLE
    .\Get-AppRegistrationSecrets.ps1 -TenantId "your-tenant-id" -DaysThreshold 30
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [int]$DaysThreshold = 90
)

# Function to get color based on days remaining
function Get-ExpirationColor {
    param(
        [int]$DaysRemaining,
        [int]$Threshold
    )
    
    if ($DaysRemaining -le 0) {
        return "Red"
    }
    elseif ($DaysRemaining -le [Math]::Floor($Threshold * 0.25)) {
        return "Red"
    }
    elseif ($DaysRemaining -le [Math]::Floor($Threshold * 0.5)) {
        return "Yellow"
    }
    elseif ($DaysRemaining -le [Math]::Floor($Threshold * 0.75)) {
        return "Cyan"
    }
    else {
        return "Green"
    }
}

# Function to process secrets and filter duplicates
function Get-FilteredSecrets {
    param(
        [array]$Secrets,
        [int]$Threshold,
        [string]$AppName,
        [string]$AppId
    )
    
    $results = @()
    $now = Get-Date
    
    # Group secrets by display name
    $groupedSecrets = $Secrets | Group-Object -Property DisplayName
    
    foreach ($group in $groupedSecrets) {
        $secretsInGroup = $group.Group | Sort-Object -Property EndDateTime -Descending
        
        # Check if there's a newer secret that won't expire within threshold
        $hasValidReplacement = $false
        foreach ($secret in $secretsInGroup) {
            if ($secret.EndDateTime) {
                $daysUntilExpiration = ($secret.EndDateTime - $now).Days
                if ($daysUntilExpiration -gt $Threshold) {
                    $hasValidReplacement = $true
                    # Only add the newest non-expiring secret
                    $results += [PSCustomObject]@{
                        AppName = $AppName
                        AppId = $AppId
                        SecretName = if ($secret.DisplayName) { $secret.DisplayName } else { "No Display Name" }
                        KeyId = $secret.KeyId
                        StartDate = $secret.StartDateTime
                        EndDate = $secret.EndDateTime
                        DaysRemaining = $daysUntilExpiration
                        Status = "Valid"
                    }
                    break
                }
            }
        }
        
        # If no valid replacement, add all expiring secrets in this group
        if (-not $hasValidReplacement) {
            foreach ($secret in $secretsInGroup) {
                if ($secret.EndDateTime) {
                    $daysUntilExpiration = ($secret.EndDateTime - $now).Days
                    if ($daysUntilExpiration -le $Threshold) {
                        $status = if ($daysUntilExpiration -le 0) { "Expired" } else { "Expiring" }
                        $results += [PSCustomObject]@{
                            AppName = $AppName
                            AppId = $AppId
                            SecretName = if ($secret.DisplayName) { $secret.DisplayName } else { "No Display Name" }
                            KeyId = $secret.KeyId
                            StartDate = $secret.StartDateTime
                            EndDate = $secret.EndDateTime
                            DaysRemaining = $daysUntilExpiration
                            Status = $status
                        }
                    }
                }
            }
        }
    }
    
    return $results
}

# Check if Microsoft.Graph module is installed
$requiredModules = @('Microsoft.Graph.Applications', 'Microsoft.Graph.Authentication')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Warning "Module '$module' is not installed. Installing..."
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install module '$module': $_"
            exit 1
        }
    }
}

# Import required modules
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    $connectParams = @{
        Scopes = @("Application.Read.All")
    }
    
    if ($TenantId) {
        $connectParams['TenantId'] = $TenantId
    }
    
    Connect-MgGraph @connectParams -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}

# Get current context
$context = Get-MgContext
Write-Host "Tenant: $($context.TenantId)" -ForegroundColor Cyan
Write-Host "Checking for secrets expiring within $DaysThreshold days...`n" -ForegroundColor Cyan

# Retrieve all app registrations
Write-Host "Retrieving app registrations..." -ForegroundColor Cyan
try {
    $appRegistrations = Get-MgApplication -All
    Write-Host "Found $($appRegistrations.Count) app registrations.`n" -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve app registrations: $_"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Process app registrations and check for expiring secrets
$expiringSecrets = @()

foreach ($app in $appRegistrations) {
    if ($app.PasswordCredentials -and $app.PasswordCredentials.Count -gt 0) {
        $filteredSecrets = Get-FilteredSecrets -Secrets $app.PasswordCredentials -Threshold $DaysThreshold -AppName $app.DisplayName -AppId $app.AppId
        if ($filteredSecrets) {
            $expiringSecrets += $filteredSecrets
        }
    }
}

# Display results
if ($expiringSecrets.Count -eq 0) {
    Write-Host "No secrets found expiring within $DaysThreshold days." -ForegroundColor Green
}
else {
    Write-Host "Found $($expiringSecrets.Count) secret(s) requiring attention:`n" -ForegroundColor Yellow
    
    # Sort by days remaining (ascending)
    $sortedSecrets = $expiringSecrets | Sort-Object -Property DaysRemaining
    
    # Display with color coding
    foreach ($secret in $sortedSecrets) {
        $color = Get-ExpirationColor -DaysRemaining $secret.DaysRemaining -Threshold $DaysThreshold
        
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "App Name: " -NoNewline -ForegroundColor White
        Write-Host $secret.AppName -ForegroundColor Cyan
        Write-Host "App ID: " -NoNewline -ForegroundColor White
        Write-Host $secret.AppId -ForegroundColor Gray
        Write-Host "Secret Name: " -NoNewline -ForegroundColor White
        Write-Host $secret.SecretName -ForegroundColor White
        Write-Host "Key ID: " -NoNewline -ForegroundColor White
        Write-Host $secret.KeyId -ForegroundColor Gray
        Write-Host "Start Date: " -NoNewline -ForegroundColor White
        Write-Host $secret.StartDate.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Gray
        Write-Host "End Date: " -NoNewline -ForegroundColor White
        Write-Host $secret.EndDate.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Gray
        Write-Host "Days Remaining: " -NoNewline -ForegroundColor White
        Write-Host $secret.DaysRemaining -ForegroundColor $color
        Write-Host "Status: " -NoNewline -ForegroundColor White
        Write-Host $secret.Status -ForegroundColor $color
    }
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""
    
    # Summary table
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    $expired = ($sortedSecrets | Where-Object { $_.DaysRemaining -le 0 }).Count
    $critical = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt 0 -and $_.DaysRemaining -le ($DaysThreshold * 0.25) }).Count
    $warning = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt ($DaysThreshold * 0.25) -and $_.DaysRemaining -le ($DaysThreshold * 0.5) }).Count
    $info = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt ($DaysThreshold * 0.5) }).Count
    
    Write-Host "Expired: " -NoNewline -ForegroundColor White
    Write-Host $expired -ForegroundColor Red
    Write-Host "Critical (< $([Math]::Floor($DaysThreshold * 0.25)) days): " -NoNewline -ForegroundColor White
    Write-Host $critical -ForegroundColor Red
    Write-Host "Warning (< $([Math]::Floor($DaysThreshold * 0.5)) days): " -NoNewline -ForegroundColor White
    Write-Host $warning -ForegroundColor Yellow
    Write-Host "Info (< $DaysThreshold days): " -NoNewline -ForegroundColor White
    Write-Host $info -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
}

# Disconnect from Microsoft Graph
Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Cyan
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected successfully." -ForegroundColor Green
