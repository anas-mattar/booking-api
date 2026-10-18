# AI Code Review — 001 Solution Scaffold, Phase 2 (liveness, test infrastructure, OpenAPI)

**Reviewer**: fresh-context agent — claude-sonnet-5-5
**Date**: 2026-10-18
**Branches**: booking-api `001-solution-scaffold` (phase commit `7e4debb`; branch tip `45cc075`, which only ticks T009-T014 and T026)
**Scope reviewed**: `git show --stat` and full `git show` of 7e4debb (HealthEndpoints.cs, HealthOpenApi.cs, Program.cs, ApiFactory.cs, Api.Tests csproj, DependencyRuleTests.cs, HealthEndpointTests.cs, OpenApiTests.cs, deleted ScaffoldSmokeTests.cs); `BookingApi.Api.csproj`, `launchSettings.json`, `appsettings*.json`; spec.md (US1, US4, FR-002, FR-007, FR-010), plan.md (ADR-001, Design Notes, phase table), tasks.md (Phase 2, Territory, T026 amendment record), contracts/http-baseline.md; d9bd395 (T026 amendment commit); ai-code-review-phase1.md; `git log`/`git diff --stat` of specs/ between phase 1 and phase 2; build, test, scope-check and ritual-checks runs; reflection on the built Api assembly for `Program` visibility.
**Feature contract**: ADR-001 layout; phase 2 adds only `GET /health` (no checks run), a WebApplicationFactory-based test host, Development-only OpenAPI listing `/health`, and Infrastructure/Api dependency-rule tests (T026); the single permitted new package is `Microsoft.AspNetCore.Mvc.Testing` 10.0.13 in `BookingApi.Api.Tests`; no problem details, EF Core or readiness endpoint.

## Reviewer Provenance

