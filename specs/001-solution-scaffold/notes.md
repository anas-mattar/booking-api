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
