<#
.SYNOPSIS
    Monitor Azure AD App Registration secrets expiration

.DESCRIPTION
    Monitors app registration secrets for expiration across configured tenants

.PARAMETER TenantName
    Monitor a specific tenant by name

.PARAMETER TenantId
    Monitor a specific tenant by ID

.PARAMETER DaysThreshold
    Override the days threshold for this run

.PARAMETER All
    Monitor all configured tenants

.EXAMPLE
    Invoke-SecretsMonitor -TenantName "Production"

.EXAMPLE
    Invoke-SecretsMonitor -All

.EXAMPLE
    Invoke-SecretsMonitor -TenantId "12345678-1234-1234-1234-123456789abc" -DaysThreshold 30
#>
function Invoke-SecretsMonitor {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [Alias('Monitor-Secrets', 'Check-Secrets')]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$TenantName,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysThreshold,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [switch]$All
    )
    
    # Check for required modules
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
                return
            }
        }
    }
    
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    
    # Load configuration
    $config = Get-StoredConfig
    if (-not $config) {
        $config = Initialize-DefaultConfig
    }
    
    if ($config.Tenants.Count -eq 0) {
        Write-Host "No tenants configured. Use Add-MonitorTenant to add a tenant." -ForegroundColor Yellow
        Write-Host "`nExample:" -ForegroundColor Cyan
        Write-Host '  Add-MonitorTenant -TenantId "your-tenant-id" -Name "Production"' -ForegroundColor White
        return
    }
    
    # Determine which tenants to monitor
    $tenantsToMonitor = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $tenant = $config.Tenants | Where-Object { $_.Name -eq $TenantName }
        if (-not $tenant) {
            Write-Error "Tenant '$TenantName' not found"
            return
        }
        $tenantsToMonitor = @($tenant)
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
        $tenant = $config.Tenants | Where-Object { $_.TenantId -eq $TenantId }
        if (-not $tenant) {
            Write-Error "Tenant '$TenantId' not found"
            return
        }
        $tenantsToMonitor = @($tenant)
    }
    else {
        # Monitor all tenants
        $tenantsToMonitor = $config.Tenants
    }
    
    Write-Host "`nSecrets Expiration Monitor" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Monitoring $($tenantsToMonitor.Count) tenant(s)" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    $allResults = @()
    
    foreach ($tenant in $tenantsToMonitor) {
        $threshold = if ($DaysThreshold) { $DaysThreshold } else { $tenant.DaysThreshold }
        
        Write-Host "`n[$($tenant.Name)] Connecting to Microsoft Graph..." -ForegroundColor Cyan
        
        try {
            Connect-MgGraph -TenantId $tenant.TenantId -Scopes "Application.Read.All" -NoWelcome -ErrorAction Stop
            
            $context = Get-MgContext
            Write-Host "[$($tenant.Name)] Connected to tenant: $($context.TenantId)" -ForegroundColor Green
            Write-Host "[$($tenant.Name)] Checking for secrets expiring within $threshold days..." -ForegroundColor Cyan
            
            # Retrieve app registrations
            Write-Host "[$($tenant.Name)] Retrieving app registrations..." -ForegroundColor Cyan
            $appRegistrations = Get-MgApplication -All -ErrorAction Stop
            Write-Host "[$($tenant.Name)] Found $($appRegistrations.Count) app registrations" -ForegroundColor Green
            
            # Process secrets
            $expiringSecrets = @()
            foreach ($app in $appRegistrations) {
                if ($app.PasswordCredentials -and $app.PasswordCredentials.Count -gt 0) {
                    $filteredSecrets = Get-FilteredSecrets -Secrets $app.PasswordCredentials -Threshold $threshold -AppName $app.DisplayName -AppId $app.AppId
                    if ($filteredSecrets) {
                        $expiringSecrets += $filteredSecrets
                    }
                }
            }
            
            # Display results for this tenant
            Show-SecretResults -Secrets $expiringSecrets -Threshold $threshold -TenantName $tenant.Name
            
            # Add to overall results
            foreach ($secret in $expiringSecrets) {
                $secret | Add-Member -NotePropertyName "TenantName" -NotePropertyValue $tenant.Name -Force
                $allResults += $secret
            }
            
            # Disconnect
            Disconnect-MgGraph | Out-Null
            Write-Host "[$($tenant.Name)] Disconnected from Microsoft Graph" -ForegroundColor Green
        }
        catch {
            Write-Error "[$($tenant.Name)] Error: $_"
            try {
                Disconnect-MgGraph | Out-Null
            } catch {}
            continue
        }
    }
    
    # Overall summary if monitoring multiple tenants
    if ($tenantsToMonitor.Count -gt 1) {
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 80) -ForegroundColor Cyan
        Write-Host "Overall Summary Across All Tenants" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Cyan
        
        $totalExpired = ($allResults | Where-Object { $_.DaysRemaining -le 0 }).Count
        $totalCritical = ($allResults | Where-Object { $_.DaysRemaining -gt 0 -and $_.Status -eq "Expiring" }).Count
        $totalValid = ($allResults | Where-Object { $_.Status -eq "Valid" }).Count
        
        Write-Host "Total Secrets Requiring Attention: " -NoNewline -ForegroundColor White
        Write-Host $allResults.Count -ForegroundColor Yellow
        Write-Host "  Expired: " -NoNewline -ForegroundColor White
        Write-Host $totalExpired -ForegroundColor Red
        Write-Host "  Expiring: " -NoNewline -ForegroundColor White
        Write-Host $totalCritical -ForegroundColor Yellow
        Write-Host "  Valid (but flagged): " -NoNewline -ForegroundColor White
        Write-Host $totalValid -ForegroundColor Green
        Write-Host ("=" * 80) -ForegroundColor Cyan
    }
    
    return $allResults
}
