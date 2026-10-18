# Implementation Plan: Time Slots

**Branch**: `003-time-slots` | **Date**: 2026-10-19 | **Spec**: `specs/003-time-slots/spec.md`
**Input**: Feature specification from `specs/003-time-slots/spec.md`
**Status**: Approved
**Gate Batching**: none
**Gate Certification**: user-run
**Merge Readiness**: pending

## Summary

The second domain entity, and the first one governed by the domain invariants. A `TimeSlot` lives
in the Domain project with its validation rules (`start < end`, UTC); three use cases (open, get,
list) and the slot repository port live in Application; EF Core mapping, the repository and the
second migration `TimeSlots` live in Infrastructure; three nested minimal-API endpoints live in
Api. All of it follows ADR-001 (`specs/001-solution-scaffold/plan.md`) and the patterns of
feature 002, which this feature does not change. The one new technique is the **database-level
no-overlap guarantee** (see Design Notes): a trigger that serialises writers per resource and
refuses an overlapping row, proven against real SQL Server including under concurrency. Four
phases, each one user-gated; this is a Critical feature, so only the owner runs the gate.

## Technical Context

**Language/Version**: C# on .NET 10 (SDK 10.0.400, `global.json`)  
**Primary Dependencies**: ASP.NET Core minimal APIs; EF Core 10 (SQL Server provider), already in place  
**Storage**: SQL Server; table `Slots` per `data-model.md`; local dev database `BookingApi` on LocalDB  
**Testing**: xUnit; `Microsoft.AspNetCore.Mvc.Testing`; Testcontainers for SQL Server (`BookingApi.TestSupport`, feature 002)  
**Target Platform**: Linux or Windows server; CI on ubuntu-latest (Docker preinstalled)  
**Project Type**: web service (REST API)  
**Performance Goals**: none beyond the paging bound (page size at most 100)  
**Constraints**: the gate needs a running Docker engine (feature 002); database rules per
`docs/rulebooks/database-rules.md`; invariants 2 and 5 of `docs/domain/booking-invariants.md`  
**Scale/Scope**: single service, one developer

### Packages and tools (constitution IV — approved by approving this plan)

**None.** Every package and tool this feature needs (EF Core, `Microsoft.EntityFrameworkCore.Design`,
`dotnet-ef` 10.0.13, `Testcontainers.MsSql` 4.16.0, xUnit, `Mvc.Testing`) was approved in feature 001
or 002 and is already in place. No other package is approved; a new package needs a plan amendment
with an owner approver record.

## Constitution Check

*Evaluated before design and again after it; both pass.*

- [x] **Specification First (I)**: spec.md approved by the owner (2026-10-19); this plan, the data
  model, the contract and tasks.md are approved before any phase is implemented.
- [x] **Source of Truth (II)**: spec → plan → contract → data model agree; the open points the spec
  left to the plan (non-overlap mechanism, instant precision) are decided below.
- [x] **Repository Separation (III)**: not applicable — single repository.
- [x] **Architecture Consistency (IV)**: no new architecture and no new package; ADR-001's layout and
  dependency rule are followed. The trigger is persistence detail inside Infrastructure's migration.
- [x] **Domain Invariants (V)**: invariant 2 is implemented at three layers (API boundary, Domain,
  database check); invariant 5's "open slot first" is prepared (the slots bookings will fall
  inside) and its retire half is only prepared by the soft-delete columns; invariant 1's
  concurrency standard is applied to slot overlap; invariants 3 and 4 are not exercisable (no
  booking exists). The Critical reviews pass over every invariant item by item.
