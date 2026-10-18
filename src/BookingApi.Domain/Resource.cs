namespace BookingApi.Domain;

// Rules: specs/002-resource-catalog/spec.md FR-001, FR-008, FR-009; data-model.md.

/// <summary>One invalid input field. <see cref="Field"/> uses the API contract's field names.</summary>
public sealed record ValidationError(string Field, string Message);

/// <summary>The outcome of <see cref="Resource.Create"/>: the resource, or the field errors.</summary>
public sealed class CreateResourceResult
{
    public Resource? Value { get; init; }

    public IReadOnlyList<ValidationError> Errors { get; init; } = [];

    public bool IsSuccess => Errors.Count == 0;
}

/// <summary>A bookable thing. Can only be created valid; never edited or retired by this code.</summary>
public sealed class Resource
{
    public const int MaxNameLength = 100;
    public const int MaxDescriptionLength = 500;

    /// <summary>Recorded as creator and updater until an identity exists (spec FR-008).</summary>
    public const string AnonymousUser = "anonymous";

    public const string NameField = "name";
    public const string DescriptionField = "description";

    // Set by EF Core when the row is read; this code never sets the retirement marker.
    public int Id { get; private set; }

    public string Name { get; private set; } = "";

    public string? Description { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public string CreatedBy { get; private set; } = "";

    public DateTime UpdatedAtUtc { get; private set; }

    public string UpdatedBy { get; private set; } = "";

    public bool IsDeleted { get; private set; }

    public DateTime? DeletedAtUtc { get; private set; }

    public string? DeletedBy { get; private set; }

    private Resource()
    {
    }

    /// <summary>
    /// Creates a resource from raw input. The name is trimmed and then must be 1 to
    /// <see cref="MaxNameLength"/> characters; the description is kept as given and must be at
    /// most <see cref="MaxDescriptionLength"/> characters. Lengths are UTF-16 code units, which
    /// is what the database's nvarchar columns count. All invalid fields are reported together.
    /// </summary>
    public static CreateResourceResult Create(string? name, string? description, DateTimeOffset now)
    {
        var errors = new List<ValidationError>();

        var trimmed = name?.Trim() ?? "";
        if (trimmed.Length == 0)
        {
            errors.Add(new ValidationError(NameField, "Name is required."));
        }
        else if (trimmed.Length > MaxNameLength)
        {
            errors.Add(new ValidationError(NameField, $"Name must be at most {MaxNameLength} characters."));
        }

        if (description is { Length: > MaxDescriptionLength })
        {
            errors.Add(new ValidationError(DescriptionField, $"Description must be at most {MaxDescriptionLength} characters."));
        }

        if (errors.Count > 0)
        {
            return new CreateResourceResult { Errors = errors };
        }

        var nowUtc = now.UtcDateTime;
        return new CreateResourceResult
        {
            Value = new Resource
            {
                Name = trimmed,
                Description = description,
                CreatedAtUtc = nowUtc,
                CreatedBy = AnonymousUser,
                UpdatedAtUtc = nowUtc,
                UpdatedBy = AnonymousUser,
            },
        };
    }
}
