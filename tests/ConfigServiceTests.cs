using System.Text.Json;
using SecretsExpirationMonitor.Models;
using SecretsExpirationMonitor.Services;

namespace SecretsExpirationMonitor.Tests;

[TestClass]
public class ConfigServiceTests
{
    private string _tempDir = null!;
    private TestableConfigService _svc = null!;

    [TestInitialize]
    public void Init()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(_tempDir);
        _svc = new TestableConfigService(_tempDir);
    }

    [TestCleanup]
    public void Cleanup()
        => Directory.Delete(_tempDir, recursive: true);

    [TestMethod]
    public void Load_WhenNoFile_ReturnsDefaults()
    {
        var config = _svc.Load();
        config.DefaultDaysThreshold.ShouldBe(90);
        config.Tenants.ShouldBeEmpty();
    }

    [TestMethod]
    public void SaveAndLoad_RoundTrips()
    {
        var config = new AppConfig
        {
            DefaultDaysThreshold = 60,
            Tenants = [new TenantConfig { TenantId = "aaaabbbb-0000-0000-0000-000000000001", Name = "Contoso" }]
        };

        _svc.Save(config);
        var loaded = _svc.Load();

        loaded.DefaultDaysThreshold.ShouldBe(60);
        loaded.Tenants.ShouldHaveSingleItem();
        loaded.Tenants[0].TenantId.ShouldBe("aaaabbbb-0000-0000-0000-000000000001");
        loaded.Tenants[0].Name.ShouldBe("Contoso");
    }

    [TestMethod]
    public void Save_IsAtomic_NoTempFileLeft()
    {
        _svc.Save(new AppConfig());

        var files = Directory.GetFiles(_tempDir);
        files.ShouldHaveSingleItem();
        Path.GetFileName(files[0]).ShouldBe("config.json");
    }

    [TestMethod]
    public void Load_CorruptJson_ReturnsDefaults_NoThrow()
    {
        File.WriteAllText(Path.Combine(_tempDir, "config.json"), "{ not valid json !!!");
        var config = _svc.Load();
        config.DefaultDaysThreshold.ShouldBe(90);
        config.Tenants.ShouldBeEmpty();
    }

    [TestMethod]
    public void Load_EmptyFile_ReturnsDefaults_NoThrow()
    {
        File.WriteAllText(Path.Combine(_tempDir, "config.json"), "");
        var config = _svc.Load();
        config.ShouldNotBeNull();
    }

    [TestMethod]
    public void MultipleSaves_EachOverwritesPrevious()
    {
        _svc.Save(new AppConfig { DefaultDaysThreshold = 30 });
        _svc.Save(new AppConfig { DefaultDaysThreshold = 45 });

        _svc.Load().DefaultDaysThreshold.ShouldBe(45);
    }

    [TestMethod]
    public void Save_MultipleTenants_AllPersisted()
    {
        var config = new AppConfig
        {
            Tenants =
            [
                new TenantConfig { TenantId = "aaaabbbb-0000-0000-0000-000000000001", Name = "Alpha" },
                new TenantConfig { TenantId = "aaaabbbb-0000-0000-0000-000000000002", Name = "Beta" },
            ]
        };

        _svc.Save(config);
        var loaded = _svc.Load();

        loaded.Tenants.Count.ShouldBe(2);
        loaded.Tenants.Select(t => t.Name).ShouldBe(["Alpha", "Beta"]);
    }

    /// <summary>Subclass that writes to a temp dir instead of %APPDATA%.</summary>
    private sealed class TestableConfigService(string dir) : ConfigService(dir);
}
