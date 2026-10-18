using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Tests.Resources;

// Spec FR-005; contract: GET /resources (page default 1, pageSize default 50, 1 to 100).
public class ListResourcesHandlerTests
{
    private readonly FakeResourceRepository _repository = new();

    private ListResourcesHandler Handler() => new(_repository);

    [Fact]
    public async Task NoParametersMeansPageOneOfFifty()
    {
        var outcome = await Handler().HandleAsync(null, null, default);

        var listed = Assert.IsType<ResourcesListed>(outcome);
        Assert.Equal((1, 50), _repository.LastListRequest);
        Assert.Equal(1, listed.Page.Page);
        Assert.Equal(50, listed.Page.PageSize);
    }

    [Theory]
    [InlineData(1, 1)]
    [InlineData(3, 100)]
    [InlineData(2147483647, 7)]
    public async Task ValidParametersReachTheRepositoryUnchanged(int page, int pageSize)
    {
        var outcome = await Handler().HandleAsync(page, pageSize, default);

        Assert.IsType<ResourcesListed>(outcome);
        Assert.Equal((page, pageSize), _repository.LastListRequest);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(int.MinValue)]
    public async Task APageBelowOneIsInvalid(int page)
    {
        var outcome = await Handler().HandleAsync(page, 50, default);

        var invalid = Assert.IsType<ListResourcesInvalid>(outcome);
        Assert.Equal("page", Assert.Single(invalid.Errors).Field);
        Assert.Null(_repository.LastListRequest);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    [InlineData(101)]
    [InlineData(int.MaxValue)]
    public async Task APageSizeOutsideOneToOneHundredIsInvalid(int pageSize)
    {
        var outcome = await Handler().HandleAsync(1, pageSize, default);

        var invalid = Assert.IsType<ListResourcesInvalid>(outcome);
        Assert.Equal("pageSize", Assert.Single(invalid.Errors).Field);
        Assert.Null(_repository.LastListRequest);
    }

    [Fact]
    public async Task BothParametersCanBeInvalidAtOnce()
    {
        var outcome = await Handler().HandleAsync(0, 0, default);

        var invalid = Assert.IsType<ListResourcesInvalid>(outcome);
        Assert.Equal(["page", "pageSize"], invalid.Errors.Select(e => e.Field).ToArray());
        Assert.All(invalid.Errors, e => Assert.False(string.IsNullOrWhiteSpace(e.Message)));
    }

    [Fact]
    public async Task TheResultCarriesTheItemsAndTheTotalCount()
    {
        var items = new[] { Resource.Create("Room A", null, DateTimeOffset.UtcNow).Value! };
        _repository.PageToReturn = new ResourcePage(items, 1, 50, 120);

        var outcome = await Handler().HandleAsync(2, 50, default);

        var page = Assert.IsType<ResourcesListed>(outcome).Page;
        Assert.Equal(2, page.Page);
        Assert.Equal(50, page.PageSize);
        Assert.Equal(120, page.TotalCount);
        Assert.Same(items[0], Assert.Single(page.Items));
    }
}
