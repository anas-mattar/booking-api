# AI Code Review — 002 Resource Catalog, Phase 1 (Domain)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-18
**Branches**: booking-api `002-resource-catalog` (tip `b545120`; phase commit under review `d5d4abb`)
**Scope reviewed**: `git show d5d4abb` in full (`src/BookingApi.Domain/Resource.cs`,
`tests/BookingApi.Domain.Tests/ResourceTests.cs`); `git diff d5d4abb HEAD` (checkbox ticks);
`src/BookingApi.Domain/BookingApi.Domain.csproj`; `tests/BookingApi.Domain.Tests/DependencyRuleTests.cs`
(existence and pass state); spec.md FR-001/FR-006/FR-008/FR-009, US1, Edge Cases; plan.md Design
Notes and Constitution Check; tasks.md Phase 1; data-model.md; contracts/resources-api.md (create
and Audit sections); backend-rules.md (API Surface, Domain Logic); specs/001-solution-scaffold/notes.md
(platform-sensitivity context). Not read line by line: the constitution and the other rulebooks
beyond the points cited below.
**Feature contract**: no new package; Domain references no project and no package; no use case,
port, EF mapping or endpoint in phase 1; nothing can update, retire or delete a resource.

## Reviewer Provenance

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 / Claude Opus 5.5 session (the implementing agent session that produced commit d5d4abb)
- **Inputs provided**: commit d5d4abb diff and stat; the follow-up tick commit b545120; spec.md, plan.md, tasks.md, data-model.md, contracts/resources-api.md of feature 002; backend-rules.md; specs/001-solution-scaffold/notes.md; this review template
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — Phase 1 adds one entity (`Resource` with a private constructor, a
validating factory `Create`, read-only state including the retirement marker) and a small result
type, all inside Domain, with 18 new tests. Every rule in scope (name trimmed then 1-100,
description at most 500 and kept as given, field names `name`/`description`, all invalid fields
reported together, UTC instants, `anonymous` audit users, not retired) is implemented and pinned by
a test; build, tests, scope-check and ritual-checks are green. I found no blocking defect. The
follow-ups are: `CreateResourceResult` can express states that make no sense (F1), a database
check constraint in the approved data model is weaker than its documented intent (F2, for the
phase 3 owner), and a few small test, citation and wording gaps (F3-F8). Residual risk sits in the
Domain-to-database seam, which phase 3 must prove against real SQL Server.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | FR-001 name: `Resource.cs` `name?.Trim() ?? ""`, then `Length == 0` (required) and `> MaxNameLength` (100) checks; tests `CreateTrimsTheName`, `CreateAcceptsNamesAtTheLengthLimits(1,100)`, `CreateMeasuresTheNameAfterTrimming` (100 chars padded to 104 raw), `CreateRejectsAMissingOrBlankName` (null, "", "   ", "\t\n"), `CreateRejectsANameOver100Characters` (101). FR-001 description: `description is { Length: > 500 }`, stored untouched; tests `CreateKeepsTheDescriptionAsGiven` (null, text, "   "; the "   " row would fail if the code trimmed, so it is meaningful), `CreateAcceptsADescriptionOf500Characters`, `CreateRejectsADescriptionOver500Characters` (501). Field names `NameField="name"`, `DescriptionField="description"`, asserted as literals in tests. All fields together: one error list, no early return; `CreateReportsEveryInvalidFieldAtOnce` pins order `["name","description"]` and non-empty messages. FR-008: `now.UtcDateTime`, `AnonymousUser="anonymous"` for creator and updater; `CreateStampsBothInstantsAndBothUsers` (values and `DateTimeKind.Utc`), `CreateConvertsAnOffsetInstantToUtc` (+03:00 input becomes 12:00Z). Not retired: `ANewResourceIsNotRetired`. FR-009: no member reachable from outside changes `IsDeleted`/`DeletedAtUtc`/`DeletedBy`; no update, retire or delete member exists (file read in full). FR-006 properties are available; DTO mapping is phase 4 and correctly absent. Edge cases reasoned through: null vs empty description (null stays null, "" stays "", see F5); 100 chars after trim but 102 raw is accepted (covered with 104 raw); surrogate pairs: length is UTF-16 code units, equal to `nvarchar(n)` capacity under non-SC collations, so a name the domain accepts fits the column; `DateTimeOffset.MinValue/MaxValue`: `UtcDateTime` does not throw for any `DateTimeOffset` (the stored clock time is already UTC internally), so no overflow path, and `datetime2` covers the full `DateTime` range. |
| Visual-reference match | N/A: no UI or visual reference exists for this feature; no deviation table applies. |
| Feature contract held (no unapproved table/migration/permission/package) | `BookingApi.Domain.csproj` read: no `ProjectReference`, no `PackageReference`. `git show --stat d5d4abb`: 2 files, both new, both under Domain or Domain.Tests. No Application, Infrastructure or Api file touched; no repository port, mapping, migration or endpoint present. The dependency-rule test in `tests/BookingApi.Domain.Tests/DependencyRuleTests.cs` still passes (Domain.Tests has 19 passing tests: 18 new in `ResourceTests` plus 1 existing dependency-rule test). |
| Constitution / domain invariants | Invariant 2 (UTC): instants converted via `UtcDateTime`, Kind asserted. Invariants 4 and 5 (no delete, soft delete): retirement marker exists as read-only state, no operation sets it. Principle VIII: rules have tests at the owning layer (Domain). Principle X: phase 1 only, Phase 2+ content absent. Principle IV (layering): Domain has no framework or project reference. |
| Security (authn/authz, secrets, sensitive logging) | No I/O, logging, secrets or auth in the diff. `anonymous` is the approved interim value (spec FR-008). Validation messages are fixed text and limits, never user input. Nothing further applies at this layer. |
| Scope guard (`scope-check.ps1` PASS on the phase commit; `git diff --stat` read for intent) | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit d5d4abb` printed `scope-check: PASS phase 1 commit d5d4abb (2 file(s))`. `pwsh -NoProfile -File scripts/ritual-checks.ps1`: doc-lint OK, enforcement-pack OK, scope-check OK, scope-repos n/a, digests OK, roadmap-claims OK, verify-kit OK, `RESULT OK`. Diff stat read: 99 + 133 insertions, matches the commit message. |
| Rollback safety (phase reverts cleanly; schema additive?) | The commit only adds two files and modifies none, so `git revert d5d4abb` is a clean deletion (after reverting the tick commit b545120, which touches only `tasks.md` checkboxes). No schema, migration or data exists yet. |
| Build and tests | `dotnet build BookingApi.slnx --warnaserror`: succeeded, 0 warnings, 0 errors. `dotnet test BookingApi.slnx --no-build`: Domain.Tests 19 passed / 0 failed; Application.Tests 2 passed / 0 failed; Api.Tests 13 passed / 0 failed. |
| Platform sensitivity (cf. feature 001 notes) | `ResourceTests.cs` uses no file paths, no culture-sensitive comparison, no `ToLower/ToUpper`, no `string.Compare`, no environment or live clock. `string.Trim()` and `Length` are culture-invariant and identical on Linux and Windows; xUnit `Assert.Equal` on strings is ordinal. The `DateTimeOffset` inputs are fixed. I found no reason the suite would behave differently on ubuntu CI. I did not run it on Linux. |

## Findings

### F1 — `CreateResourceResult` can express "success with no value" and "value and errors" — MINOR

`CreateResourceResult` has public `init` setters for `Value` and `Errors`, and
`IsSuccess => Errors.Count == 0`. Outside the factory, `new CreateResourceResult()` (neither set) is
`IsSuccess == true` with `Value == null`, and a result with both a `Value` and `Errors` is
representable. `Resource.Create` itself always builds a consistent result (verified: failure sets
only `Errors`, success sets only `Value`), so there is no bug today. But phase 2 handlers will
write `result.Value!` after `IsSuccess`, and nothing in the type stops a future producer (a test
fake, say) from violating that. In addition `Errors` is the same `List<ValidationError>` the
factory built, exposed as `IReadOnlyList`, so a consumer can cast and mutate it. The type needs no
framework and its shape (success flag, value, field-keyed errors) is adequate for phase 2; the
problem is only that it is not tamper-proof.
*Action: implementing agent, before or in phase 2: make the constructor private or internal and expose `Success(Resource)` / `Failure(IReadOnlyList<ValidationError>)` (or derive `IsSuccess` from `Value is not null`), with a test that a failure has `Value == null` and a success has empty `Errors`. Not blocking phase 1 approval; owner may defer.*

### F2 — Approved `CK_Resources_Name_Trimmed` is weaker than its stated intent (T-SQL `=` ignores trailing spaces; LTRIM/RTRIM trim only U+0020) — CONFIRM

Question asked: can the domain accept a name the database CHECK rejects, or the reverse?

- Domain to database: no. `string.Trim()` removes every `char.IsWhiteSpace` character (space, tab,
  newline, NBSP U+00A0, U+3000, U+0085, U+2028/9 and others) from both ends, so any name the
  domain accepts has no leading or trailing whitespace of any kind, hence no leading or trailing
  space, and `Name = LTRIM(RTRIM(Name))` holds. `LEN(Name) > 0` holds because the trimmed name has
  at least one non-whitespace character. The domain is the stricter side, so a valid `Create`
  result can never be rejected by the CHECK, and a 500 from this CHECK cannot arise on the Create
  path. Length: UTF-16 code units match `nvarchar(100)` capacity (a surrogate pair counts 2 on
  both sides).
- Database to domain (the reverse): the CHECK accepts names the domain would never produce, for
  example a leading or trailing tab, newline or NBSP (LTRIM/RTRIM leave them). Harmless while the
  domain is the only writer, but the CHECK does not do what data-model.md says ("stored trimmed").
- A separate weakness in the approved definition: under SQL Server's default ANSI padding, `=`
  ignores trailing spaces, so `'Room A ' = LTRIM(RTRIM('Room A '))` is true. The CHECK therefore
  catches leading spaces but not trailing spaces. The same padding rule makes the unique index
  treat `'Room A'` and `'Room A '` as equal, which helps FR-002, but the database is not the
  trimming guarantee the data model implies. This comes from documented T-SQL semantics; I did
  not run SQL Server (none exists in phase 1).

This is a phase 3 matter, not a phase 1 defect, and data-model.md is an approved document I must
not edit. A real-SQL-Server test in phase 3 should insert `' x'`, `'x '` and `N'x'` plus NBSP
directly and record which are rejected, so the model's claim matches observed behaviour.
*Action: owner (anas.m) to decide at phase 3 whether to amend data-model.md (for example strengthen the check, or document it as "defence in depth, domain is authoritative") or accept it as is; implementing agent to add the direct-insert test in phase 3. No change to phase 1 code.*

### F3 — Tests do not pin non-ASCII whitespace trimming — MINOR

`CreateTrimsTheName` uses space and `\t`; the blank-name theory uses spaces, tab and newline. The
domain's behaviour for NBSP (U+00A0) and ideographic space (U+3000) is a consequence of `Trim()`
and is the premise of the F2 analysis, but no test pins it, so a later change to `Trim(' ')`
would pass the suite and open exactly the gap described in F2.
*Action: implementing agent: add one case for `" Room A　"` (trimmed to "Room A") and one for a name made only of `" 　"` (rejected as blank). Optional for this phase; may be folded into phase 2 or a fix commit.*

### F4 — File headers cite spec and data-model but not the contract — MINOR

backend-rules.md (API Surface) requires code implementing a feature contract to cite the contract
file at the top. `Resource.cs` and `ResourceTests.cs` cite `spec.md FR-001, FR-008, FR-009;
data-model.md` and not `contracts/resources-api.md`, although the field names and create rules come
from the contract. Domain is not the API layer and the cited FRs carry the same rules, so nothing
is functionally wrong.
*Action: implementing agent: add `contracts/resources-api.md` (create section) to the two header comments when next touching these files; no separate commit needed.*

### F5 — Empty-string description is kept as `""`; not specified, not tested — MINOR

`Create("Room A", "")` succeeds and stores `""`; only `null` and whitespace-only text are covered.
The contract says "Absent and `null` mean none" and spec and T001 say the description is kept as
given, so `""` stored as `""` follows the literal text, but FR-006 says `description` is `null`
"when absent", and one client could send `""` while another omits the field. The approved
documents do not decide this.
*Action: owner (anas.m) to confirm that "kept as given" includes `""`; if so, add a one-line test pinning it so phases 2 and 4 do not normalise it differently. No code change unless the owner decides otherwise.*

### F6 — Minor test-strength gaps — MINOR

(a) `CreateRejectsANameOver100Characters` and the description-over-500 test assert the field name
but not `Assert.Null(result.Value)` (only the blank-name theory does). (b) Messages are asserted
non-empty only in the "both invalid" test, not their content; acceptable, since the contract
specifies them only as "messages". (c) No assertion is vacuous: `Assert.All(result.Errors, ...)`
runs after `Assert.Equal(["name","description"], ...)` proves the list is non-empty, and the array
`Assert.Equal` compares elements in order, which is intended. I did not run a mutation probe, but
the trim test, the blank theory and the 104-raw case each depend on `Trim()`, and the implementer's
report of 18 of 19 failing against a throwing skeleton is consistent with the one passing test
being the existing dependency-rule test.
*Action: implementing agent: add the two `Assert.Null(result.Value)` lines when next touching the file; otherwise none.*

### F7 — Forward notes for phase 3 (EF mapping) and plan wording — DOC DRIFT

(a) Private setters, a private parameterless constructor and `int Id { get; private set; }` are
workable with EF Core fluent configuration and no attributes in Domain: EF binds to private
setters by convention and materialises through a private parameterless constructor, so `Id` and
the retirement marker can be set by EF only, as intended. (b) EF returns `DateTime` values with
`Kind == Unspecified` from `datetime2`, so the domain's `Kind == Utc` guarantee holds only at
creation; phase 3 needs a UTC value converter (or phase 4 must serialise with an explicit UTC
offset, FR-006). (c) plan.md and tasks.md name the factory `Create(name, description, nowUtc)`; the
code is `Create(string? name, string? description, DateTimeOffset now)`. Behaviour is the same, and
`TimeProvider.GetUtcNow()` returns a `DateTimeOffset`, so this fits phase 2 better than a
`DateTime` would; only the wording is stale.
*Action: implementing agent: in phase 3 add the UTC converter and a read-back `Kind` test; owner may touch the plan wording at the next approved amendment, no urgency.*

### F8 — Public surface and placement — MINOR

`ValidationError` and `CreateResourceResult` live in `Resource.cs` beside the entity, so one file
holds three public types. Placing `ValidationError` in Domain is sensible (Application and Api both
reference Domain and need it; moving it later is cheap). The public constants (`NameField`,
`DescriptionField`, limits) are useful to Application and tests. Nothing needs to be `internal`.
No rule in backend-rules.md requires one type per file.
*Action: none.*

## Amendments in this diff

- [x] **None** stated explicitly. `git show --stat d5d4abb` touches only
  `src/BookingApi.Domain/Resource.cs` and `tests/BookingApi.Domain.Tests/ResourceTests.cs`. The
  follow-up commit b545120 changes only `tasks.md` checkboxes T001-T005 (diffing d5d4abb..HEAD with
  checkbox lines removed leaves nothing). The one-line `plan.md` change in the branch history
  belongs to the approval commit d97adcd, not to this phase. No spec.md, plan.md, data-model.md or
  contracts/ change was made by phase 1.

## Constitution re-check (post-implementation)

PASS. Satisfied: IV (layering: Domain has no project or package reference, csproj read and the
dependency-rule test passes), V (domain invariants 2, 4 and the resource half of 5 are respected;
no retire operation exists), VIII (each rule has an automated Domain test; real-SQL-Server proof is
correctly deferred to phase 3), X (single phase, scope-check PASS, tasks ticked, awaiting the user
gate), I (no approved document amended). N/A at this phase: VI (security, no endpoint yet) and VII
(external integration); IX is what this review performs. Nuance versus the plan-time check: F2
shows the database trim constraint is weaker than the plan implies; it engages in phase 3.

## Test coverage observed

`tests/BookingApi.Domain.Tests`: 19 tests, all passing: 18 in `ResourceTests` (12 methods; the
theories add rows) plus the existing Domain dependency-rule test. Critical assertions: trim result
("Room A"); name length boundaries 1, 100, 101 and "100 after trim, 104 raw"; blank inputs
null, "", "   ", "\t\n"; description null, text and whitespace-only kept exactly; 500 accepted, 501
rejected; both fields invalid gives both errors in order name, description; UTC instants with
`Kind == Utc`; +03:00 input converted to 12:00Z; `anonymous` for creator and updater; not retired.
Gaps: F3 (non-ASCII whitespace), F5 (`""` description), F6 (null Value on some failure paths).
Application.Tests (2) and Api.Tests (13) are unchanged and passing.

## Residual risk

Low for phase 1. The risk is concentrated at the Domain-to-database seam: F2 (the approved trim
CHECK does not enforce what it says; trailing spaces and non-space whitespace are not rejected by
it) and F7(b) (UTC `Kind` lost on read) must be handled in phase 3 with real SQL Server tests, and
F1 should be closed before phase 2 code starts relying on `Value!`. Nothing here blocks proceeding
to the user gate for phase 2.
