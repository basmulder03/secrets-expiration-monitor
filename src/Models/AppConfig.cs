using System.Reflection;

namespace SecretsExpirationMonitor.Models;

public class TenantConfig
{
    public required string TenantId { get; set; }
    public required string Name { get; set; }
}

public class AppConfig
{
    public string Version { get; set; } = Assembly
        .GetExecutingAssembly()
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()
        ?.InformationalVersion ?? "unknown";

    public int DefaultDaysThreshold { get; set; } = 90;
    public List<TenantConfig> Tenants { get; set; } = [];
}
