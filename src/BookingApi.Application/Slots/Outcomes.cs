using BookingApi.Domain;

namespace BookingApi.Application.Slots;

// Every expected outcome is a value, never an exception. One base per use case; the "resource not
// found" outcome has its own type under each base (a record has a single base type).

public abstract record OpenSlotOutcome;

public sealed record SlotOpened(TimeSlot Slot) : OpenSlotOutcome;

public sealed record SlotInvalid(IReadOnlyList<ValidationError> Errors) : OpenSlotOutcome;

public sealed record SlotOverlaps : OpenSlotOutcome;

public sealed record OpenSlotResourceNotFound : OpenSlotOutcome;

public abstract record GetSlotOutcome;

public sealed record SlotFound(TimeSlot Slot) : GetSlotOutcome;

public sealed record SlotNotFound : GetSlotOutcome;

public sealed record GetSlotResourceNotFound : GetSlotOutcome;

public abstract record ListSlotsOutcome;

public sealed record SlotsListed(SlotPage Page) : ListSlotsOutcome;

public sealed record ListSlotsInvalid(IReadOnlyList<ValidationError> Errors) : ListSlotsOutcome;

public sealed record ListSlotsResourceNotFound : ListSlotsOutcome;
