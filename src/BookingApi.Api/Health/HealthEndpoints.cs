using Microsoft.AspNetCore.Diagnostics.HealthChecks;

namespace BookingApi.Api.Health;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md
public static class HealthEndpoints
{
    private const string ReadyTag = "ready";

    public static IServiceCollection AddHealth(this IServiceCollection services)
    {
        services.AddHealthChecks();
        return services;
    }

    public static IEndpointRouteBuilder MapHealth(this IEndpointRouteBuilder endpoints)
    {
        // Liveness: runs no checks, so it never depends on the database.
        endpoints.MapHealthChecks("/health", new HealthCheckOptions { Predicate = _ => false });

        // Readiness: runs only the checks tagged `ready` (the database check, from Infrastructure).
        endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = registration => registration.Tags.Contains(ReadyTag),
        });
        return endpoints;
    }
}
