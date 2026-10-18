# Repository Strategy

## Rule

booking-api is a **single repository**: the API, its tests, its database migrations, and
its governance (constitution, `CLAUDE.md`, `docs/`, `specs/`) all live here. Constitution
principle III (Repository Separation) is recorded as not applicable. Adding a second
repository — a frontend, a worker, a shared library — is an architecture change: it
requires approval in a feature's `plan.md` and the re-ratification of principle III before
that repository receives code.

<!-- digest: booking-api is a single repository; adding a second repository needs plan.md approval and re-ratifying principle III. -->

## This repository

Contains:

- ASP.NET Core Web API (.NET 10) — **src/BookingApi/**
- Backend tests — **tests/BookingApi.Tests/**
- Database migrations (EF Core, SQL Server), once the first persistence feature adds them
- Governance and the feature trail — `.specify/`, `docs/`, `specs/`, `scripts/`

Does not contain:

- Frontend or mobile source code
- Secrets of any kind (constitution VI)

## Territory across repositories

Not applicable: with one repository, a feature's **Territory** entries are plain paths from
this repository's root, and `pwsh -File scripts/scope-check.ps1` grades every phase commit.
`kit-adoption.json` declares no `codeRepos`, so `scripts/scope-check-repos.ps1` reports
`n/a` by design.

<!-- digest: Territory entries are plain repository-root paths; scope-check.ps1 grades them, scope-check-repos.ps1 reports n/a. -->

## Cross-Repository Feature Rule

Not applicable while this is the only repository. A feature that would span repositories
is, by the rule above, first an architecture change.

<!-- digest: Always confirm which repository is active before changing files. -->

Always confirm which repository is active before changing files.
