using System.Net;
using BookingApi.TestSupport;

namespace BookingApi.Api.Tests;

// Contract: GET /resources.
[Collection(SqlServerCollection.Name)]
public class ListResourcesTests(SqlServerFixture sql) : ResourceApiTest(sql)
{
    [Fact]
    public async Task DefaultsAreFirstPageOfFifty()
    {
        await PostAsync("Room A");

        var response = await Client.GetAsync("/resources");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await JsonAsync(response);
        Assert.Equal(1, body.GetProperty("page").GetInt32());
        Assert.Equal(50, body.GetProperty("pageSize").GetInt32());
        Assert.Equal(1, body.GetProperty("totalCount").GetInt32());
        Assert.Single(body.GetProperty("items").EnumerateArray());
    }

    [Fact]
    public async Task OneHundredResourcesPageAsFiftyAndFiftyWithTheTotal()
    {
        for (var i = 0; i < 100; i++)
        {
            Assert.Equal(HttpStatusCode.Created, (await PostAsync($"Resource {i:D3}")).StatusCode);
        }

        var first = await JsonAsync(await Client.GetAsync("/resources?page=1&pageSize=50"));
        var second = await JsonAsync(await Client.GetAsync("/resources?page=2&pageSize=50"));

        Assert.Equal(100, first.GetProperty("totalCount").GetInt32());
        Assert.Equal(100, second.GetProperty("totalCount").GetInt32());
        var ids = first.GetProperty("items").EnumerateArray().Concat(second.GetProperty("items").EnumerateArray())
            .Select(i => i.GetProperty("id").GetInt32()).ToList();
        Assert.Equal(100, ids.Distinct().Count());
        Assert.Equal(50, first.GetProperty("items").GetArrayLength());
        Assert.Equal(50, second.GetProperty("items").GetArrayLength());
    }

    [Fact]
    public async Task APagePastTheEndIs200AndEmptyWithTheTrueTotal()
    {
        await PostAsync("Room A");

        var response = await Client.GetAsync("/resources?page=9&pageSize=50");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await JsonAsync(response);
        Assert.Equal(0, body.GetProperty("items").GetArrayLength());
        Assert.Equal(1, body.GetProperty("totalCount").GetInt32());
    }

    [Theory]
    [InlineData("page=abc", "page")]
    [InlineData("page=0", "page")]
    [InlineData("page=-1", "page")]
    [InlineData("page=1.5", "page")]
    [InlineData("page=99999999999", "page")]
    [InlineData("pageSize=abc", "pageSize")]
    [InlineData("pageSize=0", "pageSize")]
    [InlineData("pageSize=101", "pageSize")]
    [InlineData("pageSize=", "pageSize")]
    public async Task AnInvalidOrNonNumericParameterIs400NamingIt(string query, string parameter)
    {
        var response = await Client.GetAsync($"/resources?{query}");

        AssertProblem(response, HttpStatusCode.BadRequest);
        Assert.True((await JsonAsync(response)).GetProperty("errors").TryGetProperty(parameter, out _));
    }

    [Fact]
    public async Task BothParametersCanBeInvalidAtOnce()
    {
        var response = await Client.GetAsync("/resources?page=0&pageSize=abc");

        AssertProblem(response, HttpStatusCode.BadRequest);
        var errors = (await JsonAsync(response)).GetProperty("errors");
        Assert.True(errors.TryGetProperty("page", out _));
        Assert.True(errors.TryGetProperty("pageSize", out _));
    }

    [Fact]
    public async Task RetiredResourcesAreExcluded()
    {
        var id = (await JsonAsync(await PostAsync("Retired"))).GetProperty("id").GetInt32();
        await PostAsync("Live");
        await Factory.ExecuteSqlAsync($"UPDATE Resources SET IsDeleted = 1, DeletedAtUtc = SYSUTCDATETIME(), DeletedBy = 'test' WHERE Id = {id}");

        var body = await JsonAsync(await Client.GetAsync("/resources"));

        Assert.Equal(1, body.GetProperty("totalCount").GetInt32());
        Assert.Equal("Live", body.GetProperty("items")[0].GetProperty("name").GetString());
    }

    [Fact]
    public async Task OrderIsByNameCaseInsensitively()
    {
        foreach (var name in new[] { "banana", "Cherry", "apple", "Banana2" })
        {
            await PostAsync(name);
        }

        var body = await JsonAsync(await Client.GetAsync("/resources"));

        Assert.Equal(
            ["apple", "banana", "Banana2", "Cherry"],
            body.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("name").GetString()));
    }
}
