namespace BookingApi.Api.Tests;

public class ScaffoldSmokeTests
{
    [Fact]
    public void ApiAssemblyLoads()
    {
        var assembly = typeof(Program).Assembly;

        Assert.Equal("BookingApi.Api", assembly.GetName().Name);
    }
}
