using BookingApi.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace BookingApi.Infrastructure;

// Scaffolding only (dotnet ef migrations ...): the application never uses this and never
// migrates on startup. The connection string is the local-dev LocalDB database, or the
// BOOKINGAPI_CONNECTION environment variable when set.
public sealed class BookingDbContextFactory : IDesignTimeDbContextFactory<BookingDbContext>
{
    public BookingDbContext CreateDbContext(string[] args)
    {
        var connection = Environment.GetEnvironmentVariable("BOOKINGAPI_CONNECTION")
            ?? "Server=(localdb)\\MSSQLLocalDB;Database=BookingApi;Trusted_Connection=True;TrustServerCertificate=True";

        return new BookingDbContext(new DbContextOptionsBuilder<BookingDbContext>().UseSqlServer(connection).Options);
    }
}
