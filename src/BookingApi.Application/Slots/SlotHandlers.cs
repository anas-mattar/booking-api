using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Application.Slots;

public sealed record OpenSlotCommand(int ResourceId, DateTimeOffset Start, DateTimeOffset End);

// Spec FR-001, FR-003, FR-004, FR-005; contract: POST /resources/{resourceId}/slots.
public sealed class OpenSlotHandler(ISlotRepository slots, IResourceRepository resources, TimeProvider time)
{
    public async Task<OpenSlotOutcome> HandleAsync(OpenSlotCommand command, CancellationToken cancellationToken)
    {
        // The resource comes first: a slot cannot exist without a non-retired resource (FR-005).
        if (await resources.GetByIdAsync(command.ResourceId, cancellationToken) is null)
        {
            return new OpenSlotResourceNotFound();
        }

        var created = TimeSlot.Create(command.ResourceId, command.Start, command.End, time.GetUtcNow());
        if (!created.IsSuccess)
        {
            return new SlotInvalid(created.Errors);
        }

        var slot = created.Value!;

        // The check gives a clean answer in the common case; the store's own refusal below (the
        // database trigger) covers the concurrent insert that slips past it (FR-004, SC-003).
        if (await slots.OverlapExistsAsync(slot.ResourceId, slot.StartUtc, slot.EndUtc, cancellationToken))
        {
            return new SlotOverlaps();
        }

        return await slots.AddAsync(slot, cancellationToken) switch
        {
            AddSlotResult.Added => new SlotOpened(slot),
            AddSlotResult.Overlaps => new SlotOverlaps(),
            var other => throw new InvalidOperationException($"Unexpected add result '{other}'."),
        };
    }
}

// Spec FR-006; contract: GET /resources/{resourceId}/slots/{id}.
public sealed class GetSlotHandler(ISlotRepository slots, IResourceRepository resources)
{
    public async Task<GetSlotOutcome> HandleAsync(int resourceId, int id, CancellationToken cancellationToken)
    {
        if (await resources.GetByIdAsync(resourceId, cancellationToken) is null)
        {
            return new GetSlotResourceNotFound();
        }

        var slot = await slots.GetAsync(resourceId, id, cancellationToken);

        return slot is null ? new SlotNotFound() : new SlotFound(slot);
    }
}

// Spec FR-007; contract: GET /resources/{resourceId}/slots. The paging rules are the ones of
// GET /resources, so the bounds and field names are reused, not restated.
public sealed class ListSlotsHandler(ISlotRepository slots, IResourceRepository resources)
{
    public async Task<ListSlotsOutcome> HandleAsync(int resourceId, int? page, int? pageSize, CancellationToken cancellationToken)
    {
        if (await resources.GetByIdAsync(resourceId, cancellationToken) is null)
        {
            return new ListSlotsResourceNotFound();
        }

        var effectivePage = page ?? ListResourcesHandler.DefaultPage;
        var effectivePageSize = pageSize ?? ListResourcesHandler.DefaultPageSize;

        var errors = new List<ValidationError>();
        if (effectivePage < 1)
        {
            errors.Add(new ValidationError(ListResourcesHandler.PageField, "Page must be at least 1."));
        }

        if (effectivePageSize is < 1 or > ListResourcesHandler.MaxPageSize)
        {
            errors.Add(new ValidationError(
                ListResourcesHandler.PageSizeField, $"Page size must be between 1 and {ListResourcesHandler.MaxPageSize}."));
        }

        if (errors.Count > 0)
        {
            return new ListSlotsInvalid(errors);
        }

        return new SlotsListed(await slots.ListAsync(resourceId, effectivePage, effectivePageSize, cancellationToken));
    }
}
