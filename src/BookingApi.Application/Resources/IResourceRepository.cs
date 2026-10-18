using BookingApi.Domain;

namespace BookingApi.Application.Resources;

// The persistence port for resources. Implemented by Infrastructure (phase 3).
public interface IResourceRepository
{
    /// <summary>True when a non-retired resource already has this name (case-insensitive).</summary>
    Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken);

    /// <summary>
    /// Stores the resource. Answers <see cref="AddResourceResult.DuplicateName"/> when the store
    /// itself refuses the name, which covers a concurrent insert that slipped past
    /// <see cref="NameExistsAsync"/>.
    /// </summary>
    Task<AddResourceResult> AddAsync(Resource resource, CancellationToken cancellationToken);

    /// <summary>The non-retired resource with this id, or null.</summary>
    Task<Resource?> GetByIdAsync(int id, CancellationToken cancellationToken);

    /// <summary>One page of non-retired resources, ordered by name (case-insensitive) then id.</summary>
    Task<ResourcePage> ListAsync(int page, int pageSize, CancellationToken cancellationToken);
}

public enum AddResourceResult
{
    Added,
    DuplicateName,
}

public sealed record ResourcePage(IReadOnlyList<Resource> Items, int Page, int PageSize, int TotalCount);
