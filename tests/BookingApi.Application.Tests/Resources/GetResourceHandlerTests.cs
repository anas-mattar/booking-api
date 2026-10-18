using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Tests.Resources;

// Spec FR-004; contract: GET /resources/{id}.
public class GetResourceHandlerTests
{
    private readonly FakeResourceRepository _repository = new();

    [Fact]
    public async Task AnExistingResourceIsFoundById()
    {
        var first = await AddAsync("Room A");
        var second = await AddAsync("Room B");

        var outcome = await new GetResourceHandler(_repository).HandleAsync(second.Id, default);

        Assert.NotEqual(first.Id, second.Id);
        Assert.Same(second, Assert.IsType<ResourceFound>(outcome).Resource);
    }

    [Fact]
    public async Task AnUnknownIdIsNotFound()
    {
        var outcome = await new GetResourceHandler(_repository).HandleAsync(12345, default);

        Assert.IsType<ResourceNotFound>(outcome);
    }

    [Fact]
    public async Task TheCancellationTokenReachesTheRepository()
    {
        using var source = new CancellationTokenSource();

        await new GetResourceHandler(_repository).HandleAsync(1, source.Token);

        Assert.Equal(source.Token, Assert.Single(_repository.Tokens));
    }

    private async Task<Resource> AddAsync(string name)
    {
        var resource = Resource.Create(name, null, DateTimeOffset.UtcNow).Value!;
        await _repository.AddAsync(resource, default);
        return resource;
    }
}