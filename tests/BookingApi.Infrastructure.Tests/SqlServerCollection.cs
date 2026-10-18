using BookingApi.TestSupport;

namespace BookingApi.Infrastructure.Tests;

[CollectionDefinition(Name)]
public sealed class SqlServerCollection : ICollectionFixture<SqlServerFixture>
{
    public const string Name = "SqlServer";
}
