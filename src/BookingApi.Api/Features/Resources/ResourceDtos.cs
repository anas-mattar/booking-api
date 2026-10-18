using BookingApi.Domain;

namespace BookingApi.Api.Features.Resources;

// Contract: specs/002-resource-catalog/contracts/resources-api.md ("The Resource representation").
// Retirement state and the audit user columns are deliberately not exposed.

public sealed record CreateResourceRequest(string? Name, string? Description);

public sealed record ResourceResponse(int Id, string Name, string? Description, DateTime CreatedAtUtc, DateTime UpdatedAtUtc)
{
    public static ResourceResponse From(Resource resource) => new(
        resource.Id, resource.Name, resource.Description, resource.CreatedAtUtc, resource.UpdatedAtUtc);
}

public sealed record ResourcePageResponse(IReadOnlyList<ResourceResponse> Items, int Page, int PageSize, int TotalCount);
