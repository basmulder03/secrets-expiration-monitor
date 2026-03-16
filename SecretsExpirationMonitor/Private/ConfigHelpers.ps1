<#
.SYNOPSIS
    Private helper functions for configuration management
#>

$script:CompactEllipsisLength = 3

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

function Format-CompactText {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,
        [int]$MaxLength
    )
    
    $validatedMaxLength = [Math]::Max(0, $MaxLength)
    if ($validatedMaxLength -eq 0) {
        return ""
    }
    
    $ellipsisLength = $script:CompactEllipsisLength
    if ([string]::IsNullOrEmpty($Value)) {
        return ""
    }
    
    if ($Value.Length -le $validatedMaxLength) {
        return $Value
    }
    
    if ($validatedMaxLength -le $ellipsisLength) {
        return $Value.Substring(0, $validatedMaxLength)
    }
    
    return $Value.Substring(0, $validatedMaxLength - $ellipsisLength) + "..."
}

function Format-CompactId {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,
        [int]$MaxLength
    )
    
    $validatedMaxLength = [Math]::Max(0, $MaxLength)
    if ($validatedMaxLength -eq 0) {
        return ""
    }
    
    $ellipsisLength = $script:CompactEllipsisLength
    if ([string]::IsNullOrEmpty($Value)) {
        return ""
    }
    
    if ($Value.Length -le $validatedMaxLength) {
        return $Value
    }
    
    if ($validatedMaxLength -le $ellipsisLength) {
        return $Value.Substring(0, $validatedMaxLength)
    }
    
    $remainingLength = $validatedMaxLength - $ellipsisLength
    $prefixLength = [Math]::Floor($remainingLength / 2)
    # When the remaining length is odd, keep the extra character in the suffix.
    $suffixLength = $remainingLength - $prefixLength
    return $Value.Substring(0, $prefixLength) + "..." + $Value.Substring($Value.Length - $suffixLength)
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

function Get-PortalUrl {
    [CmdletBinding()]
    param(
        [string]$AppId,
        [string]$TenantId
    )

    if ($TenantId) {
        return "https://portal.azure.com/$TenantId/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$AppId"
    }
    return "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$AppId"
}

function Get-AnsiHyperlink {
    [CmdletBinding()]
    param(
        [string]$Text,
        [string]$Url
    )

    # OSC 8 hyperlink escape sequence: ESC ] 8 ; ; URL BEL text ESC ] 8 ; ; BEL
    $esc = [char]27
    $bel = [char]7
    return "${esc}]8;;${Url}${bel}${Text}${esc}]8;;${bel}"
}

function Test-AnsiHyperlinkSupport {
    [CmdletBinding()]
    param()

    # Check for terminals known to support OSC 8 hyperlinks
    $termProgram = $env:TERM_PROGRAM
    $wtSession   = $env:WT_SESSION          # Windows Terminal
    $vscTerm     = $env:TERM_PROGRAM -eq 'vscode'
    $colorterm   = $env:COLORTERM

    if ($wtSession -or $vscTerm -or $termProgram -eq 'iTerm.app' -or $colorterm -eq 'truecolor' -or $colorterm -eq '24bit') {
        return $true
    }

    # Also check for ConEmu / Cmder
    if ($env:ConEmuBuild -or $env:ConEmuANSI -eq 'ON') {
        return $true
    }

    return $false
}

