# Rollback — 001 Solution Scaffold

## Rollback Method

```bash
git revert <sha>        # one revert per phase commit, newest first: phase 4, 3, 2, 1
```

Each phase is independently revertible on top of its predecessors (plan, Phase sizing), so a
plain revert is sufficient. Revert newest first: phases 3 and 4 use the test factory from
phase 2, and phase 2's tests use the layout from phase 1.

## Changed Areas

- `src/BookingApi.{Domain,Application,Infrastructure,Api}/`, `tests/BookingApi.*.Tests/`,
  `BookingApi.slnx` (the whole scaffold)
- Governance paths updated in phase 1: `CLAUDE.md`, `docs/rulebooks/backend-rules.md`,
  `docs/sdlc/repository-strategy.md`

## Database Rollback

- Schema changes in this feature: **none**. The context is empty; there are no tables and no
  migrations.
- Migration down-path: not applicable.
- Protected domain data touched: none. No domain data exists.

## Deployment Rollback

- No environment is deployed. Local setup from `quickstart.md` (the empty `BookingApi`
  LocalDB database and the `ConnectionStrings:BookingApi` user secret) is outside git; its
  clean-up commands are in `quickstart.md`. Dropping that empty database is safe: it holds no
  data.

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code)
- [ ] After reverting phases 1-4, the repository is the adoption scaffold (the template
  weatherforecast API and its single smoke test)
