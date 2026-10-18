using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using BookingApi.TestSupport;

namespace BookingApi.Api.Tests;

/// <summary>A fresh, migrated database and HTTP client per test, plus request helpers.</summary>
public abstract class ResourceApiTest(SqlServerFixture sql) : IAsyncLifetime
{
    protected SqlServerFixture Sql { get; } = sql;

    internal ResourceApiFactory Factory { get; private set; } = null!;

    protected HttpClient Client { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        Factory = await ResourceApiFactory.CreateAsync(Sql);
        Client = Factory.CreateClient();
    }

    public Task DisposeAsync()
    {
        Client.Dispose();
        Factory.Dispose();
        return Task.CompletedTask;
    }

    protected Task<HttpResponseMessage> PostAsync(string name, string? description = null) =>
        Client.PostAsJsonAsync("/resources", new { name, description });

    protected Task<HttpResponseMessage> PostRawAsync(string body, string contentType = "application/json") =>
        Client.PostAsync("/resources", new StringContent(body, Encoding.UTF8, contentType));

    protected static async Task<JsonElement> JsonAsync(HttpResponseMessage response)
    {
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return document.RootElement.Clone();
    }

    protected static void AssertProblem(HttpResponseMessage response, HttpStatusCode status)
    {
        Assert.Equal(status, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }
}
