using Spectre.Console;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Services;

namespace SecretsExpirationMonitor.Commands;

public class TenantListCommand : Command
{
    protected override int Execute(CommandContext context, CancellationToken cancellationToken)
    {
        var svc = new ConfigService();
        var config = svc.Load();

        if (config.Tenants.Count == 0)
        {
            AnsiConsole.MarkupLine("[grey]No tenants configured. Use [bold]sem tenant add <id> <name>[/] to add one.[/]");
            return 0;
        }

        var table = new Table()
            .Border(TableBorder.Rounded)
            .AddColumn("[bold]Name[/]")
            .AddColumn("[bold]Tenant ID[/]");

        foreach (var t in config.Tenants)
            table.AddRow(Markup.Escape(t.Name), $"[grey]{t.TenantId}[/]");

        AnsiConsole.Write(table);
        return 0;
    }
}
