<#
.SYNOPSIS
    Test suite for the SecretsExpirationMonitor module

.DESCRIPTION
    Tests the CLI tool functionality including tenant management,
    configuration, and module loading
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Module Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$testsPassed = 0
$testsFailed = 0

# Clean up any existing config
$configDir = if ($IsLinux -or $IsMacOS) {
    if ($IsMacOS) {
        Join-Path $HOME "Library/Application Support/SecretsExpirationMonitor"
    } else {
        Join-Path $HOME ".config/SecretsExpirationMonitor"
    }
} else {
    Join-Path $env:APPDATA "SecretsExpirationMonitor"
}

if (Test-Path $configDir) {
    Remove-Item $configDir -Recurse -Force
    Write-Host "Cleaned up existing configuration" -ForegroundColor Yellow
}

Write-Host "`nTest 1: Module Import" -ForegroundColor Cyan
try {
    Import-Module ./SecretsExpirationMonitor/SecretsExpirationMonitor.psd1 -Force
    $commands = Get-Command -Module SecretsExpirationMonitor
    if ($commands.Count -ge 7) {
        Write-Host "✓ PASS: Module imported with $($commands.Count) commands" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Expected at least 7 commands, got $($commands.Count)" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Module import failed: $_" -ForegroundColor Red
    $testsFailed++
    exit 1
}

Write-Host "`nTest 2: Get-MonitorConfig (Initial)" -ForegroundColor Cyan
try {
    $config = Get-MonitorConfig
    if ($config.Version -and $config.DefaultDaysThreshold -eq 90) {
        Write-Host "✓ PASS: Config initialized with correct defaults" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Config not initialized correctly" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Get-MonitorConfig failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 3: Add-MonitorTenant" -ForegroundColor Cyan
try {
    Add-MonitorTenant -TenantId "12345678-1234-1234-1234-123456789abc" -Name "TestTenant1" -DaysThreshold 60
    $config = Get-MonitorConfig
    if ($config.Tenants.Count -eq 1 -and $config.Tenants[0].Name -eq "TestTenant1") {
        Write-Host "✓ PASS: Tenant added successfully" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Tenant not added correctly" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Add-MonitorTenant failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 4: Add Multiple Tenants" -ForegroundColor Cyan
try {
    Add-MonitorTenant -TenantId "87654321-4321-4321-4321-cba987654321" -Name "TestTenant2" -DaysThreshold 30
    $config = Get-MonitorConfig
    if ($config.Tenants.Count -eq 2) {
        Write-Host "✓ PASS: Multiple tenants added successfully" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Expected 2 tenants, got $($config.Tenants.Count)" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Add-MonitorTenant (second) failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 5: Get-MonitorTenants" -ForegroundColor Cyan
try {
    Get-MonitorTenants
    Write-Host "✓ PASS: Get-MonitorTenants executed successfully" -ForegroundColor Green
    $testsPassed++
}
catch {
    Write-Host "✗ FAIL: Get-MonitorTenants failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 6: Set-MonitorConfig" -ForegroundColor Cyan
try {
    Set-MonitorConfig -DefaultDaysThreshold 120
    $config = Get-MonitorConfig
    if ($config.DefaultDaysThreshold -eq 120) {
        Write-Host "✓ PASS: Config updated successfully" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Config not updated correctly" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Set-MonitorConfig failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 7: Remove-MonitorTenant by Name" -ForegroundColor Cyan
try {
    Remove-MonitorTenant -Name "TestTenant1"
    $config = Get-MonitorConfig
    if ($config.Tenants.Count -eq 1 -and $config.Tenants[0].Name -eq "TestTenant2") {
        Write-Host "✓ PASS: Tenant removed successfully" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Tenant not removed correctly" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Remove-MonitorTenant failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 8: Remove-MonitorTenant by ID" -ForegroundColor Cyan
try {
    Remove-MonitorTenant -TenantId "87654321-4321-4321-4321-cba987654321"
    $config = Get-MonitorConfig
    if ($config.Tenants.Count -eq 0) {
        Write-Host "✓ PASS: All tenants removed successfully" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Expected 0 tenants, got $($config.Tenants.Count)" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Remove-MonitorTenant (by ID) failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 9: Configuration Persistence" -ForegroundColor Cyan
try {
    Add-MonitorTenant -TenantId "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" -Name "PersistTest" -DaysThreshold 45
    
    # Reload module
    Remove-Module SecretsExpirationMonitor -Force -ErrorAction SilentlyContinue
    Import-Module ./SecretsExpirationMonitor/SecretsExpirationMonitor.psd1 -Force
    
    $config = Get-MonitorConfig
    if ($config.Tenants.Count -eq 1 -and $config.Tenants[0].Name -eq "PersistTest") {
        Write-Host "✓ PASS: Configuration persisted correctly" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Configuration not persisted" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Configuration persistence test failed: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host "`nTest 10: Aliases" -ForegroundColor Cyan
try {
    $aliases = Get-Alias -Definition Invoke-SecretsMonitor -ErrorAction SilentlyContinue
    if ($aliases.Count -ge 2) {
        Write-Host "✓ PASS: Aliases configured correctly" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Expected at least 2 aliases, got $($aliases.Count)" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Alias test failed: $_" -ForegroundColor Red
    $testsFailed++
}

# Clean up
if (Test-Path $configDir) {
    Remove-Item $configDir -Recurse -Force
    Write-Host "`nCleaned up test configuration" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "Total:  $($testsPassed + $testsFailed)" -ForegroundColor White

if ($testsFailed -eq 0) {
    Write-Host "`nAll tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed! ✗" -ForegroundColor Red
    exit 1
}
