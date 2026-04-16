using System.Text.Json;
using SecretsExpirationMonitor.Models;
using Spectre.Console;

namespace SecretsExpirationMonitor.Services;

public class ConfigService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly string _configPath;

    public ConfigService() : this(DefaultConfigDir()) { }

    protected ConfigService(string configDir)
    {
        Directory.CreateDirectory(configDir);
        _configPath = Path.Combine(configDir, "config.json");
    }

    private static string DefaultConfigDir() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SecretsExpirationMonitor");

    public AppConfig Load()
    {
        if (!File.Exists(_configPath))
            return new AppConfig();

        try
        {
            var json = File.ReadAllText(_configPath);
            return JsonSerializer.Deserialize<AppConfig>(json, JsonOptions) ?? new AppConfig();
        }
        catch (Exception ex)
        {
            AnsiConsole.MarkupLine(
                $"[yellow]Warning: Could not read config file ({Markup.Escape(ex.Message)}). " +
                $"Starting with defaults. Your existing config is at: {Markup.Escape(_configPath)}[/]");
            return new AppConfig();
        }
    }

    public void Save(AppConfig config)
    {
        var json = JsonSerializer.Serialize(config, JsonOptions);

        // Atomic write: write to a temp file then replace
        var tmp = _configPath + ".tmp";
        File.WriteAllText(tmp, json);
        File.Move(tmp, _configPath, overwrite: true);
    }

    public string ConfigPath => _configPath;
}
