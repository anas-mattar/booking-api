# AI Code Review — 002 Resource Catalog, Phase 4 (API)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-19
**Branches**: booking-api `002-resource-catalog` (tip `a42f69b`; phase commit under review `a42f69b`)
**Scope reviewed**: `git show a42f69b` in full (17 files): `ResourceEndpoints.cs`, `ResourceDtos.cs`, `Program.cs`,
`BookingApi.Api.Tests.csproj`, all new Api tests (`ResourceApiFactory`, `ResourceApiTest`, `CreateResourceTests`,
`GetResourceTests`, `ListResourcesTests`, `ConcurrentCreateTests`, `ErrorShapeTests`, `OpenApiTests`,
`SqlServerCollection`), `quickstart.md`, `rollback.md`, `notes.md`, `tasks.md` (ticks). Also read: contracts/resources-api.md,
http-baseline.md, tasks.md Phase 4 and Territory, rollback-template.md, `CreateResourceHandler.cs`,
`ListResourcesHandler.cs`, `ProblemDetailsSetup.cs`, `launchSettings.json`, the phase 3 review (format only). Not read line
by line: spec.md and plan.md beyond the contract-relevant FRs/SCs, the rulebooks beyond the HTTP/validation sections.
**Feature contract**: three endpoints exactly as `contracts/resources-api.md`; no new package, table or migration; errors
through the baseline problem-details pipeline; tests over HTTP against real SQL Server; quickstart (SC-005 by hand) and rollback.

