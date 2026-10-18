# Critical Delivery Addendum

Additive requirements for high-risk features. This file is only read when a feature is
declared **Critical**; everything here applies **on top of** the full numbered-feature
workflow, never instead of it.

## Delivery levels

The kit has four delivery levels. The first three are defined elsewhere — Lite and
Standard under other names in `docs/sdlc/branch-strategy.md`, Micro in constitution X
(Micro lane); this file defines only the last:

| Level | Lane | Requirements |
|---|---|---|
| **Lite** | `fix/`, `chore/`, `docs/` — the lightweight lane (`docs/sdlc/branch-strategy.md`) | User-run gate + `git diff --stat` scope check + human review |
| **Micro** | `NNN-` numbered feature, single-page mini-spec, one phase inside hard bounds (constitution X, Micro lane) | Mini-spec approved + Definition of Done with the Micro arms (`docs/sdlc/definition-of-done.md`) |
| **Standard** | `NNN-` numbered feature | Full spec workflow + Definition of Done (`docs/sdlc/definition-of-done.md`) |
| **Critical** | `NNN-` numbered feature + this addendum | Standard, plus the additions below — **never** Micro, gate batching, or ci-held |

The level is chosen **per feature, at feature creation** — not per project. A project in a
regulated domain will declare most features Critical; the same project's internal admin
report can still ship Standard. Declare the level in the feature's `spec.md` header; if a
feature's risk grows mid-flight (it starts touching money movement, patient data, or
irreversible operations), stop and promote it — exactly like promoting a `fix/` branch that
grew into a feature.

<!-- digest: The level is chosen per feature at creation, declared in spec.md; risk growing mid-flight promotes — never stretch. -->

## When a feature MUST be Critical

Declare Critical when the feature touches any of:

- rules in the domain-invariants pack (constitution V) — postings, balances, consent
  trails, state machines;
- irreversible or destructive data operations (migrations that drop or rewrite data);
- authentication, authorization, or payment flows;
- anything a regulator, auditor, or contract can ask evidence for.

**Why**: these are the changes where "we can fix it in a follow-up" is false.

<!-- digest: Declare Critical for domain invariants, irreversible data operations, authn/authz/payment, or auditor-facing evidence. -->

### The level is a written claim

The four triggers have stable keys — `domain-invariants`, `irreversible-data`,
`authn-authz-payment`, `auditable-evidence` — and a numbered feature's `spec.md` answers
each in its **Level Rationale**: *applies* or *does not apply*, with a reason. The declared
level must agree with the answers: a Standard feature answers *applies* to none, and a
Critical feature answers *applies* to at least one or states why it is Critical regardless.
A project may also name its **critical surfaces** — path globs — in `kit-adoption.json`
(`criticalSurfaces`); a Standard or Micro feature whose Territory reaches one is promoted,
narrowed, or carries an approved **Surface Exception**. `scripts/enforcement-pack.ps1`
grades both (constitution X, Level declaration). The rationale is a claim a reviewer can
falsify, not proof: the owner who writes *does not apply* is still trusted, and the written
claim is what makes the choice visible in review. A **Micro** feature owes no rationale (its
mini-spec has no such section) and is held only to the surface floor.

A Surface Exception is two lines in the feature's `spec.md`, and the second is its approval:

```text
**Surface Exception**: `path/in/territory` — reason
**Exception approved by**: <name>, <YYYY-MM-DD>
```

The approval is a recorded claim like any other (constitution I): an implementing agent does
not give it to itself, and a machine can check only that it is well formed.

<!-- digest: spec.md answers the four Critical triggers in a Level Rationale; a sub-Critical Territory on a declared surface fails. -->

## Additional requirements (all MUST)

1. **Rollback plan before implementation** — `specs/_templates/rollback-template.md` is
   filled for this feature **before phase 1 begins**, not at review time.
   **Why**: a rollback plan written after the change is a description, not a plan.

   <!-- digest: Critical 1: the rollback plan is filled before phase 1 begins, not at review time. -->

2. **Domain-invariant review** — the AI review and the human review each include an explicit
   pass over the domain-invariants pack (constitution V), item by item, recorded in the
   review document.
   **Why**: invariant violations are the one class of defect the gate cannot catch.

   <!-- digest: Critical 2: AI and human reviews each pass over the domain-invariants pack item by item, recorded. -->

3. **Audit evidence retained** — the gate command + exit code, the `scope-check.ps1`
   verdict and the `git diff --stat` output,
   and both completed review checklists are kept in the feature directory.
   **Why**: "we reviewed it" must be demonstrable later, not remembered.

   <!-- digest: Critical 3: audit evidence retained — gate command + exit code, scope-check verdict, diff stat, both review checklists. -->

