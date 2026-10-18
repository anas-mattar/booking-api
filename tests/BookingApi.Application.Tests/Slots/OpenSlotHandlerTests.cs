using BookingApi.Application.Resources;
using BookingApi.Application.Slots;
using BookingApi.Application.Tests.Resources;
using static BookingApi.Application.Tests.Slots.SlotTestData;

namespace BookingApi.Application.Tests.Slots;

// Spec FR-001..FR-005; contract: POST /resources/{resourceId}/slots.
public class OpenSlotHandlerTests
{
    private readonly FakeSlotRepository _slots = new();
    private readonly FakeResourceRepository _resources = new();

    private OpenSlotHandler Handler() => new(_slots, _resources, new FixedTimeProvider(Now));

    [Fact]
    public async Task ValidInputIsStoredAndReturnedWithTheClockInstants()
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(new OpenSlotCommand(resourceId, At(9), At(10)), default);

        var opened = Assert.IsType<SlotOpened>(outcome);
        Assert.Same(Assert.Single(_slots.Stored), opened.Slot);
        Assert.True(opened.Slot.Id > 0);
        Assert.Equal(resourceId, opened.Slot.ResourceId);
        Assert.Equal(At(9).UtcDateTime, opened.Slot.StartUtc);
        Assert.Equal(At(10).UtcDateTime, opened.Slot.EndUtc);
        Assert.Equal(Now.UtcDateTime, opened.Slot.CreatedAtUtc);
    }

    [Fact]
    public async Task AnUnknownResourceIsNotFoundAndNothingIsCheckedOrAdded()
    {
        var outcome = await Handler().HandleAsync(new OpenSlotCommand(999, At(9), At(10)), default);

        Assert.IsType<OpenSlotResourceNotFound>(outcome);
        Assert.Equal(0, _slots.OverlapChecks);
        Assert.Equal(0, _slots.AddCalls);
    }

    [Theory]
    [InlineData(10, 9)]   // end before start
    [InlineData(9, 9)]    // empty interval
    public async Task AnEndNotAfterTheStartIsInvalidAndStoresNothing(int startHour, int endHour)
    {
        var resourceId = await AddResourceAsync(_resources);

        var outcome = await Handler().HandleAsync(new OpenSlotCommand(resourceId, At(startHour), At(endHour)), default);

        var invalid = Assert.IsType<SlotInvalid>(outcome);
        Assert.Equal("endUtc", Assert.Single(invalid.Errors).Field);
        Assert.Equal(0, _slots.OverlapChecks);
        Assert.Equal(0, _slots.AddCalls);
    }

    [Theory]
    [InlineData(9, 0, 10, 0)]    // identical
    [InlineData(9, 15, 9, 45)]   // inside
    [InlineData(8, 0, 11, 0)]    // containing
    [InlineData(9, 30, 10, 30)]  // starts inside
    [InlineData(8, 30, 9, 30)]   // ends inside
    public async Task AnOverlapWithAnExistingSlotIsRefusedAndNothingIsAdded(int sh, int sm, int eh, int em)
    {
        var resourceId = await AddResourceAsync(_resources);
        await AddSlotAsync(_slots, resourceId, At(9), At(10));
        var addsBefore = _slots.AddCalls;

        var outcome = await Handler().HandleAsync(new OpenSlotCommand(resourceId, At(sh, sm), At(eh, em)), default);

        Assert.IsType<SlotOverlaps>(outcome);
        Assert.Equal(addsBefore, _slots.AddCalls);
        Assert.Single(_slots.Stored);
    }

    [Theory]
    [InlineData(10, 11)]   // touching after
    [InlineData(8, 9)]     // touching before
    [InlineData(11, 12)]   // disjoint
    public async Task TouchingOrDisjointSlotsAreOpened(int startHour, int endHour)
    {
        var resourceId = await AddResourceAsync(_resources);
        await AddSlotAsync(_slots, resourceId, At(9), At(10));

        var outcome = await Handler().HandleAsync(new OpenSlotCommand(resourceId, At(startHour), At(endHour)), default);

        Assert.IsType<SlotOpened>(outcome);
        Assert.Equal(2, _slots.Stored.Count);
    }

    [Fact]
    public async Task ASlotOnAnotherResourceDoesNotBlock()
    {
        var first = await AddResourceAsync(_resources, "Room A");
        var second = await AddResourceAsync(_resources, "Room B");
        await AddSlotAsync(_slots, first, At(9), At(10));

        var outcome = await Handler().HandleAsync(new OpenSlotCommand(second, At(9), At(10)), default);

        Assert.IsType<SlotOpened>(outcome);
    }

    [Fact]
    public async Task AnOffsetInstantIsComparedAsUtc()
    {
        var resourceId = await AddResourceAsync(_resources);
        await AddSlotAsync(_slots, resourceId, At(9), At(10));
        var plusTwo = TimeSpan.FromHours(2);

        // 11:00+02:00 to 12:00+02:00 is 09:00Z to 10:00Z: identical to the existing slot.
        var outcome = await Handler().HandleAsync(
            new OpenSlotCommand(resourceId, new DateTimeOffset(2026, 11, 2, 11, 0, 0, plusTwo), new DateTimeOffset(2026, 11, 2, 12, 0, 0, plusTwo)),
            default);

        Assert.IsType<SlotOverlaps>(outcome);
    }

    [Fact]
    public async Task AnOverlapRefusedByTheStoreIsStillAnOverlapOutcome()
    {
        var resourceId = await AddResourceAsync(_resources);
        _slots.ForcedAddResult = AddSlotResult.Overlaps;

        var outcome = await Handler().HandleAsync(new OpenSlotCommand(resourceId, At(9), At(10)), default);

        Assert.IsType<SlotOverlaps>(outcome);
        Assert.Equal(1, _slots.AddCalls);
    }

    [Fact]
    public async Task TheCancellationTokenReachesBothRepositories()
    {
        var resourceId = await AddResourceAsync(_resources);
        using var source = new CancellationTokenSource();
        _resources.Tokens.Clear();

        await Handler().HandleAsync(new OpenSlotCommand(resourceId, At(9), At(10)), source.Token);

        Assert.All(_resources.Tokens, token => Assert.Equal(source.Token, token));
        Assert.NotEmpty(_resources.Tokens);
        Assert.All(_slots.Tokens, token => Assert.Equal(source.Token, token));
        Assert.NotEmpty(_slots.Tokens);
    }

    [Fact]
    public async Task AStoreFailurePropagatesInsteadOfBecomingAnOutcome()
    {
        var resourceId = await AddResourceAsync(_resources);
        _slots.FailWith = new InvalidOperationException("store down");

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Handler().HandleAsync(new OpenSlotCommand(resourceId, At(9), At(10)), default));
    }
}
