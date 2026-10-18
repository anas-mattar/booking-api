using BookingApi.Infrastructure.Data;
using BookingApi.TestSupport;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace BookingApi.Infrastructure.Tests;

/// <summary>A fresh, migrated database per test, plus raw-SQL helpers.</summary>
public abstract class DatabaseTest(SqlServerFixture sql) : IAsyncLifetime
{
    protected string ConnectionString { get; private set; } = "";

    public async Task InitializeAsync()
    {
        ConnectionString = await sql.CreateDatabaseAsync();
        await using var context = NewContext();
        await context.Database.MigrateAsync();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    protected BookingDbContext NewContext() => new(
        new DbContextOptionsBuilder<BookingDbContext>().UseSqlServer(ConnectionString).Options);

    protected async Task<int> ExecuteAsync(string commandText)
    {
        await using var connection = new SqlConnection(ConnectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = commandText;
        return await command.ExecuteNonQueryAsync();
    }

    protected async Task<object?> ScalarAsync(string commandText)
    {
        await using var connection = new SqlConnection(ConnectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = commandText;
        return await command.ExecuteScalarAsync();
    }
}
