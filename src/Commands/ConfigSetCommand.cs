using Spectre.Console;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Services;
using System.ComponentModel;

namespace SecretsExpirationMonitor.Commands;

public class ConfigSetCommand : Command<ConfigSetCommand.Settings>
{
    public class Settings : CommandSettings
    {
        [CommandOption("--threshold <DAYS>")]
        [Description("Number of days before expiry to start alerting")]
        public int? Threshold { get; set; }

        public override ValidationResult Validate()
        {
            if (Threshold.HasValue && Threshold.Value <= 0)
                return ValidationResult.Error("--threshold must be a positive number of days.");
            return ValidationResult.Success();
        }
    }

    public override int Execute(CommandContext context, Settings settings)
    {
        if (settings.Threshold == null)
        {
            AnsiConsole.MarkupLine("[yellow]Nothing to set. Use [bold]--threshold <days>[/].[/]");
            return 1;
        }

        var svc = new ConfigService();
        var config = svc.Load();

        config.DefaultDaysThreshold = settings.Threshold.Value;
        svc.Save(config);

        AnsiConsole.MarkupLine($"[green]Threshold set to [bold]{settings.Threshold.Value}[/] days.[/]");
        return 0;
    }
}
