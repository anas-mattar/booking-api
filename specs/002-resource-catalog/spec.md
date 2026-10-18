# Feature Specification: Resource Catalog

**Feature Branch**: `002-resource-catalog`  
**Created**: 2026-10-18  
**Status**: Draft  
**Delivery Level**: Standard
**Rationale Rule**: 1
**Input**: User description: "Resource catalog: the first domain entity. A Resource (name, description, active flag) with create, get-by-id and list endpoints; the first EF Core migration with audit and soft-delete columns per the database rulebook."

A **resource** is the thing that gets booked: a meeting room, a vehicle, a person's calendar.
This feature lets an API client register resources and read them back. It introduces the
first domain entity and the first database migration; time slots and bookings come in later
features.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a resource (Priority: P1)

An API client registers a new resource by giving it a name and, optionally, a description.
The service stores it and returns the resource with its identifier.

**Why this priority**: nothing else in the booking domain can exist without resources; this
is the first write path and the first use of the database.

**Independent Test**: post a name and description; the response carries the new resource's id
and a location to fetch it; fetching it returns the same data.

**Acceptance Scenarios**:

1. **Given** no resource named "Room A" exists, **When** a client registers "Room A" with a
   description, **Then** the service responds 201 with a `Location` header and the stored
   resource (id, name, description, creation and update instants in UTC).
2. **Given** a client registers a resource with no description, **When** the response is
   returned, **Then** the description is null and the resource is otherwise complete.
3. **Given** a resource named "Room A" exists, **When** a client registers "room a" (different
   case) or " Room A " (surrounding spaces), **Then** the service responds 409 with a problem
   details body and creates nothing.
4. **Given** a request with a missing, blank or over-long name, or an over-long description,
   **When** it is submitted, **Then** the service responds 400 with validation problem details
   naming each invalid field, and creates nothing.

---

### User Story 2 - Look up a resource (Priority: P2)

An API client fetches one resource by its identifier.

**Why this priority**: every later feature (slots, bookings) must be able to confirm a
resource exists; it also proves the read path.

**Independent Test**: create a resource, fetch it by id, compare; fetch an id that does not
exist.

**Acceptance Scenarios**:

1. **Given** a resource exists, **When** a client requests it by id, **Then** the service
   responds 200 with the resource.
2. **Given** no resource has the requested id, **When** a client requests it, **Then** the
   service responds 404 with a problem details body.
3. **Given** a resource has been retired (soft-deleted — a state this feature can read but
   never produce), **When** a client requests it by id, **Then** the service responds 404.

---

### User Story 3 - Browse resources (Priority: P3)

An API client lists registered resources a page at a time, in a stable order.

**Why this priority**: clients need to discover resources, but nothing else depends on the
list.

**Independent Test**: create 120 resources and page through them; every resource appears
exactly once, in name order.

**Acceptance Scenarios**:

1. **Given** resources exist, **When** a client lists them with no parameters, **Then** the
   service responds 200 with the first page of 50, ordered by name (case-insensitive, then id),
   and the total count.
2. **Given** more resources than one page holds, **When** a client requests page 2, **Then**
   it receives the next resources with no overlap and no gap.
3. **Given** a page number past the end, **When** requested, **Then** the service responds 200
   with an empty page and the correct total count.
4. **Given** invalid paging parameters (page below 1, page size outside 1 to 100, non-numeric
   values), **When** requested, **Then** the service responds 400 with validation problem
   details.
5. **Given** retired resources exist, **When** a client lists, **Then** they are not included.

---

### Edge Cases

- Two clients register the same name at the same instant: exactly one succeeds (201) and the
  other receives 409; neither receives a server error. The database, not just the application,
  guarantees this.
- A name that differs only by case or surrounding whitespace counts as the same name.
- An empty request body, malformed JSON, or a body of the wrong type responds 400 problem
  details, not 500.
- A resource id that is not a whole number does not match any route (404 problem details).
- A retired resource's name is free to be registered again (uniqueness applies among
  non-retired resources).

## Level Rationale *(mandatory — answers the four Critical triggers, in writing)*

- **domain-invariants**: does not apply — no time slot or booking exists, so invariants 1 to 4
  of `docs/domain/booking-invariants.md` cannot be exercised or violated. Invariant 5's
  resource half (a retired resource takes no new bookings, and is never hard-deleted) is only
  prepared here by the soft-delete columns; no retire operation ships.
- **irreversible-data**: does not apply — the migration is additive (one new table, nothing
  dropped or rewritten) and no operation deletes or overwrites data. The migration's down path
  drops only the table this feature created, and is lawful only while that table is empty;
  once data exists, rollback is a code revert that leaves the table (see the rollback plan).
