using System.Xml.Linq;

namespace BookingApi.Domain.Tests;

// ADR-001 (specs/001-solution-scaffold/plan.md): Domain depends on nothing.
public class DependencyRuleTests
{
    [Fact]
    public void DomainReferencesNoProjectsAndNoPackages()
    {
        var project = LoadProject("src/BookingApi.Domain/BookingApi.Domain.csproj");

        Assert.Empty(project.Descendants("ProjectReference"));
        Assert.Empty(project.Descendants("PackageReference"));
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
