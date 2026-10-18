using BookingApi.TestSupport;
using Microsoft.Data.SqlClient;

namespace BookingApi.Infrastructure.Tests;

// data-model.md: the database itself refuses what slips past the application (raw SQL, no EF).
[Collection(SqlServerCollection.Name)]
public class ConstraintTests(SqlServerFixture sql) : DatabaseTest(sql)
{
    private const string Now = "'2026-01-01T00:00:00'";

    private Task<int> InsertAsync(string name, string? description = "NULL", string createdAt = Now, string updatedAt = Now,
        int isDeleted = 0, string deletedAt = "NULL", string deletedBy = "NULL") =>
        ExecuteAsync($"""
            INSERT INTO Resources (Name, Description, CreatedAtUtc, CreatedBy, UpdatedAtUtc, UpdatedBy, IsDeleted, DeletedAtUtc, DeletedBy)
            VALUES ({name}, {description}, {createdAt}, 'anonymous', {updatedAt}, 'anonymous', {isDeleted}, {deletedAt}, {deletedBy})
            """);

    private async Task AssertRefusedAsync(Func<Task<int>> insert, string constraint)
    {
        var ex = await Assert.ThrowsAsync<SqlException>(insert);
        Assert.Contains(constraint, ex.Message);
    }

    [Fact]
    public async Task AValidRowIsAccepted() => Assert.Equal(1, await InsertAsync("'Room A'"));

    [Theory]
    [InlineData("' Room A'")]
    [InlineData("'Room A '")]
    [InlineData("''")]
    [InlineData("'   '")]
    public async Task AnUntrimmedOrBlankNameIsRefused(string name) =>
        await AssertRefusedAsync(() => InsertAsync(name), "CK_Resources_Name_Trimmed");

    [Fact]
    public async Task ANameOverOneHundredCharactersIsRefused() =>
        await Assert.ThrowsAsync<SqlException>(() => InsertAsync($"'{new string('a', 101)}'"));

    [Fact]
    public async Task ADescriptionOverFiveHundredCharactersIsRefused() =>
        await Assert.ThrowsAsync<SqlException>(() => InsertAsync("'Room A'", $"'{new string('a', 501)}'"));

    [Fact]
    public async Task ARetiredRowWithoutDeletionDataIsRefused() =>
        await AssertRefusedAsync(() => InsertAsync("'Room A'", isDeleted: 1), "CK_Resources_Deleted_Consistent");

    [Fact]
    public async Task ALiveRowWithDeletionDataIsRefused() =>
        await AssertRefusedAsync(
            () => InsertAsync("'Room A'", deletedAt: Now, deletedBy: "'someone'"), "CK_Resources_Deleted_Consistent");

    [Fact]
    public async Task ARetiredRowWithDeletionDataIsAccepted() =>
        Assert.Equal(1, await InsertAsync("'Room A'", isDeleted: 1, deletedAt: Now, deletedBy: "'someone'"));

    [Fact]
    public async Task UpdatedBeforeCreatedIsRefused() =>
        await AssertRefusedAsync(
            () => InsertAsync("'Room A'", updatedAt: "'2025-12-31T00:00:00'"), "CK_Resources_Updated_NotBeforeCreated");
}
