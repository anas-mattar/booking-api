# AI Code Review — 003 Time Slots, Phase 2 (Application)

**Reviewer**: fresh-context agent - claude-sonnet-5-5
**Date**: 2026-10-19
**Branches**: booking-api `003-time-slots` (tip `f1a3fc4`; phase commit under review `b8ac1aa`)
**Scope reviewed**: `git show b8ac1aa` in full (7 files): `src/BookingApi.Application/Slots/{ISlotRepository,Outcomes,SlotHandlers}.cs`,
`tests/BookingApi.Application.Tests/Slots/{TestDoubles,OpenSlotHandlerTests,GetSlotHandlerTests,ListSlotsHandlerTests}.cs`.
Also read: CLAUDE.md, `docs/domain/booking-invariants.md` (all five), spec.md (FR-001 to FR-008, FR-010, user stories),
plan.md (Application design note), tasks.md (Phase 2 and Territory), `contracts/slots-api.md`, notes.md (Phase 1 and 2),
`ai-code-review-phase1.md` (F2 and F3), `Resources/` (feature-002 pattern: port, outcomes, create handler),
`BookingApi.Application.csproj`. Not read line by line: data-model.md, critical-delivery.md and review-process.md (the
review follows the template and the task's checklist), Domain `TimeSlot.cs` beyond its public surface.
**Feature contract**: Application references only Domain and no framework package; no persistence, endpoint, migration
or package in this phase; every expected outcome is a value; no update, retire or delete of a slot (FR-010).

## Reviewer Provenance

- **Reviewer**: fresh-context agent - claude-sonnet-5-5
- **Implementer**: Claude Sonnet 5.5 session (the implementing agent session that produced commit b8ac1aa)
- **Inputs provided**: phase 2 diff (`b8ac1aa`), spec.md, plan.md, tasks.md, contracts/slots-api.md, notes.md, booking-invariants.md, phase 1 review, feature-002 Application pattern, ai-code-review template
- **Attestation**: This reviewer did not produce the diff under review.

## Verdict

**APPROVE with follow-ups** — the phase adds `ISlotRepository` with a documented contract, nine outcome records, and
`OpenSlotHandler`, `GetSlotHandler`, `ListSlotsHandler`, mirroring feature 002, plus 37 new tests (64 total in
Application.Tests, all pass). Every use-case outcome maps one-to-one to a status of the contract, the phase 1 follow-ups
F2 and F3 are handled in the port documentation and handler code, and the project still references only Domain. Twelve
handler mutations were applied: ten caught, one did not compile, and two ordering mutations survived (F1), so the
"resource first, then validation" rule the plan states is not pinned by a test. No BLOCKER or MAJOR finding. This is not
certification: the owner runs the gate (Critical). Residual risk sits in phase 3, which must satisfy a port contract that
has two unstated corners (F2) and a fake that is looser than the real store (F3).

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | **FR-001**: `OpenSlotHandler` returns `SlotOpened(slot)`, the same instance the port gave an `Id` (test `Assert.Same(Assert.Single(_slots.Stored), opened.Slot)`, `Id > 0`, clock instants). **FR-003**: `SlotInvalid` carries the Domain error; theory `(10,9)` and `(9,9)` asserts a single `endUtc` field error, no overlap check, no add. **FR-004**: handler checks `OverlapExistsAsync` then relies on `AddSlotResult.Overlaps` for the race; five overlap shapes refused, three touching/disjoint accepted, other resource not blocking, offset instants compared as UTC (`11:00+02:00` vs existing `09:00Z`). **FR-005**: resource looked up through `IResourceRepository.GetByIdAsync` (non-retired) before anything else in all three handlers; open: `OverlapChecks == 0` and `AddCalls == 0` for an unknown resource. **FR-006**: get returns `SlotFound`/`SlotNotFound`/`GetSlotResourceNotFound`; another resource's slot is `SlotNotFound` (fake scopes by resource id). **FR-007**: `ListSlotsHandler` reuses `ListResourcesHandler.DefaultPage`, `DefaultPageSize`, `MaxPageSize`, `PageField`, `PageSizeField`; bounds tested at 0, -1, `int.MinValue`, 0, -5, 101, `int.MaxValue`; both errors at once; valid values (including page `int.MaxValue`) reach the port unchanged. FR-002 parsing is phase 4; FR-008 and FR-010 untouched (no update or retire method anywhere). |
| Contract status mapping (one-to-one) | `SlotOpened` 201; `SlotInvalid` 400; `SlotOverlaps` 409; `OpenSlotResourceNotFound` 404; `SlotFound` 200; `SlotNotFound` 404; `GetSlotResourceNotFound` 404; `SlotsListed` 200; `ListSlotsInvalid` 400; `ListSlotsResourceNotFound` 404. Each contract row that a handler can produce has exactly one outcome type, no two statuses share a type, and no outcome lacks a status. Rows the handler cannot produce (empty or malformed body, non-numeric ids, unparsable instants) belong to the API layer (phase 4). The unexpected add result throws (`InvalidOperationException`), a fall-through arm as in feature 002. |
| Handler ordering | Resource check, then validation, then overlap check, then add: matches plan.md's design note word for word. The contract states no precedence between 404 and 400; see F1. |
| Port contract (`ISlotRepository`) | States: retired slots invisible to every member and never block; overlap per resource among non-retired on half-open intervals via `SlotInterval.Overlaps`, enforced by the database under concurrency; instants are UTC values from `TimeSlot.Create` (phase 1 F2); the port does not check the resource; the same instance gets its `Id` on `Added`; `Overlaps` covers the race; get scoped by resource and id; list ordered by start then id with non-retired totals; caller validates bounds; 64-bit offset; cancellation and unexpected failures propagate. Two corners not stated: see F2. |
| Phase 1 follow-ups | **F2 (UTC values from Create)**: handler passes `slot.StartUtc`/`slot.EndUtc` of the entity returned by `TimeSlot.Create`, never the raw command instants (`SlotHandlers.cs`, overlap call); the port doc says the same. The fake passes its arguments straight to `TimeSlot.Overlaps`. Handled. **F3 (retired does not block)**: stated in the port remarks and in the `OverlapExistsAsync`/`GetAsync` docs, and the fake filters `!s.IsDeleted`. Handled in words; it cannot be exercised by a test yet because `IsDeleted` has a private setter and nothing sets it (see F3 below); phase 3 must carry it (T019). |
| Fake repository fidelity | Id assigned to the same instance (reflection on the private setter); get and overlap scoped by resource and filtered on `IsDeleted`; token recorded on every member; `FailWith` throws from every member. Looser than the port in places: F3. |
| Test discrimination (mutations of `SlotHandlers.cs`, each restored with `git checkout --`, rebuilt, 64 pass, 0 warnings, `git status --short` empty) | CAUGHT: overlap args swapped (5 failures); get with `resourceId` as the slot id (2); list passes page and size swapped (3); page `< 0` instead of `< 1` (2); size `< 0` instead of `< 1` (2); default page 2 (1); `AddSlotResult.Overlaps` mapped to `SlotOpened` (1); `SlotInvalid` with empty errors (2); default page size 10 (1); max page size 101 (1); wrong field name on the page error (4). Did not compile (not a result): `slot with { }` on a non-record. **SURVIVED**: (a) `OpenSlotHandler` resource check only when `End > Start`, i.e. validation first for an invalid interval on an unknown resource: 64 pass; (b) `ListSlotsHandler` resource check only when the paging is valid, i.e. validation first: 64 pass (F1). The implementer's own ten mutations (notes.md) are consistent with these. |
| Application dependencies | `BookingApi.Application.csproj` read: one `ProjectReference` (Domain), no `PackageReference`. `dotnet build tests/BookingApi.Application.Tests` after restoring: 0 warnings, 0 errors. |
| Feature contract held | `git show --stat b8ac1aa`: seven `.cs` files, all under `src/BookingApi.Application/` or `tests/BookingApi.Application.Tests/`; no csproj, migration, endpoint or package. |
| Security (authn/authz, secrets, sensitive logging) | No I/O, no logging, no secrets; the endpoints' public status is the spec's recorded interim state (feature 002 precedent). |
| Scope guard | `pwsh -NoProfile -File scripts/scope-check.ps1 -Commit b8ac1aa` -> `scope-check: PASS phase 2 commit b8ac1aa (7 file(s))`. `pwsh -NoProfile -File scripts/ritual-checks.ps1` -> doc-lint, enforcement-pack, scope-check, digests, roadmap-claims, verify-kit OK; scope-repos n/a; `RESULT OK` (run before this review file was added). Stat read: 623 insertions, 182 production lines, 441 test lines, all additive. |
| Rollback safety | Purely additive: new files only, no consumer yet (phase 3 and 4 depend on them; revert newest first). No schema. |
| Build and tests | Scoped only (no gate run, per the Critical rule): `dotnet test tests/BookingApi.Application.Tests` -> Passed 64, Failed 0. |
| Test-first claim (notes.md: 37 of 64 failed against a throwing skeleton) | Not independently reproducible: the skeleton was never committed (same as phase 1 F5). The mutation results show tests that bite, with the two exceptions in F1. |

## Invariant pass (Critical: each of the five, item by item)

| # | Invariant | Status in this phase | Evidence |
|---|---|---|---|
| 1 | No Double Booking | **Cannot yet exercise** (no booking exists). **Prepares** the slot-level analogue: the application half of the two-layer rule (check, then add) and the port clause that the store itself must refuse a concurrent overlap and answer `Overlaps`. The application check alone is explicitly not trusted: `AddSlotResult.Overlaps` is handled and tested (`AnOverlapRefusedByTheStoreIsStillAnOverlapOutcome`), and the port doc says the database enforces it under concurrency. Not violated; the concurrency guarantee itself is phase 3 (T015, T021) and phase 4 (T030), and nothing here claims it. | `SlotHandlers.cs` overlap check then `AddAsync` with the `Overlaps` arm; port remarks; fake `ForcedAddResult`. The fake cannot show concurrency (single-threaded, no store-side refusal of its own: F3). |
| 2 | Time Is UTC | **Exercised and respected.** Handler hands `DateTimeOffset` to `TimeSlot.Create` (normalization and `start < end` there), then uses only the entity's UTC values for the overlap check and the add; the clock is injected (`TimeProvider`), no `DateTime.Now` or `UtcNow` in the diff. Phase 1 F2 is closed here: no raw request instant reaches `Overlaps`. | Test `AnOffsetInstantIsComparedAsUtc` (11:00+02:00 equals 09:00Z, refused as overlapping); `ValidInputIsStoredAndReturnedWithTheClockInstants` (`CreatedAtUtc` equals the fixed clock); `AnEndNotAfterTheStartIsInvalid...` (equal and earlier end, one `endUtc` error, nothing stored). Offset-less text is refused by the API parser (phase 4), not here. |
| 3 | Booking Lifecycle | **Cannot yet exercise** (no booking or status). **Respected**: no status, no transition table, no second state machine is introduced. | No status property or mutator in any of the seven files. |
| 4 | Bookings Are Never Deleted | **Cannot yet exercise** (no booking). **Respected** for slots: the port has add, get, list and overlap check only; no delete, retire or update member (FR-010). | `ISlotRepository` has four members, none removes or changes a row. |
| 5 | Bookable Only Within a Slot | **Prepares.** A slot can only be opened on an existing, non-retired resource (resource checked first; unknown resource: nothing checked, nothing added), and the port gives later bookings what they need: get by resource and id (a slot under another resource is not found). The "retired resource accepts no new bookings" half is applied to slots; booking-side enforcement cannot yet be exercised. Residual: F2(b), the window between the resource check and the add. | `AnUnknownResourceIsNotFoundAndNothingIsCheckedOrAdded`; `ASlotOfAnotherResourceIsNotFound`; `GetSlotResourceNotFound` and `ListSlotsResourceNotFound` tests. |

## Findings

### F1 — Resource-before-validation ordering is the plan's rule but no test pins it, and the contract is silent — MINOR

plan.md says the handlers check the resource first, then validate. The code does (all three handlers). Two mutations
that invert this, in `OpenSlotHandler` (validate first) and in `ListSlotsHandler` (validate paging first), leave all 64
tests green, because the "unknown resource" tests use valid input and the "invalid" tests use an existing resource. The
contract table lists 404 and 400 for the same request without saying which wins when both apply. Together with phase 4
this will also behave unevenly: unparsable instant text (400 at the API, before any handler) beats an unknown resource,
while an end not after the start (400 from `TimeSlot.Create`) loses to it (404). notes.md records this as a design
note; it is a legitimate choice (not leaking validation detail for a resource that is not there), but it is not in the
contract.
*Action: implementer adds one test per handler (unknown resource with an invalid interval or invalid paging gives the
resource-not-found outcome) so the order is pinned, and the owner decides, with an approver record, whether a sentence
stating the precedence goes into `contracts/slots-api.md` (a contract amendment is the owner's, not the implementer's).
Not blocking.*

### F2 — Two corners of the port contract are not stated, and phase 3 must satisfy them — MINOR

(a) The port says `Added` assigns the `Id`, but not what `AddAsync` leaves behind on `Overlaps`: nothing stored and no
`Id` assigned. The handler returns `SlotOverlaps` and drops the instance, so this is behaviour phase 3 gets right
anyway, but it is the property T015, T018 and T021 assert ("leaves no row"), so it belongs on the port. (b) The port
says the resource is checked by the handler, not the port. Between that check and the insert a resource could
disappear (FR-005's foreign key refuses the insert); the port has no outcome for it, so the real store would throw and
the API would answer 500. Today nothing in the solution retires a resource, so this is a latent window, not a live
defect; it is also the behaviour feature 002's port documents implicitly. The handler's `Added`/`Overlaps` arms plus the
throwing fall-through make any new outcome a compile-visible change later.
*Action: implementer adds one sentence to the `AddAsync` doc for (a) (nothing stored, no `Id` on `Overlaps`) and one for
(b) ("a foreign-key failure from a resource that vanished after the check propagates as an exception; no retire exists
in this feature"). Phase 3 review to confirm the repository and its tests match. Not blocking.*

### F3 — The fake is looser than the port in three places, and retirement is untestable in this phase — MINOR

`FakeSlotRepository` is faithful on ids, resource scoping, token recording and failure propagation. It differs from the
port contract: `ListAsync` returns the canned `PageToReturn` and ignores the resource id, retirement, order and
paging (the tests check only what reaches it and what comes back); `AddAsync` never refuses an overlap itself (only
`ForcedAddResult`); and the `!s.IsDeleted` filters are dead code, because `TimeSlot.IsDeleted` has a private setter and
no code sets it, so "a retired slot does not block" (phase 1 F3) has no test in this phase. None of this makes a
handler test wrong, since the handlers hold none of these rules, but the behaviours are proven only against real SQL
Server (T019, T020, T021, T015) and a reader of the fake could assume otherwise. Id assignment uses reflection on a
private setter, an acceptable test-double shortcut.
*Action: none required now; the phase 3 review must confirm T019 (retired invisible to get, list and overlap), T020
(paging and ordering) and T021 (parallel adds) exist and pass. Implementer may add a one-line comment on the fake saying
which port rules it deliberately does not model.*

### F4 — plan.md names the outcome `ResourceNotFound`; the code has three types — DOC DRIFT

plan.md lists `ResourceNotFound`; the code has `OpenSlotResourceNotFound`, `GetSlotResourceNotFound` and
`ListSlotsResourceNotFound` (one base per use case, a record having one base type) and notes.md says so. Feature 002
already has a type named `ResourceNotFound` (the get-resource outcome), which is why the plan's informal name could not
be used. The one-to-one status mapping holds. No spec, plan, tasks or contract file was changed.
*Action: none required; mention the three names in the phase 4 endpoint mapping so no `ResourceNotFound` of feature 002
is reused by mistake. An amendment of plan.md, if the owner wants the name fixed there, needs an approver record.*

### F5 — Phase 1 follow-ups F2 and F3 — ACCEPTED

Both are carried into this phase and handled as described in the evidence table: the handler passes only values produced
by `TimeSlot.Create` to the overlap check, and the port documents that retired slots are invisible and never block.
*Action: none; phase 3 carries the retirement rule into its tests (T019).*

### F6 — Test-first evidence cannot be verified from history — ACCEPTED

Same as phase 1 F5: the throwing skeleton was never committed. The mutations (F1 aside) show the tests discriminate.
*Action: none.*

## Amendments in this diff

- [x] **None.** `b8ac1aa` touches only Application source and Application tests. spec.md, plan.md, tasks.md and
  contracts/ are unchanged by it; the follow-up docs commit `f1a3fc4` ticks T008 to T014 in tasks.md and adds notes, a
  progress mark and evidence, not a change to scope or wording.

## Constitution re-check (post-implementation)

**PASS.** IV (layering and dependency policy): Application references only Domain, no framework or package, no new
dependency. V (domain invariants): invariant 2 exercised through the injected clock and Domain normalization, 1 and 5
prepared, 3 and 4 untouched (see the invariant pass). VII (contract before implementation): the contract exists and each
outcome maps to a row; the precedence gap is F1. VIII (tests at the owning layer): use-case rules are tested against a
hand-written fake, database rules are left to phase 3 on real SQL Server. I/II (source of truth, amendments): code
matches the approved spec and plan; nothing amended. X (Critical): no gate run by the agent; certification stays with the
owner.

## Test coverage observed

`BookingApi.Application.Tests`: 64 passed, 0 failed (27 pre-existing resource tests, 37 new). `OpenSlotHandlerTests`
(theories counted by case): valid open with the clock instants and the same instance, unknown resource touching nothing,
two invalid intervals, five overlap shapes, three touching/disjoint, another resource, offset instants, the store's
`Overlaps`, token forwarding, failure propagation. `GetSlotHandlerTests`: found, unknown id, other resource, unknown
resource, token. `ListSlotsHandlerTests`: unknown resource with the store untouched, defaults, valid pass-through
(including page `int.MaxValue`), page below one, size outside the range, both invalid, the page carried back, token.
Critical assertions: `Assert.Same` on the stored slot, zero overlap checks and zero adds for refusals, the exact field
names `endUtc`, `page`, `pageSize`. Weak spot: ordering of resource check against validation (F1).

## Residual risk

Low for this phase. The risk that matters for the feature, no overlap under concurrency (invariant 1's standard), is in
phase 3 (trigger, T015 first, parallel-insert tests on real SQL Server) and phase 4 (T030); the Application half here is
correct and relies explicitly on the store's refusal. Before phase 3: optionally address F1 and F2 (small test and
documentation additions) and keep F3 in mind when reviewing the repository tests. Merge readiness remains subject to the
owner's gate, the later phases, human review, the second-model review and the 24-hour cooling-off.
