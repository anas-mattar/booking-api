# AI Code Review — 001 Solution Scaffold, Phase 3 (problem details)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-18
**Branches**: booking-api `001-solution-scaffold` (phase commit `1fda1ee`; tip `8b26b7e`, later commits tick checkboxes only)
**Scope reviewed**: `git show 1fda1ee` in full (`src/BookingApi.Api/Errors/ProblemDetailsSetup.cs`, `src/BookingApi.Api/Program.cs`, `tests/BookingApi.Api.Tests/ProblemDetailsTests.cs`); `ApiFactory.cs`, `OpenApiTests.cs`, `Health/*.cs`; spec.md (US3, FR-005/006, SC-003), plan.md (ADR-001 error handling, Design Notes), tasks.md Phase 3, contracts/http-baseline.md; `git diff 1fda1ee~1 8b26b7e -- specs`.
**Feature contract**: no new package this phase; no Phase 4 content (no EF Core, no readiness endpoint); one RFC 9457 pipeline in Api, registered in every environment; the 500 body carries no exception message, type or stack trace.

## Reviewer Provenance

<!-- MANDATORY (Definition of Done gate 5): the review MUST be produced by a reviewer that
  did not write the code — a fresh-context agent session or a second model. A review
  self-graded by the implementing agent in the same context is invalid.
  scripts/enforcement-pack.ps1 fails the branch when a review file added on it lacks this
  section, leaves the Reviewer line unfilled, names the implementer as reviewer, or omits
  the attestation sentence verbatim. Reviews committed before the verification pack are
  grandfathered (only files ADDED in the branch's diff are checked). -->

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 / Claude Opus 5.5 session (the implementing agent session that produced commit 1fda1ee)
- **Inputs provided**: phase 3 commit diff, spec.md, plan.md, tasks.md, contracts/http-baseline.md, constitution, backend and integration rulebooks, definition-of-done, review-process, phase 1 and 2 reviews and notes.md
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — Phase 3 registers `AddProblemDetails`, `UseExceptionHandler` and `UseStatusCodePages` unconditionally, ahead of every other middleware, and tests 404 and 500 in Development and Production. I confirmed by mutation that the tests depend on the real handlers, and by printing the bodies that the 500 body carries no exception data. No blocking issue. The residual items are observations: the stack-trace assertion is a heuristic, wrong-verb requests on `/health` are not covered by SC-003 evidence, and SC-003 is demonstrated for only two request types.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | FR-005: `GET /no/such/route` returns 404 `application/problem+json` with `status` and `traceId` (test plus printed body). FR-006: forced exception returns 500 `application/problem+json`; body printed in both environments: `{"type":"https://tools.ietf.org/html/rfc9110#section-15.6.1","title":"An error occurred while processing your request.","status":500,"traceId":"00-..."}`. No `detail`, `exception` or `stackTrace` in Development or Production. 404 body: type `rfc9110#section-15.5.5`, title `Not Found`, matching the contract example. |
| Visual-reference match | N/A: no UI, no visual references. |
| Feature contract held (no unapproved table/migration/permission/package) | `git show --stat 1fda1ee`: 3 files, no csproj or package change. No EF Core and no `/health/ready` in `src/`. `grep "throw\|__test" src`: no match, so no throwing endpoint in the application. |
| Constitution / domain invariants | IV: problem-details wiring lives in Api only. VI: see Security. VIII/X: tests accompany the code, gate green (below). |
| Security (authn/authz, secrets, sensitive logging) | A throwaway probe with a capturing logger showed `ExceptionHandlerMiddleware` logs at Error with the `InvalidOperationException` attached (server-side only) while the client body has none of it. The only other warning was HttpsRedirection "Failed to determine the https port" under TestServer (test-host artefact). No secrets involved. Probe file deleted. |
| Scope guard (`scope-check.ps1` PASS on the phase commit; `git diff --stat` read for intent) | `scope-check: PASS phase 3 commit 1fda1ee (3 file(s))`. All 3 files are under `src/BookingApi.Api/**` or `tests/BookingApi.Api.Tests/**`. `ritual-checks.ps1`: doc-lint, enforcement-pack, scope-check, digests, roadmap-claims, verify-kit all OK; `RESULT OK`. |
| Rollback safety (phase reverts cleanly; schema additive?) | The commit is purely additive (2 new files; Program.cs +4 lines: one `using`, one service call, one pipeline call). No schema. Reverting removes them and leaves phase 2 behaviour (Production OpenAPI 404, health) untouched. |

Build and tests: `dotnet build BookingApi.slnx --warnaserror` succeeded, 0 warnings, 0 errors. `dotnet test --no-build`: Domain.Tests 1 passed, Application.Tests 2 passed, Api.Tests 9 passed; 0 failed.

Mutation evidence (each restored with `git checkout --`, `git status` clean afterwards):
- `app.UseExceptionHandler()` commented out: both `UnhandledExceptionReturnsProblemDetailsWithoutExceptionData` cases (Development and Production) FAILED (7 passed, 2 failed); the 404 tests still passed.
- `app.UseStatusCodePages()` commented out: both `UnknownRouteReturnsProblemDetails` cases FAILED (7 passed, 2 failed); the 500 tests still passed.
- Placement: the test filter calls `next(app)` first and then `app.Use(...)`, so the thrower sits after the whole app pipeline, downstream of `UseExceptionHandler`. The Development case fails when the app handler is removed, so it is the app's handler, not the Developer Exception Page, that produces the passing 500 problem-details body. Neither test can pass for the wrong reason.
- Middleware order in Program.cs: `UseProblemDetailsErrors` is first, before `MapOpenApi`, `UseHttpsRedirection` and `MapHealth`, so anything those throw is handled. Observed: Development `/openapi/v1.json` 200 JSON; Production same path 404 `application/problem+json`; `/health` 200 `text/plain Healthy`.

## Findings

### F1 — `" at "` assertion is a weak stack-trace check — MINOR

`Assert.DoesNotContain(" at ", text)` only catches the English preposition in .NET stack frames. A body with `"stackTrace":["Foo.Bar()"]` or a `detail` with different text would pass. The other assertions cover the message, the exception type name and an `exception` property, which are what FR-006 names. I printed the real body and it has exactly `type,title,status,traceId`, so there is no present defect; the risk is future regression.
*Action: follow-up (optional, implementer): assert the 500 body property set equals {type, title, status, traceId}, which proves FR-006 structurally.*

### F2 — Non-GET verbs on `/health` return 200 text/plain, never 405 — MINOR

Probe: `POST /health` returned `200 text/plain Healthy`, because `MapHealthChecks` carries no method restriction. That is neither HTML nor a stack trace, so SC-003 ("health status or problem details") still holds, but the contract's `GET` is not enforced and no test sends a wrong verb. Outside Phase 3 scope.
*Action: none for phase 3; owner may later restrict `/health` to GET (which would then yield a problem-details 405 via `UseStatusCodePages`).*

### F3 — Production OpenAPI 404 test asserts only the status — DOC DRIFT

`OpenApiTests.ProductionDoesNotServeTheDocument` still passes and still means "not served in Production". The 404 is now a problem-details body (observed), a stronger form of the same fact that the test and its comment do not mention.
*Action: none (optionally assert the content type in a later phase).*

### F4 — SC-003 demonstrated for only 404 and 500 — MINOR

No 400 or other 4xx path is exercised because no endpoint takes input yet (the contract assigns 400 to later features). `UseStatusCodePages` converts any empty 4xx/5xx response into problem details. This is an observation against the approved spec, not a demand.
*Action: none; later features that add input must add 400 tests.*

### F5 — 500 type/title are framework defaults — MINOR

The 500 `title` is "An error occurred while processing your request." and `type` is rfc9110 section 15.6.1. The contract shows only the 404 values and says nothing specific for 500, so this is compliant; a framework upgrade could change the defaults.
*Action: none.*

## Amendments in this diff

- [x] **None** stated explicitly. The only change to an approved feature document between `1fda1ee~1` and the branch tip is `tasks.md` ticking T015-T017 (checkboxes only, verified with `git diff -- specs`). spec.md, plan.md and contracts/ are unchanged.

## Constitution re-check (post-implementation)

**PASS.** IV (layering): problem-details wiring in Api only. VI (security/logging): exception logged server-side by the framework handler, nothing leaked to the client, in every environment. VIII/X (tests, gate): 9 Api tests, build with `--warnaserror` clean, ritual-checks OK. I (amendment authority): no amendments. Territory: all files inside the Phase 3 Territory.

## Test coverage observed

- `BookingApi.Api.Tests` (9 total, all passing): `UnknownRouteReturnsProblemDetails` (theory: Development, Production) asserts 404, media type `application/problem+json`, `status` 404, non-blank `traceId`. `UnhandledExceptionReturnsProblemDetailsWithoutExceptionData` (theory: Development, Production) asserts 500, media type, `status` 500, and that the body lacks the secret message, `InvalidOperationException`, `" at "` and an `exception` property. Plus the existing health, OpenAPI and dependency-rule tests.
- The throwing endpoint exists only in the test (`ThrowingStartupFilter` via `ThrowingApiFactory`); each case uses its own factory and there is no timing dependence (repeated runs, including mutation runs, were stable). Domain.Tests (1) and Application.Tests (2) are unchanged.

## Residual risk

Low. Risk concentrates in F1 (assertion strength against future regression) and F2/F4 (SC-003 shown only for 404 and 500; wrong-verb behaviour untested). None blocks merging phase 3. Phase 4 must keep the problem-details pipeline registered before any new middleware.
