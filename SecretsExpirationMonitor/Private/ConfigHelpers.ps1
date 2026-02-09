<#
.SYNOPSIS
    Private helper functions for configuration management
#>

function Get-ConfigPath {
    [CmdletBinding()]
    param()
    
    $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        Join-Path $env:APPDATA "SecretsExpirationMonitor"
    } elseif ($IsMacOS) {
        Join-Path $HOME "Library/Application Support/SecretsExpirationMonitor"
    } else {
        Join-Path $HOME ".config/SecretsExpirationMonitor"
    }
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    return Join-Path $configDir "config.json"
}

function Get-StoredConfig {
    [CmdletBinding()]
    param()
    
    $configPath = Get-ConfigPath
    
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            return $config
        }
        catch {
            Write-Warning "Failed to read configuration: $_"
            return $null
        }
    }
    
    return $null
}

function Save-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    $configPath = Get-ConfigPath
    
    try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
        return $true
    }
    catch {
        Write-Error "Failed to save configuration: $_"
        return $false
    }
}

function Initialize-DefaultConfig {
    [CmdletBinding()]
    param()
    
    $config = [PSCustomObject]@{
        Version = "1.0.0"
        DefaultDaysThreshold = 90
        LastUpdateCheck = $null
        AutoUpdate = $true
        Tenants = @()
    }
    
    Save-Config -Config $config
    return $config
}

function Get-ExpirationColor {
    [CmdletBinding()]
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

function Get-FilteredSecrets {
    [CmdletBinding()]
    param(
        [array]$Secrets,
        [int]$Threshold,
        [string]$AppName,
        [string]$AppId
    )
    
    $results = @()
    $now = Get-Date
    
    if (-not $Secrets -or $Secrets.Count -eq 0) {
        return $results
    }
    
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

function Show-SecretResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Secrets,
        [Parameter(Mandatory = $true)]
        [int]$Threshold,
        [Parameter(Mandatory = $false)]
        [string]$TenantName
    )
    
    if ($Secrets.Count -eq 0) {
        if ($TenantName) {
            Write-Host "`n[$TenantName] No secrets found expiring within $Threshold days." -ForegroundColor Green
        } else {
            Write-Host "`nNo secrets found expiring within $Threshold days." -ForegroundColor Green
        }
        return
    }
    
    $headerPrefix = if ($TenantName) { "[$TenantName] " } else { "" }
    Write-Host "`n${headerPrefix}Found $($Secrets.Count) secret(s) requiring attention:" -ForegroundColor Yellow
    
    # Sort by days remaining (ascending)
    $sortedSecrets = $Secrets | Sort-Object -Property DaysRemaining
    
    # Display with color coding
    foreach ($secret in $sortedSecrets) {
        $color = Get-ExpirationColor -DaysRemaining $secret.DaysRemaining -Threshold $Threshold
        
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
    Write-Host "${headerPrefix}Summary:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    $expired = ($sortedSecrets | Where-Object { $_.DaysRemaining -le 0 }).Count
    $critical = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt 0 -and $_.DaysRemaining -le ($Threshold * 0.25) }).Count
    $warning = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt ($Threshold * 0.25) -and $_.DaysRemaining -le ($Threshold * 0.5) }).Count
    $info = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt ($Threshold * 0.5) }).Count
    
    Write-Host "Expired: " -NoNewline -ForegroundColor White
    Write-Host $expired -ForegroundColor Red
    Write-Host "Critical (< $([Math]::Floor($Threshold * 0.25)) days): " -NoNewline -ForegroundColor White
    Write-Host $critical -ForegroundColor Red
    Write-Host "Warning (< $([Math]::Floor($Threshold * 0.5)) days): " -NoNewline -ForegroundColor White
    Write-Host $warning -ForegroundColor Yellow
    Write-Host "Info (< $Threshold days): " -NoNewline -ForegroundColor White
    Write-Host $info -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
}
