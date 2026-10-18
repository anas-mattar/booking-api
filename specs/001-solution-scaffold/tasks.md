---

description: "Tasks for 001-solution-scaffold"
---

# Tasks: Solution Scaffold

**Input**: `specs/001-solution-scaffold/` — spec.md (approved), plan.md (approved, ADR-001),
contracts/http-baseline.md

**Tests**: required in every phase. There is no business-critical logic yet (no entities);
the tests here cover the contract (`contracts/http-baseline.md`) and the ADR-001 dependency
rule. Tests are written first and seen failing before the implementation that makes them
pass.

**Phase ritual** (every phase): implement → agent-run gate (feedback) → `git diff --stat`
review → commit with `phase N` in the subject → `pwsh -File scripts/scope-check.ps1` PASS →
fresh-context AI review (`specs/001-solution-scaffold/ai-code-review-phaseN.md`) → **stop:
the owner runs the gate and confirms the exit code** before the next phase starts.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Clean Architecture layout (ADR-001)

**Goal**: the four-project solution and three test projects exist, the dependency rule is
machine-checked, and the template sample is gone.

**Independent Test**: the gate passes; the dependency-rule tests fail if a forbidden
project reference is added.

**Territory**:

- `BookingApi.slnx`
- `src/BookingApi/**`
- `src/BookingApi.Api/**`
- `src/BookingApi.Domain/**`
- `src/BookingApi.Application/**`
- `src/BookingApi.Infrastructure/**`
- `tests/BookingApi.Tests/**`
- `tests/BookingApi.Api.Tests/**`
- `tests/BookingApi.Domain.Tests/**`
- `tests/BookingApi.Application.Tests/**`
- `CLAUDE.md`
- `docs/rulebooks/backend-rules.md`
- `docs/sdlc/repository-strategy.md`
- `docs/digests/branching-digest.md`

### Tests

- [x] T001 [P] Create `tests/BookingApi.Domain.Tests` (xUnit) with `DependencyRuleTests`:
  the `BookingApi.Domain` assembly references no other BookingApi assembly and no
  `Microsoft.AspNetCore.*` / `Microsoft.EntityFrameworkCore*` assembly
- [x] T002 [P] Create `tests/BookingApi.Application.Tests` (xUnit) with `DependencyRuleTests`:
  `BookingApi.Application` references `BookingApi.Domain` and no `BookingApi.Infrastructure`,
  `BookingApi.Api`, `Microsoft.AspNetCore.*` or `Microsoft.EntityFrameworkCore*` assembly

### Implementation

- [x] T003 `git mv src/BookingApi src/BookingApi.Api`, rename the project file and the
  assembly to `BookingApi.Api`; update `BookingApi.slnx`
- [x] T004 [P] Create class libraries `src/BookingApi.Domain`, `src/BookingApi.Application`,
  `src/BookingApi.Infrastructure` (no template `Class1.cs`), add to `BookingApi.slnx` under
  `/src/`
- [x] T005 Add project references per ADR-001: Application → Domain; Infrastructure →
  Application; Api → Application and Infrastructure; each test project → its layer
- [x] T006 Remove the weatherforecast endpoint and record from
  `src/BookingApi.Api/Program.cs`; remove the sample request from `BookingApi.http` (FR-001)
- [x] T007 `git mv tests/BookingApi.Tests tests/BookingApi.Api.Tests`, rename project and
  namespace, keep the smoke test pointed at `BookingApi.Api`; update `BookingApi.slnx`
