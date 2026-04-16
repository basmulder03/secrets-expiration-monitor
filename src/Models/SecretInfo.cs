namespace SecretsExpirationMonitor.Models;

public record SecretInfo(
    string AppName,
    string AppId,
    string SecretName,
    DateTimeOffset? ExpiryDate,
    int DaysRemaining,
    bool IsExpired
);
