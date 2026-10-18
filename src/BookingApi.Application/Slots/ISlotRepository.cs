using BookingApi.Domain;

namespace BookingApi.Application.Slots;

/// <summary>
/// The persistence port for time slots, implemented by Infrastructure (phase 3). The rules below
/// are part of the contract: the handlers rely on every one of them, and the implementation is
/// tested against them on real SQL Server.
/// </summary>
/// <remarks>
/// <list type="bullet">
/// <item><description>Retired (soft-deleted) slots are invisible to every member: they are not
/// returned, not counted, and they do not block a new slot (their interval is free again).</description></item>
/// <item><description>Overlap is judged per resource, among non-retired slots, on half-open
/// <c>[start, end)</c> intervals: <see cref="SlotInterval.Overlaps"/> is the one definition, and the
/// database enforces the same rule under concurrency (spec FR-004). Instants arrive as UTC values
/// that came from <see cref="TimeSlot.Create"/>; the port does not re-validate them.</description></item>
/// <item><description>The port does not check that the resource exists: the handlers do, through
/// <c>IResourceRepository</c>.</description></item>
/// <item><description>Cancellation, and any unexpected store failure, propagate as exceptions. Only
/// the expected outcomes below are values.</description></item>
/// </list>
/// </remarks>
public interface ISlotRepository
{
    /// <summary>True when a non-retired slot of this resource overlaps <c>[startUtc, endUtc)</c>.</summary>
    Task<bool> OverlapExistsAsync(int resourceId, DateTime startUtc, DateTime endUtc, CancellationToken cancellationToken);

    /// <summary>
    /// Stores the slot and, on <see cref="AddSlotResult.Added"/>, assigns its database-generated
    /// <c>Id</c> to the SAME instance that was passed in: the caller returns that instance, and the
    /// API builds its <c>Location</c> header and body from it. Answers
    /// <see cref="AddSlotResult.Overlaps"/> when the store itself refuses the interval, which covers
    /// a concurrent insert that slipped past <see cref="OverlapExistsAsync"/>; in that case nothing
    /// is stored and the instance keeps <c>Id</c> 0. If the resource is gone by the time of the insert
    /// (the foreign key refuses), that is an unexpected store failure and propagates as an exception:
    /// no resource can be retired or deleted in this feature, so it is not an expected outcome.
    /// </summary>
    Task<AddSlotResult> AddAsync(TimeSlot slot, CancellationToken cancellationToken);

    /// <summary>The non-retired slot with this id that belongs to this resource, or null.</summary>
    Task<TimeSlot?> GetAsync(int resourceId, int id, CancellationToken cancellationToken);

    /// <summary>
    /// One page of this resource's non-retired slots, ordered by start then id. The caller has
    /// already validated the bounds (<paramref name="page"/> at least 1, <paramref name="pageSize"/>
    /// from 1 to 100) and the implementation trusts them. The offset MUST be computed in 64-bit
    /// arithmetic: an offset past the end, even beyond the int range, is an empty page with the true
    /// total, never an overflow or an exception.
    /// </summary>
    Task<SlotPage> ListAsync(int resourceId, int page, int pageSize, CancellationToken cancellationToken);
}

public enum AddSlotResult
{
    Added,
    Overlaps,
}

/// <summary>One page of results. <paramref name="TotalCount"/> counts the resource's non-retired slots.</summary>
public sealed record SlotPage(IReadOnlyList<TimeSlot> Items, int Page, int PageSize, int TotalCount);
