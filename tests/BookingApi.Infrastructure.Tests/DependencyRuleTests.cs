using System.Xml.Linq;

namespace BookingApi.Infrastructure.Tests;

// Plan, Structure Decision: TestSupport references no BookingApi project; Infrastructure.Tests
// references Infrastructure and TestSupport only.
public class DependencyRuleTests
{
    [Fact]
    public void TestSupportReferencesNoBookingApiProject()
    {
        Assert.Empty(ProjectReferences("tests/BookingApi.TestSupport/BookingApi.TestSupport.csproj"));
    }

    [Fact]
    public void InfrastructureTestsReferenceOnlyInfrastructureAndTestSupport()
    {
        var references = ProjectReferences("tests/BookingApi.Infrastructure.Tests/BookingApi.Infrastructure.Tests.csproj");

        Assert.Equal(["BookingApi.Infrastructure", "BookingApi.TestSupport"], references);
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
            .Select(r => Path.GetFileNameWithoutExtension(((string)r.Attribute("Include")!).Replace('\\', '/')))
            .Order()
            .ToArray();
    }
}
