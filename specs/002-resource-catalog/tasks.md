---

description: "Tasks for 002-resource-catalog"
---

# Tasks: Resource Catalog

**Input**: `specs/002-resource-catalog/` — spec.md (approved), plan.md (approved), data-model.md,
contracts/resources-api.md

**Tests**: required in every phase, written first and seen failing before the implementation
that makes them pass. Behaviour is tested at the layer that owns it: Domain rules in
Domain.Tests, use cases against a fake repository in Application.Tests, database behaviour
against real SQL Server in Infrastructure.Tests, the contract over HTTP in Api.Tests.

**Phase ritual** (every phase): implement → agent-run gate (feedback) → `git diff --stat`
review → commit with `phase N` in the subject → `pwsh -File scripts/scope-check.ps1` PASS →
**read the branch's CI run** (`ritual-checks` and `project-gate`) → fresh-context AI review
(`specs/002-resource-catalog/ai-code-review-phaseN.md`) → **stop: the owner runs the gate and
confirms the exit code** before the next phase starts. From phase 3 the gate needs Docker
running (plan, Design Notes).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Domain — the Resource entity

**Goal**: a `Resource` that can only be created valid, in a project with no framework
dependency.

**Independent Test**: `Resource.Create` accepts and trims valid input and returns field errors
for invalid input; nothing else in the solution is needed.

**Territory**:

- `src/BookingApi.Domain/**`
- `tests/BookingApi.Domain.Tests/**`

### Tests

- [x] T001 [P] [US1] `ResourceTests`: `Create` trims the name; accepts names of exactly 1 and
  exactly 100 characters; rejects blank, whitespace-only and 101-character names; accepts a
  null description and a 500-character one; rejects 501 characters; a whitespace-only
  description is treated as present text, not trimmed away (the contract only trims the name)
- [x] T002 [P] [US1] `ResourceTests`: a valid `Create` sets `CreatedAtUtc` and `UpdatedAtUtc`
  to the given instant and `CreatedBy` and `UpdatedBy` to `anonymous`; the new resource is not
  retired (`IsDeleted` false, `DeletedAtUtc` and `DeletedBy` null)
- [x] T003 [P] [US1] `ResourceTests`: invalid input returns one error per invalid field
  (`name`, `description`) and collects both when both are invalid; errors are keyed by the
  contract's field names

### Implementation

- [x] T004 [US1] `src/BookingApi.Domain/Resource.cs`: the entity (private constructor,
  read-only properties including the retirement marker) and the limits as named constants
- [x] T005 [US1] `Resource.Create(name, description, nowUtc)` returning the entity or the field
  errors (a small result type in Domain; no package)

**Checkpoint**: gate green; Domain still references no project and no package.

---

## Phase 2: Application — port and use cases

**Goal**: create, get and list as use cases over a repository port, with every expected
outcome explicit.

**Independent Test**: handlers run against a hand-written fake repository.

**Territory**:

- `src/BookingApi.Application/**`
- `tests/BookingApi.Application.Tests/**`

### Tests

- [x] T006 [P] [US1] `CreateResourceHandlerTests` against a fake repository and a controllable
  `TimeProvider`: valid input → `Created` carrying the stored resource with the clock's
  instants; invalid input → `Invalid` with the field errors and nothing added; name already
  present → `Duplicate` and nothing added; repository answers `Duplicate` on add (the race)
  → `Duplicate`
- [x] T007 [P] [US2] `GetResourceHandlerTests`: existing id → `Found`; unknown id → `NotFound`
- [x] T008 [P] [US3] `ListResourcesHandlerTests`: no parameters → page 1, size 50; `page` below 1
  or `pageSize` outside 1 to 100 → `Invalid` naming the parameter; valid parameters reach the
  repository unchanged; the result carries items, page, page size and total count

### Implementation

- [x] T009 [US1] `src/BookingApi.Application/Resources/`: `IResourceRepository` (add, get by
  id, list a page, name exists) and the page type
