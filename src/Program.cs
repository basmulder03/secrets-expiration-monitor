using System.Reflection;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Commands;

var version = Assembly.GetExecutingAssembly()
    .GetCustomAttribute<AssemblyInformationalVersionAttribute>()
    ?.InformationalVersion ?? "unknown";

var app = new CommandApp();

app.Configure(config =>
{
    config.SetApplicationName("sem");
    config.SetApplicationVersion(version);

    config.AddCommand<MonitorCommand>("monitor")
        .WithDescription("Check expiring secrets across configured tenants.")
        .WithExample("monitor")
        .WithExample("monitor", "--tenant", "contoso", "--detailed");

    config.AddBranch("tenant", tenant =>
    {
        tenant.SetDescription("Manage monitored tenants.");
        tenant.AddCommand<TenantAddCommand>("add")
            .WithDescription("Add a tenant to monitor.")
            .WithExample("tenant", "add", "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "Contoso");
        tenant.AddCommand<TenantRemoveCommand>("remove")
            .WithDescription("Remove a tenant by name or ID.")
            .WithExample("tenant", "remove", "Contoso");
        tenant.AddCommand<TenantListCommand>("list")
            .WithDescription("List all configured tenants.");
    });

    config.AddBranch("config", cfg =>
    {
        cfg.SetDescription("View or update tool configuration.");
        cfg.AddCommand<ConfigShowCommand>("show")
            .WithDescription("Show current configuration.");
        cfg.AddCommand<ConfigSetCommand>("set")
            .WithDescription("Update configuration values.")
            .WithExample("config", "set", "--threshold", "60");
    });
});

return app.Run(args);
