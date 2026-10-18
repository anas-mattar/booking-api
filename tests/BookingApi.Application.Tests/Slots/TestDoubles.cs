using BookingApi.Application.Resources;
using BookingApi.Application.Slots;
using BookingApi.Application.Tests.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Tests.Slots;

// Hand-written fake following the port's documented contract (ISlotRepository): ids are assigned
// on add, overlap is the half-open predicate per resource, retired slots are invisible, failures
// propagate.
internal sealed class FakeSlotRepository : ISlotRepository
{
    private int _nextId = 1;

    public List<TimeSlot> Stored { get; } = [];

    public List<CancellationToken> Tokens { get; } = [];

    public int AddCalls { get; private set; }

    public int OverlapChecks { get; private set; }

    // Lets a test simulate the race: the interval looked free, but the store refuses the insert.
    public AddSlotResult? ForcedAddResult { get; set; }

    // Lets a test simulate an unexpected store failure on any member.
    public Exception? FailWith { get; set; }

    public (int ResourceId, int Page, int PageSize)? LastListRequest { get; private set; }

    public SlotPage PageToReturn { get; set; } = new([], 1, 50, 0);

    public Task<bool> OverlapExistsAsync(int resourceId, DateTime startUtc, DateTime endUtc, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        OverlapChecks++;
        return Task.FromResult(Stored.Any(s => !s.IsDeleted && s.ResourceId == resourceId && s.Overlaps(startUtc, endUtc)));
    }

    public Task<AddSlotResult> AddAsync(TimeSlot slot, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        AddCalls++;
        if (ForcedAddResult is { } forced)
        {
            return Task.FromResult(forced);
        }

        // The real store assigns the database-generated id to the same instance.
        typeof(TimeSlot).GetProperty(nameof(TimeSlot.Id))!.SetValue(slot, _nextId++);
        Stored.Add(slot);
        return Task.FromResult(AddSlotResult.Added);
    }

    public Task<TimeSlot?> GetAsync(int resourceId, int id, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        return Task.FromResult(Stored.FirstOrDefault(s => !s.IsDeleted && s.ResourceId == resourceId && s.Id == id));
    }

    public Task<SlotPage> ListAsync(int resourceId, int page, int pageSize, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        LastListRequest = (resourceId, page, pageSize);
        return Task.FromResult(PageToReturn with { Page = page, PageSize = pageSize });
    }

    private void Enter(CancellationToken cancellationToken)
    {
        Tokens.Add(cancellationToken);
        if (FailWith is not null)
        {
            throw FailWith;
        }
    }
}

internal static class SlotTestData
{
    public static readonly DateTimeOffset Now = new(2026, 10, 19, 12, 0, 0, TimeSpan.Zero);

    public static DateTimeOffset At(int hour, int minute = 0) => new(2026, 11, 2, hour, minute, 0, TimeSpan.Zero);

    /// <summary>Stores a resource in the fake and returns its assigned id.</summary>
    public static async Task<int> AddResourceAsync(FakeResourceRepository resources, string name = "Room A")
    {
        var resource = Resource.Create(name, null, Now).Value!;
        await resources.AddAsync(resource, default);
        return resource.Id;
    }

    /// <summary>Stores a slot straight in the fake slot repository (setup, bypassing the handler).</summary>
    public static async Task<TimeSlot> AddSlotAsync(FakeSlotRepository slots, int resourceId, DateTimeOffset start, DateTimeOffset end)
    {
        var slot = TimeSlot.Create(resourceId, start, end, Now).Value!;
        await slots.AddAsync(slot, default);
        return slot;
    }
}
