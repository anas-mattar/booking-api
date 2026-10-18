# Database Rules — booking-api

> **Binding**: this rulebook is enforced through the compliance checklist of whichever
> tier owns the migration (Definition of Done item 5, `docs/sdlc/definition-of-done.md`).
> Schema changes are the least reversible thing an agent ships — this file is always read
> together with `docs/sdlc/rollback-process.md`, never alone.

The Schema Standards below are conventions of this rulebook, not constitutional principles:
deviations are a plan-approved judgment call, not a constitutional violation. Domain
invariants (`docs/domain/booking-invariants.md`) are different — they carry constitutional
force.

## Setup

- Before the FIRST migration runs, the connection string's target database MUST be
  confirmed as dedicated to this project — not silently inherited from another project's
  local-dev setup and not a shared/production database. Deliberately sharing a database
  across services is permitted only as an explicit, plan-approved decision: the rule is
  confirmation, not a ban on reuse. **Why**: a connection string silently reused from
  another project points the first `migration apply` at an existing database, mixing
  schemas the moment it runs.
- Local development runs on SQL Server LocalDB (`(localdb)\MSSQLLocalDB`).
- Tests run against throwaway SQL Server containers (Testcontainers; Docker must be running)
  and never against the developer's `BookingApi` LocalDB database: each test creates its own
  uniquely named database in the container and applies the real migrations.

## Schema Standards

- Primary keys: the default primary key MUST be `Id INT IDENTITY(1,1) PRIMARY KEY`.
  Deviations are prohibited unless explicitly approved in the technical plan.
  Externally-exposed identifiers (public IDs, correlation IDs, integration references,
  idempotency keys) MAY use opaque values such as GUIDs, but these are not primary keys.
  **Why**: a uniform key strategy keeps indexes compact and joins predictable while still
  allowing opaque identifiers where external exposure genuinely requires them.
- Audit fields on every business entity: `CreatedAtUtc`, `CreatedBy`, `UpdatedAtUtc`,
  `UpdatedBy` (`datetime2`, UTC — invariant 2). **Why**: systems of record require a
  verifiable trail of who changed what and when.
- Soft delete standard: `IsDeleted`, `DeletedAtUtc`, `DeletedBy` on master data (resources,
  time slots). Business master data MUST use soft delete; physical deletion is prohibited
  unless explicitly approved in the technical plan. Bookings are never deleted at all —
  not soft, not hard — they are cancelled (invariant 4). **Why**: master data referenced by
  history must never disappear from under it.
- Naming conventions: PascalCase tables and columns; tables plural; constraint and index
  names follow EF Core's defaults (`PK_`, `FK_`, `IX_`).

## Constraints Mirror Invariants

- Every domain invariant (`docs/domain/booking-invariants.md`) that a constraint can
  express MUST be one — CHECK, FK, UNIQUE, NOT NULL — in addition to application-level
  enforcement. **Why**: application-only enforcement is one forgotten code path away from
  bad data.
- Foreign keys to soft-deleted master data MUST use restrict semantics, never cascade
  delete. **Why**: history must keep resolving after the referenced row is retired.

## Migrations

- Schema changes ship ONLY as EF Core migrations — no hand-run SQL against shared
  environments. **Why**: unscripted changes cannot be replayed, diffed, or rolled back.
- At most one migration per phase, named after the feature.
- Every migration MUST be reversible, or ship a written rollback plan from
  `specs/_templates/rollback-template.md`. **Why**: rollback designed after the incident
  is guesswork.
- Destructive operations (dropping columns/tables, truncating, rewriting data) are
  prohibited unless explicitly approved in the feature's `plan.md`.
- A migration already applied beyond the author's machine MUST NOT be edited — write a
  new one. **Why**: edited history diverges environments silently.

## Data Safety

- Rolling back code or a migration MUST NOT cascade into physical deletion of domain
  data. If a rollback would touch domain data, stop and report
  (`docs/sdlc/rollback-process.md`).
- Seed data: deterministic seeds only; production migrations carry no seed data.
