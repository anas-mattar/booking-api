using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Tests.Resources;

// Spec FR-004; contract: GET /resources/{id}.
public class GetResourceHandlerTests
{
    private readonly FakeResourceRepository _repository = new();

    [Fact]
    public async Task AnExistingResourceIsFound()
    {
        var resource = Resource.Create("Room A", null, DateTimeOffset.UtcNow).Value!;
        _repository.Stored.Add(resource);

        var outcome = await new GetResourceHandler(_repository).HandleAsync(resource.Id, default);

        Assert.Same(resource, Assert.IsType<ResourceFound>(outcome).Resource);
    }

    [Fact]
    public async Task AnUnknownIdIsNotFound()
    {
        var outcome = await new GetResourceHandler(_repository).HandleAsync(12345, default);

        Assert.IsType<ResourceNotFound>(outcome);
    }
}