- [x] **Security (VI)**: the endpoints are public by design (spec Assumptions), the accepted interim
  state of feature 002; no secret is committed; no sensitive data is logged; responses carry no
  exception data (the trigger's message is mapped to a fixed problem details body, never echoed).
- [x] **External Integration Governance (VII)**: the API is contracted in `contracts/slots-api.md`
  before implementation; no external system is called.
- [x] **Testing Requirements (VIII)**: every rule has automated tests at the layer that owns it;
  the half-open boundary cases carry hand-worked expected values (SC-006); constraints and the
  concurrency guarantee run on real SQL Server.
- [x] **Human Review (IX)**: per-phase fresh-context AI review with an invariant-by-invariant pass,
  then human review before merge.
- [x] **Controlled Delivery (X)**: Critical level: four phases, one at a time, each gated by a gate
  the owner runs (`user-run`, no batching, no ci-held, no Micro); the rollback plan
  (`rollback.md`) exists before phase 1; the second-model review and the 24-hour cooling-off
  precede merge (`docs/sdlc/critical-delivery.md`).

  **Phase sizing**: each phase is one testable slice (below) and reverts on its own, newest first;
  no phase depends on a later one. Phase 3 is the largest (the migration, the trigger and the
  concurrency proofs belong together).

## Design Notes

- **Layering (ADR-001)**: Api calls an Application use case and never the DbContext. Domain has no
  framework reference; Application references only Domain.
- **Domain**: `TimeSlot` has a private constructor and a factory
  `TimeSlot.Create(resourceId, start, end, now)` taking `DateTimeOffset`s, converting both to UTC,
  and returning either the entity or the field errors (`endUtc` when the end is not strictly after
  the start). It carries the retirement marker as read-only state, as `Resource` does. The
  overlap predicate lives in one place, `TimeSlot.Overlaps` / the interval helper, so the
  application check and the tests share one definition: `a.Start < b.End && b.Start < a.End`
  (half-open).
- **Instants at the boundary (invariant 2)**: the request carries `startUtc` and `endUtc` as text.
  The endpoint parses them strictly (ISO 8601 extended, `yyyy-MM-ddTHH:mm:ss` with up to seven
  fractional digits, followed by `Z` or `±hh:mm`; a value with no offset, a date only, or any
  other shape is refused), converts to UTC, and passes `DateTimeOffset`s on. Missing, null and
  unparsable values are field errors from the endpoint; `start < end` is the Domain's rule.
  Responses always use UTC with `Z`. This is the same pattern as the `page` parameters of
  feature 002.
- **Instant precision**: full `datetime2(7)` (100 ns, exactly the .NET tick), so what a client sends
  is what is stored and compared; no rounding. Tests pin one-tick overlaps and one-tick gaps.
- **Application**: `ISlotRepository` (add, get by resource and id, list a page for a resource,
  overlap exists) beside the unchanged `IResourceRepository`. The handlers check the resource
  through `IResourceRepository.GetByIdAsync` (non-retired) first and answer `ResourceNotFound`
  when it is absent, then validate, then check overlap for a clean 409, then add. Outcomes are
  explicit values (`SlotOpened`, `SlotInvalid(errors)`, `SlotOverlaps`, `ResourceNotFound`,
  `SlotFound`, `SlotNotFound`, `SlotsListed`, `ListSlotsInvalid`); no exceptions for expected
  outcomes. Time comes from `TimeProvider`.
- **No-overlap, both layers (FR-004, invariant 1's standard)**: the handler checks overlap first
  for a clean 409. The authoritative guarantee is a **database trigger** `TR_Slots_NoOverlap`
  (AFTER INSERT, UPDATE) on `Slots`: for each distinct resource in the changed rows it takes a
  transaction-scoped application lock (`sp_getapplock`, Exclusive, key
  `slots:<ResourceId>`, keys taken in ascending order so multi-row changes cannot deadlock), then
  refuses the change with a fixed error number (50011) if any non-retired slot of the same
  resource overlaps a changed non-retired row. The lock makes two concurrent writers for one
  resource take turns, so the second sees the first's committed row; writers for different
  resources never wait on each other. The repository maps error 50011 to
  `AddSlotResult.Overlaps`, so a concurrent insert that slips past the check still yields 409,
  never 500 (SC-003). The migration creates the trigger; `Down` drops it before the table.
  Phase 3 starts with the proof of this mechanism (raw-SQL tests, then parallel adds) before the
  rest of persistence is built on it. If real SQL Server behaves differently from this design
  (for example the statement is not rolled back by the trigger's error), the plan is amended
  with an owner approver record before phase 3 continues.
- **Persistence**: fluent mapping in Infrastructure (Domain entities carry no EF attributes);
  global query filter `!IsDeleted`; `AsNoTracking()` reads (backend rulebook); the table is
  declared to EF as having a trigger so inserts read back the generated `Id` without `OUTPUT`;
  the foreign key to `Resources` is `OnDelete(Restrict)`; the four UTC columns use the same
  UTC-kind value converters as `Resource`. Migrations live in
  `src/BookingApi.Infrastructure/Migrations/`, generated by the pinned local tool; the application
  never migrates on startup; the owner applies the migration (`quickstart.md`).
- **Paging**: as feature 002 — `Skip((page - 1) * pageSize).Take(pageSize)` in 64-bit arithmetic; an
  offset beyond the int range is an empty page. List order is `StartUtc`, then `Id`.
- **API**: a `Features/Slots/` folder in Api with the endpoint group nested under
  `/resources/{resourceId:int}/slots`, DTOs, and field-error mapping to `ValidationProblem`.
  Every outcome subtype is mapped explicitly and the fall-through arm throws (feature 002 review
  F4). Malformed bodies come back as 400 problem details through the baseline pipeline
  (`ThrowOnBadRequest` is already off in every environment).
- **Tests**: Domain tests for the rules and the overlap predicate (the hand-worked boundary
  table); Application tests against a fake slot repository; Infrastructure tests on real SQL
  Server for every constraint, the foreign key, the trigger and parallel adds; Api tests over HTTP
  with a fresh migrated database per test, reusing `ResourceApiFactory`'s pattern.
- **Critical-feature obligations** (`docs/sdlc/critical-delivery.md`): `rollback.md` is filled
  before phase 1; each phase's AI review and the human review include an explicit pass over the
  five invariants; the gate command, exit code, scope-check verdict and diff stat are kept in the
  feature directory (`notes.md`); the agent does not run the gate as feedback, the owner runs it
  each phase; a second-model review (`second-model-review.md`) and a 24-hour cooling-off
  precede merge.

## Phases

| Phase | Slice | Stories / FRs |
|---|---|---|
| 1 | Domain: `TimeSlot` entity, validation, overlap predicate, unit tests with the hand-worked boundary table | FR-002 (rules), FR-003, FR-004 (predicate), FR-008 (shape), FR-010; SC-006 (Domain half) |
| 2 | Application: slot repository port, open, get and list use cases against a fake repository | FR-001..FR-007 (behaviour), FR-005 |
| 3 | Persistence: mapping, foreign key, check constraints, the no-overlap trigger, repository, migration `TimeSlots`, DI, tests against real SQL Server including concurrency | FR-004 (database half), FR-005, FR-009, FR-012; SC-003 (database half), SC-005, SC-006 |
| 4 | API: nested endpoints, strict instant parsing, DTOs, OpenAPI, HTTP tests including end-to-end concurrency, `quickstart.md`, final `rollback.md` check | US1..US3; FR-001..FR-008, FR-011; SC-002..SC-004 |

Territory per phase is declared in `tasks.md`.

## Project Structure

### Documentation (this feature)

```text
specs/003-time-slots/
├── spec.md
├── plan.md                    # this file
├── data-model.md
├── contracts/slots-api.md
├── rollback.md                # before phase 1 (Critical)
├── quickstart.md              # phase 4
├── notes.md                   # evidence
├── second-model-review.md     # before merge (Critical)
└── tasks.md
```

### Source Code (after phase 4; additions to the feature-002 layout)

```text
src/
├── BookingApi.Domain/            TimeSlot.cs
├── BookingApi.Application/       Slots/ (port, use cases, outcomes)
├── BookingApi.Infrastructure/    Data/ (mapping), Slots/ (repository), Migrations/ (TimeSlots)
└── BookingApi.Api/               Features/Slots/ (endpoints, DTOs)
tests/
├── BookingApi.Domain.Tests/
├── BookingApi.Application.Tests/
├── BookingApi.Infrastructure.Tests/
└── BookingApi.Api.Tests/
```

**Structure Decision**: ADR-001 and the feature-002 layout, unchanged. No new project.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| A database trigger | SQL Server has no exclusion constraint, and the spec requires non-overlap to hold in the database under concurrency (FR-004, invariant 1's standard) | An application-side check or a serialisable transaction alone is not enforced by the database: any other writer, script or future code path bypasses it. A unique index cannot express interval overlap |
| `sp_getapplock` inside the trigger | Under default locking, two concurrent triggers each wait on the other's uncommitted row and deadlock, or both pass the check and both commit; the lock turns that into a clean turn-taking per resource | Range locks via `SERIALIZABLE` or `UPDLOCK, HOLDLOCK` also work but lock more than the resource's own rows and make the outcome depend on the index shape; an explicit per-resource lock is simple to reason about and test |
