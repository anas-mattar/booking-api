using BookingApi.Application.Resources;
using BookingApi.Infrastructure.Data;
using BookingApi.Infrastructure.Resources;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BookingApi.Infrastructure;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md (readiness).
public static class DependencyInjection
{
    public const string ConnectionStringName = "BookingApi";
    public const string DatabaseCheckName = "database";
    public const string ReadyTag = "ready";

    // Spec FR-004: readiness gives up and reports unhealthy within 5 seconds.
    private static readonly TimeSpan ReadinessTimeout = TimeSpan.FromSeconds(5);

    public static IServiceCollection AddInfrastructure(this IServiceCollection services)
    {
        // The connection string is read when the context is first resolved, not here, so a
        // missing or empty value fails the readiness check instead of crashing startup, and
        // test hosts can override configuration before it is read.
        services.AddDbContext<BookingDbContext>((provider, options) =>
            options.UseSqlServer(provider.GetRequiredService<IConfiguration>().GetConnectionString(ConnectionStringName)));

        services.AddScoped<IResourceRepository, ResourceRepository>();

        services.AddHealthChecks()
            .AddDbContextCheck<BookingDbContext>(DatabaseCheckName, tags: [ReadyTag]);

        services.Configure<HealthCheckServiceOptions>(options =>
        {
            foreach (var registration in options.Registrations.Where(r => r.Name == DatabaseCheckName))
            {
                registration.Timeout = ReadinessTimeout;
            }
        });

        return services;
    }
}
