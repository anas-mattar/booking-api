# Review Process

## Visual Compliance Loop *(UI phases — runs BEFORE requesting the gate)*

Required for any phase that touches UI when the feature has visual references
(`specs/[feature]/screenshots/`). The agent MUST NOT ask the user to run the gate while
this loop is open. "Looks close" is not a resolution.

<!-- digest: Never ask for the gate while the Visual Compliance Loop is open — "looks close" is not a resolution. -->

1. **Render the real output.** Start the app and capture a screenshot of the implemented
   screen at the **same viewport size** as the reference — web via browser automation;
   mobile via the emulator (`adb exec-out screencap -p` / `xcrun simctl io booted screenshot`).
   If the agent's environment cannot capture, it asks the user to capture and paste the
   screenshot — the loop still runs, with the user as the camera.
2. **Compare side by side** against the reference, walking the spec's Visual Inventory
   item by item (`spec.md`, Visual Inventory section). Compare structure and
   specification — layout, hierarchy, spacing, ordering, exact labels, colors, states —
   not pixels: prototypes are never pixel-identical to real renders, so pixel-diff
   tooling does not apply here.
3. **Produce the deviation table** in the phase notes:

   | # | Element (VI ref) | Reference shows | Implemented shows | Severity | Resolution |
   |---|---|---|---|---|---|

4. **Fix and repeat** (recapture after every fix) until the table is **empty**, or every
   remaining row is marked `proposed to accept` **and the user has approved it**
   (e.g. the prototype shows sample data the real app cannot reproduce).

Exit rule: empty table, or user-approved rows only. Attach the final table and both
screenshots to the phase notes — the AI review verifies they exist.

<!-- digest: Visual loop exit: deviation table empty, or every remaining row user-approved; attach table + both screenshots. -->

## After Each Phase

1. User runs the gate command (`docs/sdlc/gate-command.md`) — or, when the approved plan
   declares `**Gate Certification**: ci-held` (Lite/Micro/Standard only; a Micro feature
   declares it in its mini-spec `spec.md`), the agent reports the
   CI evidence triplet and the owner records approval on it; on a declared batch this
   certification lands once, at batch end.
2. Review the working diff for intent (`git diff --stat`), fix only current-phase issues,
   and commit the phase — the subject carries the `phase N` token so the scope check can
   attribute the commit.
3. Run the machine scope check **against the committed phase** (the script reads git
   history, not the working tree):

```bash
pwsh -File scripts/scope-check.ps1
pwsh -File scripts/scope-check-repos.ps1   # multi-repo only; n/a elsewhere
```

   It must report `PASS`: every changed file inside the phase's **Territory** from
   `tasks.md` — for a Micro feature, the feature-global **Territory** block in its
   mini-spec `spec.md` (constitution X, Micro lane) — (a `WARN` is acceptable only for
   features specified before the verification pack — Definition of Done, gate 4).
   In a multi-repo project the second command grades this phase's commits in the nested
   code repositories (`docs/sdlc/repository-strategy.md`, "Territory across repositories");
   neither verdict may be FAIL — `n/a`, `not applicable` and `WARN` are the cross-repo
   check's lawful non-blocking verdicts. The check asks whether each code repository has a
   branch named after the **feature**, not whether this phase touched it. A feature with no
   branch in any code repository gets `not applicable` on each repository's line and then a
   run-level `UNGRADED`, because nothing was graded anywhere. So does every
   governance-repository CI run, where the code repositories are not checked out. That is
   expected, and it is an `UNGRADED` like any other: the review records the reason in
   writing, as the next paragraph requires. For a phase that touches no code repository, on a
   feature that does have code branches, the command above grades each such branch's tip: a real `PASS` for an
   earlier phase when the tip is that phase's commit, or `not applicable` when the tip carries no
   `phase N` token. And under `-All`, one repository going ungraded while another graded no
   longer hides behind the graded one: a repository that applied (present, a repository of its
   own, carrying the feature branch) and graded nothing — no trunk found, no commits since the
   merge base, or only skipped commits — is named by its own run-level `UNGRADED` line,
   `UNGRADED (… declared code repositories applied to '<feature>' and graded nothing: <names> — …;
   graded: <names>)`, and `ritual-checks.ps1` lifts the `scope-repos` member from it. It also
   prints beside a `FAIL`, so the unread repository is named next to the failure. A repository
   that is `n/a` or `not applicable` for the reasons above (absent, not a repository of its own,
   no branch for the feature) does not make the run `UNGRADED`. The per-phase command above, in
   tip mode (no `-All`), is unchanged: there, one repository going ungraded does not change the
   run-level verdict while another was graded, so read the per-repository lines. An unresolved
   trunk now prints the command that grades that repository:
   `scope-check-repos.ps1 -All -Repo <repo> -BaseRef <trunk>`.

   **`UNGRADED` is not a pass.** It exits 0, so it will not stop you, and it means the
   check RAN AND COMPARED NOTHING: no diff base, a commit range with no commits in it, a
   clone without the history it needs. A reviewer who accepts a phase on an
   `UNGRADED` verdict has accepted it on no evidence from that check. So: an `UNGRADED` member
   is not a pass, and **a review that accepts one says in writing why** — which check, what
   it could not read, and why the phase is safe to approve without it. If the cause is a
   shallow CI checkout, the answer is `fetch-depth: 0`, not a sentence in the review. Whole-run verdicts, here and in CI, come from
   `pwsh -File scripts/ritual-checks.ps1` (doc-lint + enforcement-pack + scope-check +
   scope-repos + digests + roadmap-claims, plus the adoption doctor in adopted projects).
