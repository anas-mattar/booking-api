# AI Code Review — 001 Solution Scaffold, Phase 1 (Clean Architecture layout, ADR-001)

**Reviewer**: fresh-context agent — claude-sonnet-5-5
**Date**: 2026-10-18
**Branches**: booking-api `001-solution-scaffold` (phase commit `9c9fa5f`; branch tip `5ded1b0`, which only ticks T001-T008)
**Scope reviewed**: `git show -M --stat` and full `git show` of 9c9fa5f; every `.csproj` and `BookingApi.slnx`; `Program.cs`, `BookingApi.http`, `launchSettings.json`, `ScaffoldSmokeTests.cs`, both `DependencyRuleTests.cs`; diffs of `CLAUDE.md`, `docs/rulebooks/backend-rules.md`, `docs/sdlc/repository-strategy.md`; spec.md, plan.md (ADR-001, Packages), tasks.md (Phase 1 + Territory), contracts/http-baseline.md, constitution IV/VIII/IX/X, definition-of-done and review-process (skimmed for gates); `git grep` across all tracked files for stale paths and WeatherForecast.
**Feature contract**: ADR-001 four-project layout; dependency rule Api→Application→Domain, Infrastructure→Application, Api→Infrastructure for registration only; no new package in phase 1 (plan.md "Packages": none approved for phase 1); no health/problem-details/EF Core/Mvc.Testing in this phase.

## Reviewer Provenance

