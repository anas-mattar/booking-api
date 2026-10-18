# Data Model: Resource Catalog

**Feature**: `002-resource-catalog` | Rulebook: `docs/rulebooks/database-rules.md`

One table, created by the feature's single migration `ResourceCatalog`. SQL Server, schema
`dbo`.

## Table `Resources`

| Column | Type | Null | Notes |
|---|---|---|---|
| `Id` | `int` identity(1,1) | no | Primary key `PK_Resources` (database rulebook: INT IDENTITY) |
| `Name` | `nvarchar(100)` | no | Stored trimmed; 1 to 100 characters |
| `Description` | `nvarchar(500)` | yes | Optional |
| `CreatedAtUtc` | `datetime2` | no | UTC (invariant 2) |
| `CreatedBy` | `nvarchar(100)` | no | `anonymous` until an identity exists (spec FR-008) |
| `UpdatedAtUtc` | `datetime2` | no | Equals `CreatedAtUtc` at creation |
| `UpdatedBy` | `nvarchar(100)` | no | `anonymous` until an identity exists |
| `IsDeleted` | `bit` | no | Default 0. Soft-delete standard; this feature never sets it |
| `DeletedAtUtc` | `datetime2` | yes | Set only with `IsDeleted` |
| `DeletedBy` | `nvarchar(100)` | yes | Set only with `IsDeleted` |

## Constraints and indexes

Constraints mirror the rules (database rulebook, "Constraints Mirror Invariants"): the
application checks them first, the database refuses what slips through.

| Name | Definition | Mirrors |
|---|---|---|
| `IX_Resources_Name` | unique index on `Name` where `IsDeleted = 0` | spec FR-002: unique among non-retired resources; the database's default case-insensitive collation makes it case-insensitive |
| `CK_Resources_Name_Trimmed` | `Name = LTRIM(RTRIM(Name)) AND LEN(Name) > 0` | spec FR-001: trimmed and not blank |
| `CK_Resources_Deleted_Consistent` | `(IsDeleted = 0 AND DeletedAtUtc IS NULL AND DeletedBy IS NULL) OR (IsDeleted = 1 AND DeletedAtUtc IS NOT NULL AND DeletedBy IS NOT NULL)` | soft-delete standard: a retired row records when and by whom |
| `CK_Resources_Updated_NotBeforeCreated` | `UpdatedAtUtc >= CreatedAtUtc` | audit trail coherence |

Length limits are the column types (`nvarchar(100)`, `nvarchar(500)`): the database rejects
longer values rather than truncating.

## Behaviour

- **Global query filter**: reads exclude `IsDeleted = 1` rows unless a plan approves
  `IgnoreQueryFilters()` (backend rulebook). Nothing in this feature does.
- **No physical delete** anywhere (spec FR-009). No foreign keys yet: time slots and bookings
  arrive later and will reference `Resources` with restrict semantics.
- **No seed data.**

## Migration `ResourceCatalog`

- `Up`: creates `Resources`, its primary key, the unique index and the three check constraints.
- `Down`: drops `Resources`. Lawful only while the table is empty; once data exists, rollback
  is a code revert that leaves the table (`rollback.md`; spec Level Rationale,
  irreversible-data).
