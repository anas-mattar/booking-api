# Feature Specification: Solution Scaffold

**Feature Branch**: `001-solution-scaffold`  
**Created**: 2026-10-18  
**Status**: Approved  
**Delivery Level**: Standard
**Rationale Rule**: 1
**Input**: User description: "Solution scaffold: select and record the booking-api architecture (ADR in plan.md) and lay down the empty layered solution it implies. Scope chosen by the owner: skeleton plus database readiness — remove the template sample, liveness and readiness health endpoints, RFC 9457 problem details, an OpenAPI document in Development, API-test infrastructure, and the database connection wired with no tables and no migrations."

## User Scenarios & Testing *(mandatory)*

The "users" of this feature are the people and machines that operate and extend booking-api:
the developer, the deployment environment's health probes, and the API clients that will
consume later features. No booking behaviour ships here.

### User Story 1 - Know the service is alive (Priority: P1)

An operator or orchestrator asks booking-api whether its process is up and serving
requests, without depending on anything outside the process.

**Why this priority**: every later feature is deployed and monitored through this signal;
it is the smallest thing that proves the architecture end to end (hosting, routing, tests,
gate).

**Independent Test**: start the API and request the liveness endpoint; it answers healthy
with no database present.

**Acceptance Scenarios**:

1. **Given** the API is running, **When** a client requests the liveness endpoint, **Then**
   it responds 200 with a healthy status.
2. **Given** the API is running and its database is unreachable, **When** a client requests
   the liveness endpoint, **Then** it still responds 200 — liveness never depends on the
   database.

---

### User Story 2 - Know the service can reach its database (Priority: P2)

An operator or orchestrator asks whether booking-api is ready to serve traffic, which
requires that it can reach its own, dedicated SQL Server database.

**Why this priority**: every domain feature after this one persists data; proving the
connection, configuration and dedicated-database rule now means the first entity feature
debugs only its own logic.

**Independent Test**: with the local database available, the readiness endpoint answers
healthy; with the database unavailable or misconfigured, it answers unhealthy.

**Acceptance Scenarios**:

1. **Given** the configured database is reachable, **When** a client requests the readiness
   endpoint, **Then** it responds 200 with a healthy status.
2. **Given** the configured database is unreachable, **When** a client requests the readiness
   endpoint, **Then** it responds 503 with an unhealthy status, and the response reveals no
   connection string, server name, or credential.

---

### User Story 3 - Get consistent, machine-readable errors (Priority: P3)

An API client that calls an unknown route, or triggers an unexpected server error, receives
a response in one standard error shape it can parse, never an HTML page or a stack trace.

**Why this priority**: the error shape is part of every future contract (integration
rulebook); fixing it before the first endpoint means no endpoint ever ships a different one.

**Independent Test**: request a route that does not exist and force an unhandled error;
both responses are RFC 9457 problem details.

**Acceptance Scenarios**:

1. **Given** the API is running, **When** a client requests a route that does not exist,
   **Then** it responds 404 with an RFC 9457 problem details body.
2. **Given** a request causes an unhandled exception, **When** the response is returned,
   **Then** it is a 500 with an RFC 9457 problem details body and contains no exception
   message or stack trace.

---

### User Story 4 - Discover the API surface in development (Priority: P4)

A developer running the API locally can retrieve a machine-readable description of the
API's endpoints.

**Why this priority**: useful for every later feature's contract review, but nothing
depends on it.

**Independent Test**: run in the Development environment and fetch the OpenAPI document;
run in any other environment and confirm it is not served.

**Acceptance Scenarios**:

1. **Given** the API runs in the Development environment, **When** a developer requests the
   OpenAPI document, **Then** it is returned and lists the health endpoints.
2. **Given** the API runs in a non-Development environment, **When** the OpenAPI document is
   requested, **Then** it is not served.

---

### Edge Cases

- The database connection string is missing entirely: the API still starts and liveness is
  healthy; readiness reports unhealthy rather than the process crashing at startup.
- The configured database name is shared with another project: prevented by the database
  rulebook's Setup rule — the development database name is unique to booking-api.
- The readiness check hangs on an unresponsive server: it gives up within a bounded time
  and reports unhealthy.

## Level Rationale *(mandatory — answers the four Critical triggers, in writing)*

- **domain-invariants**: does not apply — no booking, resource or slot exists yet; nothing
  in `docs/domain/booking-invariants.md` can be exercised or violated.
- **irreversible-data**: does not apply — no tables and no migrations are created; the
  database is only connected to, never written.
- **authn-authz-payment**: does not apply — the health endpoints are explicitly public by
  design (they expose no data), and no authentication scheme is introduced (backend
  rulebook: the scheme is chosen in a later plan-approved feature).
- **auditable-evidence**: does not apply — no business records are created or changed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The template's sample endpoint and its types MUST be removed; the API exposes
  only the endpoints this specification defines.
- **FR-002**: The API MUST expose a public liveness endpoint, `GET /health`, that reports
  healthy whenever the process is serving requests and never consults the database.
- **FR-003**: The API MUST expose a public readiness endpoint, `GET /health/ready`, that
  reports healthy only when the API can open a connection to its configured database, and
  responds 503 otherwise.
- **FR-004**: The readiness check MUST complete within 5 seconds and MUST NOT include
  connection details, exception messages or credentials in its response.
- **FR-005**: Unknown routes MUST return 404 with an RFC 9457 problem details body.
- **FR-006**: Unhandled exceptions MUST return 500 with an RFC 9457 problem details body
  that contains no exception message or stack trace, in every environment.
- **FR-007**: The OpenAPI document MUST be served in the Development environment only.
- **FR-008**: The database connection string MUST come from configuration
  (`dotnet user-secrets` or environment variables), never from a committed
  `appsettings*.json`; the development database MUST be dedicated to booking-api.
- **FR-009**: The database layer MUST be wired with no tables and no migrations; no data is
  read or written.
- **FR-010**: The test suite MUST exercise every endpoint above through the HTTP pipeline,
  and MUST be runnable by the gate without a database present (readiness tests control the
  database's availability rather than requiring one).

### Key Entities

None. This feature introduces no domain entities.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The gate (`docs/sdlc/gate-command.md`) exits 0 on a machine with no SQL Server
  available.
- **SC-002**: With LocalDB running and the connection string configured, `GET /health/ready`
  returns 200; with the database unreachable (for example taken offline), it returns 503
  within 5 seconds.
- **SC-003**: Every response from the endpoints in this spec, including errors, is either a
  health status or an RFC 9457 problem details body — zero HTML or stack-trace responses in
  the test suite.
- **SC-004**: The approved `plan.md` records the architecture ADR-style (options considered,
  decision, consequences), and the code layout after merge matches it.

**Amendment approved by**: anas.m, 2026-10-18

## Assumptions

- Health endpoints are public and unauthenticated: they reveal only healthy/unhealthy, which
  is the established convention for orchestrator probes.
- "Dedicated database" for local development means a LocalDB database named for this
  project (e.g. `BookingApi`) on `(localdb)\MSSQLLocalDB`.
- Production hosting, deployment and environment promotion are out of scope
  (`docs/sdlc/deployment-standards.md` stays a placeholder).
- Authentication, the domain model and every booking behaviour are out of scope and arrive
  in later features.
