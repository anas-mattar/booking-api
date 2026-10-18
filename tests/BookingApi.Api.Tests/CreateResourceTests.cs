using System.Net;
using BookingApi.TestSupport;

namespace BookingApi.Api.Tests;

// Contract: POST /resources.
[Collection(SqlServerCollection.Name)]
public class CreateResourceTests(SqlServerFixture sql) : ResourceApiTest(sql)
{
    [Fact]
    public async Task CreatesAndReturnsTheStoredResourceWithALocation()
    {
        var response = await PostAsync("  Room A  ", "Ground floor");

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await JsonAsync(response);
        var id = body.GetProperty("id").GetInt32();
        Assert.Equal($"/resources/{id}", response.Headers.Location?.ToString());
        Assert.Equal("Room A", body.GetProperty("name").GetString());
        Assert.Equal("Ground floor", body.GetProperty("description").GetString());
        Assert.EndsWith("Z", body.GetProperty("createdAtUtc").GetString());
        Assert.EndsWith("Z", body.GetProperty("updatedAtUtc").GetString());
        Assert.False(body.TryGetProperty("isDeleted", out _));
        Assert.False(body.TryGetProperty("createdBy", out _));

        var fetched = await Client.GetAsync(response.Headers.Location);
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal(body.ToString(), (await JsonAsync(fetched)).ToString());
    }

    [Fact]
    public async Task AnAbsentOrNullDescriptionIsNull()
    {
        var absent = await PostRawAsync("""{"name":"A"}""");
        var explicitNull = await PostRawAsync("""{"name":"B","description":null}""");

        Assert.Equal(HttpStatusCode.Created, absent.StatusCode);
        Assert.Equal(HttpStatusCode.Created, explicitNull.StatusCode);
        Assert.Equal(System.Text.Json.JsonValueKind.Null, (await JsonAsync(absent)).GetProperty("description").ValueKind);
        Assert.Equal(System.Text.Json.JsonValueKind.Null, (await JsonAsync(explicitNull)).GetProperty("description").ValueKind);
    }

    [Theory]
    [InlineData("room a")]
    [InlineData("  Room A  ")]
    public async Task ADuplicateByCaseOrSurroundingWhitespaceIsRefusedWith409(string name)
    {
        await PostAsync("Room A");

        var response = await PostAsync(name);

        AssertProblem(response, HttpStatusCode.Conflict);
        Assert.Equal("Resource name already in use", (await JsonAsync(response)).GetProperty("title").GetString());
    }

    [Theory]
    [InlineData("""{"description":"x"}""", "name")]
    [InlineData("""{"name":null}""", "name")]
    [InlineData("""{"name":"   "}""", "name")]
    [InlineData("""{"name":""}""", "name")]
    public async Task AMissingOrBlankNameIs400NamingTheField(string body, string field)
    {
        var response = await PostRawAsync(body);

        AssertProblem(response, HttpStatusCode.BadRequest);
        Assert.True((await JsonAsync(response)).GetProperty("errors").TryGetProperty(field, out _));
    }

    [Fact]
    public async Task ATooLongNameAndATooLongDescriptionAreBothReported()
    {
        var response = await PostAsync(new string('a', 101), new string('b', 501));

        AssertProblem(response, HttpStatusCode.BadRequest);
        var errors = (await JsonAsync(response)).GetProperty("errors");
        Assert.True(errors.TryGetProperty("name", out _));
        Assert.True(errors.TryGetProperty("description", out _));
    }

    [Fact]
    public async Task TheLimitsThemselvesAreAccepted()
    {
        var response = await PostAsync(new string('a', 100), new string('b', 500));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("{ not json")]
    [InlineData("null")]
    [InlineData("""{"name":123}""")]
    [InlineData("""{"name":"A","description":[1]}""")]
    [InlineData("[]")]
    public async Task AnEmptyMalformedOrWronglyTypedBodyIs400ProblemDetails(string body)
    {
        var response = await PostRawAsync(body);

        AssertProblem(response, HttpStatusCode.BadRequest);
    }

    [Theory]
    [InlineData("{ not json")]
    [InlineData("""{"name":123}""")]
    [InlineData("")]
    public async Task ABadBodyIsAlso400ProblemDetailsInDevelopment(string body)
    {
        // Development makes minimal APIs throw on a bad request; the answer must not differ.
        using var factory = await ResourceApiFactory.CreateAsync(Sql, "Development");
        using var client = factory.CreateClient();

        var response = await client.PostAsync("/resources", new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        AssertProblem(response, HttpStatusCode.BadRequest);
    }
}
