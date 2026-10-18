namespace BookingApi.Domain;

// Rules: specs/003-time-slots/spec.md FR-002, FR-003, FR-004, FR-008, FR-010; data-model.md;
// invariant 2 of docs/domain/booking-invariants.md (every instant UTC; start < end for a slot);
// contract: specs/003-time-slots/contracts/slots-api.md (field names).

/// <summary>
/// The outcome of <see cref="TimeSlot.Create"/>: exactly one of a slot or at least one field error.
/// Only the factory can build one, so the impossible states (both, or neither) cannot be expressed.
/// </summary>
public sealed class CreateTimeSlotResult
{
    private CreateTimeSlotResult(TimeSlot? value, IReadOnlyList<ValidationError> errors)
    {
        Value = value;
        Errors = errors;
    }

    public TimeSlot? Value { get; }

    public IReadOnlyList<ValidationError> Errors { get; }

    public bool IsSuccess => Value is not null;

    internal static CreateTimeSlotResult Success(TimeSlot value) => new(value, []);

    // A copy, wrapped read-only: a caller cannot mutate the list it was handed.
    internal static CreateTimeSlotResult Failure(IEnumerable<ValidationError> errors)
        => new(null, Array.AsReadOnly(errors.ToArray()));
}

/// <summary>
/// The one definition of "two slots overlap". Intervals are half-open, <c>[start, end)</c>: a slot
/// ending at 10:00 and one starting at 10:00 do not overlap. The Application check, the tests and
/// (as SQL) the database trigger all state this same rule.
/// </summary>
public static class SlotInterval
{
    public static bool Overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd)
        => aStart < bEnd && bStart < aEnd;
}

/// <summary>
/// One interval during which a resource may be booked. Can only be created valid; never edited or
/// retired by this code. Instants are UTC (invariant 2).
/// </summary>
public sealed class TimeSlot
{
    /// <summary>Recorded as creator and updater until an identity exists (spec FR-009).</summary>
    public const string AnonymousUser = "anonymous";

    public const string StartField = "startUtc";
    public const string EndField = "endUtc";

    // Set by EF Core when the row is read; this code never sets the retirement marker.
    public int Id { get; private set; }

    public int ResourceId { get; private set; }

    public DateTime StartUtc { get; private set; }

    public DateTime EndUtc { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public string CreatedBy { get; private set; } = "";

    public DateTime UpdatedAtUtc { get; private set; }

    public string UpdatedBy { get; private set; } = "";

    public bool IsDeleted { get; private set; }

    public DateTime? DeletedAtUtc { get; private set; }

    public string? DeletedBy { get; private set; }

    private TimeSlot()
    {
    }

    /// <summary>
    /// Creates a slot on a resource. Both instants are converted to UTC first, then the end must be
    /// strictly after the start (invariant 2); otherwise one error names <see cref="EndField"/>.
    /// Existence of the resource and non-overlap with other slots are not this type's concern: they
    /// need the store (Application checks them, the database guarantees them).
    /// </summary>
    public static CreateTimeSlotResult Create(int resourceId, DateTimeOffset start, DateTimeOffset end, DateTimeOffset now)
    {
        var startUtc = start.UtcDateTime;
        var endUtc = end.UtcDateTime;

        if (endUtc <= startUtc)
        {
            return CreateTimeSlotResult.Failure([new ValidationError(EndField, "End must be after start.")]);
        }

        var nowUtc = now.UtcDateTime;
        return CreateTimeSlotResult.Success(new TimeSlot
        {
            ResourceId = resourceId,
            StartUtc = startUtc,
            EndUtc = endUtc,
            CreatedAtUtc = nowUtc,
            CreatedBy = AnonymousUser,
            UpdatedAtUtc = nowUtc,
            UpdatedBy = AnonymousUser,
        });
    }

    /// <summary>True when this slot overlaps the half-open interval <c>[start, end)</c>.</summary>
    public bool Overlaps(DateTime start, DateTime end) => SlotInterval.Overlaps(StartUtc, EndUtc, start, end);
}
