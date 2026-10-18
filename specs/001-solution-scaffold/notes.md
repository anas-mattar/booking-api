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
