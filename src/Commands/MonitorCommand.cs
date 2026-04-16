using Spectre.Console;
using Spectre.Console.Cli;
using SecretsExpirationMonitor.Models;
using SecretsExpirationMonitor.Services;
using System.ComponentModel;

namespace SecretsExpirationMonitor.Commands;

public class MonitorCommand : AsyncCommand<MonitorCommand.Settings>
{
    public class Settings : CommandSettings
    {
        [CommandOption("-t|--tenant <NAME_OR_ID>")]
        [Description("Only monitor this tenant (name or ID). Defaults to all configured tenants.")]
        public string? Tenant { get; set; }

        [CommandOption("--threshold <DAYS>")]
        [Description("Override the configured days threshold for this run.")]
        public int? Threshold { get; set; }

        [CommandOption("-d|--detailed")]
        [Description("Show a summary breakdown after the table.")]
        public bool Detailed { get; set; }

        public override ValidationResult Validate()
        {
            if (Threshold.HasValue && Threshold.Value <= 0)
                return ValidationResult.Error("--threshold must be a positive number of days.");
            return ValidationResult.Success();
        }
    }

    public override async Task<int> ExecuteAsync(CommandContext context, Settings settings)
    {
        var svc = new ConfigService();
        var config = svc.Load();

        var tenants = config.Tenants;
        if (settings.Tenant != null)
        {
            tenants = tenants
                .Where(t =>
                    t.TenantId.Equals(settings.Tenant, StringComparison.OrdinalIgnoreCase) ||
                    t.Name.Equals(settings.Tenant, StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (tenants.Count == 0)
            {
                AnsiConsole.MarkupLine($"[red]No tenant found matching [bold]{Markup.Escape(settings.Tenant)}[/].[/]");
                return 1;
            }
        }

        if (tenants.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]No tenants configured. Use [bold]sem tenant add <id> <name>[/] first.[/]");
            return 1;
        }

        int threshold = settings.Threshold ?? config.DefaultDaysThreshold;
        var allSecrets = new List<(string TenantName, SecretInfo Secret)>();
        using var cts = new CancellationTokenSource();

        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            cts.Cancel();
        };

        foreach (var tenant in tenants)
        {
            if (cts.Token.IsCancellationRequested) break;

            AnsiConsole.MarkupLine($"\n[bold]Connecting to [cyan]{Markup.Escape(tenant.Name)}[/]...[/]");

            List<SecretInfo> secrets = [];
            try
            {
                await AnsiConsole.Status()
                    .StartAsync($"Fetching secrets for {tenant.Name}...", async ctx =>
                    {
                        var graphSvc = await GraphService.CreateAsync(tenant.TenantId);
                        secrets = await graphSvc.GetExpiringSecretsAsync(threshold, cts.Token);
                    });
            }
            catch (OperationCanceledException)
            {
                AnsiConsole.MarkupLine("[grey]Cancelled.[/]");
                break;
            }
            catch (Exception ex)
            {
                AnsiConsole.MarkupLine($"[red]Error fetching secrets for {Markup.Escape(tenant.Name)}: {Markup.Escape(ex.Message)}[/]");
                continue;
            }

            if (secrets.Count == 0)
            {
                AnsiConsole.MarkupLine($"[green]No expiring secrets found for [bold]{Markup.Escape(tenant.Name)}[/].[/]");
                continue;
            }

            RenderTable(tenant.Name, secrets, threshold);
            allSecrets.AddRange(secrets.Select(s => (tenant.Name, s)));
        }

        if (settings.Detailed && allSecrets.Count > 0)
            RenderSummary(allSecrets);

        return 0;
    }

    private static void RenderTable(string tenantName, List<SecretInfo> secrets, int threshold)
    {
        var table = new Table()
            .Border(TableBorder.Rounded)
            .Title($"[bold cyan]{Markup.Escape(tenantName)}[/] — expiring within [bold]{threshold}[/] days")
            .AddColumn("[bold]App Name[/]")
            .AddColumn("[bold]App ID[/]")
            .AddColumn("[bold]Secret Name[/]")
            .AddColumn("[bold]Expires[/]")
            .AddColumn("[bold]Days Left[/]");

        foreach (var s in secrets)
        {
            var color = GetColor(s.DaysRemaining, threshold);

            string daysText;
            if (s.IsExpired)
                daysText = $"[{color}]EXPIRED ({Math.Abs(s.DaysRemaining)}d ago)[/{color}]";
            else if (s.DaysRemaining == int.MaxValue)
                daysText = "[grey]no expiry[/]";
            else
                daysText = $"[{color}]{s.DaysRemaining}[/{color}]";

            var expiryText = s.ExpiryDate.HasValue
                ? $"[{color}]{s.ExpiryDate.Value:yyyy-MM-dd}[/{color}]"
                : "[grey]no expiry[/]";

            table.AddRow(
                Markup.Escape(s.AppName),
                $"[grey]{Markup.Escape(s.AppId)}[/]",
                Markup.Escape(s.SecretName),
                expiryText,
                daysText);
        }

        AnsiConsole.Write(table);
    }

    private static void RenderSummary(List<(string TenantName, SecretInfo Secret)> all)
    {
        AnsiConsole.WriteLine();
        var rule = new Rule("[bold]Summary[/]") { Justification = Justify.Left };
        AnsiConsole.Write(rule);

        var byTenant = all.GroupBy(x => x.TenantName);
        foreach (var group in byTenant)
        {
            var secrets = group.Select(x => x.Secret).ToList();
            int expired  = secrets.Count(s => s.IsExpired);
            int critical = secrets.Count(s => !s.IsExpired && s.DaysRemaining != int.MaxValue && s.DaysRemaining <= 14);
            int warning  = secrets.Count(s => !s.IsExpired && s.DaysRemaining != int.MaxValue && s.DaysRemaining > 14 && s.DaysRemaining <= 30);
            int info     = secrets.Count(s => !s.IsExpired && s.DaysRemaining != int.MaxValue && s.DaysRemaining > 30);

            AnsiConsole.MarkupLine(
                $"  [bold]{Markup.Escape(group.Key)}[/]: " +
                $"[red]{expired} expired[/]  " +
                $"[darkorange]{critical} critical (≤14d)[/]  " +
                $"[yellow]{warning} warning (≤30d)[/]  " +
                $"[cyan]{info} info[/]");
        }
    }

    internal static string GetColor(int daysRemaining, int threshold)
    {
        if (daysRemaining < 0) return "red";
        if (daysRemaining == int.MaxValue) return "grey";
        double ratio = (double)daysRemaining / threshold;
        return ratio switch
        {
            <= 0.10 => "red",
            <= 0.25 => "darkorange",
            <= 0.50 => "yellow",
            _ => "cyan"
        };
    }
}