4. **Human-executed gates only, one per phase** — the agent-run gate feedback loop
   (`docs/sdlc/gate-command.md`) does not apply, and neither does gate batching
   (constitution X, Batched gates), CI-held certification (constitution X, CI-held
   certification), nor the Micro lane (constitution X, Micro lane — a Critical feature is
   never a one-phase mini-spec feature): a Critical feature MUST NOT declare
   `**Gate Batching**` or `**Gate Certification**: ci-held` in its `plan.md`, nor
   `**Delivery Level**: Micro` at all — `scripts/enforcement-pack.ps1` fails the branch
   on any of these. Every phase's gate run that counts toward Done is executed
   by a human, locally.
   **Why**: for Critical work, even the fast-feedback loop stays on the human side of the
   trust boundary, and both gate frequency and gate *execution* are part of that boundary.

   <!-- digest: Critical 4: human-executed gates only, one per phase — never agent-run gates, batching, ci-held, or the Micro lane. -->

5. **Independent approval** — the human reviewer MUST NOT be the feature's owner
   (`docs/sdlc/team-workflow.md`). A solo developer substitutes:
   - a written **second-model adversarial review**, recorded as
     `specs/NNN-name/second-model-review.md`, structured like
     `specs/_templates/ai-code-review-template.md` but performed by a model different from
     the one that implemented the feature, explicitly instructed to probe for the
     implementer's likely blind spots (not to re-confirm its work); and
   - a minimum **24-hour cooling-off period** between that review being recorded and the
     feature being merged, during which the developer does not act further on the feature.

   **Honesty**: this substitute is a mitigation for the solo-developer case, not a claim of
   true independence — it does not provide the independence an external human reviewer would.
   **Why**: the person who drove the agent is the person least able to see its blind spots,
   and an undefined substitute ("some review, some time") is not falsifiable.

   **What the machine checks** (`scripts/enforcement-pack.ps1`, CriticalEvidence). The rule
   above has two arms and the check follows whichever one applies, choosing by the
   `developers` array in `kit-adoption.json`:

   - **Nothing declared, or one developer** → `second-model-review.md`, first committed at
     least 24 hours before merge. The substitute above, unchanged.
   - **Two or more developers** → `specs/NNN-name/human-pr-review.md`, **committed**, carrying
     a filled `## Review Provenance` block whose **Reviewer** is not its **Owner**, **is on the
     roster** (below), and is not a developer whose entry says `canApproveCritical: false`, plus
     the verbatim attestation, **and a review claim by that Reviewer** (below). No cooling-off. A Reviewer who is not on the roster fails naming
     the Reviewer and the names declared; a Reviewer whose entry does not permit it fails saying
     so.

   The count is taken after every entry that is neither a non-blank name nor an object with a usable `name`
   is dropped (a number, a blank, an object with no name) and duplicates are collapsed case-insensitively, so `["Ada","ada"]` is one developer, not two. An absent, empty, or
   otherwise unusable declaration selects the **solo arm**: a project that has never declared
   anything keeps the stricter requirement, forever. The doctor (`scripts/verify-kit.ps1`)
   reports a malformed declaration and states the mode it produces, because the fallback is
   otherwise silent. See **adoption/updating.md** for the shape.

   **The roster** (feature 021). Each entry of `developers` is a name, or an object
   `{ "name": "grace", "repos": ["api"], "canApproveCritical": false }`; the two may be mixed,
   and only `name` is required. A bare name is permitted to approve Critical, so a project that has
   only ever written names is not newly locked out; `canApproveCritical: false` (a value that
   is not a boolean is read as `false`, the safe direction for a permission) is how a record says a developer may not be the
   Reviewer of a Critical feature. `repos` is validated and recorded and graded by **no check**: its one reader
   is the advisory Fit note of `scripts/claim-feature.ps1` (`docs/sdlc/team-workflow.md`), which prints a line and
   never refuses a claim, because assigning developers to repositories is assignment authority, which the kit does
   not implement. Names compare after trimming, exactly and case-insensitively: a Reviewer written
   `Grace Hopper` does not match the entry `grace`, and the failure names both strings so the fix
   is visible.

   **The review claim** (feature 037). The Reviewer is not chosen by the owner: they take the review by pushing the ref
   `review/NNN-name/<slug>` with `scripts/claim-review.ps1` (`docs/sdlc/team-workflow.md`, "Who judges a Critical feature").
   After the conditions above hold, the check requires that claim: a Reviewer with none fails naming the command; a claim whose name
   slugs to the Owner's, or whose commit was authored under the Owner's name or email, does not count; a review nobody has pulled says so
   beside the missing review. A claim is a written claim: someone who can push to `origin` wrote a roster name. It does not show who they
   are, that the review happened or that it was independent, and the author test catches only the owner's own identity. A ledger or an
   author the check cannot read is `UNGRADED` with the cause, never a pass, so a Critical team feature can reach merge with that line on a
   CI that cannot read `origin`; gate 6, the human review, stands behind it. The solo arm never reads a claim.

   <!-- digest: Critical 5 (team): the Reviewer must have pulled the review; an owner's claim does not count. -->
   **Honesty about the team arm too**: it compares names written by the same team, in one
   file. That converts a silent omission into a written claim a reviewer can falsify —
   which is worth something, and is not the same as verifying that the review happened.
   Membership of the roster catches a stranger, a typo, a name the project did not declare and a
   person the record says may not judge; it does **not** prove the person is who the name says,
   and whether the review was independent is still the human reviewer's to judge. The
   cooling-off does not apply there because the period exists to give a solo developer
   distance from their own work, and a second person already is that distance. The solo arm is
   unchanged and never reads the human review.

   **When the check demands the artifact** (feature 024). The artifact is owed *at merge*, after the final phase
   (`docs/sdlc/definition-of-done.md`, item 6), so while a Critical branch is evidently **mid-feature** (by the heuristic below, which is evidence and not proof) the check does not
   fail it for the artifact's absence: it prints one `WARNING: CriticalEvidence: ... is not yet due` line naming the artifact
   and the phase that makes the branch merge-ready, and the run is not red for it. Mid-feature means all of: the committed
   `tasks.md` declares phase headings whose **distinct** numbers are exactly `1..N` (a heading such as
   `## Phase 1 amendment requests` repeats a number and is allowed; a gap is not); some commit subject carries a phase token
   (`phase k`, `phasek`, `phase ka`, `phases k`, case-insensitive, **anywhere** in the subject, so `tasks: phase 4 done` counts)
   with `k` below `N`; no commit subject carries a token naming phase `N` or beyond; and the active arm's artifact is **not yet
   committed**. Anything else behaves
   exactly as before: the final phase has landed, or the artifact is committed (the arm then grades it, mid-feature or not),
   or the check cannot establish mid-feature at all (no diff base, a shallow clone, `tasks.md` unreadable or with no phase
   heading or a gap or a number too large to read, no commit subject with a phase token yet), in which last group it prints a
   `not treated as mid-feature` line saying why. What an owner may therefore see: committing the artifact early puts it
   under the arm's grading from that commit on (the branch is red until the artifact is valid in team mode, or 24 hours old in solo
   mode, where the cooling-off clock starts at that commit, and passes once it is); an artifact
   left uncommitted mid-feature warns where it used to fail; and an unusable `kit-adoption.json` selects the solo arm, so a
   committed team-arm file does not end the pending state there. **A limit, stated rather than hidden:** a final commit whose
   subject is not read as naming the final phase (no phase word at all; a separator the pattern does not read such as
   `phase-3`, `phase: 3`, `phase #3` or `Phase III`; a list or range whose first number is lower, such as `phase 1 and 3`,
   `phases 2-3` or `phase 2/3`), on a branch with no artifact committed yet, still reads as mid-feature and stays on the
   `WARN`. What stands behind it is gate 6, the human review at merge, which a person holds, and the `WARN` is printed on
   every run. Name the final commit `phase N: ...`. **A second limit, measured on a real Critical feature:** phases that land
   out of order, or are never named, defeat the heuristic. "Final landed" is read as a token at or above the
   highest declared phase, so a feature that does a high-numbered phase early (FitForge's phase 11 ran before its phases 4 to 9)
   reads as final too soon and stays strict for that stretch, and a subject such as `declare phase 17` reads as phase 17 landed;
   a rule requiring every declared phase to be named would instead warn at the end, as that feature's phases 14 to 16 were never
   named. The first effect is in the safe direction (relief the feature does not get); the first limit above is the unsafe
   one (an unnamed final commit can get a `WARN` where it should fail), which is why gate 6 stays behind it.

   **An explicit declaration** (feature 025). A Critical feature's `plan.md` may carry one header line, `**Merge Readiness**: pending`
   or `**Merge Readiness**: ready`, read from the committed plan (a comment, a fenced block or a code span hides it). It is read
   **before** the heuristic above and needs no history, so the CriticalEvidence line is the same in a shallow clone (the run itself still exits 1 there, because the amendment check cannot grade a shallow clone), with no usable `tasks.md`, and when phases land
   out of order. `pending`: the check prints `WARNING: CriticalEvidence: <artifact> is not yet due - specs/NNN/plan.md declares
   **Merge Readiness**: pending (...)` and does not fail for the missing artifact, whatever the commit subjects say; an artifact that is
   already committed is still graded by its arm. `ready`: the arm grades the artifact exactly as for a merge-ready branch (so a missing
   one fails), which means "owed now", **not** "approved". Two marker lines, a value other than lower-case `pending` or `ready` (including
   `Pending`), or an empty value: strict, with the `not treated as mid-feature` line saying why. No marker, or one that is hidden: the
   heuristic above, byte for byte. A Standard, Lite or Micro feature ignores the line. On a branch the heuristic already reads as
   mid-feature, `pending` gives the same verdict (a warning, not a failure) with different warning text. Changing the line on an approved
   plan is an amendment: a commit with a single parent must carry `**Amendment approved by**: <name>, <YYYY-MM-DD>` and name the
   approver (constitution I). **Limits, stated rather than hidden:** `pending` is a claim. An owner who sets it and never flips it merges
   with only the warning on this check, and gate 6, the human review at merge, is what stands behind it. The approver is a recorded name,
   a written claim a reviewer can falsify and not proof of who approved. **A merge commit is graded for what it authored** (feature 026,
   which retires the earlier limit that the amendment check skipped merges): a `pending` added inside a merge is an amendment the merge
   wrote, and needs the same `**Amendment approved by**` line in the merged file and the approver named in the merge message, unless the
   merged result equals what a parent already had or what git's own automatic merge of the two parents makes (then the merge authored
   nothing and is skipped, counted as before). **What stays open:** a merge that keeps one parent's version of the plan whole is trusted
   on that parent's content, even when that content's only grading was a creation exemption, so taking the other side's plan in a
   conflict replaces it with no record (gate 6 stands behind it); an octopus merge, a git older than 2.38 or a failing `git merge-tree`
   is graded the strict way, where a record satisfies it; a document removed or renamed inside a merge is graded and no record can satisfy it
   (make the move in an ordinary commit); and the record is still a written claim.

   **A `pending` the tasks contradict** (feature 036). A plan that says `pending` while its committed `tasks.md` has at least one
   checkbox task (a `-`, `*` or `+` list item at any indent whose box is `[ ]`, `[x]` or `[X]`; a numbered `1. [ ]` item is not read) and **none unticked** is not read as a deferral: the check prints the
   `not treated as mid-feature` line with the reason (`declares **Merge Readiness**: pending but ... has all N of its tasks ticked`) and
   the arm demands the artifact exactly as for `ready`. The repair is the one the line names: set the plan to `ready` and supply the
   review, or untick the work that is not done. Adding the marker to an existing approved plan is the same amendment as above, with
   no exemption: `**Amendment approved by**: <name>, <YYYY-MM-DD>` in the plan and the approver named in the commit message. A plan with
   no marker still gets feature 024's heuristic; where that heuristic produced its message, the message now also says that the plan can
   state the answer with `**Merge Readiness**` (a plan with a marker, valid or not, gets no such suffix). **Limits, stated rather than
   hidden:** a tick is a proxy for "complete", and the rule only ever demands the artifact **earlier**, never later. An owner who never
   ticks, or whose `tasks.md` has no checkbox tasks (or whose tasks sit in a comment or a fenced block, which are not read), keeps
   `pending` as a claim and gate 6 stands behind it. A stray unterminated `<!--` hides every line after it, so ticked tasks above it can
   read as all the tasks there are. A box with text glued to it (`- [x]done`) is not a task.

   <!-- digest: Critical 5: a Merge Readiness pending beside a tasks.md with every task ticked is graded as ready. -->
   <!-- digest: Critical 5: ticks are a proxy; an unticked, absent or hidden task leaves Merge Readiness pending a claim. -->
   <!-- digest: Critical 5: the human reviewer is never the owner; solo devs substitute a second-model review + 24h cooling-off. -->
   <!-- digest: kit-adoption.json developers picks Critical 5's arm: none or one = solo substitute, 2+ = independent human review. -->
   <!-- digest: Critical 5 team arm: the Reviewer must be on the roster and permitted; membership catches a stranger, not identity. -->
   <!-- digest: Critical 5: the artifact is a WARN until the final phase lands, it is committed or the plan says ready; then FAIL. -->
   <!-- digest: Critical 5: when mid-feature cannot be shown (no base, shallow clone, bad tasks.md) the check stays strict and says why. -->
   <!-- digest: Critical 5: plan.md may declare Merge Readiness pending or ready, overriding the heuristic; no history needed. -->
   <!-- digest: Critical 5: Merge Readiness pending is a claim, not proof; changing it is an amendment, also inside a merge. -->
   <!-- digest: Critical 5: a merge is graded for what it authored; taking one parent's plan whole is trusted on that parent. -->

## What this addendum is NOT

It adds no new gates, documents, or workflow steps beyond the five items above. Do not
invent extra ceremony for Critical features — the protection comes from evidence and
independence, not volume.

<!-- digest: Critical adds nothing beyond the five items — protection comes from evidence and independence, not volume. -->
