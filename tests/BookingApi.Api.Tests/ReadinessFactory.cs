using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BookingApi.Api.Tests;

// Isolates the readiness tests from any real database: the connection string is forced empty
// (so a developer's user secrets never reach the gate), and the `ready` check can be replaced
// by a stub that reports a chosen status. A null stub keeps the application's real check.
internal sealed class ReadinessFactory(HealthStatus? stub) : WebApplicationFactory<Program>
{
    public const string StubDetail = "stub-detail-that-must-not-appear";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Production");
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:BookingApi"] = "" }));

        if (stub is { } status)
        {
            builder.ConfigureServices(services => services.PostConfigure<HealthCheckServiceOptions>(options =>
            {
                options.Registrations.Clear();
                options.Registrations.Add(new HealthCheckRegistration(
                    "database", _ => new StubHealthCheck(status), failureStatus: null, tags: ["ready"]));
            }));
        }
    }

    private sealed class StubHealthCheck(HealthStatus status) : IHealthCheck
    {
        public Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
            => Task.FromResult(new HealthCheckResult(status, StubDetail));
    }
}
