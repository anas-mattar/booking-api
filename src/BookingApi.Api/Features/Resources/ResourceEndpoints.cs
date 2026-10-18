using System.Globalization;
using BookingApi.Application.Resources;
using BookingApi.Domain;

namespace BookingApi.Api.Features.Resources;

// Contract: specs/002-resource-catalog/contracts/resources-api.md. Every use-case outcome is
// mapped explicitly; the fall-through arm throws, so a new outcome type is a failing test and
// a 500, never a silent 200 (phase 2 review F4).
public static class ResourceEndpoints
{
    public const string BasePath = "/resources";

    public static IEndpointRouteBuilder MapResources(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup(BasePath).WithTags("Resources");

        group.MapPost("/", CreateAsync).WithName("CreateResource");
        group.MapGet("/{id:int}", GetAsync).WithName("GetResource");
        group.MapGet("/", ListAsync).WithName("ListResources");

        return endpoints;
    }

    private static async Task<IResult> CreateAsync(
        CreateResourceRequest request, CreateResourceHandler handler, CancellationToken cancellationToken)
    {
        var outcome = await handler.HandleAsync(new CreateResourceCommand(request.Name, request.Description), cancellationToken);

        return outcome switch
        {
            ResourceCreated created => Results.Created($"{BasePath}/{created.Resource.Id}", ResourceResponse.From(created.Resource)),
            ResourceInvalid invalid => ValidationProblem(invalid.Errors),
            ResourceNameTaken => Results.Problem(
                title: "Resource name already in use",
                detail: "A resource with this name already exists.",
                statusCode: StatusCodes.Status409Conflict),
            _ => throw Unmapped(outcome),
        };
    }

    private static async Task<IResult> GetAsync(int id, GetResourceHandler handler, CancellationToken cancellationToken)
    {
        var outcome = await handler.HandleAsync(id, cancellationToken);

        return outcome switch
        {
            ResourceFound found => Results.Ok(ResourceResponse.From(found.Resource)),
            ResourceNotFound => Results.Problem(
                title: "Resource not found",
                detail: "No resource has this id.",
                statusCode: StatusCodes.Status404NotFound),
            _ => throw Unmapped(outcome),
        };
    }

    // page and pageSize arrive as text so that a non-numeric value is a 400 that names the
    // parameter, like an out-of-range one, instead of the framework's generic binding failure.
    private static async Task<IResult> ListAsync(
        string? page, string? pageSize, ListResourcesHandler handler, CancellationToken cancellationToken)
    {
        var errors = new List<ValidationError>();
        var parsedPage = ParseWholeNumber(page, ListResourcesHandler.PageField, errors);
        var parsedPageSize = ParseWholeNumber(pageSize, ListResourcesHandler.PageSizeField, errors);

        if (errors.Count > 0)
        {
            // Still ask the handler about the half that parsed, so one response names every bad parameter.
            if (await handler.HandleAsync(parsedPage ?? 1, parsedPageSize ?? 1, cancellationToken) is ListResourcesInvalid invalid)
            {
                errors.AddRange(invalid.Errors.Where(e => errors.All(known => known.Field != e.Field)));
            }

            return ValidationProblem(errors);
        }

        var outcome = await handler.HandleAsync(parsedPage, parsedPageSize, cancellationToken);

        return outcome switch
        {
            ResourcesListed listed => Results.Ok(new ResourcePageResponse(
                listed.Page.Items.Select(ResourceResponse.From).ToList(),
                listed.Page.Page,
                listed.Page.PageSize,
                listed.Page.TotalCount)),
            ListResourcesInvalid invalid => ValidationProblem(invalid.Errors),
            _ => throw Unmapped(outcome),
        };
    }

    // An absent parameter is the default; a present one must be a whole number that fits an int.
    private static int? ParseWholeNumber(string? text, string field, List<ValidationError> errors)
    {
        if (text is null)
        {
            return null;
        }

        if (int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var value))
        {
            return value;
        }

        errors.Add(new ValidationError(field, $"{field} must be a whole number."));
        return null;
    }

    private static IResult ValidationProblem(IEnumerable<ValidationError> errors) => Results.ValidationProblem(
        errors.GroupBy(e => e.Field).ToDictionary(g => g.Key, g => g.Select(e => e.Message).ToArray()));

    private static InvalidOperationException Unmapped(object outcome) =>
        new($"Unmapped outcome '{outcome.GetType().Name}'.");
}
