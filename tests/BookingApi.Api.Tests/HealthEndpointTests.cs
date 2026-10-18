namespace BookingApi.Api.Tests;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md (liveness).
public class HealthEndpointTests
{
    [Fact]
    public async Task LivenessReturnsHealthyAsPlainText()
    {
        using var factory = new ApiFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        Assert.StartsWith("text/plain", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task LivenessStaysHealthyWhileTheReadyCheckIsUnhealthy()
    {
        using var factory = new ReadinessFactory(Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Unhealthy);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }
}
