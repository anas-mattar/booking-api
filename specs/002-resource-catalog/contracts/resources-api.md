# Contract: Resources API

**Feature**: `002-resource-catalog` | **Consumers**: every future booking-api client |
**Rulebook**: `docs/rulebooks/integration-rules.md` | Builds on
`specs/001-solution-scaffold/contracts/http-baseline.md` (error shape, instants, JSON style).

Constitution VII: purpose, authentication, endpoints, request, response and error schemas,
timeout, retry, idempotency, audit.

## Purpose

Register bookable resources and read them back.

## Authentication

None, deliberately: **the endpoints are public** in this feature (spec Assumptions). This is
an accepted interim state; an authentication feature MUST land before any deployment.

## Conventions

JSON property names are camelCase; enums, none here. Instants are ISO 8601 with an explicit
UTC offset, for example `2026-10-18T12:00:00Z`. Errors are RFC 9457 problem details
(`application/problem+json`) with the shape from the baseline contract.

## The `Resource` representation

```json
{
  "id": 1,
  "name": "Room A",
  "description": "Ground floor, seats 8",
  "createdAtUtc": "2026-10-18T12:00:00Z",
  "updatedAtUtc": "2026-10-18T12:00:00Z"
}
```

`description` is `null` when absent. Retirement state and the audit user columns are not
exposed.

## `POST /resources` — create

Request, `application/json`:

```json
{ "name": "Room A", "description": "Ground floor, seats 8" }
```

- `name`: required; trimmed of surrounding whitespace, then 1 to 100 characters.
- `description`: optional; at most 500 characters. Absent and `null` mean none.

| Outcome | Status | Body |
|---|---|---|
| Created | 201 | the `Resource`; header `Location: /resources/{id}` |
| Invalid input | 400 | `ValidationProblemDetails`: `errors` maps each invalid field (`name`, `description`) to messages |
| Empty body, malformed JSON, wrong JSON types | 400 | problem details |
| Name already used by a non-retired resource (case-insensitive, after trimming) | 409 | problem details, `title` `Resource name already in use` |

Not idempotent: a retry after a lost 201 yields 409. That is the safe, visible outcome.

## `GET /resources/{id}` — get one

`id` is a whole number.

| Outcome | Status | Body |
|---|---|---|
| Found | 200 | the `Resource` |
| Unknown id, or retired resource | 404 | problem details |
| Non-numeric id | 404 | problem details (no route matches) |

Safe and idempotent.

## `GET /resources` — list

Query parameters: `page` (whole number, at least 1, default 1) and `pageSize` (whole number,
1 to 100, default 50).

200, body:

```json
{
  "items": [ { "id": 1, "name": "Room A", "description": null,
               "createdAtUtc": "2026-10-18T12:00:00Z", "updatedAtUtc": "2026-10-18T12:00:00Z" } ],
  "page": 1,
  "pageSize": 50,
  "totalCount": 1
}
```

- Ordered by `name` case-insensitively, then `id`. Retired resources are excluded.
- A page past the end returns 200 with `items` empty and the true `totalCount`.
- Invalid or non-numeric `page` or `pageSize`: 400 `ValidationProblemDetails` naming the
  parameter.

Safe and idempotent.

## Timeout policy

None specified beyond the server's defaults; there is no outbound call.

## Retry policy

None inside booking-api. Clients may retry safe `GET`s freely; `POST` is not idempotent
(see above).

## Audit

Each creation records `createdAtUtc` and `updatedAtUtc` from the server clock (UTC) and the
fixed user `anonymous` until an identity exists. Nothing is exposed about retirement.
