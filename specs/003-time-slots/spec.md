# Feature Specification: Time Slots

**Feature Branch**: `003-time-slots`  
**Created**: 2026-10-19  
**Status**: Approved  
**Delivery Level**: Critical
**Rationale Rule**: 1
**Input**: User description: "Time slots: open a one-off UTC interval [start, end) on a resource so it can later be booked. Create, get and list slots nested under a resource (POST/GET /resources/{resourceId}/slots, GET /resources/{resourceId}/slots/{id}). Slots of one resource must not overlap (half-open, enforced in code and by the database under concurrency). No update or retire in this feature."

A **time slot** is the resource owner's statement of availability: one interval of time during
which a resource may be booked. Invariant 5 of `docs/domain/booking-invariants.md` says a
booking must fall entirely inside an open slot, so slots must exist before bookings can. This
feature lets an API client open a slot on a resource and read slots back. It builds on the
resource catalog (feature 002); bookings come in a later feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a slot on a resource (Priority: P1)

An API client opens a slot on an existing resource by giving a start and an end instant. The
service stores it and returns the slot with its identifier.

**Why this priority**: bookings cannot exist without slots; this is the first write that
exercises invariant 2 (UTC, start before end) and the first rule that must hold under
concurrent requests.

**Independent Test**: post a start and end for an existing resource; the response carries the
new slot and a location to fetch it; fetching it returns the same data.

**Acceptance Scenarios**:

1. **Given** resource 7 exists and has no slot, **When** a client opens a slot from
   `2026-11-02T09:00:00Z` to `2026-11-02T10:00:00Z`, **Then** the service responds 201 with a
   `Location` header and the stored slot (id, resource id, start and end in UTC, creation and
   update instants in UTC).
2. **Given** a client sends the same interval with a non-UTC offset (for example
   `2026-11-02T11:00:00+02:00`), **When** the slot is stored and returned, **Then** the
   instants are normalized to UTC (`2026-11-02T09:00:00Z`).
3. **Given** a slot `[09:00, 10:00)` exists on a resource, **When** a client opens
   `[10:00, 11:00)` or `[08:00, 09:00)` on the same resource, **Then** the service responds 201:
   intervals are half-open, so touching slots do not overlap.
4. **Given** a slot `[09:00, 10:00)` exists on a resource, **When** a client opens an
   interval that overlaps it in any way (identical, inside, containing, or sharing part),
   **Then** the service responds 409 with a problem details body and creates nothing.
5. **Given** a slot exists on resource 7, **When** a client opens an overlapping interval on a
   different resource, **Then** the service responds 201: overlap is judged per resource.
6. **Given** an end that is not after the start (equal or earlier), a missing start or end,
   or an instant without an explicit offset or not in ISO 8601, **When** it is submitted,
   **Then** the service responds 400 with validation problem details naming each invalid
   field, and creates nothing.
7. **Given** no resource has the id in the route (or it is retired), **When** a client opens a
   slot on it, **Then** the service responds 404 with a problem details body.

---

### User Story 2 - Look up a slot (Priority: P2)

An API client fetches one slot of a resource by its identifier.

**Why this priority**: bookings must be able to confirm that a slot exists and which resource
it belongs to; it also proves the read path.

**Independent Test**: open a slot, fetch it by id under its resource, compare; fetch an id
that does not exist, and an id under a different resource.

**Acceptance Scenarios**:

1. **Given** a slot exists on resource 7, **When** a client requests it under resource 7,
   **Then** the service responds 200 with the slot.
2. **Given** no slot has the requested id, **When** a client requests it, **Then** the service
   responds 404 with a problem details body.
3. **Given** a slot exists on resource 7, **When** a client requests it under a different
   resource id, **Then** the service responds 404 (a slot is only reachable through its own
   resource).
4. **Given** the resource does not exist or is retired, **When** a client requests any slot
   under it, **Then** the service responds 404.
5. **Given** a slot has been retired (a state this feature can read but never produce),
   **When** a client requests it, **Then** the service responds 404.

---

### User Story 3 - Browse the slots of a resource (Priority: P3)

An API client lists the slots of one resource a page at a time, in time order.

**Why this priority**: clients need to discover a resource's availability, but nothing else
depends on the list.

**Independent Test**: open 120 slots on one resource and page through them; every slot appears
exactly once, in start order, and another resource's slots never appear.

**Acceptance Scenarios**:

1. **Given** slots exist on a resource, **When** a client lists them with no parameters,
   **Then** the service responds 200 with the first page of 50, ordered by start then id, and
   the total count for that resource.
