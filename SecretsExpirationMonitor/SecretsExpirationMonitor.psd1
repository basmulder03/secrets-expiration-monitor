@{
    RootModule = 'SecretsExpirationMonitor.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'
    Author = 'basmulder03'
    CompanyName = 'Community'
    Copyright = '(c) 2026. All rights reserved.'
    Description = 'Monitor Azure AD App Registration secrets expiration across multiple tenants with auto-update support'
    PowerShellVersion = '5.1'
    
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Applications'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '1.0.0'}
    )
    
    FunctionsToExport = @(
        'Invoke-SecretsMonitor',
        'Add-MonitorTenant',
        'Remove-MonitorTenant',
        'Get-MonitorTenants',
        'Set-MonitorConfig',
        'Get-MonitorConfig',
        'Update-SecretsMonitor'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('Monitor-Secrets', 'Check-Secrets')
    
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'AzureAD', 'Secrets', 'Monitoring', 'Security', 'Compliance')
            LicenseUri = 'https://github.com/basmulder03/secrets-expiration-monitor/blob/main/LICENSE'
            ProjectUri = 'https://github.com/basmulder03/secrets-expiration-monitor'
            ReleaseNotes = 'Initial release with multi-tenant support and auto-update functionality'
        }
    }
}
