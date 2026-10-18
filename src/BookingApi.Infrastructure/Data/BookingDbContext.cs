using BookingApi.Domain;
using Microsoft.EntityFrameworkCore;

namespace BookingApi.Infrastructure.Data;

// Mapping per specs/002-resource-catalog/data-model.md. Domain entities carry no EF attributes.
public sealed class BookingDbContext(DbContextOptions<BookingDbContext> options) : DbContext(options)
{
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
            entity.Property(r => r.CreatedAtUtc).HasColumnType("datetime2");
            entity.Property(r => r.CreatedBy).HasMaxLength(100).IsRequired();
            entity.Property(r => r.UpdatedAtUtc).HasColumnType("datetime2");
            entity.Property(r => r.UpdatedBy).HasMaxLength(100).IsRequired();
            entity.Property(r => r.IsDeleted).HasDefaultValue(false);
            entity.Property(r => r.DeletedAtUtc).HasColumnType("datetime2");
            entity.Property(r => r.DeletedBy).HasMaxLength(100);

            entity.HasIndex(r => r.Name).IsUnique().HasFilter("[IsDeleted] = 0");

            entity.HasQueryFilter(r => !r.IsDeleted);
        });
    }
}
