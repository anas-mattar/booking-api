using System.Net;
using BookingApi.TestSupport;

namespace BookingApi.Api.Tests;

// Spec SC-004: every error answers as application/problem+json, with no HTML and no stack trace.
[Collection(SqlServerCollection.Name)]
public class ErrorShapeTests(SqlServerFixture sql) : ResourceApiTest(sql)
{
    [Fact]
    public async Task EveryErrorResponseIsProblemJsonWithoutHtmlOrStackTrace()
    {
        await PostAsync("Room A");

        var responses = new List<HttpResponseMessage>
        {
            await PostAsync("Room A"),
            await PostAsync(" "),
            await PostAsync(new string('a', 101)),
            await PostRawAsync(""),
            await PostRawAsync("{ not json"),
            await PostRawAsync("""{"name":123}"""),
            await Client.GetAsync("/resources/424242"),
            await Client.GetAsync("/resources/abc"),
            await Client.GetAsync("/resources?page=0"),
            await Client.GetAsync("/resources?pageSize=abc"),
        };

        foreach (var response in responses)
        {
            Assert.True((int)response.StatusCode is >= 400 and < 500, $"unexpected {response.StatusCode}");
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
            var text = await response.Content.ReadAsStringAsync();
            Assert.DoesNotContain("<html", text, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("Exception", text);
            Assert.DoesNotMatch(@"\bat\s+[\w.<>`+]+\(", text); // a stack frame: "at Namespace.Type.Method("
            Assert.DoesNotContain("stackTrace", text, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("BookingApi.", text);
        }
    }
}
