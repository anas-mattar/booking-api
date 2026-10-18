---

description: "Tasks for 003-time-slots"
---

# Tasks: Time Slots

**Input**: `specs/003-time-slots/` — spec.md (approved), plan.md (approved), data-model.md,
contracts/slots-api.md, rollback.md

**Tests**: required in every phase, written first and seen failing before the implementation
that makes them pass. Behaviour is tested at the layer that owns it: Domain rules in
Domain.Tests, use cases against a fake repository in Application.Tests, database behaviour
against real SQL Server in Infrastructure.Tests, the contract over HTTP in Api.Tests. Every
half-open boundary case has an expected value worked by hand and written in the test (SC-006).

**Phase ritual (Critical)** (every phase): implement → `git diff --stat` review → commit with
`phase N` in the subject → `pwsh -File scripts/scope-check.ps1` PASS → push and **read the
branch's CI run** → fresh-context AI review (`specs/003-time-slots/ai-code-review-phaseN.md`,
with an explicit item-by-item pass over the five invariants of
`docs/domain/booking-invariants.md`) → **stop: the owner runs the gate and confirms the exit
code** before the next phase starts. Critical: the agent does **not** run the gate as feedback
(`docs/sdlc/critical-delivery.md` item 4); the owner runs it, with Docker running. The gate
command and exit code, the scope-check verdict and the `git diff --stat` output of each phase are
recorded in `notes.md` (audit evidence, item 3). After the last phase: human review, the
second-model review (`second-model-review.md`), and a 24-hour cooling-off before merge.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Domain — the TimeSlot entity

**Goal**: a `TimeSlot` that can only be created valid, with the half-open overlap predicate
defined in one place, in a project with no framework dependency.

**Independent Test**: `TimeSlot.Create` accepts valid instants (normalizing offsets to UTC) and
returns field errors for an end that is not after the start; the overlap predicate gives the
hand-worked answer for every boundary case; nothing else in the solution is needed.

**Territory**:

- `src/BookingApi.Domain/**`
- `tests/BookingApi.Domain.Tests/**`

### Tests

- [x] T001 [P] [US1] `TimeSlotTests`: `Create` with a valid start and end sets `StartUtc`,
  `EndUtc` and the resource id; an offset instant (`2026-11-02T11:00:00+02:00`) is stored as
  `2026-11-02T09:00:00Z`; the stored instants have `Kind` Utc
- [x] T002 [P] [US1] `TimeSlotTests`: an end equal to the start, one tick before it, and a whole
  hour before it are each rejected with one `endUtc` error; an end one tick after the start is
  accepted; the offset is normalized before the comparison (`10:00+02:00` is before `09:00Z`'s
  end of `09:30Z`)
- [x] T003 [P] [US1] `TimeSlotTests`: a valid `Create` sets `CreatedAtUtc` and `UpdatedAtUtc` to the
  given instant and `CreatedBy` and `UpdatedBy` to `anonymous`; the new slot is not retired
  (`IsDeleted` false, `DeletedAtUtc` and `DeletedBy` null)
- [x] T004 [P] [US1] `SlotIntervalTests`: the overlap predicate on the hand-worked table (A =
  `[09:00, 10:00)`): `[10:00, 11:00)` no; `[08:00, 09:00)` no; `[09:00, 10:00)` identical yes;
  `[09:15, 09:45)` contained yes; `[08:00, 11:00)` containing yes; `[09:30, 10:30)` partial yes;
  `[08:30, 09:30)` partial yes; `[11:00, 12:00)` disjoint no; one-tick overlap
  (`[10:00 - 1 tick, 11:00)`) yes; one-tick gap (`[10:00 + 1 tick, 11:00)`) no; every case is
  symmetric (swap the two intervals, same answer)

### Implementation

- [x] T005 [US1] `src/BookingApi.Domain/TimeSlot.cs`: the entity (private constructor, read-only
  properties including the retirement marker) and the field-name constants `startUtc` and `endUtc`
