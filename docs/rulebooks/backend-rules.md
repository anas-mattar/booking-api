# Backend Rules — booking-api

> **Binding**: this rulebook is enforced through the backend tier's compliance checklist
> (Definition of Done item 5, `docs/sdlc/definition-of-done.md`): the checklist asserts,
> this rulebook explains. Domain invariants (`docs/domain/booking-invariants.md`) carry
> constitutional force and always outrank this file.

## Layering & Placement

- Code layout: Clean Architecture in four projects, decided in ADR-001
  (`specs/001-solution-scaffold/plan.md`, constitution IV): **src/BookingApi.Domain/**
  (entities, invariant logic; references nothing), **src/BookingApi.Application/** (use cases
  and ports; references Domain only), **src/BookingApi.Infrastructure/** (EF Core and other
  adapters; references Application), **src/BookingApi.Api/** (HTTP host, endpoints, DTOs;
  references Application, and Infrastructure only to register services in `Program.cs`).
  Tests: **tests/BookingApi.Domain.Tests/**, **tests/BookingApi.Application.Tests/**,
  **tests/BookingApi.Api.Tests/**, all in **BookingApi.slnx**.
- Dependencies MUST point inward: `Api → Application → Domain` and `Infrastructure →
  Application`. Domain and Application MUST NOT reference ASP.NET Core or EF Core packages.
  **Why**: the invariants in `docs/domain/booking-invariants.md` must stay testable without
  HTTP or a database; the dependency-rule tests in the Domain and Application test projects
  fail the gate on a violation.
- An endpoint MUST call an Application use case and MUST NOT use the DbContext directly.
- New code MUST follow the existing layout. A new top-level folder, layer, or project
  requires approval in the feature's `plan.md`.
  **Why**: architecture changes ride in on "just one helper folder" — this is where drift starts.

## API Surface

- Every external input MUST be validated at the API boundary; validation failures MUST
  return RFC 9457 problem details (`ValidationProblemDetails` for 400 responses).
  **Why**: the boundary is the one place a bad value is rejected once for all callers.
- Responses MUST use dedicated DTOs; domain entities MUST NOT be serialized directly.
  **Why**: entity leaks turn every schema refactor into a breaking API change.
- Code implementing a feature contract MUST cite the contract file (the feature's
  `contracts/` directory) in a comment at the top of the file.
  **Why**: the citation makes rung-checking possible during review.

## Domain Logic

- Domain invariants (`docs/domain/booking-invariants.md`) MUST be enforced in code AND
  asserted by the database schema where a constraint can express them — never in one place
  only.
- Dates and numbers MUST be parsed and formatted culture-invariantly at every boundary;
  instants are normalized to UTC at the boundary (invariant 2). **Why**: a locale-dependent
  parse is data corruption that no test on the author's machine catches.
- Overlap and availability logic (invariants 1 and 5) MUST live in one named module, fixed
  by the `plan.md` of the first feature that needs it and recorded here, covered by
  golden-fixture tests with hand-worked expected values. Re-deriving it inline is
  prohibited. **Why**: two implementations of one interval rule always diverge.

## Data Access

- Read-only queries MUST NOT track entities (`.AsNoTracking()`).
- Soft-delete filtering is owned by an EF Core global query filter; a query MUST NOT
  re-filter `IsDeleted` by hand, and bypassing the filter (`IgnoreQueryFilters()`) requires
  approval in the feature's `plan.md`.

## Testing

- xUnit. Every endpoint has an API test; overlap/availability and lifecycle logic have
  golden-fixture tests with hand-worked expected values (constitution VIII).
- Database behaviour (constraints, collation, concurrency) is tested against real SQL Server in a
  throwaway Testcontainers container (`BookingApi.TestSupport`), never an in-memory or SQLite
  stand-in. The gate therefore needs a running Docker engine; if Docker is down the database
  tests fail, they never skip.
- The gate (`docs/sdlc/gate-command.md`) is run by the user; a phase is not done before
  the user confirms exit code 0 — or, under a declared `ci-held` (Lite/Micro/Standard
  only, constitution X), before the owner records approval on the CI evidence triplet.

## Security

- Secrets MUST NOT be committed; configuration and secrets come from `dotnet user-secrets`
  in development and environment variables elsewhere — never from `appsettings*.json`.
- The authentication and authorization scheme is chosen in a plan-approved feature
  (constitution VI). Until it exists, no endpoint may be described or shipped as
  "protected": an endpoint is either explicitly public in its spec or waits for that
  feature.
