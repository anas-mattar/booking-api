using BookingApi.TestSupport;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace BookingApi.Infrastructure.Tests;

// Spec SC-005: the migration applies to an empty database and reverses to empty.
[Collection(SqlServerCollection.Name)]
public class MigrationTests(SqlServerFixture sql) : DatabaseTest(sql)
{
    [Fact]
    public async Task MigrateAppliesToAnEmptyDatabase()
    {
        Assert.Equal(1, await ScalarAsync("SELECT COUNT(*) FROM sys.tables WHERE name = 'Resources'"));
        Assert.Empty(await NewContext().Database.GetPendingMigrationsAsync());
    }

    [Fact]
    public async Task MigratingBackToZeroReturnsTheDatabaseToEmpty()
    {
        await using var context = NewContext();
        await context.GetService<Microsoft.EntityFrameworkCore.Migrations.IMigrator>().MigrateAsync("0");

        Assert.Equal(0, await ScalarAsync("SELECT COUNT(*) FROM sys.tables WHERE name = 'Resources'"));
    }
}
