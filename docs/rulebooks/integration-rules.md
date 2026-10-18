# Integration Rules — booking-api

> **Binding**: contract-before-implementation is constitution VII; this rulebook only
> operationalizes it. It covers every call that crosses a repository or leaves the system,
> and booking-api's own published HTTP contract as consumed by its clients.

## Contract First

- Every cross-repository or external call MUST have a written contract in the feature's
  `contracts/` directory BEFORE either side is implemented; both sides cite the contract
  file in a comment. **Why**: two teams (or two agents) coding against an imagined
  interface produce two interfaces.
- The contract outranks `tasks.md` and implementation notes (constitution II, the API
  contracts rung). If implementation and contract conflict: stop and report — never
  silently patch either.

## Change Discipline

- Additive changes (new optional fields, new endpoints) are the default evolution path.
  Breaking a published contract requires a spec update and `plan.md` approval.

## Wire Format

- JSON property names are camelCase; instants are ISO 8601 with an explicit offset and
  are UTC on output (invariant 2); enums are serialized as strings.
- Errors MUST use the contract's declared error shape (RFC 9457 problem details) —
  consumers MUST distinguish "call failed" from "empty result".
  **Why**: a failure decoded as an empty list is silent data loss.

## Runtime Discipline

- Every outbound call MUST have an explicit timeout: 10 seconds unless the contract states
  otherwise.
- Retry/backoff policy: no automatic retries unless approved in the feature's `plan.md`.
- A failed integration MUST surface as the consumer's error/unavailable state — never as
  fabricated or cached-stale data presented as fresh.

## Configuration & Secrets

- Base URLs, keys, and credentials come from configuration (`dotnet user-secrets` in
  development, environment variables elsewhere), never hard-coded. Secrets MUST NOT reach
  client-side code.
