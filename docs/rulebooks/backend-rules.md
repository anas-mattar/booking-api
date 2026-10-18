# Backend Rules — booking-api

> **Binding**: this rulebook is enforced through the backend tier's compliance checklist
> (Definition of Done item 5, `docs/sdlc/definition-of-done.md`): the checklist asserts,
> this rulebook explains. Domain invariants (`docs/domain/booking-invariants.md`) carry
> constitutional force and always outrank this file.

## Layering & Placement

- Code layout: decided ADR-style in feature 001's approved `plan.md` (constitution IV,
  bootstrap clause) and recorded here once 001 merges. Until then the layout is the empty
  scaffold: API in **src/BookingApi/**, tests in **tests/BookingApi.Tests/**, both in
  **BookingApi.slnx**.
- New code MUST follow the existing layout. A new top-level folder, layer, or project
  requires approval in the feature's `plan.md`.
  **Why**: architecture changes ride in on "just one helper folder" — this is where drift starts.

## API Surface

- Every external input MUST be validated at the API boundary; validation failures MUST
  return RFC 9457 problem details (`ValidationProblemDetails` for 400 responses).
  **Why**: the boundary is the one place a bad value is rejected once for all callers.
- Responses MUST use dedicated DTOs; domain entities MUST NOT be serialized directly.
  **Why**: entity leaks turn every schema refactor into a breaking API change.
- Code implementing a feature contract MUST cite the contract file (the feature's
  `contracts/` directory) in a comment at the top of the file.
  **Why**: the citation makes rung-checking possible during review.

## Domain Logic

- Domain invariants (`docs/domain/booking-invariants.md`) MUST be enforced in code AND
  asserted by the database schema where a constraint can express them — never in one place
  only.
- Dates and numbers MUST be parsed and formatted culture-invariantly at every boundary;
  instants are normalized to UTC at the boundary (invariant 2). **Why**: a locale-dependent
  parse is data corruption that no test on the author's machine catches.
- Overlap and availability logic (invariants 1 and 5) MUST live in one named module, fixed
  by the `plan.md` of the first feature that needs it and recorded here, covered by
  golden-fixture tests with hand-worked expected values. Re-deriving it inline is
  prohibited. **Why**: two implementations of one interval rule always diverge.

## Data Access

- Read-only queries MUST NOT track entities (`.AsNoTracking()`).
- Soft-delete filtering is owned by an EF Core global query filter; a query MUST NOT
  re-filter `IsDeleted` by hand, and bypassing the filter (`IgnoreQueryFilters()`) requires
  approval in the feature's `plan.md`.

## Testing

- xUnit. Every endpoint has an API test; overlap/availability and lifecycle logic have
  golden-fixture tests with hand-worked expected values (constitution VIII).
- The gate (`docs/sdlc/gate-command.md`) is run by the user; a phase is not done before
  the user confirms exit code 0 — or, under a declared `ci-held` (Lite/Micro/Standard
  only, constitution X), before the owner records approval on the CI evidence triplet.

## Security

- Secrets MUST NOT be committed; configuration and secrets come from `dotnet user-secrets`
  in development and environment variables elsewhere — never from `appsettings*.json`.
- The authentication and authorization scheme is chosen in a plan-approved feature
  (constitution VI). Until it exists, no endpoint may be described or shipped as
  "protected": an endpoint is either explicitly public in its spec or waits for that
  feature.
