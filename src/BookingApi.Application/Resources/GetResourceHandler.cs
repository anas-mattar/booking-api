namespace BookingApi.Application.Resources;

// Spec FR-004; contract: GET /resources/{id}.
public sealed class GetResourceHandler(IResourceRepository repository)
{
    public async Task<GetResourceOutcome> HandleAsync(int id, CancellationToken cancellationToken)
    {
        var resource = await repository.GetByIdAsync(id, cancellationToken);

        return resource is null ? new ResourceNotFound() : new ResourceFound(resource);
    }
}