4. On `FAIL`, remediate and redo the phase commit: revert the undeclared change — or, if
   it is legitimate scope discovery, amend the phase's **Territory** in `tasks.md` (owner
   approval, recorded as constitution I requires) in a commit made **before** the
   re-committed phase. The check reads the
   declaration from the commit's parent, so same-commit widening never passes. On a
   Micro feature the territory amendment lives in `spec.md`, must stay within the lane's
   file cap, and the standing alternative is always **promotion to Standard** (full spec
   + `plan.md` + `tasks.md` in a commit before the next phase commit).
5. Do not start next phase without approval.

<!-- digest: After each phase: certify the gate, review git diff --stat, commit with the "phase N" token, scope-check must PASS. -->
<!-- digest: Territory amendments land in a commit BEFORE the re-committed phase — same-commit widening never passes. -->

## AI Review

**Reviewer separation is mandatory** (Definition of Done gate 5): the review is produced
by a reviewer that did not write the code, and the implementing agent never grades its own
diff. Procedure:

1. The implementing agent (or the owner) starts a **fresh-context reviewer** — a new agent
   session with no implementation context, or a second model. Fresh context is the
   minimum; a second model is encouraged where available.
2. The reviewer is given: the phase diff (commit sha), `spec.md`, `plan.md`, and the
   feature's contracts — for a Micro feature, the mini-spec `spec.md` alone, which is all
   the lane has — never the implementer's conversation or reasoning. Read-only
   verification (running checks, replicating logic) is allowed and encouraged.
3. The reviewer completes `specs/_templates/ai-code-review-template.md` **including the
   Reviewer Provenance block** (reviewer identity, inputs supplied, verbatim
   non-implementer attestation), filed as `specs/NNN-name/ai-code-review*.md` — the exact
   naming the machine check keys on. `scripts/enforcement-pack.ps1` fails the branch when
   a review added on it lacks the block or names the implementer as reviewer.
4. The implementer acts on the findings and records each finding's disposition (fixed /
   deferred-where / rejected-why) — appended to the review file, never edited into the
   reviewer's text.

<!-- digest: The AI review is produced by a fresh-context agent or second model — the implementer never grades its own diff. -->
<!-- digest: The reviewer gets diff + spec/plan/contracts, never the implementer's conversation; dispositions are appended. -->

Complete `specs/_templates/ai-code-review-template.md`. Check:

- Spec match
- Visual-reference match (where visual references exist): the Visual Compliance Loop's
  deviation table is attached and is empty or user-approved
- Backend rules
- Frontend rules
- Security
- Tests
- Migrations
- Unrelated changes
- Rollback safety
- Block structure of every document the diff touches: a `digest:` marker, like any comment,
  sits on its own line **after** a table or a list, never inside one. A comment or blank
  line inside a table ends it at that line, and a comment at column zero between two list
  items starts a new list, so the rest renders as stray text while every other check stays
  green. `scripts/doc-lint.ps1` now fails a severed table, a delimiter row with no header,
  a row whose cell count differs from its header's, and a list split by a comment line,
  naming the file and line. It is not a markdown renderer and grades only those rules, so
  a document whose layout matters more than that is still read, not trusted.

<!-- digest: A digest marker goes after a table or list, never inside one; doc-lint fails a table or list it severs. -->

## Human Review

AI review alone is insufficient. **Human review is required before merge**, and a
change MUST NOT be merged until a human reviewer approves it (constitution IX).

<!-- digest: Human review is required before merge — a change is never merged until a human reviewer approves (constitution IX). -->

<!-- digest: The human reviewer judges whether an amendment's approver really agreed — no machine can check that. -->

Human reviewer checks (record in `specs/NNN-name/human-pr-review.md`, written from
`specs/_templates/human-pr-review-template.md`):

- Actual UI vs visual references
- Business behavior
- Domain correctness (business-critical calculations against `docs/domain/booking-invariants.md`)
- Security implications
- Architectural compliance
- Code diff
- Gate result
- No unrelated changes
- Every amendment in the feature diff carries its record — each change to an approved
  `spec.md`, `plan.md`, `tasks.md` or `contracts/` file names an approver who is not the
  implementing agent (constitution I). A machine can grade that a record exists and agrees
  with its commit; **whether the named person actually agreed — and whether the agent
  approved its own amendment — is this reviewer's to judge**, and it is the half no check
  reaches.

## Merge

Merge only after the human reviewer approves. See the consolidated gates in
`docs/sdlc/definition-of-done.md`.
