# Implementation Plan: Solution Scaffold

**Branch**: `001-solution-scaffold` | **Date**: 2026-10-18 | **Spec**: `specs/001-solution-scaffold/spec.md`
**Input**: Feature specification from `specs/001-solution-scaffold/spec.md`
**Status**: Approved
**Gate Batching**: none
**Gate Certification**: user-run

## Summary

Record booking-api's architecture — Clean Architecture in four projects — and lay down the
solution it implies, carrying only the operational baseline the approved spec asks for:
liveness and readiness endpoints, RFC 9457 problem details, a Development-only OpenAPI
document, and API-test infrastructure. EF Core is wired to a dedicated SQL Server database
with an empty context: no tables, no migrations. Four phases, each one user-gated.

## Architecture Decision (ADR-001)

*Constitution IV, bootstrap clause: until this feature merges, this section **is** the
architecture; afterwards it is the existing architecture every feature follows.*

### Context

booking-api is a REST API over three aggregates — resources, time slots, bookings — whose
correctness is dominated by five domain invariants (`docs/domain/booking-invariants.md`):
overlap prevention, UTC time, a booking state machine, no deletion, slot containment. Those
rules must be testable without HTTP or a database, enforced in one place, and impossible for
an endpoint to bypass. One developer, AI-assisted delivery, .NET 10 and SQL Server.

### Options considered

1. **Single API project, feature folders.** Fewest moving parts. Rejected: nothing
   structural keeps domain logic free of EF Core and HTTP, so the invariants would be
   enforced by discipline alone — the failure mode the kit exists to prevent.
2. **API project plus a pure Domain project.** Isolates the invariants cheaply. Rejected by
   the owner in favour of a firmer split between use cases and infrastructure.
3. **Clean Architecture, four projects.** Chosen by the owner, 2026-10-18.

### Decision

Four source projects with dependencies pointing inward, and one test project per layer that
has logic:

```text
src/BookingApi.Domain/          entities, value objects, invariant logic; no dependencies
src/BookingApi.Application/     use cases, ports (interfaces) — references Domain only
src/BookingApi.Infrastructure/  EF Core, SQL Server, health checks — references Application
src/BookingApi.Api/             HTTP host: Program.cs, endpoints, DTOs, problem details;
                                references Application, and Infrastructure ONLY for
                                service registration in Program.cs (the composition root)
tests/BookingApi.Domain.Tests/       unit + golden-fixture tests of Domain
tests/BookingApi.Application.Tests/  use-case tests against fake ports
tests/BookingApi.Api.Tests/          HTTP tests through WebApplicationFactory
```

Dependency rule: `Api → Application → Domain`, `Infrastructure → Application → Domain`,
`Api → Infrastructure` for registration only. Domain references no other project and no
framework package; Application references no infrastructure package. Each rule is a test
(phase 1), so a violation fails the gate instead of waiting for review.

### Consequences

- **Layering**: an endpoint calls an Application use case; it never touches the DbContext.
  Application declares the ports (repositories, clock, etc.) that Infrastructure implements.
- **Dependency direction**: enforced by assembly-reference tests in Domain.Tests and
  Application.Tests (no extra package — `Assembly.GetReferencedAssemblies`).
- **Persistence boundary**: the `BookingDbContext`, its configuration, migrations and query
  filters live in Infrastructure only; Domain entities carry no EF attributes (mapping by
  fluent configuration). Migrations are added by the first entity feature, never here.
- **Error handling**: one problem-details pipeline in Api (contract `contracts/http-baseline.md`).
  Domain signals rule violations with domain results/exceptions that Api maps to problem
  details; no layer below Api knows about HTTP status codes.
- **Endpoint style**: minimal APIs grouped per feature under `src/BookingApi.Api/Features/<Area>/`
  — the template's style, no controllers.
- **Cost accepted**: more projects and ceremony per feature than options 1–2; every new
  aggregate touches up to four projects.

## Technical Context

**Language/Version**: C# on .NET 10 (SDK 10.0.400, `global.json`)  
**Primary Dependencies**: ASP.NET Core minimal APIs; EF Core 10 (SQL Server provider)  
**Storage**: SQL Server; local development on LocalDB, database `BookingApi` (verified
2026-10-18: LocalDB held no user databases, so the name is dedicated to this project —
database rulebook, Setup)  
**Testing**: xUnit; `Microsoft.AspNetCore.Mvc.Testing` for HTTP tests  
**Target Platform**: Linux or Windows server; CI on ubuntu-latest  
**Project Type**: web service (REST API)  
**Performance Goals**: none in this feature  
**Constraints**: readiness answers within 5 s; the gate passes with no SQL Server present
(spec FR-010, SC-001)  
**Scale/Scope**: single service, one developer

### Packages (constitution IV — approved by approving this plan)

| Package | Version | Project | Phase |
|---|---|---|---|
| `Microsoft.AspNetCore.Mvc.Testing` | 10.0.13 | BookingApi.Api.Tests | 2 |
| `Microsoft.EntityFrameworkCore.SqlServer` | 10.0.13 | BookingApi.Infrastructure | 4 |
| `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore` | 10.0.13 | BookingApi.Infrastructure | 4 |

