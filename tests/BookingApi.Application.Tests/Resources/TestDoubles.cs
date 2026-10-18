using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Tests.Resources;

// Hand-written fakes: no mocking package (plan, Packages). The fake follows the port's
// documented contract (IResourceRepository): ids are assigned on add, names compare
// case-insensitively, failures propagate.
internal sealed class FakeResourceRepository : IResourceRepository
{
    private int _nextId = 1;

    public List<Resource> Stored { get; } = [];

    public List<string> NamesChecked { get; } = [];

    public List<CancellationToken> Tokens { get; } = [];

    public int AddCalls { get; private set; }

    // Lets a test simulate the race: the name looked free, but the store refuses the insert.
    public AddResourceResult? ForcedAddResult { get; set; }

    // Lets a test simulate an unexpected store failure on any member.
    public Exception? FailWith { get; set; }

    public (int Page, int PageSize)? LastListRequest { get; private set; }

    public ResourcePage PageToReturn { get; set; } = new([], 1, 50, 0);

    public Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        NamesChecked.Add(name);
        return Task.FromResult(Stored.Any(r => string.Equals(r.Name, name, StringComparison.OrdinalIgnoreCase)));
    }

    public Task<AddResourceResult> AddAsync(Resource resource, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        AddCalls++;
        if (ForcedAddResult is { } forced)
        {
            return Task.FromResult(forced);
        }

        // The real store assigns the database-generated id to the same instance.
        typeof(Resource).GetProperty(nameof(Resource.Id))!.SetValue(resource, _nextId++);
        Stored.Add(resource);
        return Task.FromResult(AddResourceResult.Added);
    }

    public Task<Resource?> GetByIdAsync(int id, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        return Task.FromResult(Stored.FirstOrDefault(r => r.Id == id));
    }

    public Task<ResourcePage> ListAsync(int page, int pageSize, CancellationToken cancellationToken)
    {
        Enter(cancellationToken);
        LastListRequest = (page, pageSize);
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

internal sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => now;
}
