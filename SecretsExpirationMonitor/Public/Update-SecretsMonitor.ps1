<#
.SYNOPSIS
    Check for and install updates

.DESCRIPTION
    Checks GitHub for new releases and updates the module if a newer version is available

.PARAMETER Force
    Force check for updates even if recently checked

.EXAMPLE
    Update-SecretsMonitor

.EXAMPLE
    Update-SecretsMonitor -Force
#>
function Update-SecretsMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    $config = Get-StoredConfig
    if (-not $config) {
        $config = Initialize-DefaultConfig
    }
    
    # Check if we should skip (unless forced)
    if (-not $Force -and $config.LastUpdateCheck) {
        $lastCheck = [DateTime]::Parse($config.LastUpdateCheck)
        $hoursSinceCheck = ((Get-Date) - $lastCheck).TotalHours
        
        if ($hoursSinceCheck -lt 24) {
            Write-Host "Last update check was $([Math]::Round($hoursSinceCheck, 1)) hours ago. Use -Force to check again." -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "Checking for updates..." -ForegroundColor Cyan
    
    $modulePath = Split-Path -Parent $PSScriptRoot
    try {
        # Get current version
        $manifestPath = Join-Path $modulePath "SecretsExpirationMonitor.psd1"
        
        if (Test-Path $manifestPath) {
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $currentVersion = [Version]$manifest.ModuleVersion
        } else {
            $currentVersion = [Version]"1.0.0"
        }
        
        Write-Host "Current version: $currentVersion" -ForegroundColor White
        
        # Check GitHub for latest release
        $repoOwner = "basmulder03"
        $repoName = "secrets-expiration-monitor"
        $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
        
        try {
            $latestRelease = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            $latestVersion = [Version]($latestRelease.tag_name -replace '^v', '')
            
            Write-Host "Latest version: $latestVersion" -ForegroundColor White
            
            # Update last check time
            $config.LastUpdateCheck = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Save-Config -Config $config | Out-Null
            
            if ($latestVersion -gt $currentVersion) {
                Write-Host "`nNew version available!" -ForegroundColor Green
                Write-Host "Current: $currentVersion" -ForegroundColor Yellow
                Write-Host "Latest:  $latestVersion" -ForegroundColor Green
                Write-Host "`nRelease Notes:" -ForegroundColor Cyan
                Write-Host $latestRelease.body -ForegroundColor White
                
                $response = Read-Host "`nWould you like to update now? (Y/N)"
                
                if ($response -eq 'Y' -or $response -eq 'y') {
                    Write-Host "`nUpdating module..." -ForegroundColor Cyan
                    
                    # Download and extract the update
                    $downloadUrl = $latestRelease.zipball_url
                    $tempPath = Join-Path $env:TEMP "SecretsExpirationMonitor-Update.zip"
                    
                    Write-Host "Downloading update..." -ForegroundColor Cyan
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -ErrorAction Stop
                    
                    # Extract to temp location
                    $extractPath = Join-Path $env:TEMP "SecretsExpirationMonitor-Extract"
                    if (Test-Path $extractPath) {
                        Remove-Item $extractPath -Recurse -Force
                    }
                    
                    Expand-Archive -Path $tempPath -DestinationPath $extractPath -Force
                    
                    # Find the extracted folder (GitHub creates a folder with repo name + commit hash)
                    $extractedFolder = Get-ChildItem $extractPath | Select-Object -First 1
                    $sourceModulePath = Join-Path $extractedFolder.FullName "SecretsExpirationMonitor"
                    
                    # Copy to module path
                    $moduleInstallPath = (Get-Module -Name SecretsExpirationMonitor | Select-Object -First 1).ModuleBase
                    if (-not $moduleInstallPath) {
                        $moduleInstallPath = $modulePath
                    }
                    
                    if (-not (Test-Path (Split-Path $moduleInstallPath))) {
                        New-Item -ItemType Directory -Path (Split-Path $moduleInstallPath) -Force | Out-Null
                    }
                    
                    if (Test-Path $moduleInstallPath) {
                        Remove-Item $moduleInstallPath -Recurse -Force
                    }
                    
                    Copy-Item $sourceModulePath -Destination $moduleInstallPath -Recurse -Force
                    
                    # Cleanup
                    Remove-Item $tempPath -Force
                    Remove-Item $extractPath -Recurse -Force
                    
                    Write-Host "`nUpdate completed successfully!" -ForegroundColor Green
                    Write-Host "Please restart your PowerShell session to use the new version." -ForegroundColor Yellow
                    
                    # Update config version
                    $config.Version = $latestVersion.ToString()
                    Save-Config -Config $config | Out-Null
                }
                else {
                    Write-Host "Update cancelled." -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "You are running the latest version." -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Could not check for updates: $_"
            Write-Host "Visit https://github.com/$repoOwner/$repoName/releases for manual updates" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "Error checking for updates: $_"
    }
}
