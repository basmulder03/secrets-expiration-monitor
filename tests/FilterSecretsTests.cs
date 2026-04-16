using Microsoft.Graph.Models;
using SecretsExpirationMonitor.Services;

namespace SecretsExpirationMonitor.Tests;

[TestClass]
public class FilterSecretsTests
{
    private static readonly DateTimeOffset Now = new(2026, 4, 16, 0, 0, 0, TimeSpan.Zero);
    private const int Threshold = 90;

    private static PasswordCredential Cred(string name, int daysFromNow) => new()
    {
        DisplayName = name,
        EndDateTime = Now.AddDays(daysFromNow)
    };

    private static PasswordCredential CredNoExpiry(string name) => new()
    {
        DisplayName = name,
        EndDateTime = null
    };

    private static List<PasswordCredential> Filter(IEnumerable<PasswordCredential> creds)
        => GraphService.FilterSecrets(creds, Now, Threshold).ToList();

    // ── Single secret ────────────────────────────────────────────────────────

    [TestMethod]
    public void SingleSecret_Expiring_IsReturned()
    {
        var result = Filter([Cred("key", 30)]);
        result.ShouldHaveSingleItem();
        result[0].DisplayName.ShouldBe("key");
    }

    [TestMethod]
    public void SingleSecret_Expired_IsReturned()
    {
        var result = Filter([Cred("key", -5)]);
        result.ShouldHaveSingleItem();
    }

    [TestMethod]
    public void SingleSecret_ValidBeyondThreshold_IsNotReturned()
    {
        var result = Filter([Cred("key", 120)]);
        result.ShouldBeEmpty();
    }

    [TestMethod]
    public void SingleSecret_NoExpiry_IsNotReturned()
    {
        var result = Filter([CredNoExpiry("key")]);
        result.ShouldBeEmpty();
    }

    // ── Multiple secrets same name ───────────────────────────────────────────

    [TestMethod]
    public void TwoSecrets_SameName_OneValid_ExpiringIsSuppressed()
    {
        // rotation in progress: old secret expiring soon, new one valid
        var result = Filter([Cred("key", 10), Cred("key", 120)]);
        result.ShouldBeEmpty();
    }

    [TestMethod]
    public void TwoSecrets_SameName_BothExpiring_BothReturned()
    {
        var result = Filter([Cred("key", 10), Cred("key", 50)]);
        result.Count.ShouldBe(2);
    }

    [TestMethod]
    public void TwoSecrets_SameName_OneExpired_OneExpiring_NoValidReplacement_BothReturned()
    {
        var result = Filter([Cred("key", -3), Cred("key", 45)]);
        result.Count.ShouldBe(2);
    }

    [TestMethod]
    public void TwoSecrets_SameName_OneNoExpiry_ExpiringIsSuppressed()
    {
        // secret with no expiry date counts as permanently valid
        var result = Filter([Cred("key", 10), CredNoExpiry("key")]);
        result.ShouldBeEmpty();
    }

    // ── Different names are independent ─────────────────────────────────────

    [TestMethod]
    public void DifferentNames_EachEvaluatedIndependently()
    {
        var creds = new[]
        {
            Cred("alpha", 30),   // expiring — should appear
            Cred("beta",  10),   // expiring — should appear
            Cred("beta",  120),  // valid replacement for beta — beta suppressed
            Cred("gamma", 200),  // valid — should not appear
        };

        var result = Filter(creds);
        result.Count.ShouldBe(1);
        result[0].DisplayName.ShouldBe("alpha");
    }

    // ── Case-insensitive grouping ────────────────────────────────────────────

    [TestMethod]
    public void SecretNames_GroupedCaseInsensitively()
    {
        // "Key" and "key" should be treated as the same name
        var result = Filter([Cred("Key", 10), Cred("key", 120)]);
        result.ShouldBeEmpty();
    }

    // ── Threshold boundary ───────────────────────────────────────────────────

    [TestMethod]
    public void SecretExpiringExactlyAtThreshold_IsReturned()
    {
        var result = Filter([Cred("key", Threshold)]);
        result.ShouldHaveSingleItem();
    }

    [TestMethod]
    public void SecretExpiringOneDayBeyondThreshold_IsNotReturned()
    {
        var result = Filter([Cred("key", Threshold + 1)]);
        result.ShouldBeEmpty();
    }
}