- [x] T010 [US1] The explicit outcome types for the three use cases
- [x] T011 [US1] `CreateResourceHandler`, `GetResourceHandler`, `ListResourcesHandler`

**Checkpoint**: gate green; Application still references only Domain and no framework package.

---

## Phase 3: Persistence — real SQL Server

**Goal**: the table, the mapping, the repository and the migration `ResourceCatalog`, proven
against real SQL Server in a throwaway container.

**Independent Test**: with Docker running, Infrastructure.Tests migrate an empty database and
exercise every constraint, the query filter, paging and a concurrent duplicate.

**Territory**:

- `src/BookingApi.Infrastructure/**`
- `tests/BookingApi.TestSupport/**`
- `tests/BookingApi.Infrastructure.Tests/**`
- `BookingApi.slnx`
- `.config/dotnet-tools.json`
- `CLAUDE.md`
- `README.md`
- `docs/rulebooks/backend-rules.md`
- `docs/rulebooks/database-rules.md`

### Tests

- [x] T012 [US1] Create `tests/BookingApi.TestSupport` (class library; `Testcontainers.MsSql`
  4.16.0): a collection fixture that starts one SQL Server container per test assembly and a
  helper that creates a uniquely named database in it and returns its connection string;
  add to `BookingApi.slnx`
- [x] T013 [US1] Create `tests/BookingApi.Infrastructure.Tests` (xUnit; references
  Infrastructure and TestSupport only); add to `BookingApi.slnx`; its `DependencyRuleTests`
  assert TestSupport references no BookingApi project and Infrastructure.Tests references only
  Infrastructure and TestSupport
- [x] T014 [P] [US1] `MigrationTests`: `Migrate()` applies to an empty database; migrating back
  to zero returns it to empty (SC-005)
- [x] T015 [P] [US1] `ConstraintTests` (raw SQL, so the database itself must refuse): an
  untrimmed or blank name; a name over 100 or a description over 500 characters; a retired
  row without its deletion data; `UpdatedAtUtc` before `CreatedAtUtc`
- [x] T016 [P] [US1] `ResourceRepositoryTests`: add then get round-trips every field; a name
  differing only by case collides (`Duplicate`); the same name is allowed once the earlier
  holder is retired (row retired through raw SQL)
- [x] T017 [P] [US2] `ResourceRepositoryTests`: retired rows are invisible to get, list and the
  name-exists check (query filter)
- [x] T018 [P] [US3] `ResourceRepositoryTests`: 100 inserted resources page as 50 and 50, each
  exactly once, ordered by name case-insensitively then id; a page past the end is empty with
  the true total; an offset beyond the int range is an empty page, not an overflow
- [x] T019 [P] [US1] `ResourceRepositoryTests`: many parallel adds of one name yield exactly
  one success and the rest `Duplicate`, never an exception (SC-003, database half)

### Implementation

- [x] T020 [US1] Add `Microsoft.EntityFrameworkCore.Design` 10.0.13 (`PrivateAssets=all`) to
  Infrastructure and the pinned `dotnet-ef` 10.0.13 local tool manifest
  (`.config/dotnet-tools.json`)
- [x] T021 [US1] Fluent mapping per `data-model.md`: table `Resources`, column types, filtered
  unique index `IX_Resources_Name`, the three check constraints, global query filter; add the
  `DbSet` to `BookingDbContext`
- [x] T022 [US1] `ResourceRepository` implementing the port; `AsNoTracking()` reads; unique-index
  violations (SQL Server errors 2601 and 2627) mapped to `Duplicate`; paging in 64-bit
  arithmetic
- [x] T023 [US1] Design-time `IDesignTimeDbContextFactory<BookingDbContext>` (scaffolding only)
  and the generated migration `ResourceCatalog`; read the generated SQL against
  `data-model.md` before committing
- [x] T024 [US1] Register the repository in `AddInfrastructure`; liveness and readiness stay
  unchanged
