using BookingApi.Application.Resources;

namespace BookingApi.Application.Tests.Resources;

// Spec FR-001, FR-002 (application half), FR-003, FR-008; contract: POST /resources.
public class CreateResourceHandlerTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 18, 12, 0, 0, TimeSpan.Zero);

    private readonly FakeResourceRepository _repository = new();

    private CreateResourceHandler Handler() => new(_repository, new FixedTimeProvider(Now));

    [Fact]
    public async Task ValidInputIsStoredAndReturnedWithTheClockInstants()
    {
        var outcome = await Handler().HandleAsync(new CreateResourceCommand("Room A", "Seats 8"), default);

        var created = Assert.IsType<ResourceCreated>(outcome);
        Assert.Equal("Room A", created.Resource.Name);
        Assert.Equal("Seats 8", created.Resource.Description);
        Assert.Equal(Now.UtcDateTime, created.Resource.CreatedAtUtc);
        Assert.Same(created.Resource, Assert.Single(_repository.Stored));
    }

    [Fact]
    public async Task InvalidInputReturnsTheFieldErrorsAndStoresNothing()
    {
        var outcome = await Handler().HandleAsync(new CreateResourceCommand("   ", new string('d', 501)), default);

        var invalid = Assert.IsType<ResourceInvalid>(outcome);
        Assert.Equal(["name", "description"], invalid.Errors.Select(e => e.Field).ToArray());
        Assert.Equal(0, _repository.AddCalls);
        Assert.Empty(_repository.NamesChecked);
    }

    [Fact]
    public async Task ANameAlreadyPresentIsRefusedWithoutAdding()
    {
        await Handler().HandleAsync(new CreateResourceCommand("Room A", null), default);

        var outcome = await Handler().HandleAsync(new CreateResourceCommand("room a", null), default);

        Assert.IsType<ResourceNameTaken>(outcome);
        Assert.Equal(1, _repository.AddCalls);
        Assert.Single(_repository.Stored);
    }

    [Fact]
    public async Task TheNameIsTrimmedBeforeItIsLookedUp()
    {
        await Handler().HandleAsync(new CreateResourceCommand("Room A", null), default);
        _repository.NamesChecked.Clear();

        var outcome = await Handler().HandleAsync(new CreateResourceCommand("  Room A  ", null), default);

        Assert.IsType<ResourceNameTaken>(outcome);
        Assert.Equal("Room A", Assert.Single(_repository.NamesChecked));
    }

    [Fact]
    public async Task AConcurrentDuplicateRefusedByTheStoreIsStillANameTakenOutcome()
    {
        _repository.ForcedAddResult = AddResourceResult.DuplicateName;

        var outcome = await Handler().HandleAsync(new CreateResourceCommand("Room A", null), default);

        Assert.IsType<ResourceNameTaken>(outcome);
        Assert.Equal(1, _repository.AddCalls);
    }
}
