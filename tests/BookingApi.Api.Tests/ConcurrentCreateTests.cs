using System.Net;
using BookingApi.TestSupport;

namespace BookingApi.Api.Tests;

// Spec SC-003: two simultaneous creations of one name give one 201 and one 409, never a 5xx.
[Collection(SqlServerCollection.Name)]
public class ConcurrentCreateTests(SqlServerFixture sql) : ResourceApiTest(sql)
{
    [Fact]
    public async Task TwoSimultaneousCreatesOfOneNameGiveOneCreatedAndOneConflict()
    {
        for (var round = 0; round < 15; round++)
        {
            var name = $"Contended {round}";

            var responses = await Task.WhenAll(
                Task.Run(() => PostAsync(name)),
                Task.Run(() => PostAsync(name)));

            var statuses = responses.Select(r => r.StatusCode).Order().ToArray();
            Assert.Equal([HttpStatusCode.Created, HttpStatusCode.Conflict], statuses);
        }
    }
}
