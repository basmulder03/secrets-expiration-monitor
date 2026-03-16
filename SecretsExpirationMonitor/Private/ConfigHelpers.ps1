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

# ---------------------------------------------------------------------------
# Render-SecretsTable
#   Pure rendering function – writes the table to stdout given a terminal
#   width. Kept separate so it can be called both for the initial paint and
#   on every resize in the live-view loop.
# ---------------------------------------------------------------------------
function Render-SecretsTable {
    [CmdletBinding()]
    param(
        [array]$SortedSecrets,
        [int]$Threshold,
        [string]$TenantId,
        [bool]$SupportsHyperlinks,
        # Usable width: caller is responsible for passing (WindowWidth - 1)
        [int]$Width
    )

    $separator      = "  "
    $separatorTotal = 7 * $separator.Length   # 7 gaps between 8 columns

    # Fixed-width columns
    $dateWidth = 10   # yyyy-MM-dd
    $minDays   = [Math]::Max(4, "Days".Length)
    $minStatus = [Math]::Max(7, "Status".Length)
    $fixedTotal = ($dateWidth * 2) + $minDays + $minStatus

    # Available space distributed across the four variable columns
    $available     = $Width - $separatorTotal - $fixedTotal
    $varAppName    = [Math]::Max("App".Length,    [Math]::Floor($available * 0.30))
    $varAppId      = [Math]::Max("App ID".Length, [Math]::Floor($available * 0.20))
    $varSecretName = [Math]::Max("Secret".Length, [Math]::Floor($available * 0.30))
    $varKeyId      = [Math]::Max("Key ID".Length, $available - $varAppName - $varAppId - $varSecretName)

    # Build display rows
    $rows = $SortedSecrets | ForEach-Object {
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
        }
    }

    # Actual column widths = max(header, max-content) — no wider than allocated
    $cw = @{
        AppName       = [Math]::Max("App".Length,    ($rows | ForEach-Object { $_.AppName.Length }       | Measure-Object -Maximum).Maximum)
        AppId         = [Math]::Max("App ID".Length, ($rows | ForEach-Object { $_.AppId.Length }         | Measure-Object -Maximum).Maximum)
        SecretName    = [Math]::Max("Secret".Length, ($rows | ForEach-Object { $_.SecretName.Length }    | Measure-Object -Maximum).Maximum)
        KeyId         = [Math]::Max("Key ID".Length, ($rows | ForEach-Object { $_.KeyId.Length }         | Measure-Object -Maximum).Maximum)
        StartDate     = $dateWidth
        EndDate       = $dateWidth
        DaysRemaining = [Math]::Max("Days".Length,   ($rows | ForEach-Object { $_.DaysRemaining.Length } | Measure-Object -Maximum).Maximum)
        Status        = [Math]::Max("Status".Length, ($rows | ForEach-Object { $_.Status.Length }        | Measure-Object -Maximum).Maximum)
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

    $headerLine  = ($columns | ForEach-Object { $_.Name.PadRight($cw[$_.Property]) }) -join $separator
    $dividerLine = ($columns | ForEach-Object { "-" * $cw[$_.Property] }) -join $separator
    $barWidth    = $headerLine.Length

    Write-Host ("=" * $barWidth) -ForegroundColor Gray
    Write-Host $headerLine -ForegroundColor White
    Write-Host $dividerLine -ForegroundColor Gray

    foreach ($row in $rows) {
        if ($SupportsHyperlinks) {
            $appNameCell = Get-AnsiHyperlink -Text $row.AppName.PadRight($cw.AppName) -Url $row.PortalUrl
            Write-Host $appNameCell -NoNewline -ForegroundColor Cyan
        } else {
            Write-Host $row.AppName.PadRight($cw.AppName) -NoNewline -ForegroundColor Cyan
        }
        Write-Host $separator -NoNewline
        Write-Host $row.AppId.PadRight($cw.AppId) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $row.SecretName.PadRight($cw.SecretName) -NoNewline -ForegroundColor White
        Write-Host $separator -NoNewline
        Write-Host $row.KeyId.PadRight($cw.KeyId) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $row.StartDate.PadRight($cw.StartDate) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $row.EndDate.PadRight($cw.EndDate) -NoNewline -ForegroundColor Gray
        Write-Host $separator -NoNewline
        Write-Host $row.DaysRemaining.PadRight($cw.DaysRemaining) -NoNewline -ForegroundColor $row.Color
        Write-Host $separator -NoNewline
        Write-Host $row.Status.PadRight($cw.Status) -ForegroundColor $row.Color
    }

    Write-Host ("=" * $barWidth) -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# Show-SecretResults
#   Orchestrates the display for a single tenant result set.
#   With -Detailed: enters a live-resize TUI loop (press any key to exit).
#   Without -Detailed: prints a compact summary only.
# ---------------------------------------------------------------------------
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

    $headerPrefix = if ($TenantName) { "[$TenantName] " } else { "" }

    if ($Secrets.Count -eq 0) {
        Write-Host "`n${headerPrefix}No secrets found expiring within $Threshold days." -ForegroundColor Green
        return
    }

    # Always-visible compact summary
    $sortedSecrets = $Secrets | Sort-Object -Property EndDate
    $expired  = ($sortedSecrets | Where-Object { $_.DaysRemaining -le 0 }).Count
    $critical = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt 0 -and $_.DaysRemaining -le [Math]::Floor($Threshold * 0.25) }).Count
    $warning  = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt [Math]::Floor($Threshold * 0.25) -and $_.DaysRemaining -le [Math]::Floor($Threshold * 0.5) }).Count
    $info     = ($sortedSecrets | Where-Object { $_.DaysRemaining -gt [Math]::Floor($Threshold * 0.5) }).Count

    Write-Host ""
    Write-Host "${headerPrefix}Found $($Secrets.Count) secret(s) requiring attention:" -ForegroundColor Yellow
    Write-Host "  Expired : " -NoNewline -ForegroundColor White;  Write-Host $expired  -ForegroundColor Red
    Write-Host "  Critical: " -NoNewline -ForegroundColor White;  Write-Host "$critical (< $([Math]::Floor($Threshold * 0.25)) days)"  -ForegroundColor Red
    Write-Host "  Warning : " -NoNewline -ForegroundColor White;  Write-Host "$warning (< $([Math]::Floor($Threshold * 0.5)) days)"   -ForegroundColor Yellow
    Write-Host "  Info    : " -NoNewline -ForegroundColor White;  Write-Host "$info (< $Threshold days)"    -ForegroundColor Cyan

    if (-not $Detailed) {
        Write-Host "  (Run with -Detailed to see the full table)" -ForegroundColor DarkGray
        return
    }

    # --- Detailed: live-resize TUI table ---
    $supportsHyperlinks = Test-AnsiHyperlinkSupport

    Write-Host ""
    if ($supportsHyperlinks) {
        Write-Host "(Ctrl+Click an app name to open it in Azure Portal  |  Press any key to exit)" -ForegroundColor DarkGray
    } else {
        Write-Host "(Press any key to exit the live view)" -ForegroundColor DarkGray
    }

    # Helper: get usable width (WindowWidth - 1 avoids the wrap-on-last-col quirk)
    $getWidth = {
        $w = 79
        try { $w = [Console]::WindowWidth - 1 } catch {}
        if ($w -lt 40) { $w = 40 }
        $w
    }

    # Initial paint
    $lastWidth = & $getWidth
    Render-SecretsTable -SortedSecrets $sortedSecrets -Threshold $Threshold `
        -TenantId $TenantId -SupportsHyperlinks $supportsHyperlinks -Width $lastWidth

    # Live-resize loop: re-draw whenever the window width changes
    # Runs until the user presses a key.
    [Console]::CursorVisible = $false
    try {
        while (-not [Console]::KeyAvailable) {
            Start-Sleep -Milliseconds 150
            $currentWidth = & $getWidth
            if ($currentWidth -ne $lastWidth) {
                $lastWidth = $currentWidth

                # Move cursor up by (3 header rows + number of data rows + 1 closing bar)
                $rowsToErase = 3 + $sortedSecrets.Count + 1
                $esc = [char]27
                # Erase the table: move up N lines, then clear from cursor to end of screen
                Write-Host -NoNewline "${esc}[${rowsToErase}A${esc}[J"

                Render-SecretsTable -SortedSecrets $sortedSecrets -Threshold $Threshold `
                    -TenantId $TenantId -SupportsHyperlinks $supportsHyperlinks -Width $lastWidth
            }
        }
        # Consume the keypress
        [Console]::ReadKey($true) | Out-Null
    } finally {
        [Console]::CursorVisible = $true
        Write-Host ""
    }
}
