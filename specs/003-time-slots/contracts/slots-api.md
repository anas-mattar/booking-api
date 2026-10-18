# Contract: Slots API

**Feature**: `003-time-slots` | **Consumers**: every future booking-api client |
**Rulebook**: `docs/rulebooks/integration-rules.md` | Builds on
`specs/001-solution-scaffold/contracts/http-baseline.md` (error shape, instants, JSON style) and
`specs/002-resource-catalog/contracts/resources-api.md` (paging, the parent resource).

Constitution VII: purpose, authentication, endpoints, request, response and error schemas,
timeout, retry, idempotency, audit.

## Purpose

Open bookable time on a resource and read it back. A slot is the owner's statement that a resource
may be booked during one interval (invariant 5).

## Authentication

None, deliberately: **the endpoints are public** in this feature (spec Assumptions). This is the
accepted interim state of feature 002; an authentication feature MUST land before any deployment.

## Conventions

JSON property names are camelCase. Instants are ISO 8601 **with an explicit offset**, for example
`2026-11-02T09:00:00Z` or `2026-11-02T11:00:00+02:00`; they are accepted in any offset and always
returned in UTC with `Z` (invariant 2). Intervals are half-open: `startUtc` inclusive, `endUtc`
exclusive. Errors are RFC 9457 problem details (`application/problem+json`) with the shape from
the baseline contract.

Accepted instant text: `yyyy-MM-ddTHH:mm:ss`, optionally with 1 to 7 fractional digits, followed
by `Z` or `±hh:mm`. A value with no offset (`2026-11-02T09:00:00`), a date only, a Unix timestamp,
or any other shape is refused with 400.

## The `Slot` representation

```json
{
  "id": 1,
  "resourceId": 7,
  "startUtc": "2026-11-02T09:00:00Z",
  "endUtc": "2026-11-02T10:00:00Z",
  "createdAtUtc": "2026-10-19T12:00:00Z",
  "updatedAtUtc": "2026-10-19T12:00:00Z"
}
```

Retirement state and the audit user columns are not exposed.

## `POST /resources/{resourceId}/slots` — open a slot

`resourceId` is a whole number. Request, `application/json`:

```json
{ "startUtc": "2026-11-02T09:00:00Z", "endUtc": "2026-11-02T10:00:00Z" }
```

- `startUtc`, `endUtc`: both required, ISO 8601 with an explicit offset; the end MUST be strictly
  after the start.

| Outcome | Status | Body |
|---|---|---|
| Opened | 201 | the `Slot`; header `Location: /resources/{resourceId}/slots/{id}` |
| Missing, null or unparsable instant; no offset; end not after start | 400 | `ValidationProblemDetails`: `errors` maps each invalid field (`startUtc`, `endUtc`) to messages |
| Empty body, malformed JSON, wrong JSON types | 400 | problem details |
| Unknown or retired resource | 404 | problem details |
| Non-numeric `resourceId` | 404 | problem details (no route matches) |
| Overlaps a non-retired slot of the same resource | 409 | problem details, `title` `Slot overlaps an existing slot` |

Touching slots (one ends where the next starts) do not overlap and are accepted. Overlap is judged
per resource. Not idempotent: a retry after a lost 201 yields 409 (the interval now overlaps
itself). That is the safe, visible outcome.

## `GET /resources/{resourceId}/slots/{id}` — get one

`resourceId` and `id` are whole numbers.

| Outcome | Status | Body |
|---|---|---|
| Found | 200 | the `Slot` |
| Unknown slot id, retired slot, slot of another resource, or unknown or retired resource | 404 | problem details |
| Non-numeric `resourceId` or `id` | 404 | problem details (no route matches) |

Safe and idempotent.

## `GET /resources/{resourceId}/slots` — list a resource's slots

Query parameters: `page` (digits only, at least 1, default 1) and `pageSize` (digits only, 1 to
100, default 50), as in `GET /resources`.

200, body:

```json
{
  "items": [ { "id": 1, "resourceId": 7, "startUtc": "2026-11-02T09:00:00Z", "endUtc": "2026-11-02T10:00:00Z",
               "createdAtUtc": "2026-10-19T12:00:00Z", "updatedAtUtc": "2026-10-19T12:00:00Z" } ],
  "page": 1,
  "pageSize": 50,
  "totalCount": 1
}
```

- Only this resource's slots; ordered by `startUtc`, then `id`. Retired slots are excluded.
  `totalCount` counts this resource's non-retired slots.
- A page past the end returns 200 with `items` empty and the true `totalCount`; a resource with no
  slots returns an empty page with `totalCount` 0.
- Invalid or non-numeric `page` or `pageSize`: 400 `ValidationProblemDetails` naming the
  parameter (only the unparsable parameters are named when any does not parse, as in feature 002).
- Unknown or retired resource: 404 problem details.

Safe and idempotent.

## Timeout policy

None specified beyond the server's defaults; there is no outbound call. A request that waits for
another writer on the same resource (the database serialises concurrent slot writes per resource)
completes when that writer does.

## Retry policy

None inside booking-api. Clients may retry safe `GET`s freely; `POST` is not idempotent (see
above).

## Audit

Each opening records `createdAtUtc` and `updatedAtUtc` from the server clock (UTC) and the fixed
user `anonymous` until an identity exists. Nothing is exposed about retirement.