- [x] T006 [US1] `TimeSlot.Create(resourceId, start, end, now)` returning the entity or the field
  errors, reusing the existing `ValidationError` and a result type in Domain (no package)
- [x] T007 [US1] The half-open overlap predicate in one place (`start < otherEnd && otherStart <
  end`) used by `TimeSlot` and by the tests

**Checkpoint**: tests written first and seen failing; Domain still references no project and no
package; the owner runs the gate.

---

## Phase 2: Application — port and use cases

**Goal**: open, get and list as use cases over a slot repository port, with every expected
outcome explicit.

**Independent Test**: handlers run against hand-written fake repositories.

**Territory**:

- `src/BookingApi.Application/**`
- `tests/BookingApi.Application.Tests/**`

### Tests

- [ ] T008 [P] [US1] `OpenSlotHandlerTests` against fake repositories and a controllable
  `TimeProvider`: valid input on an existing resource → `SlotOpened` carrying the stored slot with
  the clock's instants; unknown resource → `ResourceNotFound`, nothing added and no overlap check;
  invalid input (end not after start) → `SlotInvalid` with the `endUtc` error and nothing added;
  an overlapping existing slot → `SlotOverlaps` and nothing added; touching slots → `SlotOpened`;
  the repository answers `Overlaps` on add (the race) → `SlotOverlaps`; the resource id is part of
  the overlap check (a slot on another resource does not block)
- [ ] T009 [P] [US2] `GetSlotHandlerTests`: existing slot of that resource → `SlotFound`; unknown
  slot id → `SlotNotFound`; a slot id that belongs to another resource → `SlotNotFound`; unknown
  resource → `ResourceNotFound`
- [ ] T010 [P] [US3] `ListSlotsHandlerTests`: unknown resource → `ResourceNotFound` with the
  repository untouched; no parameters → page 1, size 50; `page` below 1 or `pageSize` outside 1 to
  100 → `Invalid` naming the parameter; valid parameters reach the repository unchanged with the
  resource id; the result carries items, page, page size and total count
- [ ] T011 [P] [US1] Cancellation-token forwarding for all three handlers and repository-failure
  propagation for open (an exception from the store is not turned into an outcome)

### Implementation

- [ ] T012 [US1] `src/BookingApi.Application/Slots/`: `ISlotRepository` (overlap exists, add, get by
  resource and id, list a page for a resource) and the page type, with the contract written on the
  port as in feature 002 (the same instance returned with its `Id`; a retired slot is invisible
  and does not block; overlap is the store's guarantee; 64-bit paging; cancellation and unexpected
  failures propagate)
- [ ] T013 [US1] The explicit outcome types for the three use cases
- [ ] T014 [US1] `OpenSlotHandler`, `GetSlotHandler`, `ListSlotsHandler` (the paging bounds reuse
  the constants of `ListResourcesHandler`)

**Checkpoint**: tests written first and seen failing; Application still references only Domain and
no framework package; the owner runs the gate.

---

## Phase 3: Persistence — real SQL Server, and the database-level no-overlap guarantee

**Goal**: the table, the constraints, the trigger, the repository and the migration `TimeSlots`,
proven against real SQL Server in a throwaway container, including concurrent writers.

**Independent Test**: with Docker running, Infrastructure.Tests migrate an empty database and
exercise every constraint, the foreign key, the trigger, the query filter, paging and parallel
adds of overlapping slots.

**Territory**:

- `src/BookingApi.Infrastructure/**`
- `tests/BookingApi.Infrastructure.Tests/**`
- `BookingApi.slnx`
- `README.md`
- `docs/rulebooks/database-rules.md`

### Tests

