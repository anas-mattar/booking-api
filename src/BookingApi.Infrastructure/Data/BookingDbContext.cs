using BookingApi.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace BookingApi.Infrastructure.Data;

// Mapping per specs/002-resource-catalog/data-model.md. Domain entities carry no EF attributes.
public sealed class BookingDbContext(DbContextOptions<BookingDbContext> options) : DbContext(options)
{
    // datetime2 comes back with Kind Unspecified; every instant in this model is UTC (invariant 2),
    // so mark it on the way out so serialization carries the Z. Storage is unchanged.
    private static readonly ValueConverter<DateTime, DateTime> UtcDateTime =
        new(v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));

    private static readonly ValueConverter<DateTime?, DateTime?> UtcNullableDateTime =
        new(v => v, v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : v);

    public DbSet<Resource> Resources => Set<Resource>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Resource>(entity =>
        {
            entity.ToTable("Resources", table =>
            {
                table.HasCheckConstraint(
                    "CK_Resources_Name_Trimmed",
                    "DATALENGTH([Name]) = DATALENGTH(LTRIM(RTRIM([Name]))) AND LEN([Name]) > 0");
                table.HasCheckConstraint(
                    "CK_Resources_Deleted_Consistent",
                    "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL AND [DeletedBy] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL AND [DeletedBy] IS NOT NULL)");
                table.HasCheckConstraint(
                    "CK_Resources_Updated_NotBeforeCreated",
                    "[UpdatedAtUtc] >= [CreatedAtUtc]");
            });

            entity.HasKey(r => r.Id);
            entity.Property(r => r.Id).UseIdentityColumn();

            entity.Property(r => r.Name).HasMaxLength(Resource.MaxNameLength).IsRequired();
            entity.Property(r => r.Description).HasMaxLength(Resource.MaxDescriptionLength);
            entity.Property(r => r.CreatedAtUtc).HasColumnType("datetime2").HasConversion(UtcDateTime);
            entity.Property(r => r.CreatedBy).HasMaxLength(100).IsRequired();
            entity.Property(r => r.UpdatedAtUtc).HasColumnType("datetime2").HasConversion(UtcDateTime);
            entity.Property(r => r.UpdatedBy).HasMaxLength(100).IsRequired();
            entity.Property(r => r.IsDeleted).HasDefaultValue(false);
            entity.Property(r => r.DeletedAtUtc).HasColumnType("datetime2").HasConversion(UtcNullableDateTime);
            entity.Property(r => r.DeletedBy).HasMaxLength(100);

            entity.HasIndex(r => r.Name).IsUnique().HasFilter("[IsDeleted] = 0");

            entity.HasQueryFilter(r => !r.IsDeleted);
        });
    }
}
