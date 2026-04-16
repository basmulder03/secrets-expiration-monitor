using Spectre.Console;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Services;

namespace SecretsExpirationMonitor.Commands;

public class TenantRemoveCommand : Command<TenantRemoveCommand.Settings>
{
    public class Settings : CommandSettings
    {
        [CommandArgument(0, "<NAME_OR_ID>")]
        public required string NameOrId { get; set; }
    }

    public override int Execute(CommandContext context, Settings settings)
    {
        var svc = new ConfigService();
        var config = svc.Load();

        var tenant = config.Tenants.FirstOrDefault(t =>
            t.TenantId.Equals(settings.NameOrId, StringComparison.OrdinalIgnoreCase) ||
            t.Name.Equals(settings.NameOrId, StringComparison.OrdinalIgnoreCase));

        if (tenant == null)
        {
            AnsiConsole.MarkupLine($"[red]No tenant found matching [bold]{Markup.Escape(settings.NameOrId)}[/].[/]");
            return 1;
        }

        config.Tenants.Remove(tenant);
        svc.Save(config);

        AnsiConsole.MarkupLine($"[green]Removed tenant [bold]{Markup.Escape(tenant.Name)}[/] ({Markup.Escape(tenant.TenantId)})[/]");
        return 0;
    }
}
