using System.Net;
using BookingApi.TestSupport;

namespace BookingApi.Api.Tests;

// Contract: GET /resources/{id}.
[Collection(SqlServerCollection.Name)]
public class GetResourceTests(SqlServerFixture sql) : ResourceApiTest(sql)
{
    [Fact]
    public async Task AnExistingResourceIs200()
    {
        var created = await JsonAsync(await PostAsync("Room A", "Ground floor"));
        var id = created.GetProperty("id").GetInt32();

        var response = await Client.GetAsync($"/resources/{id}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal(created.ToString(), (await JsonAsync(response)).ToString());
    }

    [Fact]
    public async Task AnUnknownIdIs404ProblemDetails() =>
        AssertProblem(await Client.GetAsync("/resources/424242"), HttpStatusCode.NotFound);

    [Fact]
    public async Task ARetiredIdIs404ProblemDetails()
    {
        var id = (await JsonAsync(await PostAsync("Room A"))).GetProperty("id").GetInt32();
        await Factory.ExecuteSqlAsync($"UPDATE Resources SET IsDeleted = 1, DeletedAtUtc = SYSUTCDATETIME(), DeletedBy = 'test' WHERE Id = {id}");

        AssertProblem(await Client.GetAsync($"/resources/{id}"), HttpStatusCode.NotFound);
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("1.5")]
    [InlineData("99999999999")]
    public async Task ANonNumericIdIs404ProblemDetails(string id) =>
        AssertProblem(await Client.GetAsync($"/resources/{id}"), HttpStatusCode.NotFound);
}
