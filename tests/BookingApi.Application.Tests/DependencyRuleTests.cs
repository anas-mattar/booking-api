using System.Xml.Linq;

namespace BookingApi.Application.Tests;

// ADR-001 (specs/001-solution-scaffold/plan.md): Application references Domain only, and
// no web or persistence framework.
public class DependencyRuleTests
{
    [Fact]
    public void ApplicationReferencesOnlyDomain()
    {
        var project = LoadProject("src/BookingApi.Application/BookingApi.Application.csproj");

        var references = project.Descendants("ProjectReference")
            .Select(r => Path.GetFileNameWithoutExtension(((string)r.Attribute("Include")!).Replace('\\', '/')))
            .ToArray();

        Assert.Equal(["BookingApi.Domain"], references);
    }

    [Fact]
    public void ApplicationReferencesNoWebOrPersistencePackages()
    {
        var project = LoadProject("src/BookingApi.Application/BookingApi.Application.csproj");

        var forbidden = project.Descendants("PackageReference")
            .Select(r => (string)r.Attribute("Include")!)
            .Where(name => name.StartsWith("Microsoft.AspNetCore", StringComparison.OrdinalIgnoreCase)
                || name.StartsWith("Microsoft.EntityFrameworkCore", StringComparison.OrdinalIgnoreCase))
            .ToArray();

        Assert.Empty(forbidden);
    }

    private static XDocument LoadProject(string relativePath)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "BookingApi.slnx")))
        {
            dir = dir.Parent;
        }

        Assert.NotNull(dir);
        return XDocument.Load(Path.Combine(dir.FullName, relativePath));
    }
}
