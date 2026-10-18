# AI Code Review — 002 Resource Catalog, Phase 3 (Persistence)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-19
**Branches**: booking-api `002-resource-catalog` (tip `6c08402`; phase commit under review `6c08402`)
**Scope reviewed**: `git show 6c08402` in full (23 files): `ResourceRepository.cs`, `BookingDbContext.cs`,
`BookingDbContextFactory.cs`, `DependencyInjection.cs`, the migration `ResourceCatalog` (+ Designer), the model snapshot,
`BookingApi.Infrastructure.csproj`, `.config/dotnet-tools.json`, `BookingApi.slnx`, `TestSupport` (csproj,
`SqlServerFixture`), `Infrastructure.Tests` (csproj, `DatabaseTest`, `SqlServerCollection`, `MigrationTests`,
`ConstraintTests`, `ResourceRepositoryTests`, `DependencyRuleTests`), and the doc edits (CLAUDE.md, README.md, backend and
database rulebooks). Also read: `IResourceRepository.cs`, data-model.md, plan.md (package table, Design Notes), tasks.md
Phase 3 and Territory, `database-rules.md`. Not read line by line: spec.md beyond FR-002/007/008/011, contracts (no endpoint
in this phase), the Designer file (checked only that it mirrors the snapshot by diffstat).
**Feature contract**: persistence only: one table and one migration `ResourceCatalog`; three approved additions only
(`Testcontainers.MsSql` 4.16.0, `Microsoft.EntityFrameworkCore.Design` 10.0.13 PrivateAssets=all, `dotnet-ef` 10.0.13 local
tool); repository implements the phase 2 port; no endpoint; database tests on real SQL Server in a throwaway container.

