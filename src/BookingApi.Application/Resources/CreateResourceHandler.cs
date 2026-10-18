using BookingApi.Domain;

namespace BookingApi.Application.Resources;

public sealed record CreateResourceCommand(string? Name, string? Description);

// Spec FR-001, FR-002, FR-003, FR-008; contract: POST /resources.
public sealed class CreateResourceHandler(IResourceRepository repository, TimeProvider time)
{
    public async Task<CreateResourceOutcome> HandleAsync(CreateResourceCommand command, CancellationToken cancellationToken)
    {
        var created = Resource.Create(command.Name, command.Description, time.GetUtcNow());
        if (!created.IsSuccess)
        {
            return new ResourceInvalid(created.Errors);
        }

        var resource = created.Value!;

        // The check gives a clean answer in the common case; the store's own refusal below
        // covers the concurrent insert that slips past it (spec FR-002, SC-003).
        if (await repository.NameExistsAsync(resource.Name, cancellationToken))
        {
            return new ResourceNameTaken();
        }

        return await repository.AddAsync(resource, cancellationToken) switch
        {
            AddResourceResult.Added => new ResourceCreated(resource),
            AddResourceResult.DuplicateName => new ResourceNameTaken(),
            var other => throw new InvalidOperationException($"Unexpected add result '{other}'."),
        };
    }
}
