using BookingApi.Application.Resources;
using BookingApi.Domain;
using BookingApi.Infrastructure.Resources;
using BookingApi.TestSupport;
using Microsoft.EntityFrameworkCore;

namespace BookingApi.Infrastructure.Tests;

// Spec FR-002, FR-007, FR-008, FR-011; SC-003 (database half).
[Collection(SqlServerCollection.Name)]
public class ResourceRepositoryTests(SqlServerFixture sql) : DatabaseTest(sql)
{
    private static readonly DateTimeOffset Instant = new(2026, 1, 2, 3, 4, 5, TimeSpan.Zero);

    private static Resource NewResource(string name, string? description = null) =>
        Resource.Create(name, description, Instant).Value!;

    private ResourceRepository NewRepository(out BookingApi.Infrastructure.Data.BookingDbContext context)
    {
        context = NewContext();
        return new ResourceRepository(context);
    }

    private async Task<AddResourceResult> AddAsync(Resource resource)
    {
        await using var context = NewContext();
        return await new ResourceRepository(context).AddAsync(resource, default);
    }

    private async Task RetireAsync(string name) => await ExecuteAsync(
        $"UPDATE Resources SET IsDeleted = 1, DeletedAtUtc = '2026-01-03', DeletedBy = 'test' WHERE Name = '{name}'");

    [Fact]
    public async Task AddThenGetRoundTripsEveryField()
    {
        var resource = NewResource("  Room A ", "Ground floor");

        Assert.Equal(AddResourceResult.Added, await AddAsync(resource));
        Assert.True(resource.Id > 0);

        await using var context = NewContext();
        var loaded = await new ResourceRepository(context).GetByIdAsync(resource.Id, default);

        Assert.NotNull(loaded);
        Assert.Equal(resource.Id, loaded.Id);
        Assert.Equal("Room A", loaded.Name);
        Assert.Equal("Ground floor", loaded.Description);
        Assert.Equal(Instant.UtcDateTime, loaded.CreatedAtUtc);
        Assert.Equal(DateTimeKind.Utc, loaded.CreatedAtUtc.Kind);
        Assert.Equal(DateTimeKind.Utc, loaded.UpdatedAtUtc.Kind);
        Assert.Equal("anonymous", loaded.CreatedBy);
        Assert.Equal(Instant.UtcDateTime, loaded.UpdatedAtUtc);
        Assert.Equal("anonymous", loaded.UpdatedBy);
        Assert.False(loaded.IsDeleted);
        Assert.Null(loaded.DeletedAtUtc);
        Assert.Null(loaded.DeletedBy);
    }

    [Fact]
    public async Task ARetiredRowReadWithoutTheFilterKeepsItsDeletionInstantAsUtc()
    {
        var resource = NewResource("Retired");
        await AddAsync(resource);
        await RetireAsync("Retired");

        await using var context = NewContext();
        var loaded = await context.Resources.IgnoreQueryFilters().AsNoTracking().SingleAsync(r => r.Id == resource.Id);

        Assert.True(loaded.IsDeleted);
        Assert.Equal(DateTimeKind.Utc, loaded.DeletedAtUtc!.Value.Kind);
    }

    [Fact]
    public async Task ANullDescriptionAndAnEmptyOneRoundTripAsGiven()
    {
        var none = NewResource("None");
        var empty = NewResource("Empty", "");
        await AddAsync(none);
        await AddAsync(empty);

        await using var context = NewContext();
        var repository = new ResourceRepository(context);
        Assert.Null((await repository.GetByIdAsync(none.Id, default))!.Description);
        Assert.Equal("", (await repository.GetByIdAsync(empty.Id, default))!.Description);
    }

    [Fact]
    public async Task ANameDifferingOnlyByCaseCollides()
    {
        await AddAsync(NewResource("Room A"));

        Assert.Equal(AddResourceResult.DuplicateName, await AddAsync(NewResource("room a")));

        await using var context = NewContext();
        Assert.True(await new ResourceRepository(context).NameExistsAsync("ROOM A", default));
    }

    [Fact]
    public async Task ANameIsAllowedOnceTheEarlierHolderIsRetired()
    {
        await AddAsync(NewResource("Room A"));
        await RetireAsync("Room A");

        Assert.Equal(AddResourceResult.Added, await AddAsync(NewResource("Room A")));
    }

    [Fact]
    public async Task RetiredRowsAreInvisibleToGetListAndNameExists()
    {
        var retired = NewResource("Retired");
        await AddAsync(retired);
        await AddAsync(NewResource("Live"));
        await RetireAsync("Retired");

        await using var context = NewContext();
        var repository = new ResourceRepository(context);

        Assert.Null(await repository.GetByIdAsync(retired.Id, default));
        Assert.False(await repository.NameExistsAsync("Retired", default));
        var page = await repository.ListAsync(1, 50, default);
        Assert.Equal(["Live"], page.Items.Select(r => r.Name));
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task AnUnknownIdIsNull()
    {
        await using var context = NewContext();
        Assert.Null(await new ResourceRepository(context).GetByIdAsync(12345, default));
    }

    [Fact]
    public async Task OneHundredResourcesPageAsFiftyAndFiftyEachExactlyOnceInOrder()
    {
        // Mixed case so the case-insensitive ordering is what is being asserted, inserted in
        // descending name order so that ordering by Id instead of by name would fail.
        for (var i = 99; i >= 0; i--)
        {
            await AddAsync(NewResource(i % 2 == 0 ? $"res {i:D3}" : $"RES {i:D3}"));
        }

        await using var context = NewContext();
        var repository = new ResourceRepository(context);
        var first = await repository.ListAsync(1, 50, default);
        var second = await repository.ListAsync(2, 50, default);

        Assert.Equal(50, first.Items.Count);
        Assert.Equal(50, second.Items.Count);
        Assert.Equal(100, first.TotalCount);
        Assert.Equal(1, first.Page);
        Assert.Equal(50, first.PageSize);

        var names = first.Items.Concat(second.Items).Select(r => r.Name).ToList();
        Assert.Equal(100, names.Distinct().Count());
        Assert.Equal(names.OrderBy(n => n, StringComparer.OrdinalIgnoreCase), names);
    }

    [Fact]
    public async Task APagePastTheEndIsEmptyWithTheTrueTotal()
    {
        await AddAsync(NewResource("Only"));

        await using var context = NewContext();
        var page = await new ResourceRepository(context).ListAsync(5, 50, default);

        Assert.Empty(page.Items);
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task AnOffsetBeyondTheIntRangeIsAnEmptyPageNotAnOverflow()
    {
        await AddAsync(NewResource("Only"));

        await using var context = NewContext();
        var page = await new ResourceRepository(context).ListAsync(int.MaxValue, 100, default);

        Assert.Empty(page.Items);
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task ManyParallelAddsOfOneNameYieldExactlyOneSuccessAndNoException()
    {
        var results = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => Task.Run(() => AddAsync(NewResource("Contended")))));

        Assert.Equal(1, results.Count(r => r == AddResourceResult.Added));
        Assert.Equal(19, results.Count(r => r == AddResourceResult.DuplicateName));
        Assert.Equal(1, await ScalarAsync("SELECT COUNT(*) FROM Resources WHERE Name = 'Contended'"));
    }
}
