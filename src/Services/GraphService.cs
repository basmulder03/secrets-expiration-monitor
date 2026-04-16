using Azure.Identity;
using Microsoft.Graph;
using SecretsExpirationMonitor.Models;

namespace SecretsExpirationMonitor.Services;

public class GraphService
{
    private static readonly string[] Scopes = ["https://graph.microsoft.com/.default"];

    private readonly GraphServiceClient _client;

    private GraphService(string tenantId)
    {
        // AzureCliCredential delegates to the active `az login` session — no app
        // registration required. Falls back with a clear error if not signed in.
        var credential = new AzureCliCredential(new AzureCliCredentialOptions
        {
            TenantId = tenantId
        });

        _client = new GraphServiceClient(credential, Scopes);
    }

    public static GraphService Create(string tenantId) => new(tenantId);

    public async Task<List<SecretInfo>> GetExpiringSecretsAsync(
        int daysThreshold,
        CancellationToken ct = default)
    {
        var secrets = new List<SecretInfo>();
        var now = DateTimeOffset.UtcNow;

        var apps = await _client.Applications
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
            .CreatePageIterator(_client, apps, app =>
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

                secrets.Add(new SecretInfo(
                    AppName: app.DisplayName ?? "(no name)",
                    AppId: app.AppId ?? "(no id)",
                    SecretName: cred.DisplayName ?? "(unnamed)",
                    ExpiryDate: expiry,
                    DaysRemaining: days,
                    IsExpired: days < 0
                ));
            }
        }

        return secrets.OrderBy(s => s.DaysRemaining).ToList();
    }

    /// <summary>
    /// Filters secrets: if a secret name has a valid (non-expiring within threshold) counterpart,
    /// suppress the expiring ones — rotation is already in progress.
    /// Secrets with no expiry date are treated as permanently valid.
    /// </summary>
    internal static IEnumerable<Microsoft.Graph.Models.PasswordCredential> FilterSecrets(
        IEnumerable<Microsoft.Graph.Models.PasswordCredential> credentials,
        DateTimeOffset now,
        int daysThreshold)
    {
        var groups = credentials
            .GroupBy(c => (c.DisplayName ?? string.Empty).ToLowerInvariant());

        var result = new List<Microsoft.Graph.Models.PasswordCredential>();

        foreach (var group in groups)
        {
            var items = group.ToList();

            bool hasValidItem = items.Any(c =>
            {
                if (!c.EndDateTime.HasValue) return true; // no expiry = permanently valid
                int d = (int)Math.Floor((c.EndDateTime.Value - now).TotalDays);
                return d > daysThreshold;
            });

            if (hasValidItem) continue;

            foreach (var c in items)
            {
                if (!c.EndDateTime.HasValue) continue;
                int d = (int)Math.Floor((c.EndDateTime.Value - now).TotalDays);
                if (d <= daysThreshold)
                    result.Add(c);
            }
        }

        return result;
    }
}
