using System.Net;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BookingApi.Api.Tests;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md (readiness).
public class ReadinessTests
{
    [Fact]
    public async Task ReadyWhenTheDatabaseCheckIsHealthy()
    {
        using var factory = new ReadinessFactory(HealthStatus.Healthy);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health/ready");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task NotReadyWhenTheDatabaseCheckIsUnhealthy()
    {
        using var factory = new ReadinessFactory(HealthStatus.Unhealthy);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.StartsWith("text/plain", response.Content.Headers.ContentType?.MediaType);
        var text = await response.Content.ReadAsStringAsync();
        Assert.Equal("Unhealthy", text);
        Assert.DoesNotContain(ReadinessFactory.StubDetail, text);
    }

    [Fact]
    public async Task AppStartsWithoutAConnectionStringAndReportsNotReady()
    {
        using var factory = new ReadinessFactory(stub: null);
        using var client = factory.CreateClient();

        var live = await client.GetAsync("/health");
        var ready = await client.GetAsync("/health/ready");

        Assert.Equal(HttpStatusCode.OK, live.StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, ready.StatusCode);
        var text = await ready.Content.ReadAsStringAsync();
        Assert.Equal("Unhealthy", text);
        Assert.DoesNotContain("ConnectionString", text, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Exception", text, StringComparison.OrdinalIgnoreCase);
    }
}
