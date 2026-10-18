namespace BookingApi.Domain.Tests;

// Rules: specs/002-resource-catalog/spec.md FR-001, FR-008, FR-009; data-model.md;
// contract: specs/002-resource-catalog/contracts/resources-api.md.
public class ResourceTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 18, 12, 0, 0, TimeSpan.Zero);

    private static CreateResourceResult Create(string? name, string? description = null)
        => Resource.Create(name, description, Now);

    [Theory]
    [InlineData(" Room A ")]   // no-break space
    [InlineData("　Room A　")]   // ideographic space
    [InlineData("\t\nRoom A\r\n")]       // control whitespace
    public void CreateTrimsEveryKindOfUnicodeWhitespaceFromTheName(string name)
    {
        var result = Create(name);

        Assert.True(result.IsSuccess);
        Assert.Equal("Room A", result.Value!.Name);
    }

    [Fact]
    public void ASuccessfulResultCarriesAValueAndNoErrors()
    {
        var result = Create("Room A");

        Assert.True(result.IsSuccess);
        Assert.NotNull(result.Value);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void AFailedResultCannotBeMutatedThroughItsErrorList()
    {
        var result = Create("   ");

        var errors = Assert.IsAssignableFrom<IReadOnlyList<ValidationError>>(result.Errors);
        Assert.Throws<NotSupportedException>(() => ((IList<ValidationError>)errors).Add(new ValidationError("x", "y")));
        Assert.Single(result.Errors);
    }
    [Fact]
    public void CreateTrimsTheName()
    {
        var result = Create("  Room A \t");

        Assert.True(result.IsSuccess);
        Assert.Equal("Room A", result.Value!.Name);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(100)]
    public void CreateAcceptsNamesAtTheLengthLimits(int length)
    {
        var result = Create(new string('n', length));

        Assert.True(result.IsSuccess);
        Assert.Equal(length, result.Value!.Name.Length);
    }

    [Fact]
    public void CreateMeasuresTheNameAfterTrimming()
    {
        var result = Create("  " + new string('n', 100) + "  ");

        Assert.True(result.IsSuccess);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\t\n")]
    public void CreateRejectsAMissingOrBlankName(string? name)
    {
        var result = Create(name);

        Assert.False(result.IsSuccess);
        Assert.Null(result.Value);
        Assert.Equal("name", Assert.Single(result.Errors).Field);
    }

    [Fact]
    public void CreateRejectsANameOver100Characters()
    {
        var result = Create(new string('n', 101));

        Assert.False(result.IsSuccess);
        Assert.Null(result.Value);
        Assert.Equal("name", Assert.Single(result.Errors).Field);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("Ground floor, seats 8")]
    [InlineData("   ")]
    [InlineData("")]
    public void CreateKeepsTheDescriptionAsGiven(string? description)
    {
        var result = Create("Room A", description);

        Assert.True(result.IsSuccess);
        Assert.Equal(description, result.Value!.Description);
    }

    [Fact]
    public void CreateAcceptsADescriptionOf500Characters()
    {
        var result = Create("Room A", new string('d', 500));

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public void CreateRejectsADescriptionOver500Characters()
    {
        var result = Create("Room A", new string('d', 501));

        Assert.False(result.IsSuccess);
        Assert.Null(result.Value);
        Assert.Equal("description", Assert.Single(result.Errors).Field);
    }

    [Fact]
    public void CreateReportsEveryInvalidFieldAtOnce()
    {
        var result = Create("   ", new string('d', 501));

        Assert.False(result.IsSuccess);
        Assert.Null(result.Value);
        Assert.Equal(["name", "description"], result.Errors.Select(e => e.Field).ToArray());
        Assert.All(result.Errors, e => Assert.False(string.IsNullOrWhiteSpace(e.Message)));
    }

    [Fact]
    public void CreateStampsBothInstantsAndBothUsers()
    {
        var resource = Create("Room A").Value!;

        Assert.Equal(Now.UtcDateTime, resource.CreatedAtUtc);
        Assert.Equal(Now.UtcDateTime, resource.UpdatedAtUtc);
        Assert.Equal(DateTimeKind.Utc, resource.CreatedAtUtc.Kind);
        Assert.Equal(DateTimeKind.Utc, resource.UpdatedAtUtc.Kind);
        Assert.Equal("anonymous", resource.CreatedBy);
        Assert.Equal("anonymous", resource.UpdatedBy);
    }

    [Fact]
    public void CreateConvertsAnOffsetInstantToUtc()
    {
        var local = new DateTimeOffset(2026, 10, 18, 15, 0, 0, TimeSpan.FromHours(3));

        var resource = Resource.Create("Room A", null, local).Value!;

        Assert.Equal(new DateTime(2026, 10, 18, 12, 0, 0, DateTimeKind.Utc), resource.CreatedAtUtc);
    }

    [Fact]
    public void ANewResourceIsNotRetired()
    {
        var resource = Create("Room A").Value!;

        Assert.False(resource.IsDeleted);
        Assert.Null(resource.DeletedAtUtc);
        Assert.Null(resource.DeletedBy);
    }
}
