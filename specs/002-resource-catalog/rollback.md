# Rollback — 002 Resource Catalog

## Rollback Method

```bash
git revert <sha>        # one revert per phase commit, newest first: phase 4, 3, 2, 1
```

Phase commits: phase 1 `d5d4abb` (remediation `763fe1c`, `a0a2565`), phase 2 `b4efceb`
(remediation `1493236`), phase 3 `6c08402` (remediation `107a872`), phase 4 the commit whose
subject starts `phase 4` (`git log --oneline --grep "^phase 4"`). A phase and its remediation
commits are reverted together. Revert newest first: phase 4 calls the phase 2 handlers over the
phase 3 repository, phase 3 implements the phase 2 port, phase 2 uses the phase 1 entity.

## Changed Areas

- `src/BookingApi.Domain`, `src/BookingApi.Application` (`Resources/`), `src/BookingApi.Infrastructure`
  (mapping, repository, `Migrations/`), `src/BookingApi.Api` (`Features/Resources/`, `Program.cs`).
- New test projects `tests/BookingApi.TestSupport` and `tests/BookingApi.Infrastructure.Tests`;
  `BookingApi.slnx`; `.config/dotnet-tools.json`.
- Docs: `CLAUDE.md`, `README.md` and the two rulebooks gained the Docker prerequisite (phase 3).
  Reverting phase 3 removes the need for Docker.

## Database Rollback

- Schema changes in this feature: **additive** — one new table `Resources` with its index and
  check constraints; no existing object changes.
- Migration down-path: `ResourceCatalog.Down` drops `Resources`. Safe **only while the table is
  empty**. Once any resource exists, do **not** run it: revert the code and leave the table
  (`data-model.md`, Migration). A later feature can use or retire the table; nothing in the
  reverted code reads it.
- Protected domain data touched: resources are master data under the soft-delete standard.
  Physical deletion (`DELETE`, `DROP TABLE`) of populated data is NOT a rollback mechanism
  (`docs/sdlc/rollback-process.md`); if a rollback would need it, stop and report. Bookings do
  not exist yet.

## Deployment Rollback

- No configuration, environment variable, permission or feature flag was added.
- The migration is applied by the owner with `dotnet ef database update`, never on startup, so
  reverting the code never touches a database by itself. A database that already holds
  `ResourceCatalog` keeps it after a code revert; that is intended.
- The three endpoints are public by design in this feature; reverting removes them.

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code)
- [ ] `GET /resources` answers `404` problem details again and `/health` and `/health/ready`
      still answer as in feature 001
- [ ] If the table was empty and dropped: `SELECT name FROM sys.tables` lists no `Resources` and
      `dotnet ef migrations list` is empty
