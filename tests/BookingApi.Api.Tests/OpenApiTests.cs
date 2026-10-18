namespace BookingApi.Api.Tests;

// Spec US4 / FR-007: the OpenAPI document is served in Development only.
public class OpenApiTests
{
    [Fact]
    public async Task DevelopmentServesTheDocumentAndListsHealth()
    {
        using var factory = new ApiFactory("Development");
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");

        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("\"/health\"", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task DevelopmentListsTheResourceEndpoints()
    {
        using var factory = new ApiFactory("Development");
        using var client = factory.CreateClient();

        var text = await client.GetStringAsync("/openapi/v1.json");

        Assert.Contains("\"/resources\"", text);
        Assert.Contains("\"/resources/{id}\"", text);
    }

    [Fact]
    public async Task ProductionDoesNotServeTheDocument()
    {
        using var factory = new ApiFactory("Production");
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/openapi/v1.json");

        Assert.Equal(System.Net.HttpStatusCode.NotFound, response.StatusCode);
    }
}