2. **Given** more slots than one page holds, **When** a client requests page 2, **Then** it
   receives the next slots with no overlap and no gap.
3. **Given** a page number past the end, **When** requested, **Then** the service responds 200
   with an empty page and the correct total count.
4. **Given** invalid paging parameters (as in feature 002), **When** requested, **Then** the
   service responds 400 with validation problem details naming the parameter.
5. **Given** the resource does not exist or is retired, **When** a client lists its slots,
   **Then** the service responds 404.
6. **Given** retired slots exist, **When** a client lists, **Then** they are not included, and
   a resource with no slots lists as an empty page with total 0.

---

### Edge Cases

- Two clients open overlapping slots on one resource at the same instant: exactly one succeeds
  (201) and the other receives 409; neither receives a server error. The database, not just the
  application, guarantees this (invariant 1's concurrency standard applied to slots).
- Two clients open identical intervals on one resource simultaneously: one 201, one 409.
- Slots on different resources never conflict, even when they run concurrently.
- Touching intervals (`end` of one equals `start` of the next) are allowed.
- An end equal to the start is invalid (an empty interval); `start < end` strictly.
- A timestamp with no offset, a local time, or a date only is rejected with 400, never
  guessed as UTC (invariant 2).
- An empty request body, malformed JSON, or a body of the wrong type responds 400 problem
  details, not 500.
- A resource id or slot id that is not a whole number does not match any route (404 problem
  details).
- A retired slot's interval is free to be opened again (non-overlap applies among non-retired
  slots).
- Slots in the past are allowed (see Assumptions).

## Level Rationale *(mandatory — answers the four Critical triggers, in writing)*

- **domain-invariants**: applies — time slots are directly governed by invariant 2 (every
  instant UTC; `start < end` for every time slot; offset-less timestamps never reach
  persistence) and are the "open slot" that invariant 5 requires before any booking. The
  no-overlap rule is a concurrency-sensitive constraint of the same kind as invariant 1 and
  must hold in code AND in the database. Invariants 1, 3 and 4 (no double booking, lifecycle,
  never delete bookings) cannot be exercised yet because no booking exists. Retiring a slot or
  resource is not shipped here, so invariant 5's retire half is only prepared by the soft-delete
  columns.
- **irreversible-data**: does not apply — the migration is additive (one new table with a
  restrict foreign key to `Resources`, nothing dropped or rewritten) and no operation deletes
  or overwrites data. Its down path drops only the table this feature created and is lawful
  only while that table is empty; once data exists, rollback is a code revert that leaves the
  table.
- **authn-authz-payment**: does not apply — this feature neither introduces nor changes
  authentication or authorization. The endpoints are public, the accepted interim state of
  feature 002 (Assumptions); the authentication feature MUST land before any deployment.
- **auditable-evidence**: does not apply — audit columns are recorded, but nothing here is
  evidence a regulator, auditor or contract can ask for; creator identity is not yet known
  (see FR-009).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The service MUST let a client open a slot with
  `POST /resources/{resourceId}/slots`, taking a required `startUtc` and a required `endUtc`.
  On success it responds 201 with a `Location` header (`/resources/{resourceId}/slots/{id}`)
  and the slot.
- **FR-002**: Instants MUST be ISO 8601 with an explicit UTC offset, accepted in any offset
  and normalized to UTC before they are checked or stored (invariant 2). A value without an
  offset, not ISO 8601, missing or null MUST be refused with 400; it is never assumed to be
  UTC or local.
- **FR-003**: `startUtc` MUST be strictly before `endUtc` (invariant 2). Otherwise 400 with
  validation problem details naming the field (`endUtc` for an end that is not after the
  start).
- **FR-004**: Slots of one resource MUST NOT overlap. Intervals are half-open `[start, end)`:
  a slot ending at 10:00 and one starting at 10:00 do not overlap. The rule applies among
  non-retired slots of the same resource only, and a conflict responds 409 with problem
  details. The rule MUST be enforced in application code AND by the database, so concurrent
  requests cannot create two overlapping slots (no read-then-write check alone — invariant 1's
  standard).
- **FR-005**: A slot MUST belong to exactly one existing, non-retired resource. Opening a slot
  on an unknown or retired resource responds 404. The slot's reference to its resource MUST be
  a foreign key with restrict semantics (database rulebook); a resource referenced by a slot
  can never be hard-deleted (invariant 5).
- **FR-006**: The service MUST return one slot with `GET /resources/{resourceId}/slots/{id}`:
  200 with the slot, or 404 with problem details when the slot does not exist, is retired,
  belongs to another resource, or the resource does not exist or is retired.
