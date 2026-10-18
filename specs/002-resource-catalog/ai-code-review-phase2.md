# AI Code Review — 002 Resource Catalog, Phase 2 (Application)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-18
**Branches**: booking-api `002-resource-catalog` (tip `70d4725`; phase commit under review `b4efceb`)
**Scope reviewed**: `git show b4efceb` in full (all 9 files: `IResourceRepository.cs`, `Outcomes.cs`,
`CreateResourceHandler.cs`, `GetResourceHandler.cs`, `ListResourcesHandler.cs`, the three handler test
classes, `TestDoubles.cs`); `git diff b4efceb~1 HEAD -- specs` (tasks.md checkbox ticks only);
`src/BookingApi.Domain/Resource.cs` (the factory the handler calls);
`src/BookingApi.Application/BookingApi.Application.csproj`; `tests/BookingApi.Application.Tests/DependencyRuleTests.cs`;
spec.md (FR-001..FR-005, FR-008, US1-US3, Edge Cases); plan.md (Design Notes Application, Duplicate names both
layers, Paging, Constitution Check); tasks.md Phase 2 and Territory; contracts/resources-api.md (create, get, list);
the phase 1 review headline findings (F2/F5/F7). Not read line by line: the constitution, the rulebooks, data-model.md,
booking-invariants.md, definition-of-done.md, review-process.md beyond the points cited below (no booking or slot
code exists in this phase).
**Feature contract**: Application references only `BookingApi.Domain` and no `PackageReference`; no EF mapping,
repository implementation, migration, endpoint or DI registration in phase 2; no update, retire or delete path;
expected outcomes are values, not exceptions.

## Reviewer Provenance

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 / Claude Opus 5.5 session (the implementing agent session that produced commit b4efceb)
- **Inputs provided**: phase 2 diff (`b4efceb`), spec.md, plan.md, tasks.md, contracts/resources-api.md, Domain `Resource.cs`, phase 1 review and notes (context only), ADR-001 dependency-rule tests
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — the phase adds the `IResourceRepository` port, nine-type explicit outcome set and three
handlers, all behind hand-written fakes, with nothing wired into Api or DI. Behaviour matches the spec and contract on
every line I traced, the build is warning-free, all tests pass, and four deliberate mutations of the handlers were each
caught by a test. The follow-ups are about the port, which is the seam phase 3 will implement: its documentation leaves
three load-bearing expectations implicit (the saved entity must carry its database-assigned `Id`, the name arrives
already trimmed with comparison delegated to the store, and `ListAsync` bounds are trusted and may overflow int
arithmetic), and the fake does not model them. None is a defect in the phase 2 code; each is a way phase 3 or 4 could
silently get it wrong. Residual risk sits at that seam, not in the handlers.

## What was verified (evidence)