- [ ] T015 [US1] **First, before the rest is built on it — prove the mechanism.** `SlotTriggerTests`
  (raw SQL, so the database itself must refuse): an overlapping insert (identical, contained,
  containing, partial, one-tick overlap) is refused with error 50011 and leaves no row; touching
  slots, a one-tick gap and the same interval on another resource are accepted; a retired slot
  does not block; an UPDATE that would create an overlap is refused; many parallel raw inserts of
  overlapping intervals on one resource leave exactly one row; parallel inserts on different
  resources all succeed. If the real behaviour differs from plan.md's design, stop and amend the
  plan (owner approver record) before continuing
- [ ] T016 [P] [US1] `SlotMigrationTests`: `Migrate()` applies `TimeSlots` on top of
  `ResourceCatalog`; migrating back to `ResourceCatalog` drops `Slots` and the trigger and leaves
  `Resources` intact; migrating back to zero returns the database to empty (SC-005)
- [ ] T017 [P] [US1] `SlotConstraintTests` (raw SQL): an end equal to or before the start; a
  retired row without its deletion data and a live row with it; `UpdatedAtUtc` before
  `CreatedAtUtc`; a slot for an unknown resource (foreign key); deleting a resource that has a slot
  is refused (restrict)
- [ ] T018 [P] [US1] `SlotRepositoryTests`: add then get round-trips every field with `Kind` Utc and
  one-tick precision preserved; the same instance carries its `Id` after add; overlap exists
  answers per the boundary table for the same resource and false for another resource; a slot of
  another resource is not returned by get; add refused by the trigger returns `Overlaps` and never
  throws
- [ ] T019 [P] [US2] `SlotRepositoryTests`: retired slots are invisible to get, list and the
  overlap check (query filter; row retired through raw SQL)
- [ ] T020 [P] [US3] `SlotRepositoryTests`: 100 slots inserted in descending start order page as 50
  and 50, each exactly once, ordered by start then id; another resource's slots never appear; a
  page past the end is empty with the true total; an offset beyond the int range is an empty page,
  not an overflow
- [ ] T021 [P] [US1] `SlotRepositoryTests`: many parallel adds of overlapping slots on one resource
  yield exactly one `Added` and the rest `Overlaps`, never an exception (SC-003, database half);
  parallel adds of non-overlapping slots all succeed

### Implementation

- [ ] T022 [US1] Fluent mapping per `data-model.md`: table `Slots`, column types, the restrict foreign
  key, the three check constraints, the index `IX_Slots_ResourceId_StartUtc`, the trigger declared
  to EF (`HasTrigger`), the UTC-kind converters on the four instants, the global query filter;
  `DbSet<TimeSlot>` on `BookingDbContext`
- [ ] T023 [US1] The migration `TimeSlots` generated by the pinned tool, with the trigger created in
  `Up` and dropped before the table in `Down` by `migrationBuilder.Sql`; read the generated SQL
  against `data-model.md` before committing; `has-pending-model-changes` reports none
- [ ] T024 [US1] `SlotRepository` implementing the port; `AsNoTracking()` reads; the trigger's error
  50011 mapped to `Overlaps`; paging in 64-bit arithmetic; register it in `AddInfrastructure`;
  liveness and readiness stay unchanged
- [ ] T025 Record the trigger and the per-resource serialisation in the database rulebook (a short
  note under Constraints Mirror Invariants: where SQL Server has no declarative constraint, a
  trigger may enforce it when the plan approves it) and a one-line mention in `README.md`

**Checkpoint**: tests written first and seen failing; all constraint, trigger and concurrency tests
pass with Docker running; the owner runs the gate.

---

## Phase 4: API — endpoints, end-to-end tests, quickstart

**Goal**: the three nested endpoints of `contracts/slots-api.md`, proven over HTTP against real SQL
Server, plus the owner's by-hand verification.

**Independent Test**: open, fetch and page through slots over HTTP; every error is problem
details; simultaneous overlapping requests give one 201 and the rest 409.

**Territory**:

- `src/BookingApi.Api/**`
- `tests/BookingApi.Api.Tests/**`

### Tests

