using Spectre.Console;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Services;

namespace SecretsExpirationMonitor.Commands;

public class ConfigShowCommand : Command
{
    public override int Execute(CommandContext context)
    {
        var svc = new ConfigService();
        var config = svc.Load();

        var table = new Table()
            .Border(TableBorder.Rounded)
            .AddColumn("[bold]Setting[/]")
            .AddColumn("[bold]Value[/]");

        table.AddRow("Version", config.Version);
        table.AddRow("Days Threshold", config.DefaultDaysThreshold.ToString());
        table.AddRow("Tenants", config.Tenants.Count.ToString());
        table.AddRow("Config path", $"[grey]{svc.ConfigPath}[/]");

        AnsiConsole.Write(table);
        return 0;
    }
}
