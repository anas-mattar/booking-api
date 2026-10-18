using Microsoft.EntityFrameworkCore;

namespace BookingApi.Infrastructure.Data;

// Empty by design in feature 001: no DbSet, no tables, no migrations (spec FR-009).
// The first entity feature adds the model and the first migration.
public sealed class BookingDbContext(DbContextOptions<BookingDbContext> options) : DbContext(options);
