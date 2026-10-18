# CLAUDE.md

Guidance for AI coding agents working in this repository. This project uses a controlled
SDLC workflow with Spec Kit documents. Do not implement everything at once.

## Stack Profile

```text
Backend: .NET 10 / ASP.NET Core Web API (minimal-API template) → this repository
  Runtime / package manager: .NET SDK 10.0.400 (global.json, rollForward latestFeature); NuGet
  Source roots: src/BookingApi.{Domain,Application,Infrastructure,Api}/, tests/BookingApi.*.Tests/ (xUnit)
  Build: dotnet build BookingApi.slnx --warnaserror     Test: dotnet test BookingApi.slnx --no-build
  Gate slice: the whole gate — docs/sdlc/gate-command.md
  Dependency policy: no new NuGet package without plan.md approval (constitution IV)
  Known failure modes: --warnaserror trips on transitive-package advisories — triage per
                       gate-command.md, never by dropping the flag; Program is top-level
                       (tests reference it via typeof(Program))

Database: SQL Server — local dev on LocalDB (MSSQLLocalDB); EF Core arrives with the first
  feature that needs persistence (plan-approved). Rules: docs/rulebooks/database-rules.md
  Known failure modes: confirm the connection string targets a booking-api-only database
                       before the first migration (database rulebook, Setup);
                       the gate needs a running Docker engine (Testcontainers SQL Server
                       for the database tests) — with Docker down they fail, never skip
```

## The Law

- Constitution: `.specify/memory/constitution.md` — supersedes everything, including this file.
  It is the project's ONLY constitution.
- Definition of Done: `docs/sdlc/definition-of-done.md` — the six gates every phase must pass.
- Gate command: `docs/sdlc/gate-command.md` — certification is held by the user: the
  user-confirmed exit code, or (Lite/Micro/Standard, `ci-held` declared in the plan — or
  the Micro mini-spec — constitution X)
  the owner's recorded approval on the CI evidence triplet. You never claim success.

## Source of Truth

The canonical, ordered source-of-truth ladder lives in constitution **II** (`.specify/memory/constitution.md`) —
do not restate it here; read it there.

**Conflict rule**: if any two rungs conflict, stop and report — never silently choose.
Never invent a new UI layout when visual references exist.

## Feature Structure

Branch `NNN-name` maps to directory `specs/NNN-name/` — always. The core documents, with exactly these names:

```text
specs/NNN-name/
├── spec.md          # first
├── plan.md          # second
├── tasks.md         # third
├── screenshots/     # visual references, if the feature has any
├── contracts/       # external/API contracts, if any
├── data-model.md    # if the feature touches data
└── research.md      # optional
```

