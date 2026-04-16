using Spectre.Console;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Services;

namespace SecretsExpirationMonitor.Commands;

public class TenantAddCommand : Command<TenantAddCommand.Settings>
{
    public class Settings : CommandSettings
    {
        [CommandArgument(0, "<TENANT_ID>")]
        public required string TenantId { get; set; }

        [CommandArgument(1, "<NAME>")]
        public required string Name { get; set; }

        public override ValidationResult Validate()
        {
            if (!Guid.TryParse(TenantId, out _))
                return ValidationResult.Error($"'{TenantId}' is not a valid tenant GUID (expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).");
            if (string.IsNullOrWhiteSpace(Name))
                return ValidationResult.Error("Name cannot be empty.");
            return ValidationResult.Success();
        }
    }

    public override int Execute(CommandContext context, Settings settings)
    {
        var svc = new ConfigService();
        var config = svc.Load();

        if (config.Tenants.Any(t =>
            t.TenantId.Equals(settings.TenantId, StringComparison.OrdinalIgnoreCase)))
        {
            AnsiConsole.MarkupLine($"[yellow]Tenant with ID [bold]{Markup.Escape(settings.TenantId)}[/] already exists.[/]");
            return 1;
        }

        if (config.Tenants.Any(t =>
            t.Name.Equals(settings.Name, StringComparison.OrdinalIgnoreCase)))
        {
            AnsiConsole.MarkupLine($"[yellow]Tenant with name [bold]{Markup.Escape(settings.Name)}[/] already exists.[/]");
            return 1;
        }

        config.Tenants.Add(new Models.TenantConfig
        {
            TenantId = settings.TenantId,
            Name = settings.Name
        });
        svc.Save(config);

        AnsiConsole.MarkupLine($"[green]Added tenant [bold]{Markup.Escape(settings.Name)}[/] ({Markup.Escape(settings.TenantId)})[/]");
        return 0;
    }
}
