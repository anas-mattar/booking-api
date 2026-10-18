namespace BookingApi.Domain.Tests;

// Rule: specs/003-time-slots/spec.md FR-004 and data-model.md "Half-open overlap": intervals are
// [start, end); two overlap exactly when a.Start < b.End AND b.Start < a.End. Every expected value
// below was worked by hand against A = [09:00, 10:00) on one day.
public class SlotIntervalTests
{
    private static DateTime At(int hour, int minute = 0) => new(2026, 11, 2, hour, minute, 0, DateTimeKind.Utc);

    private static readonly DateTime A1 = At(9);
    private static readonly DateTime A2 = At(10);

    public static TheoryData<string, DateTime, DateTime, bool> BoundaryCases() => new()
    {
        // name, B start, B end, A and B overlap?
        { "touching after: B starts where A ends", At(10), At(11), false },
        { "touching before: B ends where A starts", At(8), At(9), false },
        { "identical", At(9), At(10), true },
        { "B inside A", At(9, 15), At(9, 45), true },
        { "B contains A", At(8), At(11), true },
        { "B starts inside A, ends after", At(9, 30), At(10, 30), true },
        { "B starts before A, ends inside", At(8, 30), At(9, 30), true },
        { "disjoint, later", At(11), At(12), false },
        { "disjoint, earlier", At(7), At(8), false },
        { "one-tick overlap at the end of A", A2.AddTicks(-1), At(11), true },
        { "one-tick gap after A", A2.AddTicks(1), At(11), false },
        { "one-tick overlap at the start of A", At(8), A1.AddTicks(1), true },
        { "one-tick gap before A", At(8), A1.AddTicks(-1), false },
        { "B shares only A's start instant, ends later", A1, At(9, 30), true },
        { "B shares only A's end instant, starts earlier", At(9, 30), A2, true },
    };

    [Theory]
    [MemberData(nameof(BoundaryCases))]
    public void TheHandWorkedBoundaryTable(string name, DateTime bStart, DateTime bEnd, bool expected)
    {
        Assert.True(expected == SlotInterval.Overlaps(A1, A2, bStart, bEnd), name);
    }

    [Theory]
    [MemberData(nameof(BoundaryCases))]
    public void TheAnswerIsTheSameWhenTheTwoIntervalsAreSwapped(string name, DateTime bStart, DateTime bEnd, bool expected)
    {
        Assert.True(expected == SlotInterval.Overlaps(bStart, bEnd, A1, A2), name);
    }
}
