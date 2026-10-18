using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Tests.Resources;

// Hand-written fakes: no mocking package (plan, Packages).
internal sealed class FakeResourceRepository : IResourceRepository
{
    public List<Resource> Stored { get; } = [];

    public List<string> NamesChecked { get; } = [];

    public int AddCalls { get; private set; }

    // Lets a test simulate the race: the name looked free, but the store refuses the insert.
    public AddResourceResult? ForcedAddResult { get; set; }

    public (int Page, int PageSize)? LastListRequest { get; private set; }

    public ResourcePage PageToReturn { get; set; } = new([], 1, 50, 0);

    public Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken)
    {
        NamesChecked.Add(name);
        return Task.FromResult(Stored.Any(r => string.Equals(r.Name, name, StringComparison.OrdinalIgnoreCase)));
    }

    public Task<AddResourceResult> AddAsync(Resource resource, CancellationToken cancellationToken)
    {
        AddCalls++;
        if (ForcedAddResult is { } forced)
        {
            return Task.FromResult(forced);
        }

        Stored.Add(resource);
        return Task.FromResult(AddResourceResult.Added);
    }

    public Task<Resource?> GetByIdAsync(int id, CancellationToken cancellationToken)
        => Task.FromResult(Stored.FirstOrDefault(r => r.Id == id));

    public Task<ResourcePage> ListAsync(int page, int pageSize, CancellationToken cancellationToken)
    {
        LastListRequest = (page, pageSize);
        return Task.FromResult(PageToReturn with { Page = page, PageSize = pageSize });
    }
}

internal sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => now;
}
