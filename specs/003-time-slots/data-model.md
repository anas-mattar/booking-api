# Data Model: Time Slots

**Feature**: `003-time-slots` | Rulebook: `docs/rulebooks/database-rules.md`

One table, created by the feature's single migration `TimeSlots`, on top of `ResourceCatalog`.
SQL Server, schema `dbo`.

## Table `Slots`

| Column | Type | Null | Notes |
|---|---|---|---|
| `Id` | `int` identity(1,1) | no | Primary key `PK_Slots` (database rulebook: INT IDENTITY) |
| `ResourceId` | `int` | no | Foreign key to `Resources(Id)`, restrict |
| `StartUtc` | `datetime2(7)` | no | UTC (invariant 2); inclusive |
| `EndUtc` | `datetime2(7)` | no | UTC (invariant 2); exclusive; strictly after `StartUtc` |
| `CreatedAtUtc` | `datetime2` | no | UTC |
| `CreatedBy` | `nvarchar(100)` | no | `anonymous` until an identity exists (spec FR-009) |
| `UpdatedAtUtc` | `datetime2` | no | Equals `CreatedAtUtc` at creation |
| `UpdatedBy` | `nvarchar(100)` | no | `anonymous` until an identity exists |
| `IsDeleted` | `bit` | no | Default 0. Soft-delete standard; this feature never sets it |
| `DeletedAtUtc` | `datetime2` | yes | Set only with `IsDeleted` |
| `DeletedBy` | `nvarchar(100)` | yes | Set only with `IsDeleted` |

## Constraints, indexes and trigger

Constraints mirror the rules (database rulebook, "Constraints Mirror Invariants"): the application
checks them first, the database refuses what slips through.

| Name | Definition | Mirrors |
|---|---|---|
| `FK_Slots_Resources_ResourceId` | `ResourceId` references `Resources(Id)`, `ON DELETE NO ACTION` (restrict) | spec FR-005; invariant 5 (a resource a slot references is never hard-deleted); database rulebook (restrict, never cascade) |
| `CK_Slots_Start_Before_End` | `StartUtc < EndUtc` | spec FR-003; invariant 2 |
| `CK_Slots_Deleted_Consistent` | `(IsDeleted = 0 AND DeletedAtUtc IS NULL AND DeletedBy IS NULL) OR (IsDeleted = 1 AND DeletedAtUtc IS NOT NULL AND DeletedBy IS NOT NULL)` | soft-delete standard: a retired row records when and by whom |
| `CK_Slots_Updated_NotBeforeCreated` | `UpdatedAtUtc >= CreatedAtUtc` | audit trail coherence |
| `IX_Slots_ResourceId_StartUtc` | non-unique index on (`ResourceId`, `StartUtc`) including `EndUtc`, where `IsDeleted = 0` | serves the overlap check and the list order (plan, Paging) |
| `TR_Slots_NoOverlap` | AFTER INSERT, UPDATE trigger: for each distinct `ResourceId` among the changed non-retired rows, take `sp_getapplock` (Exclusive, `Transaction` owner, key `slots:<ResourceId>`, keys in ascending order); then if any non-retired slot of the same resource, other than the changed row itself, satisfies `existing.StartUtc < changed.EndUtc AND changed.StartUtc < existing.EndUtc`, raise error 50011 | spec FR-004: no overlap among non-retired slots of one resource, half-open, under concurrency |

Length of the audit user columns is the column type; the database rejects longer values rather than
truncating. The trigger's error number (50011) and its fixed message are part of this model: the
repository maps that number to the overlap outcome and never echoes the message to a client.

## Behaviour

- **Global query filter**: reads exclude `IsDeleted = 1` rows unless a plan approves
  `IgnoreQueryFilters()` (backend rulebook). Nothing in this feature does.
- **Half-open overlap**: `[a.Start, a.End)` and `[b.Start, b.End)` overlap exactly when
  `a.Start < b.End AND b.Start < a.End`. Touching slots (`a.End = b.Start`) do not overlap;
  identical, contained, containing and one-tick overlaps do.
- **Per resource**: overlap is judged among slots of the same `ResourceId` only.
- **No physical delete** anywhere (spec FR-010). No other foreign keys: bookings arrive later and
  will reference `Slots` and `Resources` with restrict semantics.
- **No seed data.**

## Migration `TimeSlots`

- `Up`: creates `Slots`, its primary key, the foreign key, the three check constraints and the
  index, then creates the trigger.
- `Down`: drops the trigger, then drops `Slots`. Lawful only while the table is empty; once data
  exists, rollback is a code revert that leaves the table and the trigger (`rollback.md`; spec Level
  Rationale, irreversible-data).
