namespace BookingApi.Tests;

public class ScaffoldSmokeTests
{
    [Fact]
    public void ApiAssemblyLoads()
    {
        var assembly = typeof(Program).Assembly;

        Assert.Equal("BookingApi", assembly.GetName().Name);
    }
}
