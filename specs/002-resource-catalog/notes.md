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