## Reviewer Provenance

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 session (the implementing agent session that produced commit 6c08402)
- **Inputs provided**: phase 3 diff (`6c08402`), spec.md, plan.md, tasks.md, data-model.md, contracts/resources-api.md, the port `IResourceRepository.cs`, database and backend rulebooks, review-process.md, phase 2 review (format only)
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — the phase adds the EF mapping, the `ResourceRepository`, the single migration
`ResourceCatalog`, DI registration, Testcontainers test support and 25 database tests, and nothing outside territory. The
generated migration and snapshot match data-model.md column for column and constraint for constraint; the port contract
(same-instance `Id`, 64-bit offset, retired invisibility, duplicate mapping) is honoured and tested; build is warning-free
and all tests pass with Docker running. Nine mutations were applied: seven were caught, one survived because the paging test
cannot tell name order from id order (F1, the only substantive gap), and one survived because the error-2627 branch is
unreachable with the current schema (F2, informational). No BLOCKER or MAJOR finding. Residual risk is small and sits in the
ordering assertion and in a few reproducibility nits.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | **FR-002 (database half)**: filtered unique index `IX_Resources_Name ... WHERE [IsDeleted] = 0`; tests `ANameDifferingOnlyByCaseCollides` (`"room a"` vs `"Room A"` -> `DuplicateName`; `NameExistsAsync("ROOM A")` true), `ANameIsAllowedOnceTheEarlierHolderIsRetired`, `ManyParallelAddsOfOneNameYieldExactlyOneSuccessAndNoException` (20 parallel adds: 1 `Added`, 19 `DuplicateName`, 1 row). **FR-007/FR-011**: constraints exercised with raw SQL in `ConstraintTests` (trim, blank, 101/501 chars, retired without deletion data, live with deletion data, updated before created). **FR-008**: `AddThenGetRoundTripsEveryField` asserts all ten columns including `anonymous` and the clock instant. Paging: `OneHundredResources...` (50/50, each once), `APagePastTheEndIsEmptyWithTheTrueTotal`, `AnOffsetBeyondTheIntRangeIsAnEmptyPageNotAnOverflow` (`int.MaxValue`, 100). |
| Visual-reference match | Not applicable: no UI or visual reference. |
| Feature contract held (no unapproved table/migration/permission/package) | Package diff: Infrastructure gains only `Microsoft.EntityFrameworkCore.Design` 10.0.13 with `PrivateAssets=all`; `TestSupport` has `Testcontainers.MsSql` 4.16.0 + `xunit` 2.9.3; `Infrastructure.Tests` uses the standard `dotnet new xunit` set (coverlet.collector, Microsoft.NET.Test.Sdk, xunit, xunit.runner.visualstudio); `.config/dotnet-tools.json` pins `dotnet-ef` 10.0.13 (`rollForward: false`). No other package. One migration only (`20261018171608_ResourceCatalog`), one table. `--warnaserror` build has no advisory break. `DependencyRuleTests` (TestSupport references no BookingApi project; Infrastructure.Tests references only Infrastructure + TestSupport) pass. |
| Migration and snapshot vs data-model.md | `Up`: `Id int identity(1,1)` PK `PK_Resources`; `Name nvarchar(100) not null`; `Description nvarchar(500) null`; `CreatedAtUtc`/`UpdatedAtUtc` `datetime2 not null`; `CreatedBy`/`UpdatedBy nvarchar(100) not null`; `IsDeleted bit not null default 0`; `DeletedAtUtc datetime2 null`; `DeletedBy nvarchar(100) null`; check constraint text identical to the (amended) data-model rows, including the `DATALENGTH` form of `CK_Resources_Name_Trimmed`; `IX_Resources_Name` unique, filter `[IsDeleted] = 0`. `Down` drops `Resources` only (SC-005 test passes). Snapshot mirrors the model (same columns, index, three checks, `ProductVersion` 10.0.13); no drift observed (`GetPendingMigrationsAsync` is empty in `MigrateAppliesToAnEmptyDatabase`; a dedicated pending-model-changes check was not run). |
| Port contract (`IResourceRepository`) | Same instance returned with `Id` assigned: `context.Resources.Add(resource)` + `SaveChangesAsync`, asserted by `Assert.True(resource.Id > 0)`. Retired invisible to get/list/count/name-exists via the global query filter (`RetiredRowsAreInvisibleToGetListAndNameExists`). 64-bit offset `((long)page - 1) * pageSize`, early return when `offset >= total` with the true total. Order `OrderBy(Name).ThenBy(Id)` is as documented (but see F1). Unexpected failures and cancellation propagate: only `DbUpdateException` with `SqlException` 2601/2627 is caught. |
| Constitution / domain invariants | IV: layering held (Domain has no EF attributes; mapping is fluent in Infrastructure); package policy held (above). V: invariant 2 (UTC) mirrored by `datetime2` and the audit check; invariant 5 (retired resource) enforced through the query filter; no slot or booking code exists. VIII: each rule has a test at the owning layer, against real SQL Server, no in-memory or SQLite stand-in. |
| Security (authn/authz, secrets, sensitive logging) | No secrets committed: the design-time factory uses LocalDB or `BOOKINGAPI_CONNECTION`; the container password is Testcontainers-generated. SQL in tests is string-built (`RetireAsync`, `InsertAsync`) from constant literals only (test code). The design-time factory is not registered at runtime and there is no migrate-on-startup. |
| Scope guard | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit 6c08402` -> `scope-check: PASS phase 3 commit 6c08402 (23 file(s))`. `pwsh -NoProfile -File scripts/ritual-checks.ps1` -> `RESULT OK` (doc-lint, enforcement-pack, scope-check, digests, roadmap-claims, verify-kit OK; scope-repos n/a). `git show --stat` read: every file is in the declared Territory. |
| Rollback safety | Additive: new files plus one DI line and one `DbSet`. `Down` drops the (empty at this point) table; the table holds no data until phase 4 exposes writes. Reverting the commit removes the repository registration with no dependants (phase 4 does not exist). |
| Build and tests | `dotnet build BookingApi.slnx --warnaserror` -> 0 warnings, 0 errors. `dotnet test BookingApi.slnx --no-build` with Docker up: Domain 25, Application 27, Api 13, Infrastructure 25 (about 29 s), all passed, 0 failed, 0 skipped. |
| Mutation check (all restored with `git checkout -- src tests`; `git status --short` empty afterwards) | CAUGHT: `NameExistsAsync` with `IgnoreQueryFilters()` (1 failure); `GetByIdAsync` with `IgnoreQueryFilters()` (1); `ListAsync` with `IgnoreQueryFilters()` (1); `int` arithmetic instead of `long` for the offset (`AnOffsetBeyondTheIntRange...`); `Skip(offset + 1)` (2); duplicate-error mapping replaced by a non-matching number (2: collision and parallel tests, `DbUpdateException` escapes); `HasQueryFilter` removed from the mapping (1). SURVIVED: ordering changed to `OrderBy(Id)` with `ThenBy` removed (F1); `UniqueConstraintViolation` (2627) removed from the filter (F2). |

## Findings

### F1 — Paging test cannot distinguish name order from id order — MINOR

`OneHundredResourcesPageAsFiftyAndFiftyEachExactlyOnceInOrder` inserts `res 000`, `RES 001`, `res 002`, ... in ascending
name order, so ascending `Id` and ascending case-insensitive `Name` coincide. Mutation: in `ResourceRepository.ListAsync`
replace `.OrderBy(r => r.Name).ThenBy(r => r.Id)` with `.OrderBy(r => r.Id)`: all 25 tests still pass. The port documents
"ordered by name (case-insensitive) then id" and FR-005 depends on it; today the only protection is that the code is right.
The "mixed case" comment suggests the intent was to prove the collation ordering, which this data cannot do. The
`ThenBy(Id)` tie-break cannot trigger because live names are unique (harmless).
*Action: implementer, in a small follow-up inside phase 3 territory: insert the 100 names in a shuffled or descending order
so id order differs from name order, and re-run the `OrderBy(Id)` mutation to confirm it now fails.*

### F2 — Error 2627 branch is unreachable and untested — MINOR

`ResourceRepository` maps SQL Server 2601 and 2627. The only uniqueness rule is a filtered unique INDEX, which raises 2601;
2627 (unique constraint or primary key) cannot occur for `Name` today. Removing `or UniqueConstraintViolation` leaves all
tests green. It is defensive and matches tasks.md T022 ("2601 and 2627"), so acceptable, but a primary-key 2627 would be
reported as `DuplicateName` if it ever occurred, mislabelling a different fault.
*Action: none for this phase (it is the plan's stated mapping); optionally narrow to 2601 in a later phase.*

### F3 — `ListAsync` reads the total and the page in two separate statements — MINOR

`CountAsync` then `ToListAsync` are not in one transaction or snapshot, so a concurrent insert between them can yield a
`TotalCount` that disagrees with the page by one. No retire or update path exists in this feature and the drift is benign for
a catalogue list, but the port promises "the true total".
*Action: none now; revisit if retire or update ships.*

### F4 — Test image tag is floating (`2022-latest`) — MINOR

`SqlServerFixture` uses `mcr.microsoft.com/mssql/server:2022-latest`, a moving tag, while packages and the tool are pinned
exactly. An image change could alter gate results with no repository change. The case insensitivity the tests rely on is the
image default collation, which the fixture does not set explicitly.
*Action: implementer may pin a specific CU tag in a follow-up and record it in notes.md. Not required for merge.*

### F5 — Housekeeping nits (no behavioural impact) — MINOR

(a) `MigrationTests.MigrateAppliesToAnEmptyDatabase` calls `NewContext()` without disposing it. (b) The commit strips the
UTF-8 BOM from `BookingApi.Infrastructure.csproj` (incidental; it builds). (c) `ConstraintTests` over-length cases assert only
`SqlException`, not a message (acceptable: truncation error, not a named constraint). (d) tasks.md T012-T025 are not ticked in
this commit; the phase 2 precedent ticks them in a separate commit after the gate, so expected.
*Action: none, or implementer tidies (a) when next touching the file; tick tasks after the gate, per precedent.*

## Amendments in this diff

- [x] Amendments listed, or **none** stated explicitly — **none**: the commit changes no `spec.md`, `plan.md`, `tasks.md` or
  `contracts/` file. (CLAUDE.md, README.md and the two rulebooks are edited, but they are in the phase's declared Territory
  and implement task T025; they are not feature documents.)

## Constitution re-check (post-implementation)

**PASS.** IV (layering, package policy): satisfied, only the three plan-approved additions, Domain free of EF. V: invariants
2 and 5 are mirrored by the schema and the query filter. VII: N/A (no external integration). VIII: satisfied, constraints,
collation, query filter, paging and concurrency are proven on real SQL Server. X: phase scoped to T012-T025, no phase 4
content (no endpoint, no handler registration). Nuance versus plan time: the Docker prerequisite is now a hard gate
dependency and is recorded in CLAUDE.md, README.md and both rulebooks as T025 requires.

## Test coverage observed

`BookingApi.Infrastructure.Tests`: 25 tests, each against a fresh migrated database in one SQL Server container.
`MigrationTests` 2 (apply to empty; migrate to `0` returns the database to empty). `ConstraintTests` 12 cases (valid row;
4 untrimmed or blank names; over-long name; over-long description; retired without deletion data; live with deletion data;
retired with deletion data accepted; updated before created). `ResourceRepositoryTests` 9 (round trip of every field; null
vs empty description; case collision and case-insensitive `NameExists`; name reusable after retire; retired invisible to
get/list/exists; unknown id; 100-row paging; past-the-end; beyond-int offset; 20-way parallel duplicate). `DependencyRuleTests`
2. The discriminating assertions (query filter x3, offset width, Skip, duplicate mapping) were each killed by a mutation;
ordering (F1) was not.

## Residual risk

Low. The remaining risk is that list ordering is guarded only by the implementation, not by a discriminating test (F1), plus
the reproducibility drift of a floating container tag (F4). Neither blocks the phase gate; F1 is cheap to close. Gate
certification stays with the user (Docker must be running).
