using Testcontainers.MsSql;
using Xunit;

namespace BookingApi.TestSupport;

// One SQL Server container per test assembly (plan, Design Notes: Test database). Each test
// assembly declares the collection that uses it: xUnit requires the definition in the same
// assembly as the tests. If Docker is not running, InitializeAsync throws the container error:
// the tests fail, they never skip.
public sealed class SqlServerFixture : IAsyncLifetime
{
    // The parameterless builder is obsolete; this is the image the module used to default to.
    private const string Image = "mcr.microsoft.com/mssql/server:2022-latest";

    private readonly MsSqlContainer _container = new MsSqlBuilder(Image).Build();

    public async Task InitializeAsync() => await _container.StartAsync();

    public async Task DisposeAsync() => await _container.DisposeAsync();

    /// <summary>Creates a uniquely named empty database and returns its connection string.</summary>
    public async Task<string> CreateDatabaseAsync()
    {
        var name = $"BookingApiTest_{Guid.NewGuid():N}";

        // Testcontainers runs the script inside the container (sqlcmd), so no client package is needed here.
        var result = await _container.ExecScriptAsync($"CREATE DATABASE [{name}]");
        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException($"Creating test database failed: {result.Stdout} {result.Stderr}");
        }

        // The module's connection string targets master; swap in the new database.
        return _container.GetConnectionString().Replace("Database=master", $"Database={name}", StringComparison.OrdinalIgnoreCase);
    }
}
