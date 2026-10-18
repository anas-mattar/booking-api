using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace BookingApi.Api.Health;

// Health-check endpoints carry no method metadata, so the generated OpenAPI document omits
// them. This transformer documents /health, per the contract in
// specs/001-solution-scaffold/contracts/http-baseline.md.
public static class HealthOpenApi
{
    public static OpenApiOptions AddHealthDocumentation(this OpenApiOptions options)
    {
        options.AddDocumentTransformer((document, _, _) =>
        {
            document.Paths ??= [];
            document.Paths["/health"] = new OpenApiPathItem
            {
                Operations = new Dictionary<HttpMethod, OpenApiOperation>
                {
                    [HttpMethod.Get] = new OpenApiOperation
                    {
                        Summary = "Liveness",
                        Description = "Healthy whenever the process is serving requests; never consults the database.",
                        Responses = new OpenApiResponses
                        {
                            ["200"] = new OpenApiResponse { Description = "Healthy" },
                        },
                    },
                },
            };
            return Task.CompletedTask;
        });
        return options;
    }
}
