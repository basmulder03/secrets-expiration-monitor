using Microsoft.Graph;
using Microsoft.Identity.Client;
using Microsoft.Identity.Client.Extensions.Msal;
using Microsoft.Kiota.Authentication.Azure;
using Microsoft.Kiota.Abstractions.Authentication;
using SecretsExpirationMonitor.Models;
using Spectre.Console;

namespace SecretsExpirationMonitor.Services;

public class GraphService
{
    // Well-known Azure CLI client ID — allows device code flow without app registration
    private const string ClientId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46";
    private static readonly string[] Scopes = ["https://graph.microsoft.com/Application.Read.All"];

    private readonly IPublicClientApplication _msalApp;
    private GraphServiceClient? _cachedClient;

    private GraphService(IPublicClientApplication msalApp)
    {
        _msalApp = msalApp;
    }

    /// <summary>
    /// Factory method — use instead of constructor to allow async cache registration.
    /// </summary>
    public static async Task<GraphService> CreateAsync(string tenantId)
    {
        var msalApp = PublicClientApplicationBuilder
            .Create(ClientId)
            .WithAuthority(AzureCloudInstance.AzurePublic, tenantId)
            .WithDefaultRedirectUri()
            .Build();

        await RegisterTokenCacheAsync(msalApp.UserTokenCache);
        return new GraphService(msalApp);
    }

    private static async Task RegisterTokenCacheAsync(ITokenCache cache)
    {
        var cacheDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "SecretsExpirationMonitor", "msal_cache");
        Directory.CreateDirectory(cacheDir);

        var storage = new StorageCreationPropertiesBuilder("msal_token_cache.bin", cacheDir)
            .Build();
        var cacheHelper = await MsalCacheHelper.CreateAsync(storage);
        cacheHelper.RegisterCache(cache);
    }

    public async Task<GraphServiceClient> GetClientAsync(CancellationToken ct = default)
    {
        if (_cachedClient != null)
            return _cachedClient;

        var accounts = await _msalApp.GetAccountsAsync();
        var account = accounts.FirstOrDefault();

        AuthenticationResult? result = null;
        if (account != null)
        {
            try
            {
                result = await _msalApp.AcquireTokenSilent(Scopes, account)
                    .ExecuteAsync(ct);
            }
            catch (MsalUiRequiredException) { }
        }

        if (result == null)
        {
            // Stop any active Spectre live display before printing the device code message
            result = await _msalApp
                .AcquireTokenWithDeviceCode(Scopes, deviceCode =>
                {
                    AnsiConsole.WriteLine();
                    AnsiConsole.WriteLine(deviceCode.Message);
                    AnsiConsole.WriteLine();
                    return Task.CompletedTask;
                })
                .ExecuteAsync(ct);
        }

        var tokenProvider = new BaseBearerTokenAuthenticationProvider(
            new StaticTokenProvider(result.AccessToken));
        _cachedClient = new GraphServiceClient(tokenProvider);
        return _cachedClient;
    }

    public async Task<List<SecretInfo>> GetExpiringSecretsAsync(
        int daysThreshold,
        CancellationToken ct = default)
    {
        var client = await GetClientAsync(ct);
        var secrets = new List<SecretInfo>();
        var now = DateTimeOffset.UtcNow;

        var apps = await client.Applications
            .GetAsync(req =>
            {
                req.QueryParameters.Select = ["id", "appId", "displayName", "passwordCredentials"];
                req.QueryParameters.Top = 999;
            }, ct);

        if (apps == null)
            return secrets;

        var allApps = new List<Microsoft.Graph.Models.Application>();
        var pageIterator = Microsoft.Graph.PageIterator<
            Microsoft.Graph.Models.Application,
            Microsoft.Graph.Models.ApplicationCollectionResponse>
            .CreatePageIterator(client, apps, app =>
            {
                allApps.Add(app);
                return true;
            });
        await pageIterator.IterateAsync(ct);

        foreach (var app in allApps)
        {
            if (app.PasswordCredentials == null || app.PasswordCredentials.Count == 0)
                continue;

            var filtered = FilterSecrets(app.PasswordCredentials, now, daysThreshold);
            foreach (var cred in filtered)
            {
                var expiry = cred.EndDateTime;
                int days = expiry.HasValue
                    ? (int)Math.Floor((expiry.Value - now).TotalDays)
                    : int.MaxValue;
                bool expired = days < 0;

                secrets.Add(new SecretInfo(
                    AppName: app.DisplayName ?? "(no name)",
                    AppId: app.AppId ?? "(no id)",
                    SecretName: cred.DisplayName ?? "(unnamed)",
                    ExpiryDate: expiry,
                    DaysRemaining: days,
                    IsExpired: expired
                ));
            }
        }

        return secrets.OrderBy(s => s.DaysRemaining).ToList();
    }

    /// <summary>
    /// Filters secrets: if a secret name has a valid (non-expiring within threshold) counterpart,
    /// only show the expiring one if there is no valid replacement.
    /// Secrets with no expiry date are treated as always valid and never surfaced.
    /// </summary>
    internal static IEnumerable<Microsoft.Graph.Models.PasswordCredential> FilterSecrets(
        IEnumerable<Microsoft.Graph.Models.PasswordCredential> credentials,
        DateTimeOffset now,
        int daysThreshold)
    {
        var creds = credentials.ToList();

        // Group by display name (case-insensitive)
        var groups = creds
            .GroupBy(c => (c.DisplayName ?? string.Empty).ToLowerInvariant())
            .ToList();

        var result = new List<Microsoft.Graph.Models.PasswordCredential>();

        foreach (var group in groups)
        {
            var items = group.ToList();

            // A credential is "valid" if it has no expiry or expires beyond the threshold
            bool hasValidItem = items.Any(c =>
            {
                if (!c.EndDateTime.HasValue) return true; // no expiry = permanently valid
                int d = (int)Math.Floor((c.EndDateTime.Value - now).TotalDays);
                return d > daysThreshold;
            });

            if (hasValidItem)
                continue; // At least one valid secret with this name — suppress expiring ones

            // No valid secret for this name — surface all that are expiring or expired
            foreach (var c in items)
            {
                if (!c.EndDateTime.HasValue) continue; // no expiry, skip
                int d = (int)Math.Floor((c.EndDateTime.Value - now).TotalDays);
                if (d <= daysThreshold)
                    result.Add(c);
            }
        }

        return result;
    }

    private sealed class StaticTokenProvider(string token) : IAccessTokenProvider
    {
        public Task<string> GetAuthorizationTokenAsync(
            Uri uri,
            Dictionary<string, object>? additionalAuthenticationContext = null,
            CancellationToken cancellationToken = default)
            => Task.FromResult(token);

        public AllowedHostsValidator AllowedHostsValidator { get; } = new();
    }
}
