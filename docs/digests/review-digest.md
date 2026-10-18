# review pack — law digest (GENERATED)

<!-- GENERATED FILE — do not edit. Regenerate: pwsh -File scripts/build-digests.ps1
     Non-authoritative: for orientation only. The source documents prevail (constitution
     II is unchanged); read the full document before acting on its area. -->

- Never ask for the gate while the Visual Compliance Loop is open — "looks close" is not a resolution. (`docs/sdlc/review-process.md`)
- Visual loop exit: deviation table empty, or every remaining row user-approved; attach table + both screenshots. (`docs/sdlc/review-process.md`)
- After each phase: certify the gate, review git diff --stat, commit with the "phase N" token, scope-check must PASS. (`docs/sdlc/review-process.md`)
- Territory amendments land in a commit BEFORE the re-committed phase — same-commit widening never passes. (`docs/sdlc/review-process.md`)
- The AI review is produced by a fresh-context agent or second model — the implementer never grades its own diff. (`docs/sdlc/review-process.md`)
- The reviewer gets diff + spec/plan/contracts, never the implementer's conversation; dispositions are appended. (`docs/sdlc/review-process.md`)
- A digest marker goes after a table or list, never inside one; doc-lint fails a table or list it severs. (`docs/sdlc/review-process.md`)
- Human review is required before merge — a change is never merged until a human reviewer approves (constitution IX). (`docs/sdlc/review-process.md`)
- The human reviewer judges whether an amendment's approver really agreed — no machine can check that. (`docs/sdlc/review-process.md`)
- Prefer git revert — each phase is its own commit so a bad phase reverts cleanly. (`docs/sdlc/rollback-process.md`)
- Never DELETE or DROP protected domain records to undo a change — correct through additive, auditable mechanisms. (`docs/sdlc/rollback-process.md`)
- A rollback that cannot preserve protected-data immutability is not approved — stop and report. (`docs/sdlc/rollback-process.md`)