- [x] T025 Record the Docker prerequisite in `CLAUDE.md` (Stack Profile, known failure modes),
  `README.md`, the backend rulebook (Testing) and the database rulebook (Setup: tests use
  throwaway containers and never the developer's `BookingApi` LocalDB database)

**Checkpoint**: gate green with Docker running, all constraint and concurrency tests passing.

---

## Phase 4: API — endpoints, end-to-end tests, quickstart

**Goal**: the three endpoints of `contracts/resources-api.md`, proven over HTTP against real
SQL Server, plus the owner's by-hand verification.

**Independent Test**: create, fetch and page through resources over HTTP; every error is
problem details.

**Territory**:

- `src/BookingApi.Api/**`
- `tests/BookingApi.Api.Tests/**`

### Tests

- [ ] T026 [US1] Api.Tests references TestSupport (project reference; the dependency-rule test
  for Api.Tests is unaffected); a `ResourceApiFactory` that points the app at a fresh
  migrated database in the container
- [ ] T027 [P] [US1] `CreateResourceTests`: 201 with `Location` and the stored resource;
  absent description → null; duplicate by case and by surrounding whitespace → 409 problem
  details; missing, blank and over-long name and over-long description → 400
  `ValidationProblemDetails` naming each field; empty body, malformed JSON and wrong JSON
  types → 400 problem details
- [ ] T028 [P] [US2] `GetResourceTests`: 200; unknown id → 404; retired id (retired through raw
  SQL) → 404; non-numeric id → 404 problem details
- [ ] T029 [P] [US3] `ListResourcesTests`: defaults; 100 resources page as 50 and 50 with
  `totalCount` 100 (SC-002); a page past the end is 200 and empty with the true total;
  non-numeric and out-of-range `page` and `pageSize` → 400 naming the parameter; retired
  resources excluded; order by name case-insensitively
- [ ] T030 [P] [US1] `ConcurrentCreateTests`: two simultaneous requests creating one name give
  exactly one 201 and one 409 and no 5xx, repeated at least 10 times (SC-003)
- [ ] T031 [P] [US1] `ErrorShapeTests`: every error response in T027 to T029 is
  `application/problem+json`, with no HTML and no stack trace (SC-004)
- [ ] T032 [P] [US1] `OpenApiTests`: the Development OpenAPI document lists `/resources` and
  `/resources/{id}`

### Implementation

- [ ] T033 [US1] `src/BookingApi.Api/Features/Resources/`: the endpoint group (`POST`, `GET {id}`,
  `GET`), request and response DTOs, mapping of the use-case outcomes to the contract's
  statuses and bodies, field errors to `ValidationProblem`, `Location` header
- [ ] T034 [US1] Register the three handlers in `Program.cs` (the composition root) and map the
  group; malformed bodies and bad query values answer through the baseline problem-details
  pipeline (a framework default that answers differently is fixed here)
- [ ] T035 `specs/002-resource-catalog/quickstart.md`: apply the migration to the local
  `BookingApi` database with the pinned tool, run the API, create and list a resource with
  `curl.exe`, and verify the table and constraints with `sqlcmd` (SC-005 by hand)
- [ ] T036 `specs/002-resource-catalog/rollback.md`: one revert per phase, newest first;
  the migration's `down` only while the table is empty, else leave the table (data-model.md)

**Checkpoint**: gate green with Docker running; the owner verifies SC-005 by hand.

---

## Dependencies & Execution Order

- Phases run strictly 1 → 2 → 3 → 4; each phase stops for the owner's gate.
- Phase 2 uses the entity from phase 1; phase 3 implements the phase 2 port; phase 4 calls the
  phase 2 handlers over the phase 3 repository. Revert newest first.
- Within a phase, [P] tasks touch different files.

## After Phase 4

- Feature-level human review (`specs/_templates/human-pr-review-template.md`), PR to `main`,
  merge `--no-ff`, then flip the roadmap row to `shipped` and drop the brackets on its Spec
  cell (`docs/sdlc/branch-strategy.md`).
