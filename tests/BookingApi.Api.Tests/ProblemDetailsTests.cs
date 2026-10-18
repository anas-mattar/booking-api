using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace BookingApi.Api.Tests;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md (error schema).
public class ProblemDetailsTests
{
    private const string SecretMessage = "secret-detail-that-must-not-leak";

    [Theory]
    [InlineData("Development")]
    [InlineData("Production")]
    public async Task UnknownRouteReturnsProblemDetails(string environment)
    {
        using var factory = new ApiFactory(environment);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/no/such/route");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal(404, body.RootElement.GetProperty("status").GetInt32());
        Assert.False(string.IsNullOrWhiteSpace(body.RootElement.GetProperty("traceId").GetString()));
    }

    [Theory]
    [InlineData("Development")]
    [InlineData("Production")]
    public async Task UnhandledExceptionReturnsProblemDetailsWithoutExceptionData(string environment)
    {
        using var factory = new ThrowingApiFactory(environment);
        using var client = factory.CreateClient();

        var response = await client.GetAsync(ThrowingApiFactory.ThrowPath);

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var text = await response.Content.ReadAsStringAsync();
        using var body = JsonDocument.Parse(text);
        Assert.Equal(500, body.RootElement.GetProperty("status").GetInt32());
        Assert.DoesNotContain(SecretMessage, text);
        Assert.DoesNotContain(nameof(InvalidOperationException), text);
        Assert.DoesNotContain(" at ", text);
        Assert.False(body.RootElement.TryGetProperty("exception", out _));
    }

    // Test-only: the throwing endpoint exists in this factory, never in the application.
    private sealed class ThrowingApiFactory(string environment) : WebApplicationFactory<Program>
    {
        public const string ThrowPath = "/__test/throw";

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment(environment);
            builder.ConfigureServices(services => services.AddTransient<IStartupFilter, ThrowingStartupFilter>());
        }
    }

    private sealed class ThrowingStartupFilter : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(
            Action<IApplicationBuilder> next) => app =>
        {
            next(app);
            app.Use(async (context, pipeline) =>
            {
                if (context.Request.Path == ThrowingApiFactory.ThrowPath)
                {
                    throw new InvalidOperationException(SecretMessage);
                }

                await pipeline(context);
            });
        };
    }
}