<!-- MANDATORY (Definition of Done gate 5): the review MUST be produced by a reviewer that
  did not write the code — a fresh-context agent session or a second model. A review
  self-graded by the implementing agent in the same context is invalid.
  scripts/enforcement-pack.ps1 fails the branch when a review file added on it lacks this
  section, leaves the Reviewer line unfilled, names the implementer as reviewer, or omits
  the attestation sentence verbatim. Reviews committed before the verification pack are
  grandfathered (only files ADDED in the branch's diff are checked). -->

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 / Claude Opus 5.5 session (the implementing agent session that produced commit 7e4debb)
- **Inputs provided**: commit 7e4debb diff and stat; specs/001-solution-scaffold/{spec,plan,tasks,notes}.md, contracts/http-baseline.md and ai-code-review-phase1.md; commit d9bd395; the review template; the repository at the branch tip (build, test and script runs). The constitution and rulebooks/SDLC documents were not re-read in full; their relevant gates were taken from the plan's Constitution Check and the phase 1 review.
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — Phase 2 adds exactly what T009-T014 and T026 list: a liveness endpoint (`MapHealthChecks("/health", Predicate = _ => false)`), an `ApiFactory` that runs the real pipeline in a chosen environment, Development-only OpenAPI that documents `/health` through a document transformer, and csproj-based dependency tests for Infrastructure and Api. The one new package is the approved one, nothing from phases 3-4 is present, the phase is inside its Territory, and no approved feature document was changed beyond checkbox ticks. Build (warnings as errors), tests (8 passed), scope-check and ritual-checks all pass. Residual risk: the `/health` OpenAPI entry is hand-written and no test ties it to the real endpoint (F1), and the "never consults the database" claim is guaranteed by the predicate but only proven by a test in phase 4 (F2). Neither blocks the phase as tasked.

## What was verified (evidence)

> Every claim needs evidence — a file/symbol read, a test observed, a query run. A row
> without evidence is an assumption, not a verification.

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | FR-002 / contract: `HealthEndpoints.MapHealth` maps `/health` with `HealthCheckOptions { Predicate = _ => false }`; default writer returns 200 `text/plain` `Healthy`. `HealthEndpointTests` asserts 200, `StartsWith("text/plain")` and body exactly `Healthy` (passes). FR-007: `Program.cs` keeps `MapOpenApi()` inside `IsDevelopment()`; `OpenApiTests` asserts 200 + `"/health"` in Development and 404 in Production (both pass). FR-010 (HTTP pipeline, no DB): tests go through `WebApplicationFactory`; no database exists or is needed. Phases 3-4 content absent: no `AddProblemDetails`/`UseExceptionHandler`, no EF Core, no `/health/ready`. |
| Visual-reference match (where references exist): Visual Compliance Loop deviation table attached, empty or user-approved (`docs/sdlc/review-process.md`) | N/A — no UI or visual references. |
| Feature contract held (no unapproved table/migration/permission/package) | `git show 7e4debb` csproj diff adds only `Microsoft.AspNetCore.Mvc.Testing 10.0.13` to `BookingApi.Api.Tests`. `BookingApi.Api.csproj` still has only `Microsoft.AspNetCore.OpenApi 10.0.11` (unchanged since phase 1). `Microsoft.OpenApi` types used by the transformer arrive transitively via `Microsoft.AspNetCore.OpenApi`, not a new reference. No migration, table or permission. |
| Constitution / domain invariants | IV: no package beyond the plan's list for this phase; layout per ADR-001. VIII: every endpoint has an HTTP test (`/health`, `/openapi/v1.json`), dependency rule has tests. X: one phase commit with `phase 2` subject. V: no entity, no invariant touched. |
| Security (authn/authz, secrets, sensitive logging) | `/health` is public by design (contract, Authentication section) and returns only `Healthy`; `Predicate = _ => false` means no check output or exception text can reach the body. No secrets, connection strings or logging added. The OpenAPI document is not served outside Development (negative test). `launchSettings.json` untouched. |
| Scope guard (`scope-check.ps1` PASS on the phase commit; `git diff --stat` read for intent) | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit 7e4debb` -> `PASS phase 2 commit 7e4debb (9 file(s))`, exit 0. All 9 files are under `src/BookingApi.Api/**` or `tests/BookingApi.Api.Tests/**` (Phase 2 Territory); no stray files. `ritual-checks.ps1`: doc-lint OK, enforcement-pack OK, scope-check OK, scope-repos n/a, digests OK, roadmap-claims OK, verify-kit OK, RESULT OK. |
| Rollback safety (phase reverts cleanly; schema additive?) | No schema. The commit touches only Api health files, Program.cs (+7/-1), and Api.Tests files; phase 1 left Program.cs as `AddOpenApi/MapOpenApi/UseHttpsRedirection/Run`, so `git revert 7e4debb` restores that exactly and restores the smoke test. Phases 3-4 are not yet present, so there is nothing newer to revert first. |
| Build and test | `dotnet build BookingApi.slnx --warnaserror`: Build succeeded, 0 warnings, 0 errors. `dotnet test BookingApi.slnx --no-build`: Domain.Tests 1 passed, Application.Tests 2 passed, Api.Tests 5 passed (2 DependencyRule, 1 Health, 2 OpenApi); 0 failed. |
| Environment honoured by ApiFactory | `ApiFactory.ConfigureWebHost` calls `builder.UseEnvironment(environment)`; the Production OpenApi test returns 404 while the Development one returns 200 on the same URL, so the environment demonstrably switches behaviour (both passed). `Program.cs` reads `app.Environment` at runtime, which is what the factory sets. |
| HTTPS redirection in test host | `Program.cs` calls `UseHttpsRedirection()`, but no HTTPS port is configured in the test host (`launchSettings.json` is not read by `WebApplicationFactory`), so the middleware does not redirect; the passing tests with a default `CreateClient()` (http://localhost) confirm no 307. An https `ASPNETCORE_HTTPS_PORT`/`ASPNETCORE_URLS` in a CI environment could change this (F4). |
| Program accessibility | Reflection on the built `BookingApi.Api.dll`: `Program.IsPublic = True`. The source has no `partial class Program` and no `InternalsVisibleTo`, so the public type comes from the SDK/toolchain, not hand-written visibility. The only types made public by the phase are the two static extension classes in `BookingApi.Api.Health` (F5). |
| Amendment record (T026) | `git show d9bd395`: tasks.md +5 lines adds T026 and the line `**Amendment approved by**: anas.m, 2026-10-18`; the commit body repeats `Amendment approved by: anas.m, 2026-10-18`; notes.md (d29c4b1) records F1 accepted and F2 moved into phase 2 (anas.m). Format matches the approved-by convention and names the owner. |

## Findings

### F1 — Hand-written `/health` OpenAPI entry can drift and no test guards it — MINOR

`HealthOpenApi.AddHealthDocumentation` writes a literal `"/health"` path item with a fixed summary, description and a `200 Healthy` response. `MapHealthChecks` endpoints carry no HTTP-method or produces metadata, so the generated document omits them; the transformer fills that gap. The implementer kept `MapHealthChecks` (the mechanism plan Design Notes and T012 name: "`/health` maps with a predicate that runs no checks") instead of swapping to `MapGet`. I judge this a reasonable reading of T013 ("ensure the health endpoint appears in the document") and not a plan deviation: T012 and the plan specify `MapHealthChecks`, T013 only requires presence in the document, and the transformer is inside `src/BookingApi.Api/**`. No amendment was needed. The weaknesses are: (a) the path string and the response description are duplicated in two places (`HealthEndpoints.MapHealth` and the transformer), so renaming the route or changing the body would leave the document stale with all tests green; (b) `OpenApiTests` only asserts the substring `"/health"`, which would also pass for a wrong method, status or description; (c) the entry declares no `text/plain` content, so the document is less informative than the contract (200 `text/plain`, body `Healthy`); (d) the transformer runs in every environment (harmless, the document is only served in Development). It is honest for what exists today (GET, 200 Healthy), and phase 4's `/health/ready` will need the same treatment.
*Action: implementer, in phase 4 when `/health/ready` is added (or earlier if the owner wishes), share the route constant between the mapping and the transformer and tighten the OpenAPI test to assert the GET operation, the 200 response and `text/plain`; owner may accept as is for phase 2.*

### F2 — "Never consults the database" is guaranteed by the predicate but not proven by a phase 2 test — MINOR

`Predicate = _ => false` makes the health-check middleware run zero registered checks, so any check registered later (including the phase 4 `ready`-tagged `AddDbContextCheck`) cannot execute on `/health`, and the response is always `Healthy`. That is a sound guarantee by construction. The phase 2 test cannot prove it because no check or database exists: `HealthEndpointTests` only asserts 200/`text/plain`/`Healthy` and would still pass if the predicate were removed (with no checks registered the default also yields `Healthy`). The regression that matters (an Unhealthy check must not affect liveness) is covered only by T020 in phase 4 ("liveness stays 200 while the ready check is Unhealthy"). That is scheduled and legitimate, but until phase 4 the predicate is untested.
*Action: none for phase 2 as tasked; the phase 4 reviewer confirms T020 exists and fails when the predicate is removed. Optionally add a phase 2 test that registers an always-Unhealthy check through a test-only factory override and asserts `/health` stays 200.*

### F3 — OpenAPI negative test alone would also pass on a broken app — MINOR

`ProductionDoesNotServeTheDocument` asserts 404 only, and 404 is what any unmapped URL returns. It is meaningful only together with `DevelopmentServesTheDocumentAndListsHealth` hitting the identical URL and returning 200, which it does (both pass), so the pair is not vacuous. If the document name ever changed, the Development test would fail rather than pass falsely.
*Action: none.*

### F4 — Test-host environment sensitivity (HTTPS redirection, ports, ASPNETCORE_ENVIRONMENT) — MINOR

`WebApplicationFactory` uses an in-memory `TestServer`: no real ports are bound and `launchSettings.json` is ignored, so the tests are not port dependent. The environment is set explicitly by `ApiFactory`, so an inherited `ASPNETCORE_ENVIRONMENT` on a developer machine or CI cannot change the outcome. `UseHttpsRedirection` does not redirect here because no HTTPS port is known (observed: default `HttpClient` calls got 200, not 307). Residual: if a CI image sets `ASPNETCORE_HTTPS_PORT` or `ASPNETCORE_URLS` with an https address, the redirect middleware could start answering 307 and the health test would fail. I found no such setting in the repository and the gate passes here. Each test builds its own factory (no shared state, no timing assumptions), so ordering flakiness risk is low.
*Action: none; if CI later shows 307s, pin the https port setting to empty in `ApiFactory` or use `ClientOptions { AllowAutoRedirect = false }`.*

### F5 — Public extension classes in `BookingApi.Api.Health` — MINOR

`HealthEndpoints` and `HealthOpenApi` are `public static` classes in the host assembly. They are used only from `Program.cs` in the same assembly and could be `internal`. Harmless (the Api assembly is not a library and only its test project references it). `Program` itself is public through the toolchain, not hand-written visibility. No `InternalsVisibleTo` was added, so `internal` would not have broken the tests.
*Action: none required; optionally make the two classes `internal` when next touched.*

### F6 — T026 tests match approved text, are not vacuous, and share the accepted phase 1 F1 blind spots — ACCEPTED

`DependencyRuleTests` (Api.Tests) reads the `.csproj` files through `XDocument`, walking up from `AppContext.BaseDirectory` to `BookingApi.slnx` and asserting it was found. `InfrastructureReferencesOnlyApplication` asserts the exact sorted `ProjectReference` list equals `["BookingApi.Application"]`; `ApiReferencesOnlyApplicationAndInfrastructure` asserts equality with `["BookingApi.Application", "BookingApi.Infrastructure"]`. Adding any other project reference (or dropping a required one) fails, and a wrong path fails on `Assert.NotNull` or file-not-found, so they cannot pass vacuously. They match the approved T026 text ("reading the `.csproj` files as the phase 1 rule tests do ... Infrastructure references only Application; Api references only Application and Infrastructure"). The blind spots the owner accepted for phase 1 F1 apply unchanged: only `ProjectReference` items are inspected, not `PackageReference`/`FrameworkReference`, the `Sdk` attribute, `Directory.Build.props` or transitive leakage, and the compiled assembly references are not examined. Consistent with the accepted decision.
*Action: none (owner accepted the csproj approach in phase 1; nothing new here).*

### F7 — Phase 1 smoke test removal is justified — ACCEPTED

T014 says "Replace the phase-1 smoke test if it is superseded by the HTTP tests". `ScaffoldSmokeTests.ApiAssemblyLoads` only asserted that `typeof(Program).Assembly` is named `BookingApi.Api`. Every Api HTTP test now constructs `WebApplicationFactory<Program>`, which loads the assembly, builds the host and runs the pipeline; a wrong or missing assembly breaks all three HTTP tests. The literal name assertion is gone but is implied by `Program` resolving and has no independent value. Nothing the smoke test covered is uncovered. Api.Tests went from 1 to 5 tests; solution total from 4 to 8.
*Action: none.*

### F8 — Test-first evidence not available (repeat of phase 1 F3) — MINOR

tasks.md requires tests "written first and seen failing before the implementation". The phase is a single commit, so red-then-green cannot be confirmed from history, and I did not mutate tracked files to prove it. The tests assert real behaviour (an absent `/health` route gives 404 and fails the health test; an unconditional `MapOpenApi()` fails the Production 404 test), so I believe they would fail without the implementation.
*Action: implementer notes in notes.md how the failing run was observed, or the owner accepts.*

## Amendments in this diff

<!-- Constitution I, Amendment authority: list every change this phase made to the feature's
  own spec.md, plan.md, tasks.md or contracts/, with the approver each one records. A phase
  that rewrote its own plan changed the standard it is being graded against, and a review
  that does not say so is grading the work against a marking scheme the worker rewrote.
  "None" is a valid and common answer — say it explicitly rather than omitting the section. -->

- [x] Amendments listed, or **none** stated explicitly

**None in the phase commit.** `git show --stat 7e4debb` touches nothing under `specs/`; spec.md, plan.md and contracts/ are unchanged since their approval commits (79fb615, af9a5c6). The branch tip commit 45cc075 changes tasks.md only by flipping T009-T014 and T026 from `[ ]` to `[x]` (checked in the diff: 7 lines, checkbox characters only). For completeness, the only amendment affecting this phase is the pre-existing T026 addition in d9bd395 (committed before the phase), which records `Amendment approved by: anas.m, 2026-10-18` in both the commit body and tasks.md. The T012 and T013 text was not altered.

## Constitution re-check (post-implementation)

**PASS.** I (Specification First): implementation matches approved spec/plan/tasks and the owner-approved T026; no approved document rewritten. II: spec, plan, contract and code agree on `/health` (200 `text/plain` `Healthy`, no checks run). III: N/A. IV (Architecture Consistency): only the planned package, ADR-001 layering untouched; endpoint code lives in Api and does not touch Infrastructure. V: N/A, no entities. VI (Security): public status-word endpoint by design, nothing leaked, no secrets, no logging. VII: contract exists and is honoured (readiness part is phase 4). VIII (Testing): each endpoint has an HTTP test and the ADR rules for Infrastructure/Api now have tests (with the accepted csproj limitation). IX: this review plus human PR review. X (Controlled Delivery): single phase commit with `phase 2`, scope-check PASS on that commit; owner gate confirmation required before phase 3.

## Test coverage observed

- `BookingApi.Domain.Tests` — 1 test (unchanged from phase 1), passes.
- `BookingApi.Application.Tests` — 2 tests (unchanged), pass.
- `BookingApi.Api.Tests` — 5 tests, pass:
  - `HealthEndpointTests.LivenessReturnsHealthyAsPlainText`: status 200, media type starts with `text/plain`, body equals `Healthy`.
  - `OpenApiTests.DevelopmentServesTheDocumentAndListsHealth`: 200 and the document text contains `"/health"`.
  - `OpenApiTests.ProductionDoesNotServeTheDocument`: 404 in Production.
  - `DependencyRuleTests.InfrastructureReferencesOnlyApplication` and `ApiReferencesOnlyApplicationAndInfrastructure`: exact project-reference lists.
- Total 8 passed, 0 failed. Gaps: liveness independence from checks is not testable until phase 4 (F2); the OpenAPI entry shape is only substring-checked (F1).

## Residual risk

Low. Risk concentrates in F1 (the hand-written OpenAPI entry can drift from the real route and only a substring check guards it) and F2 (the no-database guarantee rests on the predicate until T020 lands in phase 4). F6 carries the already-accepted csproj-only limitation. No finding blocks the phase as tasked; merge remains subject to the owner running the gate and confirming the exit code per the phase ritual, and phase 4 should close F1 and F2.
