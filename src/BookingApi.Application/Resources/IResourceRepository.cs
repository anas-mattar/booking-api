using BookingApi.Domain;

namespace BookingApi.Application.Resources;

/// <summary>
/// The persistence port for resources, implemented by Infrastructure (phase 3). The rules below
/// are part of the contract: the handlers rely on every one of them, and the implementation is
/// tested against them on real SQL Server.
/// </summary>
/// <remarks>
/// <list type="bullet">
/// <item><description>Retired (soft-deleted) resources are invisible to every member: they are
/// not returned, not counted, and their names do not block a new resource.</description></item>
/// <item><description>Names arrive already trimmed. Comparing them case-insensitively is the
/// store's job (its collation), not the caller's.</description></item>
/// <item><description>Cancellation, and any unexpected store failure, propagate as exceptions.
/// Only the expected outcomes below are values.</description></item>
/// </list>
/// </remarks>
public interface IResourceRepository
{
    /// <summary>True when a non-retired resource already has this name (case-insensitive).</summary>
    Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken);

    /// <summary>
    /// Stores the resource and, on <see cref="AddResourceResult.Added"/>, assigns its
    /// database-generated <c>Id</c> to the SAME instance that was passed in: the caller returns
    /// that instance, and the API builds its <c>Location</c> header and body from it. Answers
    /// <see cref="AddResourceResult.DuplicateName"/> when the store itself refuses the name,
    /// which covers a concurrent insert that slipped past <see cref="NameExistsAsync"/>. A name
    /// held only by a retired resource is not a duplicate.
    /// </summary>
    Task<AddResourceResult> AddAsync(Resource resource, CancellationToken cancellationToken);

    /// <summary>The non-retired resource with this id, or null.</summary>
    Task<Resource?> GetByIdAsync(int id, CancellationToken cancellationToken);

    /// <summary>
    /// One page of non-retired resources, ordered by name (case-insensitive) then id. The caller
    /// has already validated the bounds (<paramref name="page"/> at least 1,
    /// <paramref name="pageSize"/> from 1 to 100) and the implementation trusts them. The offset
    /// MUST be computed in 64-bit arithmetic: an offset past the end, even beyond the int range,
    /// is an empty page with the true total, never an overflow or an exception.
    /// </summary>
    Task<ResourcePage> ListAsync(int page, int pageSize, CancellationToken cancellationToken);
}

public enum AddResourceResult
{
    Added,
    DuplicateName,
}

/// <summary>One page of results. <paramref name="TotalCount"/> counts all non-retired resources.</summary>
public sealed record ResourcePage(IReadOnlyList<Resource> Items, int Page, int PageSize, int TotalCount);