## Reviewer Provenance

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 session (the implementing agent session that produced commit a42f69b)
- **Inputs provided**: phase 4 diff (`a42f69b`), spec.md, plan.md, tasks.md, data-model.md, contracts/resources-api.md, http-baseline.md, notes.md, backend and integration rulebooks, review-process.md, the review template, phase 3 review (format only)
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — the phase adds the three endpoints, DTOs, handler registration, `ThrowOnBadRequest = false`, new
HTTP tests on a fresh migrated SQL Server database per test, quickstart and rollback. Every status, body shape, header and
field name in the contract is implemented and was observed on the wire (including probes of 415, 405, repeated and signed
query values). Build is warning-free, all 134 tests pass with Docker up, scope-check and ritual-checks pass, no package was
added. Ten mutations of `ResourceEndpoints.cs`/`Program.cs` were attempted: eight caught, one survived (parser leniency, F1),
one did not apply. No BLOCKER or MAJOR finding. The follow-ups are small: the invalid-parameter path of `GET /resources`
runs a discarded database query (F2), the integer parser is more lenient than "whole number" and untested (F1), and tasks.md
was ticked before the gate (F4).

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match / contract | **POST**: 201 + `Location: /resources/{id}` + `Resource` (camelCase `id,name,description,createdAtUtc,updatedAtUtc`, instants end in `Z`, no `isDeleted`/`createdBy`) asserted in `CreatesAndReturnsTheStoredResource...`; 409 title `Resource name already in use` for case and whitespace duplicates; 400 `errors` map for missing/null/blank/empty name, both over-length fields reported together, limits (100/500) accepted; 400 problem+json for empty, malformed, `null`, `[]`, wrong-typed bodies. Probes (temporary test, deleted): wrong content type -> 415 problem+json, `DELETE /resources` -> 405 problem+json, over-long description plus an unknown property -> 400 naming `description` only. **GET {id}**: 200 equals the created body; unknown, retired (raw SQL), `abc`, `1.5`, `99999999999`, `-1` -> 404 problem+json. **GET list**: defaults 1/50, 100 rows as 50+50 with `totalCount` 100, past-the-end 200 empty with true total, retired excluded, case-insensitive name order on creation order `banana, Cherry, apple, Banana2` (differs from id order, so discriminating), nine bad-parameter forms and both-bad-at-once name the parameter. |
| Baseline error contract | `ErrorShapeTests` sends ten error requests and asserts `application/problem+json`, no `<html`, no `Exception`, no stack-frame regex, no `BookingApi.`. Probe outputs show only `type/title/status/traceId` (+`detail` only for the two handler-authored 404/409 strings and `errors` for 400). No exception text or connection detail in any observed body. The 500 path for the new endpoints (for example database down) is not exercised in this phase; it rides the 001 exception handler (`UseProblemDetailsErrors` registered in every environment). |
| Outcome mapping completeness | Every subtype in `Outcomes.cs` for create (`ResourceCreated`, `ResourceInvalid`, `ResourceNameTaken`), get (`ResourceFound`, `ResourceNotFound`) and list (`ResourcesListed`, `ListResourcesInvalid`) has an explicit arm; the `_` arm throws (-> 500 via baseline handler). The throw arm is untested (acknowledged in notes.md; unreachable today). |
| `ThrowOnBadRequest = false` | The framework default is `true` only in Development; Production already answered 400, so the change affects Development only. It applies to every endpoint, but the only other endpoints (`/health`, `/health/ready`) bind nothing from the request, so nothing else changes. Pinned by `ABadBodyIsAlso400ProblemDetailsInDevelopment` (3 cases); removing the line fails exactly those 3 (mutation M3). Plan Design Notes: API names this fix. |
| Concurrency (SC-003) | `ConcurrentCreateTests`: 15 rounds, two `Task.Run` POSTs of one name each, asserts exactly `[201, 409]`. The path under test is handler pre-check + repository `DuplicateName` mapping (mutation-tested in phase 3). I did not mutate this test's target in phase 4 (F3). |
| Query-parameter parsing | `page`/`pageSize` bound as `string?`, parsed with `int.TryParse(NumberStyles.Integer, InvariantCulture)`; absent -> default, empty (`pageSize=`) -> 400, overflow -> 400, repeated (`page=1&page=2`) -> 400 naming `page`. Signed and padded values (`%2B1`, `%201`) are accepted (F1). Trade-off: OpenAPI shows both as strings (F5). |
| Feature contract held (no unapproved package/table/migration) | `git show --stat`: the only project-file change is a `ProjectReference` to `BookingApi.TestSupport` in `Api.Tests.csproj` (T026) plus a BOM strip; no `PackageReference`, no migration, no Infrastructure change. `Program.cs` adds `TimeProvider.System` and three scoped handlers only. |
| Constitution / domain invariants | IV layering: endpoints depend on Application and Domain types only; no EF type in Api code. V: instants serialised UTC. VII: contract exists and matches. VIII: HTTP behaviour proven over real SQL Server, no in-memory stand-in. Invariant 5 (retired invisible) proven over HTTP for get and list. |
| Security | Endpoints public by design (contract Authentication, accepted interim state). No secrets: `ResourceApiFactory` forces the connection string from the Testcontainers fixture. Errors leak nothing (above). Test SQL interpolates only an integer id from a prior response. |
| Scope guard | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit a42f69b` -> `scope-check: PASS phase 4 commit a42f69b (17 file(s))`. `pwsh -NoProfile -File scripts/ritual-checks.ps1` -> `RESULT OK` (doc-lint, enforcement-pack, scope-check, digests, roadmap-claims, verify-kit OK; scope-repos n/a). Diff stat read: code only under `src/BookingApi.Api/**` and `tests/BookingApi.Api.Tests/**`; docs are the phase's T035/T036/notes. |
| quickstart.md accuracy | Port `5132` and profile `http` match `launchSettings.json`; the three check-constraint names and `IX_Resources_Name` match the mapping; the expected statuses (409, 400 naming `name`, 404, 404, 400 naming both) match the observed behaviour of the same requests in tests. Step 1 includes the rulebook's confirm-the-database check. Not executed (instructed not to touch the owner's LocalDB). It hard-codes `/resources/1`, correct only on an empty table (F6). |
| rollback.md vs template | Has all five template sections in order (Method, Changed Areas, Database Rollback, Deployment Rollback, Verification After Rollback). Additive-schema and "down only while empty; else leave the table" agree with data-model.md and rollback-process.md; no physical deletion offered as rollback. The "revert newest first" order is correct (phase 4 uses phase 2's handlers over phase 3's repository). |
| Build and tests | `dotnet build BookingApi.slnx --warnaserror` -> 0 warnings, 0 errors. `dotnet test BookingApi.slnx --no-build` (Docker up): Domain 25, Application 27, Infrastructure 26, Api 56, all passed. |
| Mutation check (restored with `git checkout --`; final `git status --short` empty; temporary probe file deleted) | CAUGHT: Location path changed (1 failure); 409 -> 400 (2); `ThrowOnBadRequest` line removed (3, all Development tests); `totalCount` replaced by item count (2); handler-error merge removed (1, `BothParametersCanBeInvalidAtOnce`); 404 -> 400 (2); route `{id:int}` -> `{id}` (3); response `page` echoing `pageSize` (1). SURVIVED: `NumberStyles.Integer` -> `NumberStyles.Any` (F1). One further sed matched nothing (no result claimed). |

## Findings

### F1 — Integer parser accepts signed and padded values, and no test pins "whole number" — MINOR

`ParseWholeNumber` uses `NumberStyles.Integer`, which allows leading/trailing whitespace and a leading sign. Probe:
`GET /resources?page=%2B1` and `?page=%201` both return 200 with `page: 1`. The contract says "whole number"; `+1` is
arguably one, so this is a latitude question, not a violation. Replacing the style with `NumberStyles.Any` leaves all 55
non-concurrent tests green, so neither the leniency nor a stricter rule is pinned by a test.
*Action: implementer, optional follow-up: pick the intended accepted forms (for example `AllowLeadingSign` only, so `-1`
still reaches the range check) and add `%2B1` / `%201` rows to the bad-parameter theory, or a test recording the accepted forms.*

### F2 — Invalid-parameter path of `GET /resources` runs a discarded database query — MINOR

When parsing fails for one or both parameters, the endpoint still calls `handler.HandleAsync(parsedPage ?? 1,
parsedPageSize ?? 1, ...)` to learn about the half that parsed. The fallbacks are valid, so for `?pageSize=abc` or
`?page=abc&pageSize=abc` the handler proceeds to `repository.ListAsync` (count plus page query) and the result is thrown away
(`ListResourcesHandler.HandleAsync` only skips the repository when its own inputs are invalid). Consequences: a wasted round
trip on such 400s, and a 400 that becomes a 500 if the database is unreachable.
*Action: implementer, follow-up inside Api territory: validate the parsed half without the repository (or expose the range
rules as a pure method); the existing both-invalid test and the nine-row theory guard the observable behaviour.*

### F3 — Concurrency test and the unmapped-outcome arm are not mutation-checked here — MINOR

The SC-003 test relies on real overlap of two requests; 15 rounds exceeds the task's minimum of 10 and the underlying
repository mapping was killed by phase 3 mutations, so confidence is reasonable. The throwing fall-through arm in the three
switches has no test (notes.md says so).
*Action: none for this phase; an optional test with a fake outcome subtype would pin the arm.*

### F4 — Phase commit ticks T026-T036 in tasks.md before the gate — MINOR

`tasks.md` is edited (checkboxes only) in the phase commit. The phase 3 review records the precedent that ticks follow the
certified gate in a separate commit. Not an amendment (no scope, wording or contract change), and the scope check passes, but
it states completion ahead of the user-held certification.
*Action: owner to be aware; no code change. If the gate fails, the ticks must be undone.*

### F5 — `page` and `pageSize` are `string` in the OpenAPI document — ACCEPTED

Binding as text lets a non-numeric value produce the contract's 400 naming the parameter, at the price of an OpenAPI schema
that says `string`. Documented in notes.md and chosen deliberately; the contract is the source of truth for clients.
*Action: none.*

### F6 — Quickstart assumes the table is empty — MINOR

Step 3 fetches `/resources/1`, valid only if the `Resources` table was empty (identity may also have advanced). A rerun on a
populated database gives a 404 against the stated expectation.
*Action: implementer may use the id from the POST `Location` header. Not blocking.*

## Amendments in this diff

- [x] Amendments listed, or **none** stated explicitly — **none**: the commit changes no `spec.md`, `plan.md` or `contracts/`
  file. `tasks.md` gains checkbox ticks only (F4); `notes.md`, `quickstart.md` and `rollback.md` are new phase deliverables
  (T035/T036), not amendments to approved documents.

## Constitution re-check (post-implementation)

**PASS.** IV (layering, package policy): satisfied, no new package, Api depends on Application/Domain only. V: invariants 2
and 5 observed over HTTP. VII: contract matches the implementation. VIII: all behaviour proven over real SQL Server; the key
mapping, header, parser-range and Development-mode behaviours were each killed by a mutation. X: phase scoped to T026-T036; no
later-phase content. Nuance: the endpoints are public, an accepted interim state recorded in the contract; an authentication
feature must land before deployment.

## Test coverage observed

`BookingApi.Api.Tests`: 56 tests sharing one SQL Server container, a fresh migrated database per test.
`CreateResourceTests` (create and Location, null description, duplicate theory, 400 theories, limits, bad-body theory,
Development bad-body theory), `GetResourceTests` (200, unknown, retired, three non-numeric), `ListResourcesTests` (defaults,
100-row paging, past the end, nine bad-parameter rows, both invalid, retired excluded, order), `ConcurrentCreateTests` (15
rounds), `ErrorShapeTests` (ten error requests), `OpenApiTests` (Development lists `/resources` and `/resources/{id}`;
Production 404). Domain 25, Application 27 and Infrastructure 26 are unchanged by this commit and pass.

## Residual risk

Low. The risk sits in the invalid-parameter path of the list endpoint (F2: a wasted query and a DB dependency on a 400) and in
untested parser leniency (F1). Neither blocks the gate. SC-005 by hand (quickstart on the owner's LocalDB) was not run by this
review and remains the owner's check; gate certification stays with the user (Docker must be running).