That list is the core, not the whole set. `docs/sdlc/branch-strategy.md` ("Spec Directory
Contents") is the authoritative file set: it also holds `notes.md`, `quickstart.md`,
`checklists/`, and the per-feature AI review, human review and rollback files from
`specs/_templates/`. Create whatever the lane requires; never decline a file because this
summary omits it.

The layout is law even when tooling is absent. If the `/speckit.*` commands are
unavailable (kit partially installed), do NOT invent a different layout: create the core
structure manually from the templates in `.specify/templates/`, and report the incomplete
install so the user can finish it (see `adoption/`, step 0).

**Micro exception** (constitution X, Micro lane): a feature whose `spec.md` declares
`**Delivery Level**: Micro` holds `spec.md` alone — a single-page mini-spec from
`.specify/templates/micro-spec-template.md`; no `plan.md`/`tasks.md` until promoted to
Standard.

## Workflow

The whole ritual on one page: `docs/sdlc/flow.md` (summary only — the documents it
links to prevail).

1. Check current branch and working tree; stop if unrelated uncommitted changes exist.
2. Run the baseline gate on untouched code.
3. One feature branch per feature (`docs/sdlc/branch-strategy.md`).
4. Create/update `spec.md`, then `plan.md`, then `tasks.md` (the `/speckit.*` commands do
   this). Micro features: the approved mini-spec `spec.md` alone (constitution X, Micro lane).
5. Implement **one phase only**. UI phase with visual references? Run the Visual
   Compliance Loop (`docs/sdlc/review-process.md`) until the deviation table is empty or
   user-approved. Then stop and ask the user to run the gate.
6. Review the working diff for intent (`git diff --stat`), fix only current-phase issues,
   then commit the phase (`phase N` in the subject).
7. Run the machine scope check against the commit (`pwsh -File scripts/scope-check.ps1` —
   PASS required; a failing commit is remediated and redone; in a multi-repo project
   `pwsh -File scripts/scope-check-repos.ps1` grades the same phase's commits in the
   nested code repositories). AI review by a fresh-context
   agent or second model — never self-graded — with the Reviewer Provenance block; then
   human review. Merge only after approval. CI re-runs the same checks on every push
   (`scripts/ritual-checks.ps1`).

## Strict Rules

- Implement one phase only. Do not continue without user approval.
- Do not refactor unrelated files or change unrelated features.
- Do not add packages unless approved in `plan.md`.
- Do not change architecture unless approved in `plan.md`.
- Amending an approved feature document records who approved it, and **you never approve
  your own amendment** (constitution I, Amendment authority — read it for the record shape
  and the one exemption).
- Do not claim success until the user runs the gate and confirms the exit code — or, on a
  Lite/Micro/Standard feature whose approved plan (Micro: mini-spec) declares
  `**Gate Certification**: ci-held`,
  until the owner records approval on the evidence triplet (CI run URL + green conclusion
  + exact phase-commit sha — for a declared batch, the batch-end commit;
  `docs/sdlc/gate-command.md`). Under ci-held you report the evidence and request that
  approval; you still never claim success yourself.
- A Micro feature is exactly one phase inside hard bounds (≤5 territory files, ≤400
  lines). If it outgrows them, stop and promote in place to Standard (full spec + plan +
  tasks, committed before any further phase) — never stretch the lane.
- Domain invariants (`docs/domain/booking-invariants.md`) carry constitutional force.

## Task-Scoped Reading

Read the pack that matches what you are about to touch — not everything, every time:

**Orientation first (optional)**: five packs of the table below have a generated one-page
digest in `docs/digests/` — delivery, branching, review, critical, adoption (member
documents per pack: `docs/digests/digest-packs.json`, the single source of composition).
A digest orients; it is **never a source-of-truth rung and never satisfies a "read first"
obligation** — before acting on an area, read the full document. Digests are written only
by `scripts/build-digests.ps1`, and CI fails on any drift — on a green branch a digest
matches its law. The always-load row (this file + the Definition of Done) is unchanged —
digests never replace it.

| Touching… | Read first |
|---|---|
| Any phase (always) | This file + `docs/sdlc/definition-of-done.md` |
| New to the project / need the big picture | `docs/sdlc/flow.md` |
| Branching / starting a feature | `docs/sdlc/branch-strategy.md`, `docs/sdlc/repository-strategy.md` |
| Project with more than one developer | `docs/sdlc/team-workflow.md` |
| Backend / service logic | `docs/rulebooks/backend-rules.md` |
| A schema / migration | `docs/rulebooks/database-rules.md` + `docs/sdlc/rollback-process.md` |
| Domain-critical logic | `docs/domain/booking-invariants.md` |
| A feature declared Micro (small, bounded, one phase) | `.specify/templates/micro-spec-template.md` + `docs/sdlc/branch-strategy.md` (level menu) |
| A feature declared Critical (regulated / high-risk) | `docs/sdlc/critical-delivery.md` |
| An external integration | `docs/rulebooks/integration-rules.md` (contract before implementation — constitution VII) |
| Reviewing / finishing a phase | `docs/sdlc/review-process.md` + the templates in `specs/_templates/`; verdicts come from `pwsh -File scripts/ritual-checks.ps1` (doc-lint + enforcement-pack + scope-check + scope-repos + digests + roadmap-claims, plus the adoption doctor in adopted projects — same command CI runs) |
| Updating an adopted project from the kit | `adoption/updating.md`; integrity verdicts come from `pwsh -File scripts/verify-kit.ps1` (the adoption doctor — runs at init end, update end, and in adopted-project CI) |


## Repositories

This repository is the only repository.

When implementing a feature, always confirm which repository is active before changing files.
Multi-repo projects declare their code repositories in `kit-adoption.json` and write
**Territory** entries repo-prefixed from this repository's root — see "Territory across
repositories" in `docs/sdlc/repository-strategy.md`, which is what
`scripts/scope-check-repos.ps1` grades against.
