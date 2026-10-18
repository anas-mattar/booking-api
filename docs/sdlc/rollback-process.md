# Rollback Process

Prefer `git revert`. Each implementation phase is its own commit precisely so that a bad phase
reverts cleanly (see `docs/sdlc/branch-strategy.md`).

<!-- digest: Prefer git revert — each phase is its own commit so a bad phase reverts cleanly. -->

## Rollback Checklist

- Can this phase be reverted by commit?
- Did it change database schema?
- Is schema change additive or destructive?
- Are data migrations reversible?
- Are deployment rollback steps documented?

## Database

Do not drop tables/columns without explicit approval.

## Protected Domain Data

Some domain data must never be physically deleted as a rollback mechanism — see
`docs/domain/booking-invariants.md` (constitution V). For such records:

- Never `DELETE` or `DROP` protected records to undo a change.
- Correct them with the domain's approved additive mechanisms (e.g. reversal, adjustment,
  void, cancellation, or status change) — each itself auditable.
- Reverting code or a migration MUST NOT cascade into physical deletion of protected records.
  If a rollback would require touching protected data, **stop and report**; resolve it through
  a correcting entry, not a delete.
- A rollback that cannot preserve protected-data immutability is not approved.

<!-- digest: Never DELETE or DROP protected domain records to undo a change — correct through additive, auditable mechanisms. -->
<!-- digest: A rollback that cannot preserve protected-data immutability is not approved — stop and report. -->

*(booking-api: bookings are never deleted — a mistaken booking is cancelled, never removed — see `docs/domain/booking-invariants.md`, invariant 4.)*