- [ ] T026 [US1] `CreateSlotTests`: 201 with `Location` and the stored slot; an offset instant is
  returned as UTC `Z`; absent instants, null, a date only, a value with no offset, a Unix
  timestamp and unparsable text → 400 `ValidationProblemDetails` naming `startUtc` or `endUtc`;
  an end equal to or before the start → 400 naming `endUtc`; empty body, malformed JSON and wrong
  JSON types → 400 problem details (also in Development); unknown and retired resource → 404; a
  non-numeric resource id → 404
- [ ] T027 [P] [US1] `SlotBoundaryTests` over HTTP, the hand-worked table of SC-006: touching before
  and after → 201; identical, contained, containing, partial and one-tick overlap → 409 with title
  `Slot overlaps an existing slot`; the same interval on another resource → 201; a retired slot's
  interval (retired through raw SQL) → 201
- [ ] T028 [P] [US2] `GetSlotTests`: 200; unknown slot → 404; a slot under another resource → 404;
  retired slot → 404; unknown resource → 404; non-numeric ids → 404 problem details
- [ ] T029 [P] [US3] `ListSlotsTests`: defaults; 100 slots page as 50 and 50 with `totalCount` 100
  (SC-002) and a second resource unaffected; a page past the end is 200 and empty with the true
  total; an empty resource lists as total 0; non-numeric and out-of-range `page` and `pageSize` →
  400 naming the parameter; unknown resource → 404; retired slots excluded; order by start
- [ ] T030 [P] [US1] `ConcurrentSlotTests`: several simultaneous requests opening overlapping slots
  on one resource give exactly one 201 and the rest 409 and no 5xx, repeated at least 10 times;
  simultaneous requests on non-overlapping intervals all give 201 (SC-003)
- [ ] T031 [P] [US1] `SlotErrorShapeTests`: every error response in T026 to T029 is
  `application/problem+json`, with no HTML, no stack trace and no trigger message or error number
  (SC-004)
- [ ] T032 [P] [US1] `OpenApiTests`: the Development OpenAPI document lists
  `/resources/{resourceId}/slots` and `/resources/{resourceId}/slots/{id}`

### Implementation

- [ ] T033 [US1] `src/BookingApi.Api/Features/Slots/`: the endpoint group nested under
  `/resources/{resourceId:int}/slots` (`POST`, `GET {id:int}`, `GET`), request and response DTOs,
  the strict instant parser (accepted shapes of the contract only; offset required; normalized to
  UTC), mapping of every use-case outcome to the contract's statuses and bodies with a throwing
  fall-through arm, field errors to `ValidationProblem`, `Location` header
- [ ] T034 [US1] Register the three handlers in `Program.cs` and map the group
- [ ] T035 `specs/003-time-slots/quickstart.md`: apply the migration to the local `BookingApi`
  database with the pinned tool, run the API, open and list slots with `curl.exe`, try an
  overlapping one, and verify the table, constraints and trigger with `sqlcmd` (SC-005 by hand)
- [ ] T036 `specs/003-time-slots/rollback.md`: confirm it matches the shipped code (migration name,
  commit subjects) and amend it if the phases changed anything it states

**Checkpoint**: tests written first and seen failing; all tests pass with Docker running; the owner
runs the gate and verifies SC-005 by hand.

---

## Dependencies & Execution Order

- Phases run strictly 1 → 2 → 3 → 4; each phase stops for the owner's gate.
- Phase 2 uses the entity from phase 1; phase 3 implements the phase 2 port; phase 4 calls the
  phase 2 handlers over the phase 3 repository. Revert newest first.
- Within a phase, [P] tasks touch different files. In phase 3, T015 comes first.

## After Phase 4

- Set `**Merge Readiness**: ready` in the plan (an amendment: record the approver), write the
  second-model review, human review (`specs/_templates/human-pr-review-template.md`, with the
  invariant pass), wait out the 24-hour cooling-off, PR to `main`, merge `--no-ff`, then flip the
  roadmap row to `shipped` and drop the brackets on its Spec cell (`docs/sdlc/branch-strategy.md`).
