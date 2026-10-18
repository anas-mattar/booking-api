# Implementation Plan: Resource Catalog

**Branch**: `002-resource-catalog` | **Date**: 2026-10-18 | **Spec**: `specs/002-resource-catalog/spec.md`
**Input**: Feature specification from `specs/002-resource-catalog/spec.md`
**Status**: Approved
**Gate Batching**: none
**Gate Certification**: user-run

## Summary

The first domain entity. A `Resource` lives in the Domain project with its validation rules;
three use cases (create, get, list) and the repository port live in Application; EF Core
mapping, the repository, and the first migration `ResourceCatalog` live in Infrastructure;
three minimal-API endpoints live in Api. All of it follows ADR-001 (`specs/001-solution-scaffold/plan.md`),
which this feature does not change. Database behaviour is tested against real SQL Server in a
throwaway Testcontainers container, so the same tests run on a developer machine and in CI.
Four phases, each one user-gated.

## Technical Context

**Language/Version**: C# on .NET 10 (SDK 10.0.400, `global.json`)  
**Primary Dependencies**: ASP.NET Core minimal APIs; EF Core 10 (SQL Server provider), already in place  
**Storage**: SQL Server; table `Resources` per `data-model.md`; local dev database `BookingApi` on LocalDB  
**Testing**: xUnit; `Microsoft.AspNetCore.Mvc.Testing`; **Testcontainers for SQL Server** (owner's decision, 2026-10-18)  
**Target Platform**: Linux or Windows server; CI on ubuntu-latest (Docker preinstalled)  
**Project Type**: web service (REST API)  
**Performance Goals**: none beyond the paging bound (page size at most 100)  
**Constraints**: the gate needs a running Docker engine (see Design Notes); database rules per
`docs/rulebooks/database-rules.md`  
**Scale/Scope**: single service, one developer

### Packages and tools (constitution IV — approved by approving this plan)

| Package or tool | Version | Where | Phase |
|---|---|---|---|
| `Testcontainers.MsSql` | 4.16.0 | `BookingApi.TestSupport` (test infrastructure) | 3 |
| `Microsoft.EntityFrameworkCore.Design` | 10.0.13 (`PrivateAssets=all`) | `BookingApi.Infrastructure` (design-time only, for migrations) | 3 |
| `dotnet-ef` local tool | 10.0.13 | `.config/dotnet-tools.json` (pinned, so every machine and CI use the same version) | 3 |

Kept: everything approved in feature 001, including the `System.Security.Cryptography.Pkcs`
pin. The new test projects use the `dotnet new xunit` package set. No other package is
approved. A transitive advisory raised by a new package is triaged per
`docs/sdlc/gate-command.md` and, if it needs a pin, is a plan amendment with an owner approver
record, as in feature 001.

## Constitution Check

*Evaluated before design and again after it; both pass.*

- [x] **Specification First (I)**: spec.md approved (48780e2); this plan, the data model, the
  contract and tasks.md are approved before any phase is implemented.
- [x] **Source of Truth (II)**: spec → plan → contract → data model agree; the one open point
  (how tests get a database) was decided by the owner and is recorded above.
- [x] **Repository Separation (III)**: not applicable — single repository.
- [x] **Architecture Consistency (IV)**: no new architecture; ADR-001's layout and dependency
  rule are followed. The new projects (`BookingApi.TestSupport`, `BookingApi.Infrastructure.Tests`)
  are test infrastructure and the Infrastructure layer's test project, approved here as the
  backend rulebook requires; the packages above are the only additions.
- [x] **Domain Invariants (V)**: `docs/domain/booking-invariants.md` is not violated. No slot or
  booking exists; invariant 5's resource half is prepared by the soft-delete columns and the
  query filter, and no retire operation ships (spec Level Rationale).
- [x] **Security (VI)**: the endpoints are public by design in this feature (spec Assumptions,
  contract Authentication), an accepted interim state recorded in three places; no secret is
  committed; no sensitive data is logged; responses carry no exception data.
- [x] **External Integration Governance (VII)**: the API is contracted in
  `contracts/resources-api.md` before implementation; no external system is called.
- [x] **Testing Requirements (VIII)**: every rule has automated tests at the layer that owns it
  (Domain, Application, real SQL Server for constraints and concurrency, HTTP for the contract).
- [x] **Human Review (IX)**: per-phase fresh-context AI review, then human review of the PR
  before merge.
- [x] **Controlled Delivery (X)**: four phases, one at a time, each gated by the user
  (`user-run`, no batching).

  **Phase sizing**: each phase is one testable slice (below) and reverts on its own, newest
  first; no phase depends on a later one. Phase 3 is the largest (persistence, migration and
  its test infrastructure belong together: the migration cannot be proven without them).

## Design Notes

- **Layering (ADR-001)**: Api calls an Application use case and never the DbContext. Domain has
  no framework reference; Application references only Domain.
- **Domain**: `Resource` has a private constructor and a factory `Resource.Create(name,
  description, nowUtc)` that trims, validates (name 1 to 100, description at most 500) and
  returns either the entity or the list of field errors. It carries the retirement marker
  (`IsDeleted`, `DeletedAtUtc`, `DeletedBy`) as read-only state; nothing in the code sets it.
- **Application**: `IResourceRepository` (add, get by id, list a page, name-exists check) and
  three use-case handlers returning explicit outcomes (`Created`, `Invalid(errors)`,
  `Duplicate`, `Found`, `NotFound`, a page). Time comes from `TimeProvider` (BCL), so tests
  control it without a package. No exceptions for expected outcomes.
- **Duplicate names, both layers (FR-002)**: the handler checks `name-exists` first for a clean
  409, and the repository maps a unique-index violation (SQL Server errors 2601 and 2627 on
  `IX_Resources_Name`) to the same `Duplicate` outcome, so a concurrent insert that slips past
  the check still yields 409, never 500 (SC-003).
- **Case-insensitivity**: relies on the database's default case-insensitive collation (spec
  Assumptions). A real-database test asserts that "room a" collides with "Room A"; if the
  collation were ever case-sensitive, that test fails.
