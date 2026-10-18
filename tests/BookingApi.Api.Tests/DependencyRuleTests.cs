using System.Xml.Linq;

namespace BookingApi.Api.Tests;

// ADR-001 (specs/001-solution-scaffold/plan.md): Infrastructure references Application only;
// Api references Application and Infrastructure (the latter for service registration).
public class DependencyRuleTests
{
    [Fact]
    public void InfrastructureReferencesOnlyApplication()
    {
        var references = ProjectReferences("src/BookingApi.Infrastructure/BookingApi.Infrastructure.csproj");

        Assert.Equal(["BookingApi.Application"], references);
    }

    [Fact]
    public void ApiReferencesOnlyApplicationAndInfrastructure()
    {
        var references = ProjectReferences("src/BookingApi.Api/BookingApi.Api.csproj");

        Assert.Equal(["BookingApi.Application", "BookingApi.Infrastructure"], references);
    }

    private static string[] ProjectReferences(string relativePath)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "BookingApi.slnx")))
        {
            dir = dir.Parent;
        }

        Assert.NotNull(dir);
        return XDocument.Load(Path.Combine(dir.FullName, relativePath))
            .Descendants("ProjectReference")
            .Select(r => Path.GetFileNameWithoutExtension((string)r.Attribute("Include")!))
            .Order()
            .ToArray();
    }
}
