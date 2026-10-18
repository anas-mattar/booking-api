# Roadmap — booking-api

> **This file carries no implementation authority.** Agents implement only from an
> approved `specs/NNN-name/spec.md`; this roadmap only says what to spec next. A roadmap
> row is never a requirement — if an agent is asked to implement from this file, it must
> stop and ask for a spec (constitution I).

The **inventory** is generated and safe to regenerate; the **roadmap** is authored by
humans and MUST NEVER be regenerated — regeneration silently destroys priority,
sequencing, and scope decisions.

## Inventory *(generated — regenerate freely)*

**Generated from**: nothing yet — booking-api has no prototype or requirements documents.
**Generated on**: — **by**: —

| Inv # | Screen / capability | Source |
|---|---|---|
| — | — | — |

## Roadmap *(authored — humans only, never regenerated)*

One row per candidate feature. `Spec` is filled when the feature is promoted via
`/speckit.specify`; from that moment the spec directory is the truth and this row is just
a pointer. Sequence thin vertical slices: foundations first, reads before writes
(`adoption/greenfield.md` step 5).

Status flow: `idea → specified → in progress → shipped → dropped`

| Feature | Covers (Inv #) | Priority | Status | Owner | Spec |
|---|---|---|---|---|---|
| Solution scaffold (architecture ADR in plan.md) | — | P1 | shipped | anas.m | `specs/001-solution-scaffold/` |

## Decisions log *(authored)*

- 2026-10-18 Kit adopted (agentic-sdlc-kit 2d3e5bd). The first feature is the solution
  scaffold, which the greenfield adoption track requires (`adoption/greenfield.md` step 4).
- 2026-10-18 Feature 001-solution-scaffold shipped (PR #4): architecture ADR-001 (Clean
  Architecture, four projects), health endpoints, problem details, EF Core wired to an empty
  context. Next features are sequenced by the owner; none is claimed.