- **Persistence**: fluent mapping in Infrastructure (Domain entities carry no EF attributes);
  global query filter `!IsDeleted`; read queries use `AsNoTracking()` (backend rulebook).
  Migrations live in `src/BookingApi.Infrastructure/Migrations/`, generated by the pinned
  local tool through a design-time `IDesignTimeDbContextFactory` that is used only for
  scaffolding. The application never migrates on startup; the owner applies the migration
  with `dotnet ef database update` (`quickstart.md`).
- **Paging**: `Skip((page - 1) * pageSize).Take(pageSize)` computed in 64-bit arithmetic;
  an offset beyond the int range returns an empty page rather than overflowing.
- **API**: a `Features/Resources/` folder in Api with the endpoint group, request and response
  DTOs, and field-error mapping to `ValidationProblem`. Malformed bodies and non-numeric query
  values must come back as 400 problem details through the baseline error pipeline; the tests
  assert that, and a framework default that answers differently is fixed in Api, not accepted.
- **Test database**: `BookingApi.TestSupport` provides one xUnit collection fixture that starts
  a SQL Server container (the module's default image) once per test assembly; each test makes
  its own uniquely named database in it and applies the real migrations with `Migrate()`, so
  the migration itself is exercised (SC-005) and tests never share rows. The tests never touch
  the developer's LocalDB `BookingApi` database.
- **The gate now needs Docker**: Docker Desktop must be running when the gate is run locally;
  GitHub's ubuntu runners have Docker, so `project-gate.yml` is unchanged. If Docker is not
  running, the database tests fail loudly with the container error; they never skip (a gate
  that skips is not a gate). This is recorded in `CLAUDE.md` (Stack Profile), `README.md` and
  the backend and database rulebooks in phase 3.
- **First-run cost**: the first run pulls the SQL Server image (about 1.5 GB) and starts a
  container (tens of seconds); later runs reuse the cached image.

## Phases

| Phase | Slice | Stories / FRs |
|---|---|---|
| 1 | Domain: `Resource` entity, validation rules, unit tests | FR-001 (rules), FR-006 (shape), FR-009 |
| 2 | Application: repository port and the create, get and list use cases, tested against a fake repository | FR-001..FR-005 (behaviour), FR-008 |
| 3 | Persistence: Testcontainers test support, EF mapping, repository, migration `ResourceCatalog`, DI, tests against real SQL Server, Docker prerequisite documented | FR-002 (database half), FR-007, FR-008, FR-011 |
| 4 | API: the three endpoints, DTOs, OpenAPI, HTTP tests including end-to-end against real SQL Server, `quickstart.md`, `rollback.md` | US1, US2, US3; FR-001..FR-006, FR-010; SC-002..SC-005 |

Territory per phase is declared in `tasks.md`.

## Project Structure

### Documentation (this feature)

```text
specs/002-resource-catalog/
├── spec.md
├── plan.md                    # this file
├── data-model.md
├── contracts/resources-api.md
├── quickstart.md              # phase 4
├── rollback.md                # phase 4
├── notes.md                   # evidence
└── tasks.md
```

### Source Code (repository root, after phase 4)

```text
.config/dotnet-tools.json                     # dotnet-ef 10.0.13
BookingApi.slnx
src/
├── BookingApi.Domain/            Resource.cs (+ validation)
├── BookingApi.Application/       Resources/ (port, use cases, outcomes)
├── BookingApi.Infrastructure/    Data/ (mapping), Resources/ (repository), Migrations/
└── BookingApi.Api/               Features/Resources/ (endpoints, DTOs)
tests/
├── BookingApi.Domain.Tests/
├── BookingApi.Application.Tests/
├── BookingApi.Infrastructure.Tests/   (new: real SQL Server)
├── BookingApi.Api.Tests/
└── BookingApi.TestSupport/            (new: SQL Server container fixture)
```

**Structure Decision**: ADR-001, unchanged. Two test-side projects are added; the dependency-rule
tests are extended in phase 3 to cover them (TestSupport references no BookingApi project;
Infrastructure.Tests references Infrastructure and TestSupport only).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Docker required to run the gate | Constraints, collation and concurrency must be proven on real SQL Server (spec FR-011) and CI has none installed | An in-memory or SQLite stand-in cannot check the filtered unique index or the collation; the owner chose Testcontainers over it and over a LocalDB-plus-CI-service split |
| Two new test-side projects | One fixture shared by the Infrastructure and Api test projects; a test project for the layer that now holds logic (ADR-001) | Duplicating the fixture in two projects, or putting persistence tests in Api.Tests, blurs the layer-per-test-project rule |