<!-- MANDATORY (Definition of Done gate 5): the review MUST be produced by a reviewer that
  did not write the code — a fresh-context agent session or a second model. A review
  self-graded by the implementing agent in the same context is invalid.
  scripts/enforcement-pack.ps1 fails the branch when a review file added on it lacks this
  section, leaves the Reviewer line unfilled, names the implementer as reviewer, or omits
  the attestation sentence verbatim. Reviews committed before the verification pack are
  grandfathered (only files ADDED in the branch's diff are checked). -->

- **Reviewer**: fresh-context agent — claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 / Claude Opus 5.5 session (the implementing agent session that produced commit 9c9fa5f)
- **Inputs provided**: commit 9c9fa5f diff and stat; specs/001-solution-scaffold/{spec,plan,tasks}.md and contracts/http-baseline.md; .specify/memory/constitution.md; docs/rulebooks/backend-rules.md; docs/domain/booking-invariants.md; docs/sdlc/definition-of-done.md and review-process.md; the repository at the branch tip (build, test and script runs)
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — Phase 1 creates exactly the four source and three test projects ADR-001 specifies, with the project references the ADR requires, no new packages, the weatherforecast sample removed, and governance paths updated accurately. Gate commands, scope-check and ritual-checks all pass. The dependency-rule tests are not vacuous and would fail on a forbidden direct ProjectReference or PackageReference. Residual risk is that they read `.csproj` XML rather than assembly references (a deviation from the approved wording, F1) and so miss a `FrameworkReference`/SDK-based leak, and that the Infrastructure and Api rules of ADR-001 are unguarded (F2). Neither blocks the phase as tasked.

## What was verified (evidence)

> Every claim needs evidence — a file/symbol read, a test observed, a query run. A row
> without evidence is an assumption, not a verification.

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | FR-001 (no sample): `Program.cs` now only `AddOpenApi`, `MapOpenApi` in Development, `UseHttpsRedirection`, `Run`; `BookingApi.http` holds only the host variable; `git grep -i weatherforecast` hits only tasks.md (T006 text). Projects match the ADR-001 table. Phase 2-4 content absent: no health endpoints, problem details, EF Core, or Mvc.Testing. |
| Visual-reference match (where references exist): Visual Compliance Loop deviation table attached, empty or user-approved (`docs/sdlc/review-process.md`) | N/A — no UI or visual references exist. |
| Feature contract held (no unapproved table/migration/permission/package) | Every PackageReference inspected: Api has only `Microsoft.AspNetCore.OpenApi 10.0.11` (kept from adoption scaffold); each test project has only the `dotnet new xunit` set (coverlet.collector 6.0.4, Test.Sdk 17.14.1, xunit 2.9.3, runner 3.1.4). Domain/Application/Infrastructure: no packages. No migration, table or permission. ProjectReferences: Domain none; Application→Domain; Infrastructure→Application; Api→Application+Infrastructure; Domain.Tests→Domain; Application.Tests→Application; Api.Tests→Api. All exact per ADR-001. `BookingApi.slnx` lists all 7 projects under /src/ and /tests/ with correct paths. |
| Constitution / domain invariants | IV: layout is the ADR-approved one; no package added. VIII: no business logic exists; dependency rule has tests (see Test coverage). X: one phase, one commit with a `phase 1` subject. No booking invariant touched (no entities). |
| Security (authn/authz, secrets, sensitive logging) | No endpoints, secrets or logging added. `launchSettings.json` is a 100% rename (localhost ports only). |
| Scope guard (`scope-check.ps1` PASS on the phase commit; `git diff --stat` read for intent) | `scope-check.ps1` at HEAD: `PASS phase 1 commit 5ded1b0 (1 file(s))` (that is the tick commit). `scope-check.ps1 -Commit 9c9fa5f`: `PASS phase 1 commit 9c9fa5f (27 file(s))`. `ritual-checks.ps1`: doc-lint OK, enforcement-pack OK, scope-check OK, scope-repos n/a, digests OK, roadmap-claims OK, verify-kit OK, RESULT OK. Stat read: 21 entries, all inside Territory; no digest change needed. |
| Rollback safety (phase reverts cleanly; schema additive?) | No schema. Single commit touching only layout, tests and docs; `git revert 9c9fa5f` restores the single-project layout. Renames recorded (see F4). |
| Build and test | `dotnet build BookingApi.slnx --warnaserror`: Build succeeded, 0 warnings, 0 errors. `dotnet test BookingApi.slnx --no-build`: Domain.Tests 1 passed, Application.Tests 2 passed, Api.Tests 1 passed; 0 failed. |
| Governance edits accurate | CLAUDE.md Stack Profile source roots now `src/BookingApi.{Domain,Application,Infrastructure,Api}/`, `tests/BookingApi.*.Tests/` — all resolve. backend-rules.md Layering restates ADR-001 and cites plan.md; repository-strategy.md lists the real directories. Gate command text unchanged and still correct. `git grep` for `src/BookingApi/`, `BookingApi.Tests`, `weatherforecast` outside specs/001 returned nothing (covers .github, README.md, AGENTS.md, global.json, kit-adoption.json, digests); inside specs/001 the hits are the approved plan/tasks text describing the migration itself. |
| Git hygiene | `.gitignore` has `bin/` and `obj/`; no bin/obj tracked; working tree unchanged by build/test. Renames recorded for Properties/launchSettings.json, appsettings*.json (100%), Api.Tests csproj (88%) and ScaffoldSmokeTests.cs (59%). |

## Findings

### F1 — Dependency-rule tests inspect csproj XML, not assembly references; framework leaks pass undetected — CONFIRM

ADR-001 Consequences says enforcement is by "assembly-reference tests ... `Assembly.GetReferencedAssemblies`", and T001/T002 say "the `BookingApi.Domain` assembly references no ... `Microsoft.AspNetCore.*` / `Microsoft.EntityFrameworkCore*` assembly". The implementation instead loads `src/.../*.csproj` with `XDocument` and checks direct `ProjectReference`/`PackageReference` items. It is not vacuous (exact `Assert.Equal(["BookingApi.Domain"], references)`, `Assert.Empty` on both item types, and `Assert.NotNull(dir)` guards the slnx search, so a missing path fails rather than passes). But it misses: a `<FrameworkReference Include="Microsoft.AspNetCore.App"/>` or switching Domain/Application to `Sdk="Microsoft.NET.Sdk.Web"` (both pull ASP.NET Core assemblies without any PackageReference); packages or references injected via `Directory.Build.props`/`Directory.Packages.props` or imported targets; and transitive package leakage. The Domain test checks neither FrameworkReference nor the Sdk attribute. The tests also do not use the compiled assembly, so the ADR's stated mechanism was not followed.
*Action: Owner decides — either accept the csproj-based approach and record the deviation through an owner-approved plan.md amendment, or have a later phase add a `GetReferencedAssemblies()` assertion for `Microsoft.AspNetCore*`, `Microsoft.EntityFrameworkCore*` and BookingApi.* names (needs a marker type in each library). Reviewer made no code change.*

### F2 — ADR-001 Infrastructure and Api rules have no test — MINOR

Only the Domain and Application rules are tested, which is all T001/T002 require. Nothing guards "Infrastructure references only Application" or "Api references Application and Infrastructure only". plan.md says "Each rule is a test (phase 1)", which is stronger than the tasks. The Application exact-match test does cover Application→Infrastructure/Api.
*Action: Owner decides whether to add Infrastructure/Api rule tests (for example in Api.Tests, when phase 2 adds its test infrastructure); judged against the approved tasks this is not a defect.*

### F3 — Test-first evidence not available — MINOR

tasks.md requires tests "seen failing before the implementation". The phase is one commit, so red-then-green cannot be confirmed from history. The tests exercise real conditions and I believe they would fail against a violating csproj, but I did not mutate a tracked file to prove it.
*Action: Implementer states in the PR or phase notes how the failing run was observed, or the owner accepts.*

### F4 — Git rename pairing misleading for the Api csproj — MINOR

`git show -M` pairs `src/BookingApi/BookingApi.csproj` with `src/BookingApi.Application/BookingApi.Application.csproj` (62%) and shows `BookingApi.Api.csproj`, `BookingApi.http` and `Program.cs` as new files, so `git log --follow` on the Api project file will follow the Application library instead. Content is correct; this is history cosmetics only (Program.cs shows as 14 added and 41 deleted under separate paths).
*Action: none — the T003 intent is satisfied on disk; noted for reviewers reading the stat.*

### F5 — Rulebook adds MUST rules beyond a pure path update — DOC DRIFT

backend-rules.md now carries "An endpoint MUST call an Application use case and MUST NOT use the DbContext directly" and the inward-dependency MUST rule. These come from ADR-001 Consequences, agree with the constitution and booking-invariants, and T008 says the Layering section "now records ADR-001's layout and dependency rule". One nuance: the MUST bullet lists `Api → Application → Domain` and `Infrastructure → Application` but the `Api → Infrastructure (registration only)` exception appears only in the preceding bullet, so that bullet read alone slightly under-states the allowed graph. No contradiction found.
*Action: none required; optionally add "Api → Infrastructure for registration only" to the MUST bullet when the rulebook is next edited.*

### F6 — Leftover template artefacts are benign — MINOR

`BookingApi.http` keeps the `@BookingApi_HostAddress` variable (port 5132, matches `launchSettings.json`). `launchSettings.json` and several csproj files carry a UTF-8 BOM, and Application/Infrastructure place `ItemGroup` before `PropertyGroup` (template quirk). No functional effect; the build is warning-free.
*Action: none.*

## Amendments in this diff

<!-- Constitution I, Amendment authority: list every change this phase made to the feature's
  own spec.md, plan.md, tasks.md or contracts/, with the approver each one records. A phase
  that rewrote its own plan changed the standard it is being graded against, and a review
  that does not say so is grading the work against a marking scheme the worker rewrote.
  "None" is a valid and common answer — say it explicitly rather than omitting the section. -->

- [x] Amendments listed, or **none** stated explicitly

**None.** `git show --stat 9c9fa5f` touches no file under `specs/`; spec.md, plan.md, tasks.md and contracts/ are unchanged by this phase (the only later change on the branch, 5ded1b0, ticks the T001-T008 checkboxes). The governance edits (CLAUDE.md, backend-rules.md, repository-strategy.md) are the ones plan.md "Structure Decision" and T008 pre-authorise. F1 records a deviation from approved wording that is not an amendment, but one the owner should either accept explicitly or amend.

## Constitution re-check (post-implementation)

**PASS.** I (Specification First): nothing outside approved spec/plan/tasks; no approved document edited. II: spec, plan and layout agree. III: N/A, single repository. IV (Architecture Consistency): layout matches ADR-001 exactly; no package beyond the adoption scaffold; bootstrap clause applied correctly. V: N/A, no entities. VI: N/A, nothing exposed. VII: N/A. VIII (Testing): no business logic; dependency rule tested for Domain and Application (partial, see F1/F2). IX: this review plus human PR review pending. X (Controlled Delivery): single phase commit with `phase 1`, scope-check PASS on that commit; owner gate confirmation still required before phase 2.

## Test coverage observed

- `BookingApi.Domain.Tests` — 1 test: `DomainReferencesNoProjectsAndNoPackages` (no ProjectReference and no PackageReference in the Domain csproj).
- `BookingApi.Application.Tests` — 2 tests: `ApplicationReferencesOnlyDomain` (exact project-reference list equals `["BookingApi.Domain"]`) and `ApplicationReferencesNoWebOrPersistencePackages` (no `Microsoft.AspNetCore*` / `Microsoft.EntityFrameworkCore*` PackageReference).
- `BookingApi.Api.Tests` — 1 smoke test: `typeof(Program).Assembly` name equals `BookingApi.Api`.
- Total 4 passed, 0 failed. Path discovery walks up from `AppContext.BaseDirectory` to the directory containing `BookingApi.slnx` and asserts it was found, so it works under the gate and CI and cannot silently pass on a bad path. Empty libraries do not make the tests vacuous because they inspect project files, not types.

## Residual risk

Low. Risk concentrates in F1 (tests can be bypassed by a FrameworkReference or Sdk change, and differ from the ADR's stated mechanism) and F2 (two ADR rules unguarded). Neither blocks phase 2 as tasked; recommend the owner decide F1 before the layers gain real code, and that the human PR review check the rulebook wording (F5). Merge is subject to the owner running the gate and confirming the exit code per the phase ritual.
