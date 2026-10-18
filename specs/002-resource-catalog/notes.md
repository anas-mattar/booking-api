# Notes: 002-resource-catalog

Evidence and observations. Ungraded by design (`docs/sdlc/branch-strategy.md`): recording it
never costs an approval.

## Phase 1

- **Test-first**: the tests were written against a signature-only skeleton whose `Create`
  throws: 18 of 19 failed (the 19th is the existing dependency-rule test). Implementation
  then made them pass. After remediation: 24 Domain tests, 39 across the solution.
- **Review F1 fixed** (phase 1 remediation commit): `CreateResourceResult` is built only by the
  factory (private constructor, internal `Success`/`Failure`), so a result with both a value
  and errors, or neither, cannot exist; the error list is a read-only copy.
- **Review F3, F4, F6 fixed**: tests pin trimming of NBSP, U+3000 and control whitespace;
  headers cite the contract; failure tests assert a null `Value`.
- **Review F2 (CONFIRM, for phase 3): `CK_Resources_Name_Trimmed` in `data-model.md` is
  weaker than documented.** Verified by `SELECT` on LocalDB (nothing created): `N'Room A '`
  (trailing space) and a tab-padded name both satisfy `Name = LTRIM(RTRIM(Name))`; only a
  leading space is rejected. T-SQL `=` ignores trailing spaces and `LTRIM`/`RTRIM` trim
  only plain spaces. The domain trims all Unicode whitespace, so the domain can never
  produce a name the check rejects; the check simply does not guard what it says. A
  stronger check, `DATALENGTH(Name) = DATALENGTH(LTRIM(RTRIM(Name))) AND LEN(Name) > 0`,
  rejects leading and trailing spaces and all-space names (verified by `SELECT`), but no SQL
  expression of this kind catches tab or no-break-space padding. Fixing the approved data
  model is an amendment needing the owner's approver record; it is raised before phase 3.
- **Review F5 (owner decision)**: an empty-string description is kept as `""`, not
  normalized to null. The spec does not decide it and no test pins it.
- **Review F7 (DOC DRIFT)**: plan.md and tasks.md name the third parameter `nowUtc`; the
  code takes `DateTimeOffset now` (converted to UTC inside), which suits
  `TimeProvider.GetUtcNow()`. Phase 3 also needs a UTC converter: EF reads `datetime2` back
  with `Kind` Unspecified.

### Phase 1 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (39 of 39 tests
passed), on commit `8e71df6` (phase 1 is `d5d4abb`, remediation `763fe1c`) - anas.m, 2026-10-18.

## Phase 2

- **Test-first**: written against throwing skeleton handlers: 20 of 22 failed (the 2 that
  passed are the existing dependency-rule tests). The strict build was run only after the real
  handlers existed (the skeleton's unread constructor parameters trip `--warnaserror`).
  After remediation: 27 Application tests, 64 across the solution.
- **Reviewer mutation checks** (all caught, all restored): removing `NameExistsAsync` failed 2
  tests; swapping the `DuplicateName` arm failed 1; looking up the untrimmed name failed 1;
  a maximum page size of 101 failed 1.
- **Review F1, F2 fixed**: `IResourceRepository` now states, as contract for phase 3: `AddAsync`
  assigns the database-generated `Id` to the same instance it was given; retired rows are
  invisible and their names do not block a new resource; names arrive trimmed and
  case-insensitivity is the store's collation; paging bounds are trusted and the offset must
  be 64-bit, an empty page past the end; cancellation and unexpected failures propagate.
- **Review F5, F6 fixed**: the fake assigns ids; the Get test discriminates between two
  resources; tests cover cancellation-token forwarding for all three handlers and
  store-failure propagation for create.
- **Review F3 (left, accepted)**: the `default` arm of the `AddResourceResult` switch is
  unreachable today. C# needs a discard arm to call an enum switch exhaustive, and throwing is
  the safe behaviour for a value added later; no test can reach it.
- **Review F4 (accepted, for phase 4)**: the outcome records are not exhaustive to the
  compiler. Phase 4 must map every subtype explicitly, make the fall-through arm throw, and
  cover each outcome over HTTP.
- **Review F6 remainder (open, minor)**: no test for a null command; `ResourcePage` can
  express page 0 or a mutable item list. Left as is: the API only builds commands from
  parsed requests, and the page type is only built by the repository and handlers.

### Phase 2 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (64 of 64 tests
passed), on commit `47d7d27` (phase 2 is `b4efceb`, remediation `1493236`) - anas.m, 2026-10-18.

### Decisions after the phase 1 review (owner, 2026-10-19)

- **CK_Resources_Name_Trimmed amended** (phase 1 review F2): `data-model.md` now uses
  `DATALENGTH(Name) = DATALENGTH(LTRIM(RTRIM(Name))) AND LEN(Name) > 0`, which rejects
  leading, trailing and all-space names; tab and no-break-space padding stays the domain's
  job. Amended by the owner (anas.m, 2026-10-19), before the migration that relies on it.
- **Empty description kept as given** (phase 1 review F5): `""` is stored as `""`. Pinned by a
  Domain test.

