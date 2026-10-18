# Contract: HTTP Baseline — health and errors

**Feature**: `001-solution-scaffold` | **Consumers**: deployment health probes, every future
API client | **Rulebook**: `docs/rulebooks/integration-rules.md`

Constitution VII requires this contract to cover purpose, authentication, endpoints,
request, response and error schemas, timeout, retry, idempotency and audit. Items that do
not apply say so.

## Purpose

Lets an operator or orchestrator ask whether booking-api is alive and whether it is ready
(can reach its database), and fixes the one error shape every booking-api endpoint uses.

## Authentication

None. Both endpoints are public by design: they return only a status word and expose no
data (spec Level Rationale, authn-authz-payment).

## Endpoints

### `GET /health` — liveness

- Request: no parameters, no body.
- 200 `text/plain`, body `Healthy`. Returned whenever the process is serving requests.
- Never consults the database (spec FR-002).

### `GET /health/ready` — readiness

- Request: no parameters, no body.
- 200 `text/plain`, body `Healthy` — the API opened a connection to its configured database.
- 503 `text/plain`, body `Unhealthy` — the database is unreachable, the connection string is
  missing or invalid, or the check exceeded its timeout.
- The body never contains a connection string, server name, exception message or
  credential (spec FR-004).

## Error schema (every endpoint, now and later)

RFC 9457 problem details, `application/problem+json`:

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.5",
  "title": "Not Found",
  "status": 404,
  "traceId": "00-…"
}
```

| Situation | Status | Notes |
|---|---|---|
| Route does not exist | 404 | spec FR-005 |
| Unhandled exception | 500 | no `detail` with the exception message, no stack trace, no exception type — in every environment (spec FR-006) |
| Validation failure (later features) | 400 | `ValidationProblemDetails` with an `errors` map (backend rulebook) |

`traceId` is present for correlation with logs; it carries no data.

## Timeout policy

The readiness check gives up after **5 seconds** and reports 503 (spec FR-004). Liveness has
no outbound call.

## Retry policy

None inside booking-api. Probes retry on their own schedule.

## Idempotency

Both endpoints are safe and idempotent `GET`s.

## Audit

Not audited: probe traffic carries no business meaning. Failed readiness checks are logged
by the framework (`DefaultHealthCheckService`) at Error level, without the connection string.

**Amendment approved by**: anas.m, 2026-10-18
