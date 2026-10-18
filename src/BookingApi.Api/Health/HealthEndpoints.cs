using Microsoft.AspNetCore.Diagnostics.HealthChecks;

namespace BookingApi.Api.Health;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md
public static class HealthEndpoints
{
    public static IServiceCollection AddHealth(this IServiceCollection services)
    {
        services.AddHealthChecks();
        return services;
    }

    public static IEndpointRouteBuilder MapHealth(this IEndpointRouteBuilder endpoints)
    {
        // Liveness: runs no checks, so it never depends on the database.
        endpoints.MapHealthChecks("/health", new HealthCheckOptions { Predicate = _ => false });
        return endpoints;
    }
}
