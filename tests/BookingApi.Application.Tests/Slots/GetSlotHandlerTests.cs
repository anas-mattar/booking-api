using BookingApi.Application.Slots;
using BookingApi.Application.Tests.Resources;
using static BookingApi.Application.Tests.Slots.SlotTestData;

namespace BookingApi.Application.Tests.Slots;

// Spec FR-006; contract: GET /resources/{resourceId}/slots/{id}.
public class GetSlotHandlerTests
{
    private readonly FakeSlotRepository _slots = new();
    private readonly FakeResourceRepository _resources = new();

    private GetSlotHandler Handler() => new(_slots, _resources);

    [Fact]
    public async Task ASlotOfThatResourceIsFound()
    {
        var resourceId = await AddResourceAsync(_resources);
        await AddSlotAsync(_slots, resourceId, At(8), At(9));
        var wanted = await AddSlotAsync(_slots, resourceId, At(9), At(10));

        var outcome = await Handler().HandleAsync(resourceId, wanted.Id, default);

        Assert.Same(wanted, Assert.IsType<SlotFound>(outcome).Slot);
    }

    [Fact]
    public async Task AnUnknownSlotIdIsNotFound()
    {
        var resourceId = await AddResourceAsync(_resources);
        await AddSlotAsync(_slots, resourceId, At(9), At(10));

        Assert.IsType<SlotNotFound>(await Handler().HandleAsync(resourceId, 999, default));
    }

    [Fact]
    public async Task ASlotOfAnotherResourceIsNotFound()
    {
        var first = await AddResourceAsync(_resources, "Room A");
        var second = await AddResourceAsync(_resources, "Room B");
        var slot = await AddSlotAsync(_slots, first, At(9), At(10));

        Assert.IsType<SlotNotFound>(await Handler().HandleAsync(second, slot.Id, default));
    }

    [Fact]
    public async Task AnUnknownResourceIsResourceNotFound()
    {
        Assert.IsType<GetSlotResourceNotFound>(await Handler().HandleAsync(999, 1, default));
    }

    [Fact]
    public async Task TheCancellationTokenReachesTheRepositories()
    {
        var resourceId = await AddResourceAsync(_resources);
        var slot = await AddSlotAsync(_slots, resourceId, At(9), At(10));
        using var source = new CancellationTokenSource();
        _resources.Tokens.Clear();
        _slots.Tokens.Clear();

        await Handler().HandleAsync(resourceId, slot.Id, source.Token);

        Assert.NotEmpty(_resources.Tokens);
        Assert.NotEmpty(_slots.Tokens);
        Assert.All(_resources.Tokens.Concat(_slots.Tokens), token => Assert.Equal(source.Token, token));
    }
}
