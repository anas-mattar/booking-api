using BookingApi.Application.Resources;
using BookingApi.Domain;
using BookingApi.Infrastructure.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace BookingApi.Infrastructure.Resources;

// Implements the port in BookingApi.Application/Resources/IResourceRepository.cs.
public sealed class ResourceRepository(BookingDbContext context) : IResourceRepository
{
    // SQL Server: 2601 = duplicate key in a unique index, 2627 = unique constraint violation.
    private const int UniqueIndexViolation = 2601;
    private const int UniqueConstraintViolation = 2627;

    public Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken) =>
        context.Resources.AsNoTracking().AnyAsync(r => r.Name == name, cancellationToken);

    public async Task<AddResourceResult> AddAsync(Resource resource, CancellationToken cancellationToken)
    {
        context.Resources.Add(resource);
        try
        {
            await context.SaveChangesAsync(cancellationToken);
            return AddResourceResult.Added;
        }
        catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: UniqueIndexViolation or UniqueConstraintViolation })
        {
            // Leave the context clean so the caller can keep using it.
            context.Entry(resource).State = EntityState.Detached;
            return AddResourceResult.DuplicateName;
        }
    }

    public Task<Resource?> GetByIdAsync(int id, CancellationToken cancellationToken) =>
        context.Resources.AsNoTracking().FirstOrDefaultAsync(r => r.Id == id, cancellationToken);

    public async Task<ResourcePage> ListAsync(int page, int pageSize, CancellationToken cancellationToken)
    {
        var query = context.Resources.AsNoTracking();
        var total = await query.CountAsync(cancellationToken);

        // 64-bit offset: past the end (even beyond the int range) is an empty page, not an overflow.
        var offset = ((long)page - 1) * pageSize;
        if (offset >= total)
        {
            return new ResourcePage([], page, pageSize, total);
        }

        var items = await query
            .OrderBy(r => r.Name)
            .ThenBy(r => r.Id)
            .Skip((int)offset)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return new ResourcePage(items, page, pageSize, total);
    }
}