function Show-SecretResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Secrets,
        [Parameter(Mandatory = $true)]
        [int]$Threshold,
        [Parameter(Mandatory = $false)]
        [string]$TenantName,
        [Parameter(Mandatory = $false)]
        [string]$TenantId,
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
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

    $supportsHyperlinks = Test-AnsiHyperlinkSupport

    if ($supportsHyperlinks) {
        Write-Host "(Ctrl+Click a row to open the app in Azure Portal)" -ForegroundColor DarkGray
    }
    
    # Sort by expiration date (ascending)
    $sortedSecrets = $Secrets | Sort-Object -Property EndDate

    # --- Dynamic terminal-width-aware column sizing ---
    $terminalWidth = 80
    try {
        $w = $Host.UI.RawUI.WindowSize.Width
        if ($w -and $w -gt 0) { $terminalWidth = $w }
    } catch {}

    # Fixed-width columns: dates (10), days (4 min), status (7 min)
    # Separator between 8 columns = 7 * 2 = 14 chars
    $separator       = "  "
    $separatorCount  = 7
    $separatorTotal  = $separatorCount * $separator.Length

    # Minimum widths (also serve as header label lengths)
    $minAppName    = [Math]::Max(3,  "App".Length)
    $minAppId      = [Math]::Max(6,  "App ID".Length)
    $minSecretName = [Math]::Max(6,  "Secret".Length)
    $minKeyId      = [Math]::Max(6,  "Key ID".Length)
    $dateWidth     = 10   # yyyy-MM-dd — fixed
    $minDays       = [Math]::Max(4,  "Days".Length)
    $minStatus     = [Math]::Max(7,  "Status".Length)

    # Fixed columns total (dates x2, days, status)
    $fixedTotal = ($dateWidth * 2) + $minDays + $minStatus
    # Available space for the four variable columns
    $available = $terminalWidth - $separatorTotal - $fixedTotal

    # Distribute: App 30%, App ID 20%, Secret 30%, Key ID 20%
    $varAppName    = [Math]::Max($minAppName,    [Math]::Floor($available * 0.30))
    $varAppId      = [Math]::Max($minAppId,      [Math]::Floor($available * 0.20))
    $varSecretName = [Math]::Max($minSecretName, [Math]::Floor($available * 0.30))
    $varKeyId      = [Math]::Max($minKeyId,      $available - $varAppName - $varAppId - $varSecretName)

    # Build display objects using dynamic widths
    $displaySecrets = $sortedSecrets | ForEach-Object {
        $portalUrl = Get-PortalUrl -AppId $_.AppId -TenantId $TenantId
        [PSCustomObject]@{
            AppName       = Format-CompactText -Value $_.AppName    -MaxLength $varAppName
            AppId         = Format-CompactId   -Value $_.AppId      -MaxLength $varAppId
            SecretName    = Format-CompactText -Value $_.SecretName -MaxLength $varSecretName
            KeyId         = Format-CompactId   -Value $_.KeyId      -MaxLength $varKeyId
            StartDate     = $_.StartDate.ToString("yyyy-MM-dd")
            EndDate       = $_.EndDate.ToString("yyyy-MM-dd")
            DaysRemaining = $_.DaysRemaining.ToString()
            Status        = $_.Status
            Color         = Get-ExpirationColor -DaysRemaining $_.DaysRemaining -Threshold $Threshold
            PortalUrl     = $portalUrl
            # Raw AppId kept for hyperlink wrapping (full value)
            RawAppId      = $_.AppId
        }
    }

    # Compute actual column widths from content (header vs. max value)
    $colWidths = @{
        AppName       = [Math]::Max("App".Length,    ($displaySecrets | ForEach-Object { $_.AppName.Length }    | Measure-Object -Maximum).Maximum)
        AppId         = [Math]::Max("App ID".Length, ($displaySecrets | ForEach-Object { $_.AppId.Length }      | Measure-Object -Maximum).Maximum)
        SecretName    = [Math]::Max("Secret".Length, ($displaySecrets | ForEach-Object { $_.SecretName.Length } | Measure-Object -Maximum).Maximum)
        KeyId         = [Math]::Max("Key ID".Length, ($displaySecrets | ForEach-Object { $_.KeyId.Length }      | Measure-Object -Maximum).Maximum)
        StartDate     = $dateWidth
        EndDate       = $dateWidth
        DaysRemaining = [Math]::Max("Days".Length,   ($displaySecrets | ForEach-Object { $_.DaysRemaining.Length } | Measure-Object -Maximum).Maximum)
        Status        = [Math]::Max("Status".Length, ($displaySecrets | ForEach-Object { $_.Status.Length }     | Measure-Object -Maximum).Maximum)
    }

    $columns = @(
        @{ Name = "App";    Property = "AppName" },
        @{ Name = "App ID"; Property = "AppId" },
        @{ Name = "Secret"; Property = "SecretName" },
        @{ Name = "Key ID"; Property = "KeyId" },
        @{ Name = "Start";  Property = "StartDate" },
        @{ Name = "End";    Property = "EndDate" },
        @{ Name = "Days";   Property = "DaysRemaining" },
        @{ Name = "Status"; Property = "Status" }
    )

    $headerLine  = ($columns | ForEach-Object { $_.Name.PadRight($colWidths[$_.Property]) }) -join $separator
    $dividerLine = ($columns | ForEach-Object { "-" * $colWidths[$_.Property] }) -join $separator
    $tableLineWidth = $headerLine.Length

    Write-Host ("=" * $tableLineWidth) -ForegroundColor Gray
    Write-Host $headerLine -ForegroundColor White
    Write-Host $dividerLine -ForegroundColor Gray
    
    foreach ($secret in $displaySecrets) {
        if ($supportsHyperlinks) {
            # Wrap the App Name cell in an OSC 8 hyperlink so the entire row is
            # Ctrl+Clickable from the first column. We only hyperlink AppName to keep
            # the visible text width identical (the escape sequences are zero-width
            # in the rendered output).
            $appNameCell = Get-AnsiHyperlink -Text $secret.AppName.PadRight($colWidths.AppName) -Url $secret.PortalUrl
            Write-Host $appNameCell -NoNewline -ForegroundColor Cyan
        } else {
            Write-Host $secret.AppName.PadRight($colWidths.AppName) -NoNewline -ForegroundColor Cyan
        }
        Write-Host $separator -NoNewline
        Write-Host $secret.AppId.PadRight($colWidths.AppId) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $secret.SecretName.PadRight($colWidths.SecretName) -NoNewline -ForegroundColor White
        Write-Host $separator -NoNewline
        Write-Host $secret.KeyId.PadRight($colWidths.KeyId) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $secret.StartDate.PadRight($colWidths.StartDate) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $secret.EndDate.PadRight($colWidths.EndDate) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $secret.DaysRemaining.PadRight($colWidths.DaysRemaining) -NoNewline -ForegroundColor $secret.Color
        Write-Host $separator -NoNewline
        Write-Host $secret.Status.PadRight($colWidths.Status) -ForegroundColor $secret.Color
    }
    
    Write-Host ("=" * $tableLineWidth) -ForegroundColor Gray
    Write-Host ""
    
    # Summary table (only shown in detailed mode)
    if ($Detailed) {
        Write-Host "${headerPrefix}Summary:" -ForegroundColor Cyan
        Write-Host ("=" * [Math]::Min(80, $tableLineWidth)) -ForegroundColor Gray
        
        $expired  = ($sortedSecrets | Where-Object { $_.DaysRemaining -le 0 }).Count
        $critical = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt 0 -and $_.DaysRemaining -le ($Threshold * 0.25) }).Count
        $warning  = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt ($Threshold * 0.25) -and $_.DaysRemaining -le ($Threshold * 0.5) }).Count
        $info     = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt ($Threshold * 0.5) }).Count
        
        Write-Host "Expired: " -NoNewline -ForegroundColor White
        Write-Host $expired -ForegroundColor Red
        Write-Host "Critical (< $([Math]::Floor($Threshold * 0.25)) days): " -NoNewline -ForegroundColor White
        Write-Host $critical -ForegroundColor Red
        Write-Host "Warning (< $([Math]::Floor($Threshold * 0.5)) days): " -NoNewline -ForegroundColor White
        Write-Host $warning -ForegroundColor Yellow
        Write-Host "Info (< $Threshold days): " -NoNewline -ForegroundColor White
        Write-Host $info -ForegroundColor Cyan
        Write-Host ("=" * [Math]::Min(80, $tableLineWidth)) -ForegroundColor Gray
    }
}
