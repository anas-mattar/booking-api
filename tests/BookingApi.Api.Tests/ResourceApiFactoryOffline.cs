using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace BookingApi.Api.Tests;

// The application with a connection string that cannot connect: any database call fails.
internal sealed class ResourceApiFactoryOffline : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Production");
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:BookingApi"] = "Server=127.0.0.1,1;Database=none;User Id=x;Password=x;Connect Timeout=2;TrustServerCertificate=True",
            }));
    }
}
