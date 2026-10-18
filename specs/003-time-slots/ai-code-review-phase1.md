# AI Code Review — 003 Time Slots, Phase 1 (Domain)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-19
**Branches**: booking-api `003-time-slots` (tip `b33164b`; phase commit under review `36ad545`)
**Scope reviewed**: `git show 36ad545` in full (3 files): `src/BookingApi.Domain/TimeSlot.cs`,
`tests/BookingApi.Domain.Tests/TimeSlotTests.cs`, `tests/BookingApi.Domain.Tests/SlotIntervalTests.cs`. Also read:
CLAUDE.md, `docs/domain/booking-invariants.md` (all five), `critical-delivery.md` (opening), spec.md (all), plan.md
(Design Notes, phase table), tasks.md (Phase 1 and Territory), data-model.md (half-open section), notes.md (Phase 1),
`BookingApi.Domain.csproj`. Not read line by line: `contracts/slots-api.md` (field names only checked via the
constants), `review-process.md`, the docs-only commit `b33164b`.
**Feature contract**: no new package; Domain keeps no project or package reference; no update, retire or delete of a
slot (FR-010); the overlap predicate is defined once; this phase has no persistence, endpoint or migration.

## Reviewer Provenance

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 session (the implementing agent session that produced commit 36ad545)
- **Inputs provided**: phase 1 diff (`36ad545`), spec.md, plan.md, tasks.md, data-model.md, notes.md, booking-invariants.md, ai-code-review template, phase 3 review of feature 002 (format only)
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — the phase adds the `TimeSlot` entity, `CreateTimeSlotResult`, and the single
`SlotInterval.Overlaps` half-open predicate, with 41 new Domain tests, all within territory and with no new reference.
The code matches FR-002 (Domain half), FR-003, FR-004 (predicate), FR-008 (shape) and FR-010; the predicate is exactly
`a.Start < b.End && b.Start < a.End`. Thirteen mutations were applied: twelve were caught, one survived (F1, the thin
test of the `TimeSlot.Overlaps` wrapper). No BLOCKER or MAJOR finding. This is not certification: the owner runs the
gate (Critical). Residual risk sits in the contracts that later phases must keep consistent (F2, F3), not in this diff.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | **FR-002 (Domain half)**: `Create` takes `DateTimeOffset` and uses `.UtcDateTime` before any comparison; `AnOffsetInstantIsStoredAsUtc` (`11:00+02:00` -> `09:00Z`, Kind Utc), `TheOffsetIsNormalizedBeforeTheComparison` (`10:30+02:00` = `08:30Z` refused although it looks later). Parsing, missing, null and offset-less input are the API's job (phase 4, not this phase). **FR-003**: `endUtc <= startUtc` -> one `endUtc` error; theory covers equal, -1 tick, -1 hour; `OneTickAfterTheStartIsAValidEnd` pins strictness. **FR-004 (predicate)**: `SlotInterval.Overlaps` is `aStart < bEnd && bStart < aEnd`; `SlotIntervalTests` has 15 hand-worked cases (touching before and after, identical, contained, containing, both partials, disjoint x2, one-tick overlap and gap at both ends, shared start only, shared end only), each also run with A and B swapped (30 theory cases). **FR-008**: properties id, resourceId, startUtc, endUtc, createdAtUtc, updatedAtUtc exist; retirement and audit-user columns exist as properties (to be hidden by the phase 4 DTO). **FR-010**: all setters private, no method sets `IsDeleted`/`DeletedAtUtc`/`DeletedBy`; `ANewSlotIsNotRetired`. **SC-006 (Domain half)**: met by the table above; database half is phase 3. |
| Visual-reference match | Not applicable: no UI. |
| Feature contract held (no unapproved table/migration/permission/package) | `git show --stat 36ad545` lists three `.cs` files only; no csproj, no migration. `BookingApi.Domain.csproj` unchanged: no `ProjectReference`, no `PackageReference` (read in full; only `net10.0`, ImplicitUsings, Nullable). `dotnet build src/BookingApi.Domain --warnaserror` -> 0 errors. |
| Constitution / domain invariants | See the item-by-item section below. |
| Security (authn/authz, secrets, sensitive logging) | No I/O, no secrets, no logging; creator recorded as the constant `anonymous` as the spec allows. |
| Scope guard | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit 36ad545` -> `scope-check: PASS phase 1 commit 36ad545 (3 file(s))`. `pwsh -NoProfile -File scripts/ritual-checks.ps1` -> doc-lint, enforcement-pack, scope-check, digests, roadmap-claims, verify-kit OK; scope-repos n/a; `RESULT OK` (run before this review file was added). Stat read: 275 insertions, 113 production lines, 162 test lines. |
| Rollback safety | Purely additive: three new files, no schema, no consumer yet. Reverting the commit removes them with nothing depending on them. |
| Test-first claim (notes.md) | Not independently reproducible from history: only the final commit exists, so "41 of 66 failed against a throwing skeleton" is taken as the implementer's statement. My mutation results are consistent with tests that bite. |
| Build and tests | Scoped only (no gate run, per the Critical rule): `dotnet test tests/BookingApi.Domain.Tests` -> Passed 66, Failed 0 (25 pre-existing + 41 new). |
| Mutation check (each restored with `git checkout -- src/BookingApi.Domain/TimeSlot.cs`; `git status --short` empty afterwards) | CAUGHT: `aStart <= bEnd` (2 failures); `&&` -> `\|\|` (13); second clause dropped (7); `endUtc < startUtc`, i.e. empty interval allowed (1); start not normalized (`.DateTime`) (2); end not normalized (3); comparison on raw offset values (1); `EndField` renamed to `startUtc` (4); `UpdatedBy` blank (1); `UpdatedAtUtc` wrong (1); `ResourceId` forced to 0 (1); `TimeSlot.Overlaps` replaced by constant `true` (1). SURVIVED: `TimeSlot.Overlaps` passes `(start, start)` as the interval (F1). |

## Invariant pass (Critical: each of the five, item by item)

| # | Invariant | Status in this phase | Evidence |
|---|---|---|---|
| 1 | No Double Booking | **Cannot yet exercise** (no booking exists). **Prepares** the same class of rule for slots: the half-open predicate is the single definition the Application check and the phase 3 trigger must restate. Not violated. | `SlotInterval.Overlaps` and its 30-case table, including touching = no overlap and one-tick cases. Concurrency and the database half are explicitly phase 3 (T015, T021); nothing in this diff claims them. |
| 2 | Time Is UTC | **Exercised** (the one invariant this phase directly implements): every instant converted to UTC before comparison and storage; `start < end` enforced strictly; no `DateTime.Now` and no unspecified-kind value created. | `Create` uses `UtcDateTime` for start, end and `now`; `Kind` asserted Utc in two tests; `TimeSlot.cs` contains no `DateTime.Now`/`UtcNow`/`DateTime.Parse`; the clock is injected (`now`). Reject paths tested at equal, -1 tick, -1 hour and across offsets. Offset-less input cannot reach this API by type (`DateTimeOffset`); the parser that must refuse it is phase 4. Caveat F2: `SlotInterval.Overlaps` takes bare `DateTime` and does not check `Kind`. |
| 3 | Booking Lifecycle | **Cannot yet exercise** (no booking or status). **Respected**: the slot has no status or transition table, so no divergent state machine is introduced. | `TimeSlot` has no status property or mutator. |
| 4 | Bookings Are Never Deleted | **Cannot yet exercise** (no booking). **Respected** for slots: no delete or retire path exists in code (FR-010). | No public method mutates `IsDeleted`; setters private; the only constructor is private and used by `Create`. |
| 5 | Bookable Only Within a Slot | **Prepares** (the slot is what a booking will later have to fall inside) and **respects** the retire half: a slot cannot be hard-deleted or retired by this code, and nothing here lets a booking exist outside a slot. The "retired resource accepts no booking" half cannot yet be exercised (no booking; resource retirement not touched). | `TimeSlot` entity with `ResourceId`; retirement marker present but read-only. Existence of the resource is explicitly left to Application (`Create` doc comment). F3 notes the retired-slot rule is not in the Domain predicate. |

## Findings

### F1 — `TimeSlot.Overlaps` is under-tested; a wrong argument mapping survives — MINOR

`ASlotOverlapsAnIntervalExactlyWhenThePredicateSaysSo` asserts one true and one false case. Mutation: replace the body
with `SlotInterval.Overlaps(StartUtc, EndUtc, start, start)` (the end argument is ignored): all 66 tests still pass. For
the two chosen inputs `(start, start)` happens to give the same answers, so the test cannot tell. The predicate itself is
well covered; only the instance wrapper is not. Risk is low if phases 2 and 3 call `SlotInterval` directly (plan.md says
"`TimeSlot.Overlaps` / the interval helper"), but if the wrapper is used it is unprotected.
*Action: implementer adds one or two discriminating cases to `TimeSlotTests` (for example a containing interval and a
touching-before interval), or deletes the wrapper if no later phase uses it. Not blocking.*

### F2 — Predicate accepts unvalidated `DateTime` and degenerate intervals — MINOR

`SlotInterval.Overlaps(DateTime, DateTime, DateTime, DateTime)` neither checks `DateTimeKind` nor that each interval has
`start < end`; a caller passing local or unspecified `DateTime` values compares them raw (invariant 2, "comparing
instants across time zones without normalizing"). Inside Domain this is safe because `TimeSlot` stores only UTC, and
later callers are expected to pass `StartUtc`/`EndUtc` of a validated slot. It is a latent trap for phase 2 (a handler
passing the request's instants) and phase 3. Also `Create` does not validate `resourceId` (> 0); a non-positive id is for
the repository and foreign key to refuse.
*Action: no change required now. Phase 2 review must confirm every call to `Overlaps` uses values produced by
`TimeSlot.Create` (UTC), never raw request values; optionally document "arguments must be UTC" on the method.*

### F3 — Retired slots do not block overlap, but the Domain predicate does not know about retirement — MINOR

FR-004 says non-overlap applies among non-retired slots only. `TimeSlot.Overlaps` ignores `IsDeleted`: called on a
retired slot it still reports an overlap. Retirement is the query filter's and trigger's job per plan (invisible rows),
so this is by design, but it is an implicit contract that no test or comment states.
*Action: the phase 2 port contract and phase 3 tests (T015, T019) must carry the "retired does not block" rule;
optionally add a one-line remark on `TimeSlot.Overlaps`. Nothing needed in this phase.*

### F4 — Sub-tick precision — ACCEPTED

`DateTimeOffset` carries 100 ns ticks, equal to `datetime2(7)` (plan.md, Instant precision), so no rounding occurs in
Domain and the one-tick tests are meaningful. The 15 boundary cases include one-tick overlap and gap at both ends.
*Action: none.*

### F5 — Test-first evidence cannot be verified from history — MINOR

notes.md records that tests were seen failing against a throwing skeleton, but only one phase commit exists, so a
reviewer cannot check it. Mutation results indicate the tests discriminate regardless.
*Action: none; for later phases the owner may ask for a red-state commit or a pasted run if the audit needs it.*

## Amendments in this diff

- [x] **None.** The commit touches only `src/BookingApi.Domain/TimeSlot.cs` and two Domain test files. spec.md, plan.md,
  tasks.md and contracts/ are unchanged by `36ad545` (the follow-up docs commit `b33164b` ticks T001-T007 in tasks.md,
  a progress mark, not a change to scope or wording).

## Constitution re-check (post-implementation)

**PASS.** IV (layering and dependency policy): Domain has no framework, EF attribute, project or package reference; no
package added. V (domain invariants): invariant 2 implemented and tested, 1 and 5 prepared, 3 and 4 untouched (see the
invariant pass). VIII (tests at the owning layer): rules are tested in Domain.Tests with hand-worked expected values, no
mock or stand-in needed. I/II (source of truth, amendments): code matches the approved spec, plan and data-model; no
document amended by the phase. X (Critical): no gate was run by the agent; certification stays with the owner.

## Test coverage observed

`BookingApi.Domain.Tests`: 66 passed, 0 failed (25 pre-existing resource tests, 41 new). `SlotIntervalTests`: the
15-row hand-worked table, run forward and with A/B swapped (30 theory cases); critical assertions are touching before
and after = false, one-tick overlap = true, one-tick gap = false, identical = true. `TimeSlotTests`: valid creation and
UTC Kind, offset normalization, end equal / -1 tick / -1 hour rejected with one `endUtc` error, +1 tick accepted,
normalization before comparison, immutable error list, audit fields and `anonymous`, not retired, instance wrapper
(weak, F1). Thirteen mutations, twelve caught.

## Residual risk

Low for this phase. The risk that matters for the feature, no overlap under concurrency (invariant 1's standard), is not
in this diff and sits entirely in phase 3 (trigger, T015 first, plus parallel-insert tests against real SQL Server); the
predicate here is the reference they must all match. Before phase 2: address F1 optionally and keep F2 and F3 in mind
when reviewing the handlers. Merge readiness remains subject to the owner's gate, the later phases, human review, the
second-model review and the 24-hour cooling-off.
