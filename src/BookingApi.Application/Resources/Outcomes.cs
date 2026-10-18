using BookingApi.Domain;

namespace BookingApi.Application.Resources;

// Every expected outcome is a value, never an exception.

public abstract record CreateResourceOutcome;

public sealed record ResourceCreated(Resource Resource) : CreateResourceOutcome;

public sealed record ResourceInvalid(IReadOnlyList<ValidationError> Errors) : CreateResourceOutcome;

public sealed record ResourceNameTaken : CreateResourceOutcome;

public abstract record GetResourceOutcome;

public sealed record ResourceFound(Resource Resource) : GetResourceOutcome;

public sealed record ResourceNotFound : GetResourceOutcome;

public abstract record ListResourcesOutcome;

public sealed record ResourcesListed(ResourcePage Page) : ListResourcesOutcome;

public sealed record ListResourcesInvalid(IReadOnlyList<ValidationError> Errors) : ListResourcesOutcome;