> Every claim needs evidence — a file/symbol read, a test observed, a query run.

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | **Create (FR-001/002/003/008)**: `CreateResourceHandler.cs` calls `Resource.Create(command.Name, command.Description, time.GetUtcNow())`, returns `ResourceInvalid(created.Errors)` on failure before any repository call (test `InvalidInputReturnsTheFieldErrorsAndStoresNothing`: errors `["name","description"]`, `AddCalls == 0`, `NamesChecked` empty), then `NameExistsAsync(resource.Name)` with the trimmed name (tests `ANameAlreadyPresentIsRefusedWithoutAdding` with "room a" vs "Room A", `TheNameIsTrimmedBeforeItIsLookedUp` asserting the looked-up value is `"Room A"`), then `AddAsync` mapped `Added -> ResourceCreated(resource)` and `DuplicateName -> ResourceNameTaken` (test `AConcurrentDuplicateRefusedByTheStoreIsStillANameTakenOutcome`). Clock instants: `ValidInputIsStoredAndReturnedWithTheClockInstants` asserts `CreatedAtUtc == Now.UtcDateTime` through a `FixedTimeProvider` (FR-008); the `anonymous` user is Domain-owned and tested in phase 1. **Get (FR-004)**: `GetResourceHandler.cs` `resource is null ? ResourceNotFound : ResourceFound`; tests `AnExistingResourceIsFound`, `AnUnknownIdIsNotFound`. Retired -> not found is delegated to the port (`GetByIdAsync` doc: "The non-retired resource"). **List (FR-005)**: `ListResourcesHandler.cs` defaults `page ?? 1`, `pageSize ?? 50`; `effectivePage < 1` -> error field `"page"`, `effectivePageSize is < 1 or > 100` -> error field `"pageSize"`; both errors reported together; nothing reaches the repository when invalid. Tests `NoParametersMeansPageOneOfFifty` (`LastListRequest == (1,50)`), `ValidParametersReachTheRepositoryUnchanged` (1/1, 3/100, int.MaxValue/7), `APageBelowOneIsInvalid` (0, -1, int.MinValue; `LastListRequest` null), `APageSizeOutsideOneToOneHundredIsInvalid` (0, -5, 101, int.MaxValue), `BothParametersCanBeInvalidAtOnce` (order `["page","pageSize"]`, non-blank messages), `TheResultCarriesTheItemsAndTheTotalCount`. Boundaries 1 and 100 for size and 1 for page are inside the valid theory. Order, retired exclusion and past-the-end empty page are repository duties (phase 3) and are stated on `ListAsync` except past-the-end. |
| Visual-reference match (where references exist) | Not applicable: no UI or visual reference exists for this feature. |
| Feature contract held (no unapproved table/migration/permission/package) | `BookingApi.Application.csproj`: one `ProjectReference` (Domain), zero `PackageReference`; `DependencyRuleTests` (`ApplicationReferencesOnlyDomain`, `ApplicationReferencesNoWebOrPersistencePackages`) pass. `using` directives in Application: only `using BookingApi.Domain;` (implicit usings supply `System`, `System.Threading.Tasks`, `System.Collections.Generic`). `TimeProvider` is BCL. No EF, migration, endpoint, repository implementation or DI registration: `grep Resource src/BookingApi.Api/Program.cs` shows nothing; the handlers are only constructed in tests. |
| Constitution / domain invariants | Constitution IV (layering, no new package) held; V: no slot or booking exists, invariants 1-4 not exercisable, the retired-resource half of invariant 5 is only read through the port; VIII: every handler rule has a test at the owning layer; X: phase scoped to T006-T011, no later-phase content. See re-check below. |
| Security (authn/authz, secrets, sensitive logging) | No secrets, no logging, no exception text returned to callers (the only `throw` carries an enum name and is not an expected outcome). Public endpoints are the documented interim state and are phase 4. Nothing here changes authn/authz. |
| Scope guard (`scope-check.ps1` PASS on the phase commit; `git diff --stat` read for intent) | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit b4efceb` -> `scope-check: PASS phase 2 commit b4efceb (9 file(s))`. All 9 files are under `src/BookingApi.Application/**` or `tests/BookingApi.Application.Tests/**` (tasks.md Phase 2 Territory). `pwsh -NoProfile -File scripts/ritual-checks.ps1` -> `RESULT OK` (doc-lint, enforcement-pack, scope-check, digests, roadmap-claims, verify-kit all OK). |
| Rollback safety (phase reverts cleanly; schema additive?) | The commit only adds 9 files; no existing file is modified, no schema, nothing registered. Reverting `b4efceb` (then the tick commit) removes them with no dependants (phases 3 and 4 do not exist yet). |
| Build and tests | `dotnet build BookingApi.slnx --warnaserror` -> Build succeeded, 0 warnings, 0 errors. `dotnet test BookingApi.slnx --no-build`: Domain.Tests 24 passed / 0 failed; Application.Tests 22 passed / 0 failed; Api.Tests 13 passed / 0 failed. |
| Mutation check (restored) | In `CreateResourceHandler.cs`: (M1) `NameExistsAsync` call replaced by `if (false)` -> 2 failures (`TheNameIsTrimmedBeforeItIsLookedUp`, `ANameAlreadyPresentIsRefusedWithoutAdding`); (M2) `DuplicateName => ResourceCreated` -> 1 failure (`AConcurrentDuplicate...`); (M3) look up `command.Name` instead of the trimmed name -> 1 failure (`TheNameIsTrimmedBeforeItIsLookedUp`). In `ListResourcesHandler.cs`: (M4) max size 101 instead of 100 -> 1 failure (`APageSizeOutside...(pageSize: 101)`). Every file restored with `git checkout --`; `git status` showed no modified file afterwards. |
| Platform and culture sensitivity | No string formatting is asserted on; the only formatted text is `$"... {MaxPageSize}"` in an error message whose content is not compared (only non-blank). The fake compares names with `StringComparison.OrdinalIgnoreCase` (culture-independent). `FixedTimeProvider` makes create deterministic; `DateTimeOffset.UtcNow` in the Get and List tests only seeds names and is never asserted on. No file paths, line endings or time zones. Safe on ubuntu CI. |

## Findings

### F1 — Port does not say the saved entity must come back with its assigned `Id`; the fake never assigns one — MINOR

`CreateResourceHandler` returns `new ResourceCreated(resource)`, i.e. the same instance it passed to `AddAsync`.
`Resource.Id` has a `private set` and is assigned by the database (data-model: integer identity). The phase 4 endpoint
builds `Location: /resources/{id}` and the body `id` from `created.Resource.Id`. That only works if the phase 3
repository saves that exact instance (EF populates it on `SaveChanges`) and does not, for instance, insert a copy or
leave the entity detached. `IResourceRepository.AddAsync`'s summary does not state this, and
`FakeResourceRepository.AddAsync` stores the instance with `Id == 0`, so `ValidInputIsStored...` would pass with a
handler that returned an id-less resource. Nothing is wrong today; it is an unstated precondition at the seam where the
only stable identifier is created.
*Action: implementer, in phase 3 (or by a one-line `<remarks>` edit to the port now, inside the Application territory), state on `AddAsync` that on `Added` the same instance is returned populated with its `Id`; have a phase 3 Infrastructure test assert `Id > 0` on that instance and a phase 4 HTTP test assert `Location` carries it.*

### F2 — `IResourceRepository` documentation leaves trim, collation, retired-name and bounds expectations implicit — MINOR

Evidence from `IResourceRepository.cs`: (a) `NameExistsAsync` says "(case-insensitive)" but not that the argument is
already trimmed (the handler guarantees it; a second caller would not), nor that case-insensitivity is the store's
collation (spec Assumptions) and that the fake's `OrdinalIgnoreCase` only approximates it. Phase 1 F2 (trailing-space
and non-ASCII whitespace semantics of T-SQL equality) means "same name" is store-defined, which the port should say.
(b) `AddAsync` says `DuplicateName` covers "a concurrent insert" but does not say that a name held only by a retired
row is NOT a duplicate (spec Edge Cases: a retired resource's name is free again; plan: filtered unique index), so a
phase 3 implementer could map any unique violation, or a non-filtered index, to `DuplicateName`. `NameExistsAsync` does
say "non-retired", so the read half is explicit; the write half is not. (c) `ListAsync` does not state that `page >= 1`
and `1 <= pageSize <= 100` are preconditions the handler already enforced and the repository may trust, nor that
`(page - 1) * pageSize` must be computed in 64-bit arithmetic and an offset beyond int range must yield an empty page
(plan: Paging). The Application test `ValidParametersReachTheRepositoryUnchanged(int.MaxValue, 7)` proves only that the
handler lets such a value through; it cannot detect the overflow, which will first be observable in phase 3 (plan names
it, but the port a phase 3 author reads does not). Past-the-end empty page with true `TotalCount` is also not stated on
the port. (d) Cancellation: all four methods take the token and the handlers forward it; the port does not say a
cancelled call may throw `OperationCanceledException` (it will not be mapped to an outcome, which is correct, but it is
unstated). Likewise exceptions from the repository other than a duplicate-name refusal propagate unchanged
(`CreateResourceHandler` has no try/catch); that is the right behaviour for the baseline 500 pipeline and for plan
"no exceptions for expected outcomes", but it is not written on the port.
*Action: implementer, edit the XML docs of the port (Application territory, no behaviour change) to state: names are passed already trimmed and compared by the store's collation; a retired row's name is not a duplicate on `AddAsync`; `ListAsync` trusts handler-validated bounds and must page in 64-bit arithmetic with an empty page past the end; cancellation and unexpected store failures propagate as exceptions.*

### F3 — `default` arm of the `AddResourceResult` switch is unreachable today and would turn a future enum member into a runtime 500, not a compile error — MINOR

`CreateResourceHandler.cs` ends the switch with `var other => throw new InvalidOperationException(...)`. With the two
current members the arm is unreachable and untested. A `var` pattern is exhaustive, so adding a third enum value
(for example a transient-failure result in phase 3) compiles silently, and the handler throws at runtime, where
omitting the arm would instead have raised compiler warning CS8509, which `--warnaserror` turns into a build failure.
So the arm trades compile-time safety for a defensive throw. Throwing is the safe choice versus returning the wrong
outcome (it never reports success or name-taken for an unknown result), and it is consistent with unexpected states
being genuine faults, so I do not rate it a defect; it also cannot be covered by a test without an out-of-range cast.
*Action: implementer decides: either drop the `var other` arm and rely on CS8509 under `--warnaserror` (the Application project inherits the gate's warnings-as-errors), or keep it and accept it as deliberate. Record the choice in notes.md. No change required for approval.*

### F4 — Outcome hierarchies are not exhaustive to the compiler; phase 4 must handle the fall-through itself — ACCEPTED

`CreateResourceOutcome`, `GetResourceOutcome` and `ListResourcesOutcome` are abstract records with sealed subtypes
(`Outcomes.cs`). The C# compiler does not treat a type switch over an abstract base as exhaustive, so the phase 4
endpoint mapping needs a `_` arm; if a new subtype is added later and the endpoint is not updated, it falls to that arm
at runtime. The approved plan ("explicit outcomes, no exceptions for expected outcomes") is met, and the alternative
(a union type or a discriminated enum plus payload) is heavier than this feature warrants. Two details to note: the
base records have a protected constructor, so a type in another assembly could derive from them (the hierarchy is open
to Api and Infrastructure); and `ResourceNameTaken`, `ResourceNotFound` are payload-less sealed records, which is fine
for equality and matching. Mitigation lives in phase 4: the endpoint should throw on its `_` arm (never return 200),
and HTTP tests should cover each outcome subtype so a new subtype shows up as a failing test.
*Action: none for phase 2 (accepted trade-off). Phase 4 author: map every subtype explicitly, make the fall-through arm throw, and cover each outcome over HTTP; optionally close the hierarchies with a `private protected` constructor in a later phase.*

### F5 — Fake repository does not model retired rows, ids, or the real paging contract, and the Get test has weak discrimination — MINOR

`FakeResourceRepository` (`TestDoubles.cs`): (a) retired rows cannot be represented at all (`Resource.IsDeleted` has a
private setter and the factory never retires), so the "retired is invisible" half of `NameExistsAsync`/`GetByIdAsync`/
`ListAsync` is untested here; this is acceptable because it is a repository responsibility proven against SQL Server in
phase 3, but the tests do not claim otherwise, so it is noted rather than faulted; (b) `AddAsync` never assigns an `Id`
(F1); (c) `ListAsync` returns `PageToReturn with { Page = page, PageSize = pageSize }`, so the `Page` and `PageSize`
asserted by `TheResultCarriesTheItemsAndTheTotalCount` echo the request rather than anything the repository chose, and
`PageToReturn` is built with page 1 while the request is page 2: a handler that overwrote the repository's `Page` with
its own would pass the same assertions (harmless today, since the handler passes the page through); (d)
`AnExistingResourceIsFound` stores a single resource whose `Id` is 0 and asks for id 0, so it would pass a handler that
returned the first row regardless of id; this is a pass-through handler over a one-line repository call, so the practical
risk is nil, but the "unknown id" test uses an empty store, which does not discriminate either; (e) the fake's
case-insensitive match is `OrdinalIgnoreCase`, an approximation of the SQL collation (it differs for accents and
`ß`), which only matters for phase 3's real-database test, already planned (plan: "a real-database test asserts that
'room a' collides with 'Room A'"). I checked that no assertion is vacuous: `Assert.Equal` on arrays is element-wise in
xunit and both array assertions carry two elements; `Assert.All` in `BothParametersCanBeInvalidAtOnce` runs over two
errors (the preceding `Assert.Equal` pins the count).
*Action: none required. If cheap, a follow-up could assign sequential ids in `AddAsync` and store two resources in the Get test so the id lookup is discriminating.*

### F6 — Untested handler edges: cancellation forwarding, repository failure propagation, null command — MINOR

No test asserts that the `CancellationToken` reaches the repository (the fake ignores the parameter, so a handler that
passed `default` would pass), that an exception thrown by the repository propagates rather than being turned into an
outcome, or what a `null` command does (`command.Name` throws `NullReferenceException`; the only caller will be an
endpoint that constructs the command itself, so this is theoretical). `ResourcePage` can also express states the
contract forbids (page 0, negative `TotalCount`, an `Items` list that is a mutable `List<Resource>` behind
`IReadOnlyList<Resource>`; the type is a positional record so anyone can build or `with` it); the handler passes the
repository's page through unchecked. `TotalCount` as `int` is reasonable for this scale (2.1 billion non-retired rows
is outside any plausible catalog), and the handler's validation prevents the bound violations on the request side, so
this is a design note rather than a gap that can bite while the repository is the only producer.
*Action: none required for approval. A follow-up test or two (token captured by the fake and compared; a throwing fake propagates) would pin the documented behaviour from F2(d).*

## Amendments in this diff

- [x] Amendments listed, or **none** stated explicitly

**None.** Commit `b4efceb` touches no spec, plan, tasks or contract file. The following commit `70d4725` changes
`specs/002-resource-catalog/tasks.md` only by ticking T006-T011 (`- [ ]` to `- [x]`, 6 lines changed in the diff, wording
untouched). Wording drift noted, not introduced here: plan.md and tasks.md describe the Domain factory's third parameter
as `nowUtc` whereas the code takes `DateTimeOffset now` (phase 1 review F7). The Application usage is consistent with the
code: `Resource.Create(command.Name, command.Description, time.GetUtcNow())` passes a `DateTimeOffset`, and the Domain
converts with `now.UtcDateTime`; the test asserts `Now.UtcDateTime`.

## Constitution re-check (post-implementation)

**PASS.** I (specification first): the diff follows the approved Phase 2 text (T006-T011) and amends nothing. II (source
of truth): spec, plan, contract and code agree on defaults (1, 50), bounds (1..100), field names (`page`, `pageSize`),
and the check-then-store duplicate flow. IV (architecture/packages): Application references Domain only, no package, no
web or EF `using`; ADR-001 held and enforced by tests. V (domain invariants): satisfied/not engaged, no slot or booking
exists. VI (security): not engaged, no endpoint or logging; interim public endpoints remain a phase 4 matter. VII
(integration): contract unchanged; the handlers' outcomes map one-to-one to the contract's status table (Created 201,
Invalid 400, NameTaken 409, Found 200, NotFound 404, list 200 or 400), which phase 4 must realise. VIII (testing): 22
Application tests at the owning layer, with mutations of the key branches caught. IX: this review. X: phase scoped
and gated; nothing from phase 3 or 4 present. Nuance versus the plan-time check: the port is the new cross-phase seam,
and its documentation (F1, F2) is the one place the plan's "two layers, one rule" duplicate design is not fully written
down for the next implementer.

## Test coverage observed

Application.Tests: 22 tests, all passing (the implementer reports 20 of 22 failed against a throwing skeleton; the two
`DependencyRuleTests` passed before, which accounts for the 20; I did not re-run the skeleton). Create (5 tests):
success stores and stamps clock instants; invalid input stores nothing and checks no name; case-insensitive duplicate
refused with `AddCalls == 1` (only the first create added); trimmed name looked up; store-side duplicate becomes
`ResourceNameTaken`. Get (2). List: default paging; valid parameters theory (3 cases incl. `int.MaxValue`); invalid
page theory (3); invalid size theory (4, including 101 and `int.MaxValue`); both invalid; result carries items and
total. Critical assertions are the looked-up trimmed name, the `AddCalls == 0` on invalid input, `LastListRequest`
null on invalid paging, and the field names `name`/`description`/`page`/`pageSize` as literals. Domain.Tests 24 and
Api.Tests 13 unchanged and green. Gaps: F5 and F6 (retired, ids, cancellation, repository failure), none blocking.

## Residual risk

Low for the handlers; moderate and confined to the phase 3 seam. Risk concentrates in F1 (id population on the saved
instance), F2 (implicit store-side rules: trim and collation, retired names not duplicates, 64-bit paging, past-the-end
empty page) and F4 (phase 4 must handle exhaustiveness manually). All three are addressed by documentation and
Infrastructure/Api tests that the plan already schedules; F1 and F2 are cheapest to close now, as comment edits inside the
Application territory, before phase 3 begins. Nothing needs to happen before merge of this phase; the phase 3 author
should read F1 and F2 first.
