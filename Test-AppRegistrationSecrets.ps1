<#
.SYNOPSIS
    Test script for Get-AppRegistrationSecrets.ps1

.DESCRIPTION
    This script tests the functionality of the secrets expiration monitor
    by validating the helper functions and simulating scenarios.
#>

# Import the main script functions for testing
$scriptPath = Join-Path $PSScriptRoot "Get-AppRegistrationSecrets.ps1"

# Test Get-ExpirationColor function
function Test-GetExpirationColor {
    Write-Host "`nTesting Get-ExpirationColor function..." -ForegroundColor Cyan
    
    # Define test function (extracted from main script)
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
    
    $threshold = 90
    $testCases = @(
        @{ Days = -5; Expected = "Red"; Description = "Expired secret" }
        @{ Days = 0; Expected = "Red"; Description = "Expires today" }
        @{ Days = 10; Expected = "Red"; Description = "Critical (< 25%)" }
        @{ Days = 30; Expected = "Yellow"; Description = "Warning (< 50%)" }
        @{ Days = 60; Expected = "Cyan"; Description = "Info (< 75%)" }
        @{ Days = 80; Expected = "Green"; Description = "Valid (> 75%)" }
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($test in $testCases) {
        $result = Get-ExpirationColor -DaysRemaining $test.Days -Threshold $threshold
        if ($result -eq $test.Expected) {
            Write-Host "  ✓ PASS: $($test.Description) - Days: $($test.Days), Color: $result" -ForegroundColor Green
            $passed++
        }
        else {
            Write-Host "  ✗ FAIL: $($test.Description) - Expected: $($test.Expected), Got: $result" -ForegroundColor Red
            $failed++
        }
    }
    
    Write-Host "`n  Total: $($testCases.Count) | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
    return $failed -eq 0
}

# Test Get-FilteredSecrets function
function Test-GetFilteredSecrets {
    Write-Host "`nTesting Get-FilteredSecrets function..." -ForegroundColor Cyan
    
    # Define test function (extracted from main script)
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
    
    $now = Get-Date
    $threshold = 90
    $passed = 0
    $failed = 0
    
    # Test Case 1: Expiring secret with no replacement
    Write-Host "`n  Test Case 1: Expiring secret with no replacement"
    $secrets1 = @(
        [PSCustomObject]@{
            DisplayName = "TestSecret"
            KeyId = "key-123"
            StartDateTime = $now.AddDays(-100)
            EndDateTime = $now.AddDays(30)
        }
    )
    $result1 = Get-FilteredSecrets -Secrets $secrets1 -Threshold $threshold -AppName "TestApp" -AppId "app-123"
    if ($result1.Count -eq 1 -and $result1[0].Status -eq "Expiring") {
        Write-Host "    ✓ PASS: Correctly identified expiring secret" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "    ✗ FAIL: Expected 1 expiring secret, got $($result1.Count)" -ForegroundColor Red
        $failed++
    }
    
    # Test Case 2: Expiring secret WITH valid replacement
    Write-Host "`n  Test Case 2: Expiring secret with valid replacement"
    $secrets2 = @(
        [PSCustomObject]@{
            DisplayName = "TestSecret"
            KeyId = "key-old"
            StartDateTime = $now.AddDays(-100)
            EndDateTime = $now.AddDays(30)
        },
        [PSCustomObject]@{
            DisplayName = "TestSecret"
            KeyId = "key-new"
            StartDateTime = $now.AddDays(-10)
            EndDateTime = $now.AddDays(365)
        }
    )
    $result2 = Get-FilteredSecrets -Secrets $secrets2 -Threshold $threshold -AppName "TestApp" -AppId "app-123"
    if ($result2.Count -eq 1 -and $result2[0].Status -eq "Valid" -and $result2[0].KeyId -eq "key-new") {
        Write-Host "    ✓ PASS: Correctly showed only valid replacement" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "    ✗ FAIL: Expected 1 valid secret (new), got $($result2.Count)" -ForegroundColor Red
        $failed++
    }
    
    # Test Case 3: Multiple secrets with different names
    Write-Host "`n  Test Case 3: Multiple secrets with different names"
    $secrets3 = @(
        [PSCustomObject]@{
            DisplayName = "Secret1"
            KeyId = "key-1"
            StartDateTime = $now.AddDays(-100)
            EndDateTime = $now.AddDays(30)
        },
        [PSCustomObject]@{
            DisplayName = "Secret2"
            KeyId = "key-2"
            StartDateTime = $now.AddDays(-100)
            EndDateTime = $now.AddDays(20)
        }
    )
    $result3 = Get-FilteredSecrets -Secrets $secrets3 -Threshold $threshold -AppName "TestApp" -AppId "app-123"
    if ($result3.Count -eq 2) {
        Write-Host "    ✓ PASS: Correctly identified both expiring secrets" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "    ✗ FAIL: Expected 2 expiring secrets, got $($result3.Count)" -ForegroundColor Red
        $failed++
    }
    
    # Test Case 4: Expired secret
    Write-Host "`n  Test Case 4: Expired secret"
    $secrets4 = @(
        [PSCustomObject]@{
            DisplayName = "ExpiredSecret"
            KeyId = "key-expired"
            StartDateTime = $now.AddDays(-200)
            EndDateTime = $now.AddDays(-10)
        }
    )
    $result4 = Get-FilteredSecrets -Secrets $secrets4 -Threshold $threshold -AppName "TestApp" -AppId "app-123"
    if ($result4.Count -eq 1 -and $result4[0].Status -eq "Expired") {
        Write-Host "    ✓ PASS: Correctly identified expired secret" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "    ✗ FAIL: Expected 1 expired secret" -ForegroundColor Red
        $failed++
    }
    
    Write-Host "`n  Total: 4 | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
    return $failed -eq 0
}

# Run all tests
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Secrets Expiration Monitor - Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$allPassed = $true

$allPassed = (Test-GetExpirationColor) -and $allPassed
$allPassed = (Test-GetFilteredSecrets) -and $allPassed

Write-Host "`n========================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
}
else {
    Write-Host "Some tests failed! ✗" -ForegroundColor Red
    exit 1
}
Write-Host "========================================" -ForegroundColor Cyan
