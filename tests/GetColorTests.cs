using SecretsExpirationMonitor.Commands;

namespace SecretsExpirationMonitor.Tests;

[TestClass]
public class GetColorTests
{
    private const int Threshold = 90;

    [TestMethod]
    public void Expired_ReturnsRed()
        => MonitorCommand.GetColor(-1, Threshold).ShouldBe("red");

    [TestMethod]
    public void ZeroDays_ReturnsRed()
        => MonitorCommand.GetColor(0, Threshold).ShouldBe("red");

    [TestMethod]
    [DataRow(1)]
    [DataRow(9)] // 9/90 = 10% — boundary is ≤ 10%
    public void NinePercent_ReturnsRed(int days)
        => MonitorCommand.GetColor(days, Threshold).ShouldBe("red");

    [TestMethod]
    public void TenPercent_ReturnsRed()
        => MonitorCommand.GetColor(9, Threshold).ShouldBe("red"); // 9/90 = 10%

    [TestMethod]
    public void JustAboveTenPercent_ReturnsDarkOrange()
        => MonitorCommand.GetColor(10, Threshold).ShouldBe("darkorange"); // 10/90 ≈ 11.1%

    [TestMethod]
    [DataRow(10)]
    [DataRow(22)]
    public void TenToTwentyFivePercent_ReturnsDarkOrange(int days)
        => MonitorCommand.GetColor(days, Threshold).ShouldBe("darkorange");

    [TestMethod]
    [DataRow(23)] // 23/90 ≈ 25.6%
    [DataRow(44)]
    public void TwentyFiveToFiftyPercent_ReturnsYellow(int days)
        => MonitorCommand.GetColor(days, Threshold).ShouldBe("yellow");

    [TestMethod]
    [DataRow(46)] // 46/90 ≈ 51.1%
    [DataRow(90)]
    [DataRow(200)]
    public void AboveFiftyPercent_ReturnsCyan(int days)
        => MonitorCommand.GetColor(days, Threshold).ShouldBe("cyan");

    [TestMethod]
    public void NoExpiry_ReturnsGrey()
        => MonitorCommand.GetColor(int.MaxValue, Threshold).ShouldBe("grey");
}