## Phase 3

- **Test-first**: the Infrastructure tests were run before the migration existed: 20 of 25 failed
  (the 5 that passed need no table: dependency rules and the constraint-free cases). The
  container, database creation and connection worked end to end. After the migration: 25
  Infrastructure tests, 90 across the solution.
- **Migration read against `data-model.md`**: columns, types, `PK_Resources`, the filtered unique
  index `IX_Resources_Name` and the three named check constraints match, including the amended
  `CK_Resources_Name_Trimmed`; `Down` drops the table (lawful only while empty).
- **Implementation choices**: `MsSqlBuilder()` without an image is obsolete under `--warnaserror`,
  so the fixture pins `mcr.microsoft.com/mssql/server:2022-latest`. Databases are created with
  `ExecScriptAsync` inside the container because no SQL client package is approved for
  TestSupport. xUnit v2 needs the collection definition in each test assembly, so phase 4's
  Api.Tests declares its own. TestSupport sets `IsTestProject=false` so `dotnet test` skips it.
- **Reviewer mutation checks** (9 applied, restored): 7 caught (`IgnoreQueryFilters` on each of the
  three reads, int offset arithmetic, `Skip` off by one, duplicate mapping removed, query filter
  removed from the mapping); 2 survived (below).
- **Review F1 (fixed in remediation)**: the paging test inserts names in ascending order, so ordering by
  `Id` instead of `Name, Id` still passes. Names are now inserted in descending order; the reviewer's `OrderBy(Id)` mutation fails it.
- **Review F2 (accepted)**: error 2627 is unreachable with a filtered unique index (SQL Server
  raises 2601); it is mapped because T022 names both.
- **Review F3 (accepted)**: `ListAsync` counts and pages in two statements; a concurrent insert
  can make them disagree. No consistency promise is made by the contract.
- **Review F4 (open, minor)**: the test image tag floats (`2022-latest`).
- **Review F5 (nits)**: undisposed context in `MigrationTests`; BOM dropped from the Infrastructure
  csproj; the over-length constraint tests assert only `SqlException`.
- **FIXED in remediation (found while writing these notes, not by the review): the UTC converter promised in
  phase 1 note F7 was not added.** Rows read back have `Kind` Unspecified; the round-trip test
  uses `Assert.Equal` on `DateTime`, which ignores `Kind`, so it cannot see this. Phase 4 would
  serialize the instants without a `Z`. Fix: a value converter (or `DateTime.SpecifyKind`) on
  the four UTC columns plus a test asserting `Kind == Utc`. Owner approved landing it as a phase 3 remediation (anas.m, 2026-10-19): value
  converters on `CreatedAtUtc`, `UpdatedAtUtc`, `DeletedAtUtc`; tests assert `Kind == Utc` (seen
  failing first); `has-pending-model-changes` reports no change, so the migration is untouched.
- **Size**: the phase commit is 826 lines in 23 files, over the enforcement-pack's 400/15
  guideline (warning only).

### Phase 3 gate certification

Gate 3 certified (user-run): `dotnet build BookingApi.slnx --warnaserror && dotnet test
BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (90 of 90 tests
passed), on the code of commit `6c08402` (phase 3) - anas.m, 2026-10-19. CI on `6c08402`:
`project-gate` and `ritual-checks` both green.

Gate 3 re-certified after the remediation (user-run): the same command, `EXIT: 0` (91 of 91 tests
passed), on commit `107a872` (phase 3 remediation; phase 3 is `6c08402`) - anas.m, 2026-10-19.

## Phase 4

- **Test-first**: the Api tests were run before any endpoint existed: 38 of 56 failed (the 18 that
  passed are the existing scaffold tests). After implementation: 56 Api tests, 134 across the
  solution.
- **Framework default fixed in Api (plan, Design Notes: API)**: in Development, minimal APIs
  throw on a bad request, and the exception handler turned that into a 500. Production already
  answered 400. `Program.cs` now sets `RouteHandlerOptions.ThrowOnBadRequest = false` in every
  environment; a Development test pins it.
- **`page` and `pageSize` are bound as text** and parsed by the endpoint, so a non-numeric value
  is a 400 that names the parameter (the contract), not the framework's generic binding failure.
  A value outside the int range is also a 400 naming the parameter. The OpenAPI document
  therefore shows both parameters as strings.
- **Outcome mapping**: every outcome subtype is mapped explicitly and the fall-through arm
  throws (phase 2 review F4). Nothing can reach that arm today, so no test covers it.
- **Tests**: the HTTP tests share the phase 3 container fixture through
  `ResourceApiFactory`, which forces a fresh migrated database and a forced connection string
  (a developer's user secrets never reach the gate). Api.Tests declares its own
  `SqlServerCollection` (xUnit v2).
- **`quickstart.md`** targets PowerShell 7: the `curl.exe` JSON bodies use its native-argument
  quoting (checked: backslash-escaped quotes would be sent literally). The quickstart itself
  has not been run against the owner's LocalDB database; that is the owner's SC-005 check.
