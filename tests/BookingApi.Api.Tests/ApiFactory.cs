using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace BookingApi.Api.Tests;

// Runs the real HTTP pipeline of BookingApi.Api in the requested environment.
public sealed class ApiFactory(string environment = "Development") : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder) => builder.UseEnvironment(environment);
}
