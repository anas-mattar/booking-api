# Notes: 001-solution-scaffold

Evidence and observations. Ungraded by design (`docs/sdlc/branch-strategy.md`): recording it
never costs an approval.

## Phase 1

- **Test-first (review F3)**: the Domain dependency-rule test was written before
  `src/BookingApi.Domain` existed and run: it failed (`LoadProject` could not find
  `src/BookingApi.Domain/BookingApi.Domain.csproj`). The libraries were then created and the
  tests went green.
- **The rule bites**: adding `Microsoft.AspNetCore.OpenApi` to `BookingApi.Application` made
  `ApplicationReferencesNoWebOrPersistencePackages` fail; restoring the project file made it
  pass again. (A first mutation attempt, referencing Infrastructure from Application, proved
  nothing: it is a circular reference, so the build failed before any test ran.)
- **Phase size**: enforcement-pack warns that commit 9c9fa5f touches 21 files (guideline 15);
  the excess is renames and project scaffolding, one coherent slice.
- **Review F1/F2 (owner decisions pending)**: the dependency-rule tests read `.csproj` XML
  rather than `GetReferencedAssemblies()` as T001/T002 word it, and the Infrastructure and Api
  rules of ADR-001 have no test.

### Phase 1 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (7 projects
built, 4 of 4 tests passed), on commit `5ded1b0` (phase 1 is `9c9fa5f`) - anas.m, 2026-10-18.

### Review decisions (phase 1)

- **F1 accepted**: the dependency-rule tests check project and package references from the
  `.csproj` files, not `GetReferencedAssemblies()`. Accepted as is by anas.m, 2026-10-18; the
  known blind spots (rules leaked through `Directory.Build.props`, or a switch to the web SDK)
  are accepted with it. No document is amended.
- **F2 accepted as a phase 2 addition**: tests for the Infrastructure and Api rules, added to
  phase 2 as T026 by an owner-approved `tasks.md` amendment (anas.m, 2026-10-18).
- **F5 (doc drift) left open**: the backend rulebook's MUST bullet omits the "Api references
  Infrastructure for registration only" exception, which the bullet above it states.

## Phase 2

- **Test-first (review F8)**: the tests were written and run before the implementation:
  `LivenessReturnsHealthyAsPlainText` and `DevelopmentServesTheDocumentAndListsHealth` failed
  (2 failed, 4 passed). The two dependency-rule tests and the Production-404 test passed
  already, since phase 1 satisfied them; they are guards, not new behaviour. After `/health`
  was mapped, only the OpenAPI test still failed, because `MapHealthChecks` endpoints are
  not in the generated OpenAPI document (tasks T013 anticipated this). A document
  transformer now adds `/health` to it, keeping the plan's `MapHealthChecks` mechanism.
- **Review F1 (MINOR, open)**: the transformer hand-writes the `/health` entry, the test only
  checks the substring, and the entry declares no `text/plain` content. To tighten in a later
  phase (share the route constant, assert the content type).
- **Review F5 (MINOR, open)**: `HealthEndpoints` and `HealthOpenApi` are public and could be
  internal. Optional.

### Phase 2 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (8 of 8 tests
passed), on commit `3efa791` (phase 2 is `7e4debb`) - anas.m, 2026-10-18.

## Phase 3

- **Test-first**: the four new cases (unknown route and unhandled exception, each in
  Development and Production) failed before `src/BookingApi.Api/Errors/` existed (4 failed,
  5 passed), and passed after (9 of 9). The reviewer additionally removed `UseExceptionHandler`
  and `UseStatusCodePages` in turn: the 500 tests and the 404 tests failed respectively, so
  each test guards the line it is named for. Both files were restored.
- **Review F1 (MINOR, open)**: the `" at "` stack-trace assertion is a heuristic; the real
  500 body is exactly `type`, `title`, `status`, `traceId`. A later test can assert that
  property set structurally.
- **Review F2 (MINOR, open, outside phase 3)**: `POST /health` answers 200, since
  `MapHealthChecks` has no verb restriction. Not HTML or a stack trace, so SC-003 holds.
- **Review F4 (MINOR)**: SC-003 is demonstrated for 404 and 500 only; no 400 path exists yet.
  The first feature with request validation proves it for 400.

### Phase 3 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (12 of 12 tests
passed), on commit `a90c52f` (phase 3 is `1fda1ee`) - anas.m, 2026-10-18.

## Phase 4

- **Test-first**: the three readiness tests failed before the implementation (3 failed,
  10 passed); the liveness-while-unhealthy test passed already and is a guard. After: 16 of 16
  tests across three assemblies.
- **Strict build and a transitive advisory**: adding the EF Core SQL Server provider (10.0.13,
  the latest) pulled `System.Security.Cryptography.Pkcs` 9.0.11 with advisories
  GHSA-2fmv-rv2c-59x7 and GHSA-846f-f764-76mx, and `--warnaserror` failed (6 errors).
  Triage per `docs/sdlc/gate-command.md`: no newer direct dependency exists, so the patched
  version is pinned (step 2): plan and tasks amended by the owner (anas.m, 2026-10-18,
  commit e996d3a), T027. A trial of the pin gave 0 errors, 0 warnings.
- **Real run against LocalDB** (database `BookingApi` not yet created): `/health` 200 in 2 ms;
  `/health/ready` 503 `Unhealthy` in 2.5 s; unknown route a problem-details 404; no
  connection string in the logs. The reviewer additionally ran an unroutable host with a 15 s
  connect timeout: the check was cut at 5.0 s, still 503.
- **Review F1 (CONFIRM, owner decision pending)**: contract Audit section and T023 say a failed
  readiness check is logged at Warning. Nothing in the code logs it; the framework's
  `DefaultHealthCheckService` logs it at Error. No connection string reaches the log.
- **Review F4 (CONFIRM, owner decision pending)**: spec SC-002 says "with LocalDB stopped"
  but LocalDB restarts itself on the next connection, so `quickstart.md` takes the database
  OFFLINE instead. That exercises the fast-fail path, not the 5 s hang (which the reviewer
  covered with an unroutable host).
- **Review F2/F3/F5/F6/F7/F8 (MINOR)**: the stub tests register one `ready` check so they
  cannot detect an over-broad predicate; no test asserts the 5 s timeout; the cold first
  request took about 5.4 s end to end; failures log `message '(null)'`; the quickstart's
  DROP DATABASE has no "only if you created it" guard and its connection string carries
  `TrustServerCertificate=True`.

### Phase 4 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (16 of 16 tests
passed), on commit `96a6b68` (phase 4 is `6f4a5cb`) - anas.m, 2026-10-18.