- [x] T008 Update the paths in `CLAUDE.md` (Stack Profile), `docs/rulebooks/backend-rules.md`
  (Layering & Placement — now records ADR-001's layout and dependency rule) and
  `docs/sdlc/repository-strategy.md` (This repository); regenerate digests if any
  digest-marked line changed

**Checkpoint**: gate green, 3 test projects run, `pwsh -File scripts/ritual-checks.ps1` OK.

---

## Phase 2: Liveness, test infrastructure, OpenAPI (US1, US4)

**Goal**: `GET /health` answers per contract; Api tests run the real HTTP pipeline; the
OpenAPI document is Development-only.

**Independent Test**: `GET /health` → 200 `Healthy`; OpenAPI served in Development, 404
otherwise.

**Territory**:

- `src/BookingApi.Api/**`
- `tests/BookingApi.Api.Tests/**`

### Tests

- [x] T009 [US1] Add `Microsoft.AspNetCore.Mvc.Testing` 10.0.13 to `BookingApi.Api.Tests`
  (plan, Packages); add a `WebApplicationFactory<Program>`-based `ApiFactory` that can set
  the environment
- [x] T010 [P] [US1] `HealthEndpointTests`: `GET /health` → 200, `text/plain`, body `Healthy`
- [x] T011 [P] [US4] `OpenApiTests`: `GET /openapi/v1.json` → 200 in Development and lists
  `/health`; → 404 in Production
- [x] T026 [P] `DependencyRuleTests` in `BookingApi.Api.Tests`, reading the `.csproj` files as
  the phase 1 rule tests do (phase 1 review F2): Infrastructure references only Application;
  Api references only Application and Infrastructure

**Amendment approved by**: anas.m, 2026-10-18

### Implementation

- [x] T012 [US1] Add `src/BookingApi.Api/Health/` with the liveness mapping
  (`AddHealthChecks`, `MapHealthChecks("/health")` with a predicate that runs no checks)
- [x] T013 [US4] Keep `MapOpenApi()` behind `IsDevelopment()`; ensure the health endpoint
  appears in the document
- [x] T014 Replace the phase-1 smoke test if it is superseded by the HTTP tests

**Checkpoint**: gate green; US1 and US4 acceptance scenarios covered by tests.

---

## Phase 3: Problem details (US3)

**Goal**: unknown routes and unhandled exceptions return RFC 9457 problem details with no
exception data, in every environment.

**Independent Test**: unknown route → 404 problem details; forced exception → 500 problem
details without message or stack trace, also in Development.

**Territory**:

- `src/BookingApi.Api/**`
- `tests/BookingApi.Api.Tests/**`

### Tests

- [x] T015 [P] [US3] `ProblemDetailsTests`: unknown route → 404, `application/problem+json`,
  `status` 404, `traceId` present
- [x] T016 [P] [US3] `ProblemDetailsTests`: a test-only endpoint that throws (registered by
  the test factory, not by the app) → 500 problem details; body contains neither the
  exception message nor a stack trace; asserted in Development and Production

### Implementation

- [x] T017 [US3] Add `src/BookingApi.Api/Errors/` registering `AddProblemDetails`,
  `UseExceptionHandler` and `UseStatusCodePages` so the handler runs in every environment

**Checkpoint**: gate green; US3 acceptance scenarios covered.

---

## Phase 4: Database readiness (US2)

**Goal**: EF Core wired to the dedicated SQL Server database with an empty context;
`GET /health/ready` per contract; the owner can verify against real LocalDB.

**Independent Test**: stubbed ready check Healthy → 200, Unhealthy → 503 with body
`Unhealthy` only; by hand per `quickstart.md`: LocalDB up → 200, stopped → 503 within 5 s.

**Territory**:

- `src/BookingApi.Infrastructure/**`
- `src/BookingApi.Api/**`
- `tests/BookingApi.Api.Tests/**`

### Tests

- [x] T018 [P] [US2] `ReadinessTests`: replace the `ready`-tagged check with a stub; Healthy →
  200 `Healthy`, Unhealthy → 503 `Unhealthy`
- [x] T019 [P] [US2] `ReadinessTests`: with no connection string configured and the real
  check in place, the app starts, `GET /health` → 200 and `GET /health/ready` → 503 with no
  connection or exception text in the body
- [x] T020 [P] [US2] `HealthEndpointTests`: liveness stays 200 while the ready check is
  Unhealthy (spec US1 scenario 2)

### Implementation

- [x] T021 [US2] Add `Microsoft.EntityFrameworkCore.SqlServer` and
  `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore` 10.0.13 to
  `BookingApi.Infrastructure` (plan, Packages)
- [x] T022 [US2] `src/BookingApi.Infrastructure/Data/BookingDbContext.cs` — empty context, no
  `DbSet`, no migrations (FR-009)
- [x] T023 [US2] `src/BookingApi.Infrastructure/DependencyInjection.cs` — `AddInfrastructure`
  registers the context from connection string `BookingApi` and `AddDbContextCheck` tagged
  `ready` with a 5 s timeout; logs failures at Warning without the connection string
- [x] T024 [US2] Api: call `AddInfrastructure` in `Program.cs`; map `/health/ready` running
  only `ready` checks; `dotnet user-secrets init` on `BookingApi.Api` (adds `UserSecretsId`)
- [x] T025 [US2] `specs/001-solution-scaffold/quickstart.md`: create the empty `BookingApi`
  LocalDB database once, set the user secret
  (`Server=(localdb)\MSSQLLocalDB;Database=BookingApi;Trusted_Connection=True;Connect Timeout=5`),
  verify readiness up and down (SC-002)

- [x] T027 [US2] Pin `System.Security.Cryptography.Pkcs` 10.0.13 in `BookingApi.Infrastructure`
  to clear the transitive advisories that fail `--warnaserror` (plan, Packages; removal
  condition recorded there). Done together with T021.

**Amendment approved by**: anas.m, 2026-10-18

**Checkpoint**: gate green with no SQL Server; owner verifies SC-002 by hand.

---

## Dependencies & Execution Order

- Phases run strictly in order 1 → 2 → 3 → 4; each phase stops for the owner's gate.
- Phases 3 and 4 use the test factory from phase 2; revert newest-first.
- Within a phase, [P] tasks touch different files.

## After Phase 4

- Feature-level human review (`specs/_templates/human-pr-review-template.md`), PR to `main`,
  merge `--no-ff`, then flip the roadmap row to `shipped` and drop the brackets on its Spec
  cell (`docs/sdlc/branch-strategy.md`).