- **FR-007**: The service MUST list a resource's slots with `GET /resources/{resourceId}/slots`,
  accepting `page` (default 1, at least 1) and `pageSize` (default 50, from 1 to 100) exactly
  as `GET /resources` does. Retired slots are excluded. Results are ordered by start, then id.
  The response is an object with `items`, `page`, `pageSize` and `totalCount` (counting that
  resource's non-retired slots); invalid parameters respond 400; an unknown or retired
  resource responds 404.
- **FR-008**: A slot is represented as `id` (whole number), `resourceId`, `startUtc`, `endUtc`,
  `createdAtUtc` and `updatedAtUtc`. Instants are ISO 8601 with an explicit UTC offset
  (invariant 2). Retirement state and audit user columns are not exposed.
- **FR-009**: The migration MUST create one table for slots following
  `docs/rulebooks/database-rules.md`: integer identity primary key, audit fields (creation and
  update instants from a UTC clock; creator and updater record the fixed value `anonymous`
  until an identity exists), soft-delete columns, the restrict foreign key to `Resources`, and
  a database-level `start < end` check mirroring FR-003 (constraints mirror invariants). It
  MUST be reversible or ship a written rollback plan, carry no seed data, and be applied only
  to the dedicated booking-api database.
- **FR-010**: This feature MUST NOT provide any way to update, retire or delete a slot, and
  MUST NOT physically delete any row (database rulebook soft-delete standard; invariant 5).
- **FR-011**: The new endpoints MUST be described in a contract written before
  implementation (`contracts/`), appear in the Development OpenAPI document, and return the
  error shapes of `contracts/http-baseline.md` of feature 001.
- **FR-012**: Every endpoint MUST be covered by HTTP-level automated tests, and the database
  constraints (the `start < end` check, the foreign key, and the non-overlap guarantee under
  concurrency) MUST be verified against SQL Server itself, not a stand-in, with hand-worked
  boundary cases for the half-open interval (touching, containing, contained, identical,
  one-instant overlap).

### Key Entities

- **Time slot**: an interval `[start, end)` in UTC during which one resource may be booked.
  Attributes: resource, start, end, creation and update instants (UTC), creator and updater
  (fixed `anonymous` for now), and a retired marker the service reads but this feature never
  sets. Belongs to one resource; bookings will later fall inside a slot (invariant 5).
- **Resource**: unchanged from feature 002; a slot's parent.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The gate (`docs/sdlc/gate-command.md`) exits 0 on the owner's machine, run by the
  owner for every phase (Critical).
- **SC-002**: After opening 100 non-overlapping slots on one resource, listing with the default
  page size returns 2 pages (50 and 50), each slot exactly once, in start order, with
  `totalCount` 100; a second resource's list is unaffected.
- **SC-003**: Many simultaneous requests opening overlapping slots on one resource yield exactly
  one 201 and the rest 409, with zero 5xx responses, over repeated runs; simultaneous requests
  for non-overlapping slots all succeed.
- **SC-004**: Every response from the new endpoints, including every error, is a slot, a page,
  or an RFC 9457 problem details body: zero HTML or stack-trace responses.
- **SC-005**: The migration applies cleanly on top of feature 002's migration to an empty
  dedicated database, and its down path returns that database to its pre-feature state while
  the slots table is empty.
- **SC-006**: Every boundary case of the half-open interval (touching before, touching after,
  identical, contained, containing, overlapping by one instant) has a test whose expected value
  was worked by hand and produces the stated outcome, in the application and in the database.

## Assumptions

- **Endpoints are public for now**, as in feature 002; the authentication feature MUST land
  before any deployment.
- A slot is a **one-off interval**. Recurring availability, bulk creation, and time zones
  beyond the offset a client sends are out of scope.
- Update, retire and delete of slots, and any rule about a slot that has bookings, arrive in
  later features (bookings do not exist yet).
- No minimum or maximum slot length, and no rule against slots in the past, are imposed here:
  the only rules are `start < end`, UTC, per-resource non-overlap, and the resource existing.
  A later feature may add business limits; they are not guessed now.
- Instant precision (how many fractional-second digits are accepted and stored) and the
  database mechanism that enforces non-overlap under concurrency are decided in `plan.md`;
  whichever is chosen, the boundary cases in SC-006 must hold exactly.
- The public identifier is the integer primary key, as in feature 002.
- Local development uses the dedicated `BookingApi` LocalDB database; applying the migration
  to it is a step the owner performs (`quickstart.md`). Tests use throwaway SQL Server
  containers and need Docker (feature 002).