- **authn-authz-payment**: does not apply — this feature neither introduces nor changes
  authentication or authorization. The endpoints are explicitly **public** as an accepted
  interim state (no environment is deployed); see Assumptions. This is the one answer a human
  reviewer should test hardest.
- **auditable-evidence**: does not apply — audit columns are recorded, but nothing here is
  evidence a regulator, auditor or contract can ask for; creator identity is not yet known
  (see FR-008).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The service MUST let a client create a resource with `POST /resources`, taking a
  required `name` and an optional `description`. The name is trimmed of surrounding whitespace
  and MUST then be 1 to 100 characters; the description MUST be at most 500 characters. On
  success it responds 201 with a `Location` header and the resource.
- **FR-002**: Resource names MUST be unique, compared case-insensitively after trimming, among
  non-retired resources. A duplicate responds 409 with problem details. The rule MUST be
  enforced in application code AND by the database, so concurrent requests cannot create two
  resources with the same name.
- **FR-003**: Invalid input MUST respond 400 with validation problem details that name each
  invalid field; nothing is stored.
- **FR-004**: The service MUST return one resource with `GET /resources/{id}`: 200 with the
  resource, or 404 with problem details when it does not exist or is retired.
- **FR-005**: The service MUST list resources with `GET /resources`, accepting `page` (default
  1, at least 1) and `pageSize` (default 50, from 1 to 100). Retired resources are excluded.
  Results are ordered by name case-insensitively, then by id. The response is an object with
  `items`, `page`, `pageSize` and `totalCount`; invalid parameters respond 400.
- **FR-006**: A resource is represented as `id` (whole number), `name`, `description` (null
  when absent), `createdAtUtc` and `updatedAtUtc`. Instants are ISO 8601 with an explicit UTC
  offset (invariant 2). Retirement state and audit user columns are not exposed.
- **FR-007**: The first migration MUST create one table for resources following
  `docs/rulebooks/database-rules.md`: integer identity primary key, audit fields, soft-delete
  columns, and a unique constraint on the name among non-retired rows. It MUST be reversible,
  carry no seed data, and be applied only to the dedicated booking-api database.
- **FR-008**: Creation and update instants MUST come from a UTC clock. Until an identity exists
  (a later authentication feature), the creator and updater columns record the fixed value
  `anonymous`.
- **FR-009**: This feature MUST NOT provide any way to update, retire or delete a resource,
  and MUST NOT physically delete any row (invariant 4's spirit for master data; database
  rulebook soft-delete standard).
- **FR-010**: The new endpoints MUST be described in a contract written before
  implementation (`contracts/`), appear in the Development OpenAPI document, and return the
  error shapes of `contracts/http-baseline.md` of feature 001.
- **FR-011**: Every endpoint MUST be covered by HTTP-level automated tests, and the database
  constraints (uniqueness, required columns, lengths) MUST be verified against SQL Server
  itself, not a stand-in. How tests obtain a database is decided in `plan.md`.

### Key Entities

- **Resource**: a bookable thing. Attributes: name (unique among non-retired resources),
  description (optional), creation and update instants (UTC), creator and updater (fixed
  `anonymous` for now), and a retired marker the service reads but this feature never sets.
  Related later by time slots and bookings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The gate (`docs/sdlc/gate-command.md`) exits 0 on the owner's machine and in CI.
- **SC-002**: After creating 100 distinct resources, listing with the default page size
  returns 2 pages (50 and 50), each resource exactly once, in name order, with `totalCount`
  100.
- **SC-003**: Two simultaneous requests creating the same name yield exactly one 201 and one
  409, and zero 5xx responses, over repeated runs.
- **SC-004**: Every response from the new endpoints, including every error, is a resource, a
  page, or an RFC 9457 problem details body: zero HTML or stack-trace responses.
- **SC-005**: The migration applies cleanly to an empty dedicated database, and its down path
  returns that database to its pre-feature state.

## Assumptions

- **Endpoints are public for now.** No authentication scheme exists (backend rulebook: it is
  chosen in a later plan-approved feature) and no environment is deployed. Creating a
  resource is a write that a real system would protect; shipping this unprotected is an
  accepted interim risk, and the authentication feature MUST land before any deployment.
- The public identifier is the integer primary key (database rulebook permits opaque ids but
  does not require them). Integers are guessable; that matters only once access control exists.
- "Active" is not a separate flag: a resource is active unless retired (soft-deleted). The
  retire operation, resource updates, time slots and bookings are out of scope and arrive in
  later features.
- Names are compared with the database's default case-insensitive collation; names are
  free text, with no restriction on characters.
- Local development uses the dedicated `BookingApi` LocalDB database confirmed in feature 001;
  applying the migration to it is a step the owner performs (`quickstart.md`).
