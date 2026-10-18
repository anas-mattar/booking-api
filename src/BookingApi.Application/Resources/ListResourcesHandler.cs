using BookingApi.Domain;

namespace BookingApi.Application.Resources;

// Spec FR-005; contract: GET /resources.
public sealed class ListResourcesHandler(IResourceRepository repository)
{
    public const int DefaultPage = 1;
    public const int DefaultPageSize = 50;
    public const int MaxPageSize = 100;

    public const string PageField = "page";
    public const string PageSizeField = "pageSize";

    public async Task<ListResourcesOutcome> HandleAsync(int? page, int? pageSize, CancellationToken cancellationToken)
    {
        var effectivePage = page ?? DefaultPage;
        var effectivePageSize = pageSize ?? DefaultPageSize;

        var errors = new List<ValidationError>();
        if (effectivePage < 1)
        {
            errors.Add(new ValidationError(PageField, "Page must be at least 1."));
        }

        if (effectivePageSize is < 1 or > MaxPageSize)
        {
            errors.Add(new ValidationError(PageSizeField, $"Page size must be between 1 and {MaxPageSize}."));
        }

        if (errors.Count > 0)
        {
            return new ListResourcesInvalid(errors);
        }

        return new ResourcesListed(await repository.ListAsync(effectivePage, effectivePageSize, cancellationToken));
    }
}
