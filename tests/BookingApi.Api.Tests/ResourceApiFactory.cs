using BookingApi.Infrastructure.Data;
using BookingApi.TestSupport;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BookingApi.Api.Tests;

// Points the real application at a fresh, migrated database in the test container, so the
// HTTP tests run against real SQL Server. The connection string is forced, so a developer's
// user secrets never reach the gate.
internal sealed class ResourceApiFactory(string connectionString, string environment) : WebApplicationFactory<Program>
{
    public static async Task<ResourceApiFactory> CreateAsync(SqlServerFixture sql, string environment = "Production")
    {
        var factory = new ResourceApiFactory(await sql.CreateDatabaseAsync(), environment);
        using var scope = factory.Services.CreateScope();
        await scope.ServiceProvider.GetRequiredService<BookingDbContext>().Database.MigrateAsync();
        return factory;
    }

    /// <summary>Runs raw SQL against the test database (for example to retire a row).</summary>
    public async Task ExecuteSqlAsync(string sql)
    {
        using var scope = Services.CreateScope();
        await scope.ServiceProvider.GetRequiredService<BookingDbContext>().Database.ExecuteSqlRawAsync(sql);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(environment);
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:BookingApi"] = connectionString }));
    }
}
