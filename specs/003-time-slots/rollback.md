# Rollback — 003 Time Slots

Written before phase 1, as `docs/sdlc/critical-delivery.md` requires of a Critical feature.

## Rollback Method

```bash
git revert <sha>        # one revert per phase commit, newest first: phase 4, 3, 2, 1
```

Phase commits are the ones whose subject starts `phase N` (`git log --oneline --grep "^phase N"`);
a phase and its remediation commits are reverted together. Revert newest first: phase 4 calls the
phase 2 handlers over the phase 3 repository, phase 3 implements the phase 2 port, phase 2 uses the
phase 1 entity. Each phase is independently revertible on top of its predecessors (plan, Phase
sizing), so a plain revert is sufficient.

## Changed Areas

- `src/BookingApi.Domain` (`TimeSlot`), `src/BookingApi.Application` (`Slots/`),
  `src/BookingApi.Infrastructure` (mapping, repository, `Migrations/` — migration `TimeSlots`),
  `src/BookingApi.Api` (`Features/Slots/`, `Program.cs`).
- Tests in the four existing test projects. No new project, package or tool.
- Feature 002 code is not modified except to register the new services (`DependencyInjection`,
  `Program.cs`) and, if the plan's phase 3 needs it, the DbContext mapping.

## Database Rollback

- Schema changes in this feature: **additive** — one new table `Slots`, its foreign key to
  `Resources`, three check constraints, one index and one trigger `TR_Slots_NoOverlap`; no existing
  object changes.
- Migration down-path: `TimeSlots.Down` drops the trigger, then `Slots`. Safe **only while the
  table is empty**. Once any slot exists, do **not** run it: revert the code and leave the table
  and the trigger (`data-model.md`, Migration). The trigger only constrains inserts and updates of
  `Slots`; with the code reverted nothing writes there, so leaving it is harmless, and dropping it
  would remove the database-level non-overlap guarantee from existing data.
- Protected domain data touched: slots are master data under the soft-delete standard and are what
  invariant 5 requires bookings to fall inside. Physical deletion (`DELETE`, `DROP TABLE`) of
  populated data is NOT a rollback mechanism (`docs/sdlc/rollback-process.md`); if a rollback would
  need it, stop and report. Bookings do not exist yet; once they do, a slot a booking references can
  never be hard-deleted (the foreign key restricts it).

## Deployment Rollback

- No configuration, environment variable, permission or feature flag was added.
- The migration is applied by the owner with `dotnet ef database update`, never on startup, so
  reverting the code never touches a database by itself. A database that already holds `TimeSlots`
  keeps it after a code revert; that is intended.
- The three endpoints are public by design in this feature; reverting removes them.

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code, run by the owner)
- [ ] `GET /resources/{id}/slots` answers `404` problem details again, and `GET /resources`,
      `/health` and `/health/ready` still answer as before this feature
- [ ] If the table was empty and dropped: `SELECT name FROM sys.tables` lists no `Slots`,
      `SELECT name FROM sys.triggers` lists no `TR_Slots_NoOverlap`, and `dotnet ef migrations list`
      ends at `ResourceCatalog`