Kept from the adoption scaffold: `Microsoft.AspNetCore.OpenApi` (Api) and the `dotnet new
xunit` set (each test project). No other package is approved.

## Constitution Check

*Evaluated before design and again after it; both pass.*

- [x] **Specification First (I)**: spec.md approved (79fb615); this plan and tasks.md are
  approved before any phase is implemented.
- [x] **Source of Truth (II)**: spec → plan → contract agree; the one open question
  (readiness needs a database that 001 may not migrate) is resolved below, not silently.
- [x] **Repository Separation (III)**: not applicable — single repository (constitution III).
- [x] **Architecture Consistency (IV)**: the architecture is introduced by this plan under
  the bootstrap clause (ADR-001); the three packages above are the only additions.
- [x] **Domain Invariants (V)**: nothing in `docs/domain/booking-invariants.md` is touched;
  no entity exists after this feature.
- [x] **Security (VI)**: health endpoints are public by design and expose no data; the
  connection string comes from user-secrets or environment variables, never a committed
  file; no exception details or connection strings in responses or logs.
- [x] **External Integration Governance (VII)**: the HTTP baseline is contracted in
  `contracts/http-baseline.md` before implementation; no external system is called.
- [x] **Testing Requirements (VIII)**: every endpoint has an HTTP test; the dependency rule
  has architecture tests; no business-critical logic exists yet.
- [x] **Human Review (IX)**: per-phase fresh-context AI review, then human review of the PR
  before merge.
- [x] **Controlled Delivery (X)**: four phases, one at a time, each gated by the user
  (`user-run`, no batching).

  **Phase sizing**: each phase is one testable slice (below). Phases build on their
  predecessors, so they revert newest-first; no phase depends on a later one.

## Design Notes

- **Readiness without a migration**: the spec forbids tables and migrations, but readiness
  must reach a database that exists. The developer creates the empty `BookingApi` database
  once on their own LocalDB (`quickstart.md`). This is local setup, not schema: no table is
  created, and no shared environment is touched (database rulebook, Migrations). The first
  entity feature's migration takes over database creation.
- **Readiness check**: `AddDbContextCheck<BookingDbContext>` tagged `ready`, registration
  timeout 5 s, plus `Connect Timeout=5` in the connection string. `/health` maps with a
  predicate that runs no checks; `/health/ready` runs only `ready`-tagged checks.
- **Missing connection string**: the app still starts; the context fails when the check
  resolves it, and the check reports Unhealthy (spec edge case).
- **Tests without a database**: Api tests replace the `ready` check registration with a
  stub reporting Healthy or Unhealthy via `ConfigureTestServices` — the real pipeline and
  status codes are exercised, the database is not (spec FR-010). SC-002 (real LocalDB) is
  verified by the owner by hand per `quickstart.md`, not by the gate.
- **Problem details**: `AddProblemDetails` + `UseExceptionHandler` + `UseStatusCodePages`;
  the exception handler runs in every environment, so the Development exception page never
  answers a request (FR-006). Verified by a test that runs in the Development environment.

## Phases

| Phase | Slice | User stories / FRs |
|---|---|---|
| 1 | Clean Architecture layout: four src projects, three test projects, dependency-rule tests; template sample removed; governance paths updated | ADR-001, FR-001, SC-004 |
| 2 | API test infrastructure, `GET /health` liveness, OpenAPI Development-only | US1, US4; FR-002, FR-007, FR-010 |
| 3 | RFC 9457 problem details for unknown routes and unhandled exceptions | US3; FR-005, FR-006 |
| 4 | EF Core wired to SQL Server (empty context), `GET /health/ready`, `quickstart.md` | US2; FR-003, FR-004, FR-008, FR-009 |

Territory per phase is declared in `tasks.md`.

## Project Structure

### Documentation (this feature)

```text
specs/001-solution-scaffold/
├── spec.md
├── plan.md                    # this file
├── contracts/http-baseline.md
├── quickstart.md              # phase 4
└── tasks.md
```

No `data-model.md`: the feature has no entities.

### Source Code (repository root, after phase 4)

```text
BookingApi.slnx
src/
├── BookingApi.Domain/
├── BookingApi.Application/
├── BookingApi.Infrastructure/
│   ├── Data/BookingDbContext.cs
│   └── DependencyInjection.cs
└── BookingApi.Api/
    ├── Program.cs
    ├── Health/
    └── Errors/
tests/
├── BookingApi.Domain.Tests/
├── BookingApi.Application.Tests/
└── BookingApi.Api.Tests/
```

**Structure Decision**: ADR-001 above. Governance paths that name the old
`src/BookingApi/` and `tests/BookingApi.Tests/` (CLAUDE.md Stack Profile,
`docs/rulebooks/backend-rules.md` Layering, `docs/sdlc/repository-strategy.md`) are updated
in phase 1; the gate command is unchanged (`BookingApi.slnx`).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 4 source + 3 test projects for an API with no entities yet | Owner's architecture decision (ADR-001): the invariants must be structurally isolated from HTTP and EF Core | A single project or API + Domain was offered and declined by the owner |
