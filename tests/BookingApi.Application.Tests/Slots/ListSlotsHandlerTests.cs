using BookingApi.Application.Slots;
using BookingApi.Application.Tests.Resources;
using static BookingApi.Application.Tests.Slots.SlotTestData;

namespace BookingApi.Application.Tests.Slots;

// Spec FR-007; contract: GET /resources/{resourceId}/slots (page default 1, pageSize default 50, 1 to 100).
public class ListSlotsHandlerTests
{
    private readonly FakeSlotRepository _slots = new();
    private readonly FakeResourceRepository _resources = new();

    private ListSlotsHandler Handler() => new(_slots, _resources);

    [Fact]
    public async Task AnUnknownResourceIsResourceNotFoundAndTheSlotsAreNotListed()
    {
        var outcome = await Handler().HandleAsync(999, null, null, default);

        Assert.IsType<ListSlotsResourceNotFound>(outcome);
        Assert.Null(_slots.LastListRequest);
    }

    [Fact]
    public async Task NoParametersMeansPageOneOfFifty()
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(resourceId, null, null, default);

        var listed = Assert.IsType<SlotsListed>(outcome);
        Assert.Equal((resourceId, 1, 50), _slots.LastListRequest);
        Assert.Equal(1, listed.Page.Page);
        Assert.Equal(50, listed.Page.PageSize);
    }

    [Theory]
    [InlineData(1, 1)]
    [InlineData(3, 100)]
    [InlineData(2147483647, 7)]
    public async Task ValidParametersReachTheRepositoryUnchangedWithTheResourceId(int page, int pageSize)
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(resourceId, page, pageSize, default);

        Assert.IsType<SlotsListed>(outcome);
        Assert.Equal((resourceId, page, pageSize), _slots.LastListRequest);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(int.MinValue)]
    public async Task APageBelowOneIsInvalid(int page)
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(resourceId, page, 50, default);

        var invalid = Assert.IsType<ListSlotsInvalid>(outcome);
        Assert.Equal("page", Assert.Single(invalid.Errors).Field);
        Assert.Null(_slots.LastListRequest);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    [InlineData(101)]
    [InlineData(int.MaxValue)]
    public async Task APageSizeOutsideOneToOneHundredIsInvalid(int pageSize)
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(resourceId, 1, pageSize, default);

        var invalid = Assert.IsType<ListSlotsInvalid>(outcome);
        Assert.Equal("pageSize", Assert.Single(invalid.Errors).Field);
        Assert.Null(_slots.LastListRequest);
    }

    [Fact]
    public async Task BothParametersCanBeInvalidAtOnce()
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(resourceId, 0, 0, default);

        var invalid = Assert.IsType<ListSlotsInvalid>(outcome);
        Assert.Equal(["page", "pageSize"], invalid.Errors.Select(e => e.Field));
    }

    [Fact]
    public async Task TheResultCarriesTheItemsAndTheTotalCount()
    {
        var resourceId = await AddResourceAsync(_resources);
        var slot = await AddSlotAsync(_slots, resourceId, At(9), At(10));
        _slots.PageToReturn = new([slot], 1, 50, 42);

        var outcome = await Handler().HandleAsync(resourceId, 2, 5, default);

        var listed = Assert.IsType<SlotsListed>(outcome);
        Assert.Same(slot, Assert.Single(listed.Page.Items));
        Assert.Equal(42, listed.Page.TotalCount);
    }

    [Fact]
    public async Task TheCancellationTokenReachesTheRepositories()
    {
        var resourceId = await AddResourceAsync(_resources);
        using var source = new CancellationTokenSource();
        _resources.Tokens.Clear();
        _slots.Tokens.Clear();

        await Handler().HandleAsync(resourceId, null, null, source.Token);

        Assert.NotEmpty(_resources.Tokens);
        Assert.NotEmpty(_slots.Tokens);
        Assert.All(_resources.Tokens.Concat(_slots.Tokens), token => Assert.Equal(source.Token, token));
    }
}
