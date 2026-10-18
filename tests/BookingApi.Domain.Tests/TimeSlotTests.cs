namespace BookingApi.Domain.Tests;

// Rules: specs/003-time-slots/spec.md FR-002, FR-003, FR-008, FR-010 (invariant 2: UTC, start < end);
// contract: specs/003-time-slots/contracts/slots-api.md.
public class TimeSlotTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 19, 12, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset Nine = new(2026, 11, 2, 9, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset Ten = new(2026, 11, 2, 10, 0, 0, TimeSpan.Zero);

    private static CreateTimeSlotResult Create(DateTimeOffset start, DateTimeOffset end, int resourceId = 7)
        => TimeSlot.Create(resourceId, start, end, Now);

    [Fact]
    public void AValidSlotCarriesItsResourceAndItsInstantsInUtc()
    {
        var result = Create(Nine, Ten);

        Assert.True(result.IsSuccess);
        Assert.Empty(result.Errors);
        var slot = result.Value!;
        Assert.Equal(7, slot.ResourceId);
        Assert.Equal(new DateTime(2026, 11, 2, 9, 0, 0), slot.StartUtc);
        Assert.Equal(new DateTime(2026, 11, 2, 10, 0, 0), slot.EndUtc);
        Assert.Equal(DateTimeKind.Utc, slot.StartUtc.Kind);
        Assert.Equal(DateTimeKind.Utc, slot.EndUtc.Kind);
    }

    [Fact]
    public void AnOffsetInstantIsStoredAsUtc()
    {
        // 11:00+02:00 is 09:00Z; 12:00+02:00 is 10:00Z (hand-worked).
        var plusTwo = TimeSpan.FromHours(2);

        var slot = Create(new DateTimeOffset(2026, 11, 2, 11, 0, 0, plusTwo), new DateTimeOffset(2026, 11, 2, 12, 0, 0, plusTwo)).Value!;

        Assert.Equal(new DateTime(2026, 11, 2, 9, 0, 0), slot.StartUtc);
        Assert.Equal(new DateTime(2026, 11, 2, 10, 0, 0), slot.EndUtc);
        Assert.Equal(DateTimeKind.Utc, slot.StartUtc.Kind);
    }

    [Fact]
    public void OneTickAfterTheStartIsAValidEnd()
    {
        Assert.True(Create(Nine, Nine.AddTicks(1)).IsSuccess);
    }

    [Theory]
    [InlineData(0)]            // end equal to start: an empty interval
    [InlineData(-1)]           // one tick before
    [InlineData(-36_000_000_000)] // one hour before (ticks)
    public void AnEndThatIsNotAfterTheStartIsRefusedWithOneEndError(long endOffsetTicks)
    {
        var result = Create(Nine, Nine.AddTicks(endOffsetTicks));

        Assert.False(result.IsSuccess);
        Assert.Null(result.Value);
        var error = Assert.Single(result.Errors);
        Assert.Equal("endUtc", error.Field);
        Assert.False(string.IsNullOrWhiteSpace(error.Message));
    }

    [Fact]
    public void TheOffsetIsNormalizedBeforeTheComparison()
    {
        var plusTwo = TimeSpan.FromHours(2);
        var start = Nine;                                                       // 09:00Z

        // 11:30+02:00 is 09:30Z: after the start, so valid even though 11:30 > 09:00 only by text.
        Assert.True(Create(start, new DateTimeOffset(2026, 11, 2, 11, 30, 0, plusTwo)).IsSuccess);

        // 10:30+02:00 is 08:30Z: before the start, although 10:30 looks later than 09:00.
        var result = Create(start, new DateTimeOffset(2026, 11, 2, 10, 30, 0, plusTwo));
        Assert.False(result.IsSuccess);
        Assert.Equal("endUtc", Assert.Single(result.Errors).Field);
    }

    [Fact]
    public void AFailedResultCannotBeMutatedThroughItsErrorList()
    {
        var result = Create(Ten, Nine);

        var errors = Assert.IsAssignableFrom<IReadOnlyList<ValidationError>>(result.Errors);
        Assert.Throws<NotSupportedException>(() => ((IList<ValidationError>)errors).Add(new ValidationError("x", "y")));
    }

    [Fact]
    public void AValidSlotRecordsTheCreationInstantAndTheAnonymousUser()
    {
        var slot = Create(Nine, Ten).Value!;

        Assert.Equal(Now.UtcDateTime, slot.CreatedAtUtc);
        Assert.Equal(Now.UtcDateTime, slot.UpdatedAtUtc);
        Assert.Equal("anonymous", slot.CreatedBy);
        Assert.Equal("anonymous", slot.UpdatedBy);
    }

    [Fact]
    public void ANewSlotIsNotRetired()
    {
        var slot = Create(Nine, Ten).Value!;

        Assert.False(slot.IsDeleted);
        Assert.Null(slot.DeletedAtUtc);
        Assert.Null(slot.DeletedBy);
    }

    [Fact]
    public void ASlotOverlapsAnIntervalExactlyWhenThePredicateSaysSo()
    {
        var slot = Create(Nine, Ten).Value!;

        Assert.True(slot.Overlaps(Nine.UtcDateTime.AddMinutes(30), Ten.UtcDateTime.AddMinutes(30)));
        Assert.False(slot.Overlaps(Ten.UtcDateTime, Ten.UtcDateTime.AddHours(1)));
    }
}
