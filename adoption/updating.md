# Updating an Adopted Project

The kit changes after you adopt it. This page is the flow-down channel: how to pull
those changes into your project without losing anything you filled in yourself.

## 1. Run the update

From a clone of the kit (not from your project):

```powershell
pwsh -File scripts/update-kit.ps1 -Target <path to your project root>
```

`-Target` is required — the script never defaults to updating itself. Add `-DryRun`
first if you want to see the report with zero writes, and re-run without it once you're
ready to apply. The script refuses to run (exit 1) against a dirty working tree, a
partial kit install, or the kit repository itself — commit or stash first if it stops you
there.

<!-- digest: update-kit.ps1 runs from a kit clone with -Target: verbatim files copied, surgical only reported, never written. -->

**Reading the report:**

| Section | What it means |
|---|---|
| Applied | Verbatim kit files it copied — pure kit prose/scripts, nothing project-specific in them. Safe to accept as-is. |
| Surgical | Files that changed upstream but were never touched — see step 2/3 below. This report is delivered **once**, at the update that carries it: handle it in the same session. |
| Conflicts | A verbatim file your project has locally modified. Not overwritten. |
| Result | The kit version now recorded, or "up to date" if nothing was pending. |
| (never listed) | `generated`-class paths — `docs/digests/*-digest.md` — are neither copied nor reported: each project generates its own digests from its **own** law with `scripts/build-digests.ps1` (the generator and `docs/digests/digest-packs.json` arrive verbatim). |
| Adoption doctor | An apply run ends with `scripts/verify-kit.ps1`'s verdict for your project — flow-down damage surfaces in the same session that caused it. A red verdict exits 2 ("attention needed"); get the doctor green before committing the flow-down. `-DryRun` skips it; `-Json` callers run `verify-kit.ps1 -Json -Root <project>` themselves. |

<!-- digest: generated-class paths (docs/digests/*-digest.md) never flow down — each project generates digests from its own law. -->

**Resolving a conflict**: a verbatim file only conflicts when someone edited kit-owned
prose or a kit script directly, which normally shouldn't happen — verbatim files exist to
be replaced wholesale. Review the diff; if the local edit was a mistake, re-run with
`-Force <path>` to take the kit version. If the edit was deliberate, keep it and leave the
file conflicted (it'll keep being reported) or move the customization to a project-owned
file instead.

**The surgical report is delivered once**: every apply advances the recorded kit commit
in `.kit-version` to the kit HEAD it ran against, so the next run reports only what is
new since — a surgical backlog is never re-listed. Handle the report in the session that
produced it (steps 2–3 below). A past report is always recoverable: the old recorded
commit is in the superseded `.kit-version` (visible in your flow-down commit's diff), and
`git log <old>..<new>` in the kit clone re-derives exactly what that update named.

<!-- digest: The surgical report is delivered once — handle it in the session that produced it; the record advances to kit HEAD. -->

**Commit the run**: the update never commits for you. Review `git status`, commit the
applied files and the updated `.kit-version` together, exactly like any other governance
change.

**Idempotence**: running the update again immediately after a clean apply reports "up to
date" and changes nothing — a good way to confirm you're current. This holds after a
surgical-bearing apply too: the record advanced with the apply, so the re-run has nothing
new to report (unresolved verbatim conflicts are the one exception — they are re-detected
from file content every run until resolved).

## 2. When the surgical report names the constitution

The constitution is the one surgical file every amendment eventually touches, and it
needs its own procedure because your project's constitution is not a copy of the kit's —
it is *your own document*, ratified under *your own* version number, that happens to have
been founded on the kit's principles.

An amendment never gets copied in. It gets **re-expressed**:

<!-- digest: Constitution amendments are re-expressed, never copied: your own version bump, your own SYNC IMPACT, citation sweep. -->

1. **Read the kit's rationale.** The commits the report names are the amendment log (the
   kit has no separate changelog) — read what changed and why before touching anything.
2. **Bump your own version, not the kit's.** Your constitution's version footer is your
   project's semver history, independent of the kit's. A principle added or materially
   expanded is a MINOR bump for you; a principle removed or redefined is MAJOR; wording
   only is PATCH — the same policy the kit itself uses, applied to your own number.
3. **Write your own SYNC IMPACT entry.** State what changed in *your* constitution:
   which principle, what the old and new text said, and which of your own dependent
   templates and docs it touches. Do not paste the kit's SYNC IMPACT entry — it describes
   the kit's history, not yours.
4. **Verify demoted content lands before you delete anything.** If the amendment demotes
   a principle out of constitutional law (into a rulebook, a standards doc, or a template),
   confirm the target file in *your* project actually carries the demoted content — filled
   in for your stack, not left as a slot — before removing the principle from your
   constitution. A demotion with nowhere to land is a silent loss of a rule, not a
   simplification.

   <!-- digest: Verify demoted content lands in your project before deleting the principle — nowhere to land means a rule is lost. -->

5. **Sweep citations.** Grep your own governance docs for the old principle number or
   name (renumbering is common when principles are added, demoted, or deleted) and fix
   every reference — CLAUDE.md, plan/spec/task templates, rulebooks, anything that cites
   the constitution by number.
6. **Human approval adopts it.** Same rule as any other constitutional change: a person
   reviews and approves before the amendment counts as adopted in your project. The
   update script only delivers the report; it never amends your constitution for you.

   <!-- digest: Human approval adopts an amendment — the update script only delivers the report, never amends your constitution. -->

### Worked example: the 2026-09-01 kit 0.3.0 → 0.4.0 flow-back

Two sample adoptions carried out this exact procedure the same day the kit shipped a
batched-gates amendment (kit constitution 0.3.0 → 0.4.0, itself built on an earlier
0.2.0 → 0.3.0 amendment that had demoted two principles and deleted a third). Neither
project copied the kit's version string or its SYNC IMPACT text:

- Each project's **own** constitution moved **1.0.0 → 2.0.0** — a MAJOR bump, because
  from that project's point of view principles were being removed and renumbered, which
  is backward-incompatible for anything citing them by number. The kit's own version
  number (0.3.0 → 0.4.0) never appeared in either project's constitution.
- Each project wrote its **own** SYNC IMPACT entry, in its own words, listing what its
  13 principles becoming 10 meant for that project specifically.
- **Demoted-content verification**: the Data Standards and Auditability principles were
  being demoted out of constitutional law. Before either project deleted them from its
  constitution, its `database-rules.md` rulebook was confirmed to already carry that
  content in project-specific, filled-in form — not a bare template slot. Only then did
  the principle text come out of the constitution.
- **Citation sweep**: both projects grepped their own docs for the old principle numbers
  and fixed every reference — CLAUDE.md's Task-Scoped Reading table, rulebook headers,
  and plan/spec templates that cited principles by number.
- Everything non-constitutional flowed down as ordinary verbatim/surgical updates in the
  same pass: the flow ritual page, the claim/territory/enforcement scripts and their CI
  workflow, and the kit's own templates.
- **Human approval**: each project owner reviewed the resulting diff and merged it as a
  normal governance change before the amendment counted as adopted.

### Flow-down note: the 2026-09-08 CI-held certification amendment (kit 0.4.1 → 0.5.0)

The kit's constitution X gained a CI-held certification clause: a Lite/Standard feature's
approved plan MAY declare `**Gate Certification**: ci-held`, making certification the
owner's recorded approval on the CI evidence triplet (run URL + green conclusion + exact
phase-commit sha) instead of a live user-run gate. Like every amendment, it arrives here
by **re-expression** (this section's procedure), never by copy:

- Adopting it is a **MINOR bump of your own version** — a principle materially expanded.
  What you adopt is the clause's six boundaries (Lite/Standard only; declared before the
  first phase it governs; approval on the triplet; agent obligations unchanged; Critical
  excluded; absent = `user-run`) plus its mirrors in your own DoD, gate-command,
  critical-delivery, plan template, and CLAUDE.md.
- **Nothing changes until you ratify it.** The user-run gate remains your project's law —
  and stays lawful for every feature even after adoption; ci-held is an opt-in per
  feature, per plan, never a default.

### Flow-down note: the 2026-09-09 Micro-lane amendment (kit 0.5.0 → 0.6.0)

The kit's constitution gained a fourth delivery level — **Lite < Micro < Standard <
Critical** (Principles I and X): a numbered feature MAY be declared Micro, delivered from
a single-page mini-spec (`spec.md` only, no plan.md/tasks.md) in exactly one phase inside
hard machine-checked bounds (at most 5 territory files and 400 changed lines), with every
verification layer unchanged and in-place promotion to Standard when the work outgrows a
bound; CI-held eligibility widened to Lite/Micro/Standard. Like every amendment, it
arrives by **re-expression** (this section's procedure), never by copy:

- Adopting it is a **MINOR bump of your own version**. What you adopt: Principle I's
  Micro arm, Principle X's Micro-lane clause (one phase; both bound constants; the
  eligibility checklist; promotion in place; Critical excluded; absent declaration =
  Standard) and the widened CI-held eligibility, plus its mirrors in your own DoD,
  gate-command, branch-strategy, critical-delivery, spec template, and CLAUDE.md.
- The **machine half and the template arrive verbatim** through the normal update
  channel: `scripts/scope-check.ps1`, `scripts/enforcement-pack.ps1`, and
  `.specify/templates/micro-spec-template.md`. The Micro checks are inert until a
  feature's `spec.md` declares `**Delivery Level**: Micro`, so taking the scripts before
  (or without) ratifying the amendment leaves your existing features' verdicts unchanged —
  with one general hardening that rides along: scope-check now also FAILs a commit that
  deletes or renames away a feature's `spec.md` or `tasks.md` on any numbered branch
  (never a legitimate move; previously only tasks.md deletion was guarded).
- **Nothing changes until you ratify it.** Absent a declaration, every numbered feature
  is Standard — exactly as before.

### Flow-down note: the 2026-09-09 law digests (kit feature 010 — no constitution amendment)

The kit grew a per-pack law-digest machine: curated one-line markers beside binding rules,
a deterministic generator, and a CI freshness check. **No constitutional change is
involved** (the kit's constitution stayed 0.6.0) — there is nothing to re-express; this
note is the whole adoption story:

- **What arrives verbatim**: `scripts/build-digests.ps1` (generator + `-Check`),
  `docs/digests/digest-packs.json` (pack composition), and the updated
  `scripts/ritual-checks.ps1` with its `digests` member.
- **What never arrives**: the kit's own `docs/digests/*-digest.md` files — they are
  `generated`-class (neither copied nor reported; see the report table in step 1). A
  digest summarizes the law of the repository it lives in, so each project generates its
  own.
- **The flow-down includes generating your digests.** The kit's verbatim pack documents
  (DoD, flow, branch-strategy, team-workflow, critical-delivery, and this file) now carry
  digest markers, and the update copies them in — so the moment the marked law lands, the
  `digests` member demands the digests it produces. Run
  `pwsh -File scripts/build-digests.ps1` and **commit the generated digests together with
  the update**; skipping the step fails ritual-checks loudly, naming exactly those digest
  files and that command — never silently. The `n/a (no digest markers)` inert state
  belongs only to a tree with no markers anywhere (a pre-010 copy adoption that never
  updates, or a project that deletes the markers — they are ordinary comment lines in
  your law, yours to keep or remove).
- **Marking your own law (optional)**: add markers beside the binding rules of your own
  documents — gate-command, review-process, rollback-process, and repository-strategy are
  your surgical copies, so markers there summarize *your* filled-in law — then
  regenerate:

  ```markdown
  <!-- digest: <one-line rule statement, at most 120 chars> -->
  ```

  A marker counts only as a standalone line, in exact lowercase grammar, outside HTML
  comment blocks and code fences (this example is safely inside one); a near-miss line
  fails the check rather than vanishing. Bounds: at most 40 lines per pack digest,
  120 chars per one-liner. CI fails on any drift between a rule and its digest —
  regenerate with `pwsh -File scripts/build-digests.ps1`.
- **Mirror by hand (surgical)**: the CLAUDE.md Task-Scoped Reading "Orientation first"
  paragraph — the pointer that sends agents to a pack's digest before the full read —
  is surgical-class; copy the kit's wording into your own CLAUDE.md, as with the 008/009
  mirrors above. Without it your digests exist but nothing points agents at them.
- **Digests are orientation only**: never a source-of-truth rung, never a substitute for
  reading the full document before acting on its area (each digest's header says so).

### Flow-down note: the 2026-09-09 roadmap-claim check (kit feature 011 — no constitution amendment)

The kit's `ritual-checks` grew a sixth member, `roadmap-claims`: every `NNN-*` feature branch
visible on `origin` must have a `docs/roadmap.md` row, in a table with a Status column, whose
Status is not `idea`. **No constitutional change is involved** (the kit's constitution stayed
0.6.0) — there is nothing to re-express; this note is the whole adoption story:

- **What arrives verbatim**: `scripts/roadmap-claim-check.ps1` (new), the updated
  `scripts/ritual-checks.ps1` that runs it, and `scripts/claim-feature.ps1`, which now
  prints the flip reminder after a successful claim.
- **What it enforces**: the second half of the claim ritual — when you claim `NNN-name`,
  flip that feature's roadmap row in a main-side `docs/` commit in the same sitting
  (`docs/sdlc/branch-strategy.md`, Number Allocation). A claim whose row still reads `idea`
  tells the next agent the work is unstarted and invites a duplicate spec; the field
  incident this closes ran 13 days that way.
- **It can turn your CI red on the first run, by design.** The check reads the branches
  actually on your remote, so a *stale* `NNN-*` branch still sitting there — merged long
  ago, or abandoned — needs its row to read `shipped`/`dropped`, or the branch deleted.
  That sweep is the point: a lingering claim with a stale row is the same lie.
- **Three inert states, all exit 0 and reported as `n/a`, never failed**: no `origin`
  remote, a remote it cannot reach, and a `docs/roadmap.md` with no Status-bearing table.
  `docs/roadmap.md` never flows down, so a project whose ledger is shaped differently from
  the kit's is left alone rather than forced into the kit's table.
- **The branch's own number is exempt**, so a fresh claim can commit its mini-spec before
  the row exists without deadlocking itself; every *other* visible claim still has to have
  a row for the branch to go green.

### Flow-down note: the 2026-09-09 cross-repo scope check (kit feature 012 — no constitution amendment)

Machine gate 4 reaches the nested code repositories. **No constitutional change is involved**
(the kit's constitution stayed 0.6.0); this note is the whole adoption story, and it matters
most to projects in the nested multi-repo layout — until now, every phase commit containing
code was outside the scope check's reach (GAP-016).

- **What arrives verbatim**: `scripts/scope-lib.ps1` (new — the parsing/matching helpers, now
  shared), `scripts/scope-check-repos.ps1` (new — the cross-repo grader),
  `scripts/scope-check.ps1` (unchanged behavior, now dot-sourcing the library),
  `scripts/ritual-checks.ps1` (new `scope-repos` member), `scripts/init-kit.ps1` and
  `scripts/verify-kit.ps1` (the `codeRepos` field), and
  `.github/workflows/code-repo-scope-check.yml.template` (surgical — you copy it).
- **It is inert until you declare something.** With no `codeRepos` in `kit-adoption.json`, the
  member reports `n/a` and your CI verdict is unchanged. A single-repo project never declares
  it and is unaffected.
- **What a multi-repo project does**: add `codeRepos` to the record (§4), write this feature's
  **Territory** entries repo-prefixed from the governance root
  (`` `your-api/src/**` ``), and copy the code-repo workflow template into each code repository,
  filling its governance-repository and directory slots. The doctor WARNs until the field is
  there — absent and empty count the same.
- **Two rules that bite immediately**: the code repository must carry the same `NNN-name`
  branch as the governance repository (the Cross-Repository Feature Rule), and the territory
  must be declared **before** the code is committed — a declaration that post-dates a code
  phase commit FAILs it, which is the same anti-retroactivity rule the in-repo check has
  always applied to its own commits.
- **Reading a code-repo CI run**: PASS or FAIL means it graded. A run showing only WARN or
  `n/a` graded nothing — a mismatched directory name, a missing branch, or a code repository
  whose trunk is not `main` (run `scope-check-repos.ps1 -All -Repo <repo> -BaseRef <trunk>`; from kit
  feature 022 the no-trunk line prints that command). Do not accept that as a green gate.

### Flow-down note: the 2026-09-16 amendment authority (kit 0.6.0 → 0.7.0, feature 014)

Principle I gains an **Amendment authority** clause, and `scripts/enforcement-pack.ps1` gains
the check that grades it. The rule: once a feature's `spec.md` or `plan.md` has been approved,
a later change to that feature's `spec.md`, `plan.md`, `tasks.md` or `contracts/` must record
who approved it, and **an implementing agent must not approve its own amendment**. It closes
GAP-019 — until now an agent could widen its own Territory and pass the scope check by
construction, because the check reads the Territory that same agent just wrote.

- **What the update writes for you (verbatim)**: `scripts/enforcement-pack.ps1` (the new
  `Invoke-AmendmentAuthorityCheck`), `.specify/templates/tasks-template.md`,
  `docs/sdlc/definition-of-done.md` (gates 5 and 6), `docs/sdlc/branch-strategy.md`, and both
  review templates — `specs/_templates/ai-code-review-template.md` and
  `specs/_templates/human-pr-review-template.md`, which is what makes your reviewers see
  amendments at all.
- **What you mirror by hand (surgical — the update reports these, it never writes them)**:
  `CLAUDE.md` (the Strict Rules bullet: you never approve your own amendment),
  `docs/sdlc/review-process.md` (the human-reviewer check — whether the named approver really
  agreed) and `docs/sdlc/repository-strategy.md` (the multi-repo twin of the clause). Skip these
  and you get the machine while your agent instructions and your review checklist never mention
  the rule — live and unenforced, which `spec.md` US4 calls the worst state in the kit.
  `.specify/memory/constitution.md` is surgical too, and is yours: §2 reports it, nothing
  writes it.
- **Ratify the clause first.** The kit shipped the law one phase before the machine
  deliberately: a kit must not enforce a rule it has not ratified. Do the same — adopt the
  Principle I wording into your constitution as its own reviewed change, then let the check
  arrive. The wording is itself adopted from an adopting project's ratified text (FitForge
  constitution 1.1.0), so a project already carrying that clause reconciles rather than
  collides.
- **If you already carry that clause, one paragraph of it stops being true.** The field
  wording closes with an "Enforcement, honestly stated" paragraph saying the rule is enforced
  by review and not by machine, because the check was owed to the kit and did not yet exist.
  It exists now. Delete or rewrite that paragraph when the check arrives, and keep the
  honesty it was written for by replacing it with what the check does *not* verify (below) —
  otherwise your constitution understates your own enforcement, which is the same defect as
  overstating it. **This is an edit in your repository, by you, under your own ritual**: the
  kit never writes your constitution, and an update only reports it (§2).

**What the check grades.** On an `NNN-*` branch, every non-merge commit in the branch's range,
and within each commit only the paths `specs/NNN-name/spec.md`, `plan.md`, `tasks.md` and
`contracts/*`. Nothing else in your repository is in scope — `notes.md`, `research.md`,
`screenshots/`, and every file outside the feature directory are ungraded, which is why
recording evidence never costs an approval.

- A document's **first appearance is creation**, not amendment, and owes no record. This kit
  has no approval token, so existence is the proxy for approval (stated plainly in the clause).
  A branch renumbered by a lost claim race is creation too: the whole `specs/NNN-name`
  directory moves, `claim-feature.ps1` mandates the header edits that ride along, and the check
  skips a rename whose old path was in a different feature directory (FR-010). It is the one
  exempted case where a document's text did change — the alternative was a state with no legal
  path to green.
- Every later change to the document's **text** is an amendment. The test is the text, never
  the intent: re-wording, re-scoping or annotating a task is an amendment even when the work
  itself was already agreed.
- **Two exemptions, both narrow.** A `tasks.md` change that alters nothing but checkbox state
  — `- [ ]` to `- [x]` or back — is progress, not amendment. Un-ticking counts too. But
  rewriting a task's text *while* ticking it is an amendment: record what was done in
  `notes.md` and leave the task saying what was agreed.
- And the **approval transition itself**, on `spec.md` or `plan.md`: `**Status**: Draft`
  becoming `**Status**: Approved` is the act that starts the rule, not a change to an approved
  document, so it owes no record.
  The kit's own spec templates mandate that edit; a rule that charged an approver record for
  obeying the template would be charging for the approval. It is exempt only in that exact
  shape — exactly one line differs in the whole file, it is the document's **first**
  `**Status**:` line and not one inside a fenced block, the old value is `Draft`, and the new
  value is `Approved` plus at most a date, an `(owner: …)` parenthetical and the template's
  trailing comment. Anything riding along on that line, a second status line rewritten beside
  it, or `Approved` going back to `Draft`, is an amendment like any other. A `tasks.md` status
  line is not exempt — no kit template gives it one.

**A conforming record** is two halves, and the check wants both:

```text
**Amendment approved by**: anas.m, 2026-09-13
```

in the amended section of the document itself — not in `notes.md`, not inside an HTML comment —
**and** the same approver named in the amendment commit's message. The message is the half a
later edit cannot fake, which is the whole reason it is asked for. Two failures you may meet:

```text
AmendmentAuthority: commit a1b2c3d amends specs/014-amendment-authority/plan.md after
approval with no conforming approver record. Add '**Amendment approved by**: <name>,
<YYYY-MM-DD>' to the amended section and name the same approver in the commit message
(constitution I, Amendment authority). Ticking a task off is exempt …

AmendmentAuthority: commit a1b2c3d records 'anas.m' as the approver of its change to
specs/014-amendment-authority/plan.md, but its commit message does not name them — the
message is fixed at commit time and is the half a later edit cannot fake
(constitution I; plan D5)
```

"Not inside a comment" means what a Markdown renderer means by it, and the check reads your
documents the way a renderer does. A comment opener quoted in backticks, or sitting inside a
fenced block, is literal text that hides nothing; an escaped backtick opens no code span; and
an unterminated opener hides everything after it to the end of the file, because that is what
a reader would see:

```text
**Amendment approved by**: anas.m, 2026-09-13    <- counts

The syntax is `<!--`.                            <- prose. The record below still counts.
**Amendment approved by**: anas.m, 2026-09-13

<!-- **Amendment approved by**: anas.m, 2026-09-13 -->   <- hidden. Does not count.

<!-- a note someone forgot to close
**Amendment approved by**: anas.m, 2026-09-13    <- hidden too, and so is the rest of the file
```

So a graded document may freely *discuss* comment syntax and still carry a visible record. The
`<-` notes above are margin annotations, not part of the lines: a real record line ends at the
date, and anything appended to it — including a note like those — defeats the pattern and is no
record at all. The kit learned this the hard way:
 a `tasks.md` task describing this very check quoted a comment
opener in backticks, an earlier implementation read it as a real one, and every approver record
below that line went invisible — the rule was briefly impossible to comply with in any document
that mentioned it. If a record you can see is reported missing, look upward for an opener that
was never closed; that is the one case where the renderer hides it from a human too.

<!-- digest: The amendment check grades spec.md, plan.md, tasks.md and contracts/ only; a checkbox flip is progress. -->
<!-- digest: Approving a document is not amending it: a lone Draft-to-Approved status flip owes no approver record. -->

**What it does not verify, stated honestly.** It grades that a record exists, is well-formed,
and names the same approver as its commit. Three things it cannot do. It cannot verify that the
named person agreed — on a solo project the approver is the same human who drove the session.
It does **not** enforce the self-approval prohibition: the kit records no link between a commit
and the session that produced its diff, so **that half of the rule is held by review alone**.
And it does not observe approval itself. What you gain is that an amendment is now visible in
the diff and gradeable — not that consent is proven. A determined implementer can still write a
name. The record has the strength of the Reviewer Provenance block, not of an authentication;
treat it as a written claim a reviewer can falsify, and falsify it at gate 5 and gate 6.

**Arrival day is silent — the boundary.** A commit is graded only if
`Invoke-AmendmentAuthorityCheck` existed in the repository **before that commit was made**.
Nothing you committed before the update that delivers the check is graded, here or in any
adopted project. No in-flight branch turns red on arrival; the first commit the rule can fail
is one you make afterwards, knowing it applies.

One exception, worth checking *before* you update rather than after: if your CI clones
shallowly, the check fails on the first `NNN-*` branch it sees, because it will not guess at a
boundary it cannot compute. That is a verdict on the checkout, not on your history — set
`fetch-depth: 0` (below) and arrival day is silent as described.

The boundary is not a courtesy, and it is worth understanding rather than just relying on.
Half of every record lives in the commit message, and a commit message is immutable. A
retroactive rule would therefore be one **no adopter could comply with** — the only remedy
would be rewriting published history. A rule whose commonest remedy is impossible is a rule
people route around, so it binds forward only. The stated cost: between ratifying the clause
and the check landing, the rule is law and ungraded. Keep that window to one phase, as the kit
did on its own branch.

**Give CI the whole history.** The boundary is computed by reading each commit's own tree, so
the check needs real objects to read. In a shallow clone — `actions/checkout` defaults to
depth 1 — those objects are not there, and a check that grades nothing would look
exactly like a branch that is legitimately pre-boundary: green, and meaningless. So on an
`NNN-*` branch the check refuses to guess. It fails, and names the condition it met: a shallow
clone, an integration branch it cannot diff against — absent, or present but sharing no
commit with your branch — or a parent commit this clone cannot read. A
Lite branch (`fix/`, `chore/`, `docs/`) is unaffected — the check returns before it consults
history at all. **From kit feature 015 that sentence needs one word added**: a Lite branch with
no diff base is unaffected in its EXIT CODE and no longer in its verdict. The prohibited-category
and file-count guards graded an empty file list, which passed for the same reason an empty
accusation is never proved, and the run said `OK`; it now says `UNGRADED`, exits 0 exactly as
before, and names what was not compared. See the 015 flow-down note below. The kit's `.github/workflows/ritual-checks.yml` ships with `fetch-depth: 0`;
if you wrote your own workflow, or fetch shallowly on a build agent, set it there too. That is
still the fix. What it buys you is a red build instead of a green one that graded nothing.

<!-- digest: The amendment check binds forward only — nothing committed before it arrived is graded. -->
<!-- digest: The amendment check needs full history — fetch-depth 0 in CI, or it fails naming the shallow clone. -->

### Flow-down note: the 2026-09-21 verdict vocabulary and the ungraded state (kit feature 015 — no constitution amendment)

**What a green run meant before.** `ritual-checks.ps1` printed `OK` against a member in two
quite different situations: the member compared what it claims to compare and found nothing,
**or** the member ran and compared nothing at all. A depth-1 clone with no reachable base, a
commit range with no commits in it, a trunk not named `main`, a branch every one of whose commits was
skipped — each of those produced the same word as a clean grading. A run that graded nothing
was indistinguishable from a run that graded everything and liked it. That was recorded as
GAP-027 and it is what feature 015 closes.

**What a green run means now.** `OK` means the member formed an opinion and the opinion is
clean. A member that ran and formed **no** opinion says `UNGRADED`, and the run ends on
`ritual-checks: RESULT UNGRADED (N of M member(s) formed no opinion; nothing failed)`.

**What you will newly see.** Three things, and none of them is a new failure:

1. **`UNGRADED` where you used to see `OK`.** The table under "What to do about it" lists
   the common states. Several of them occur with full history, on a perfectly healthy
   repository, because there is genuinely nothing to grade yet.
2. **`n/a` where you used to see `OK`.** The two scope checks already declined on the trunk, on
   a `fix|chore|docs` branch and on an unnumbered branch, but they spelled it `not applicable`
   — and the wrapper lifts `n/a`, so those correct declines were rendered as `OK`. Measured on
   an adopted project, a trunk run moves two member lines from `OK` to
   `n/a ('main' is the trunk)`. `RESULT OK` and exit 0 are unchanged.
3. **A verdict line from `doc-lint`.** It used to exit 1 having printed `ERROR:` blocks and no
   verdict word at all. It now ends on `doc-lint: FAIL (N issue(s) — see the ERROR block(s)
   above)`.

**What does NOT change.** Exit codes — every one of them, on every member, in both
directions. `UNGRADED` is a verdict change and never an exit-code change (015 plan D6, FR-011),
so no branch protection, badge, or `if: failure()` step behaves differently. Member names are
unchanged, `ritual-checks.ps1` remains the single entry point, and the Lite lane gains no new
hard failure.

**What to do about it.** Nothing, mechanically. But an `UNGRADED` member is worth reading,
because it is telling you that a check you believe is protecting you did not run against
anything. **The authority on why is the member's own output, not this table:** every
`UNGRADED` line either names its reason or points at the line above it that does. The table
is a guide to the states you are most likely to meet. It is not a complete list, and when a
line you see is not in it, the line is right and the table is short.

| State | Member and what it prints | Full history fixes it? | What to do |
|---|---|---|---|
| Detached `HEAD` and no `-Branch` passed | `scope-check` and `scope-repos`: `UNGRADED detached HEAD — pass -Branch …` | No | Pass `-Branch <NNN-name>` (a CI wrapper on a `pull_request` checkout must). |
| No merge base with `main` / `origin/main` | `scope-check -All`: `could not resolve a merge base with main`; `enforcement-pack`: a `WARNING` naming no integration branch, and `UNGRADED:` lines — ReviewProvenance and PhaseSizeWarning on `NNN-*` (plus MicroLane on a feature declared Micro); LiteAndAbuse and ReviewProvenance on `fix/` and `chore/`; ReviewProvenance on `docs/` | **Only if the cause is a shallow clone** | Shallow clone: `fetch-depth: 0` on `actions/checkout`, and the word becomes a real verdict. A trunk not named `main`: no fetch setting helps, and these members take no parameter naming the trunk — they look for `main` and `origin/main` only. Name the trunk `main` (`docs/sdlc/branch-strategy.md`), or create a `main` ref at it before the run (for example `git branch main origin/develop`). On an `NNN-*` branch the amendment check FAILS here rather than going quiet, so that run is `FAIL`, not `UNGRADED`. |
| An `NNN-*` branch with no commits since the merge base — just created, or already merged | `scope-check -All`: `no commits since merge base`; `enforcement-pack`: `AmendmentAuthority: no commits in …` | No | Nothing: there is nothing to grade. The amendment line goes with the branch's first commit; `scope-check`'s goes with its first graded phase commit (next row). |
| An `NNN-*` branch whose commits are all skipped: spec/plan/tasks commits with no `phase N` token, merge commits, or phase commits graded only by a pre-006 `WARN` (a `tasks.md` that declares no Territory at all, or no `tasks.md` at the commit or its parent) | `scope-check -All`: `no commit on '<branch>' was graded — the reason is on the line(s) above` | No | Every feature branch is here until phase 1 is committed; the word goes with the first phase commit graded against a declared Territory. A pre-006 history stays here until it declares one. |
| `scope-check` **without** `-All` (the form run by hand after a phase commit) on a HEAD that is not a phase commit | `scope-check`: `no commit on '<branch>' was graded …`, even when earlier phase commits on the branch pass | No | Without `-All` the check grades HEAD only. Run it right after the phase commit, or pass `-All` (what `ritual-checks` and CI run) to grade every phase commit on the branch. |
| Multi-repo: nothing graded in any declared code repository | `scope-repos`: `UNGRADED (nothing was graded in the declared code repositories …)`, after one line per repository naming why — not present in this checkout (every governance-repository CI run), present but not a git repository, not a repository of its own, no branch named after the **feature** there, no trunk found, no commits, or no phase commits | No, except a shallow code-repository clone | Governance CI, and a feature that has no branch in any code repository: expected — each code repository's own CI grades it, and the review says so in writing (`docs/sdlc/review-process.md`, step 3). A code repository whose trunk is not `main`/`master`: run `scope-check-repos.ps1 -All -Repo <repo> -BaseRef <trunk>` directly, since `ritual-checks` does not pass `-BaseRef` through (from kit feature 022 the no-trunk line prints exactly that command). Both of the other flags matter: without `-All` the script ignores `-BaseRef`, and without `-Repo` it applies that one trunk name to every declared repository. |
| Multi-repo: one code repository graded, another not | `scope-repos`: the ungraded repository's own line (`<repo>: UNGRADED …`, or, when every commit it offers was skipped, `not applicable` or `WARN` lines), **and, from kit feature 022 under `-All`, a run-level `UNGRADED (… declared code repository applied to '<feature>' and graded nothing: <names> …; graded: <names>)`** that `ritual-checks` lifts, so the member says `UNGRADED` and not `OK` (before 022 the summary printed nothing here and the member said `OK`). Without `-All` (the per-phase tip command) the run-level verdict is as it was, and the per-repository lines are still where to read it | Depends on the repository's reason | The repository's reason and the fix are on its own line. See the 022 flow-down note below. |

The code-repository check asks whether a repository has a branch named after the **feature**,
not whether the current phase touched it. So a docs-only phase that follows a code phase shows
the earlier phase's `PASS` for that repository. That `PASS` is real, but it grades the earlier
phase.

<!-- digest: A green ritual-checks run now means the members formed an opinion - UNGRADED says one did not. -->
<!-- digest: UNGRADED changes the verdict and never the exit code; nothing in CI behaves differently. -->

### Flow-down note: the 2026-10-03 multi-line code spans and the skipped-marker report (kit feature 016 — no constitution amendment)

**What changes.** Four files flow down verbatim: three scripts, `scripts/markdown-lib.ps1`,
`scripts/build-digests.ps1` and `scripts/enforcement-pack.ps1`, and this document, which
carries this note. No law document, template or surgical file changes, so there is nothing to
mirror by hand.

1. **A span wrapping within a paragraph now hides nothing.** The shared reader used to treat
   a code span as ending at the line it began on. A `<!--` inside a span that wraps onto the
   next line therefore opened a comment the reader never closed, and every digest marker after
   it was silently dropped. A renderer shows that span as code. The generator now agrees: the
   marker is harvested. The fix applies to digest generation only; the amendment check keeps
   its per-line reading.
2. **A skipped digest marker now fails the run (DIGEST-020).** If a line shaped like a digest
   marker sits inside a comment opened earlier in the file, `build-digests.ps1` prints
   `skipped digest marker: <path>:<line>` and exits 1. Before, the loss was silent. The
   message is distinct from the malformed-marker one. **The remedy** is one of two edits in
   your own document: delete a marker that was commented out on purpose, or close the comment
   above it.
3. **One disagreement is reported, not fixed.** An unpaired `<!--` in prose still opens a
   comment in the kit's reading, where a renderer shows plain text. The kit does not change how
   it reads that shape, because the amendment check relies on it. What changed is that the
   resulting loss of a marker on its own line is no longer silent: it is item 2. A marker
   after a `-->` on the same line is not a standalone marker and is still not reported.

**What was measured (SC-005, FR-011).** The update was dry-run against FitForge, FlowBoard and
ExpenseTracker: no surgical file and no conflict. In a scratch copy of each with the **three
scripts** applied, the digests were regenerated and `ritual-checks.ps1` run. **Every digest is
byte-identical to the one committed, and every verdict is unchanged** (`RESULT OK` before and
after). The skipped-marker report found zero hits in the kit and in all three projects. So the
scripts change nothing you see; the new failure appears only if you later write a marker inside
an open comment. **This document is the one exception**: it is the only source of the adoption
digest and the note adds one digest marker, so the adoption digest gains exactly one line.

**What to do about it.** Apply the update, then run `scripts/build-digests.ps1` and commit the
result with the flow-down: expect the adoption digest to gain one line and the other four
digests to be unchanged. Without it, the digest freshness check fails. If
`build-digests.ps1` now names a skipped marker in your project, it was already being lost
before this update; fix it as described in item 2.

<!-- digest: A skipped digest marker now fails the run by file and line: delete it or close the comment above it. -->

### Flow-down note: the level declaration (kit feature 017 — constitution 0.7.0 → 0.8.0)

**What changes.** Ten files flow down as a clean update: the spec template, three law documents
(`docs/sdlc/branch-strategy.md`, `docs/sdlc/critical-delivery.md`,
`docs/sdlc/definition-of-done.md`), this document, and five scripts: `scripts/adoption-lib.ps1`,
`scripts/enforcement-pack.ps1`, `scripts/verify-kit.ps1` (feature 017) and
`scripts/build-digests.ps1`, `scripts/markdown-lib.ps1` (feature 016, which arrive with this update
if you have not applied the 016 note above). **One surgical item is reported, the constitution.**
It is never applied by the update: re-express the 0.8.0 amendment in your own constitution, with
your own version bump, SYNC IMPACT entry and human approval, as section 2 describes.

**What the amendment says** (Principle X, *Level declaration*). The delivery level a feature
declares is a written claim, and the kit grades it. A numbered feature's `spec.md` carries a
**Level Rationale** answering the four triggers of `docs/sdlc/critical-delivery.md`
(`domain-invariants`, `irreversible-data`, `authn-authz-payment`, `auditable-evidence`), each
*applies* or *does not apply* with a reason; a Standard feature answers *applies* to none, and a
Critical feature to at least one or states why it is Critical regardless. A project may declare
**critical surfaces**; a Standard or Micro feature whose Territory reaches one is promoted,
narrowed, or carries an approved **Surface Exception**. Add `scripts/enforcement-pack.ps1`'s new
constants (the four trigger keys and the `**Rationale Rule**` marker value) to your constitution's
sync-list line, as the kit's does.

**Two new checks, both in `scripts/enforcement-pack.ps1`.**

1. **The surface floor is opt-in.** Declare `criticalSurfaces` in `kit-adoption.json`, a JSON array
   of path globs written governance-root-relative and repo-prefixed in a multi-repo project, the
   way a Territory block is:

   ```json
   { "criticalSurfaces": ["src/auth/", "api/Payments/**"] }
   ```

   `scripts/init-kit.ps1` does not prompt for it. **Until you declare it, nothing is graded and
   no verdict changes**: each Standard or Micro feature's run prints one line,
   `LevelSurface: not armed`. Once declared, a Standard or Micro feature whose Territory (the union
   of every phase in `tasks.md`; for Micro, the block in `spec.md`) reaches a surface fails, naming
   the entry, the surface and the three ways forward. Patterns are compared by literal directory
   prefix, which **over-reports by design** (a Territory glob over a whole source tree reaches a surface inside it); a false positive costs one
   written exception, a false negative would cost the rule. A Critical feature is never failed by
   it. An unusable `criticalSurfaces`, an unreadable record or a Territory the check cannot read
   leaves the run `UNGRADED` by name, never clean.
2. **The Level Rationale applies only to a spec that carries `**Rationale Rule**: 1`**, which the
   new template stamps. Every spec you already have lacks it and is exempt and silent; a spec made
   from the new template owes the section. An unfilled template fails with one finding per
   trigger. A marker this check cannot read, such as a value other than `1` or a line that looks
   like the marker but is not one, is `UNGRADED`, not exempt.

**A Surface Exception** is two lines in `spec.md`, the second its approval, and is validated by the
function the amendment check uses. It names the exact Territory entry. A reason that is a
placeholder (bracketed, angle-bracketed, a TODO-style word, or with no word in it) does not count,
and neither does an approver left as an unfilled slot (double-braced, bracketed, angle-bracketed, or
`TODO(` followed by a name). **A bare word such as `TODO` as the approver is not caught**: that
validation is shared with the amendment check, so tightening it is a decision for the kit's owner
and review has to hold that line until then.

**When they start.** The checks run as soon as the scripts land, whether or not you have ratified
the 0.8.0 amendment in your constitution: a spec made from the new template owes its Level Rationale
from that day, and a declared `criticalSurfaces` is graded from that day. Ratify first or in the same
sitting. Micro and Lite owe no rationale; a Micro spec is held only to the surface floor.

**What these checks are not.** The rationale is a claim a reviewer can falsify, not proof: an owner
can still write *does not apply*. A spec can omit the marker and so stand outside the rationale rule,
as one can omit its `**Delivery Level**`; the omission shows in the diff, and the surface floor does
not depend on it. That an approver named in an exception agreed is held by review alone.

**What the doctor says.** `scripts/verify-kit.ps1` prints one line on every run that reaches the
record: `N critical surface(s) declared`, `criticalSurfaces is empty` or
`criticalSurfaces not declared`. The last two are information and never fail an adoption that
declares nothing; a declared list that is unusable is a finding. A test or script of your own that
matches the doctor's complete output needs that one line added.

**What was measured** (SC-004). The update was dry-run against FitForge, FlowBoard and
ExpenseTracker, each as a clone of its committed HEAD with nothing in place touched: ten files
applied cleanly, one surgical item (the constitution), no conflict. In each clone, every shipped
feature (1, 9 and 3 of them) was graded by the project's own `enforcement-pack.ps1` and then by the
new one: **no exit code moved and no verdict moved**, and no line was removed. Each non-Critical
feature whose level the pack can read gained the one `not armed` line. FlowBoard's shipped specs
mostly have no readable `**Delivery Level**` header and fail the Structure check on both the old and
the new script; the new checks say nothing about a level they cannot read and that finding is
unchanged. `verify-kit.ps1` gained the one line above and its verdict stayed `OK`. `ritual-checks.ps1`
on the trunk went from `RESULT OK` to a `digests` failure, which is the regenerate step below, and
back to `RESULT OK` once it was done.

**What to do about it.** Apply the update, re-express the amendment in your constitution, then run
`scripts/build-digests.ps1` and commit the result with the flow-down; without it the digest
freshness check fails. Expect the adoption digest to gain two lines (one is the 016 note, if you had
not taken it) and the critical digest one; the other three digests are unchanged. Your new specs
will carry the marker and owe the Level Rationale, so decide your critical surfaces in the same
sitting if you want the floor armed.

<!-- digest: Level declaration: re-express constitution 0.8.0, declare criticalSurfaces to arm the floor, then run build-digests. -->

### Flow-down note: the 2026-10-11 cross-repo territory reach (kit feature 018 — no constitution amendment)

**What the pre-phase check did before.** `scripts/territory-check.ps1` compared the governance
repository alone. In a nested multi-repo project two feature branches touch their own `specs/`
directories and little else it could see, so the code that actually collided sat in repositories it
never opened and it said `CLEAN`. Separately, an open claim it could not compare (no remote-tracking
ref for it in your clone) was skipped with a warning and the run still ended on `CLEAN`. Both are
the species of defect feature 015 closed in the ritual members: a clean word over a comparison that
was not made (GAP-018, and the governance half of GAP-029).

**What it does now.** Where `kit-adoption.json` declares `codeRepos`, each declared code repository is
read as a sibling working tree: the branch carrying the same name there, diffed against that
repository's own trunk, with the same trunk order and the same reader of `codeRepos` the scope check
uses. A shared file is reported with its repository prefix (`<repo>/<path>`), so it pastes into a
Territory block unchanged, and a feature's status is judged from its latest commit in any repository
it has a branch in. Every comparison it cannot make is listed as `UNGRADED: <repository>: <cause>` and
the run ends `UNGRADED`, never `CLEAN`. The causes and what to do about each are in
`docs/sdlc/team-workflow.md` section 5.

**What flows down.** Verbatim files only, nothing surgical and nothing in your constitution:
`scripts/territory-check.ps1`; the two libraries it now dot-sources, `scripts/adoption-lib.ps1` and
`scripts/scope-lib.ps1` (either may arrive as `never installed -> copied` if your project predates the
scope check's reach); `scripts/scope-check-repos.ps1`, which now calls the shared readers and prints
exactly what it printed before; and `docs/sdlc/team-workflow.md`.

**What you will newly see.** Three things, none of them a new failure:

1. **`UNGRADED` where `CLEAN` used to cover a skipped comparison.** An open claim with no
   remote-tracking ref in your clone (any single-branch fetch refspec) now prints
   `UNGRADED: governance: cannot compare <feature> (…)` and a closing `UNGRADED — … was NOT fully
   compared` line. Beside a `kit-adoption.json` that is not valid JSON, this is the only change for a project that
   declares no `codeRepos`; with every claim compared, the original `CLEAN` line is byte for byte
   what it was.
2. **A reach into the code repositories, if you declare them.** An overlap there is reported like any
   other. A clean run names what it compared (`compared governance and <repo>… against N open
   claim(s)`). A code repository the run cannot read says why: not present in this checkout, not a
   repository of its own, no resolvable trunk, a fetch that failed, another feature's branch it cannot
   compare, or a `codeRepos` entry that cannot be read. A code repository with no `origin` is compared
   against its local branches only and says so on its own line.
3. **`-Json`.** `UNGRADED` is always present (empty when everything was compared) and `CLEAN` is `false`
   whenever anything was not compared. `BRANCH`, `CLEAN` and `OVERLAPS` keep their meanings. The
   `no remote` state is untouched and its JSON has no `UNGRADED`.

**What does NOT change.** Every exit code: `0` no live overlap, `2` live overlap, `1` execution error.
`UNGRADED` is a verdict and never an exit code, so an ungraded run exits `0` and an overlap keeps `2`
with the ungraded lines printed beside it. The parameters, the refusal of a non-numbered branch, the
`no remote — nothing to check against` line and the four refusals (their text and their exit `1`
are as they were; since kit feature 022 they reach that exit themselves, see the 022 note below) are
as they were.

**What was measured** (SC-004). Each of FitForge, FlowBoard and ExpenseTracker was cloned (nothing in
place touched; FlowBoard has no open feature, so a throwaway branch name was checked from `main`, as
was one ExpenseTracker run; the clone's `origin` is the project on disk, so no network and no open claim from
elsewhere), the kit before this feature was applied, then the kit as it stands, and the territory check
and `ritual-checks.ps1` were run in each state, with the code repositories cloned beside the governance
clone and then with them absent. Two earlier passes were discarded: the first folded in other features' changes
(the kit before 018 versus the kit now), the second had a script defect that reverted the update before
the checks ran. The delta is this feature's alone. **Exit codes: none moved, in any run.**
**Verdicts: one kind moved.** With the code repositories present, `CLEAN` stayed `CLEAN` and gained only
the `compared governance and <repo>, <repo> against 0 open claim(s)` clause, in all three projects. With
them absent, each of the three projects, all of which declare `codeRepos`, went from `CLEAN` to `UNGRADED` (two entries, one
per declared repository, `not present in this checkout`): the old check said `CLEAN` without having looked
in those repositories at all. That is the intended change, and it is the governance-only-CI case in the
section above. A feature branch whose working tree carries no `codeRepos` (ExpenseTracker's
`003-expense-entry`, cut before the declaration reached the trunk) printed the original line, unchanged.
`ritual-checks.ps1` moved no member: FlowBoard and ExpenseTracker stayed `RESULT OK`, and FitForge stayed
at the same two failing members (`enforcement-pack` and `scope-check`) it had with the kit before this
feature; neither is this feature's. Its `scope-check` was passing with the installed 0.7.0 scripts and
failed once the kit before 018 was applied, so a project that updates and finds its own `scope-check`
red should look at the earlier kit features, not this one. Not exercised, and said so: no clone had another open feature, so
no real overlap was reported; the overlap itself is proved by the kit's fixtures.

**What to do about it.** Read the verdict word, not only the exit code: a wrapper that treats exit `0`
as clean must now also treat a line beginning `UNGRADED` as not clean. One situation will make a
healthy project print `UNGRADED` every time, and it is not a defect:

- **Governance-only CI.** A pipeline that checks out the governance repository alone has no code
  repositories to read, so a project that declares them gets `<repo>: not present in this checkout`.
  Run the check where the code repositories are, or leave it to the pre-phase habit on a developer's
  workspace. It is a pre-phase check, not a gate.

One case prints `CLEAN`, not `UNGRADED`, and is a limit of the check: the declaration is read from the
working tree you run it in. A feature branch cut before `codeRepos` reached the trunk has none, so it
gets the governance-only run and the original `CLEAN` line, which does not say the code repositories
were skipped. Take the trunk's declaration (rebase or merge) before relying on a clean result there;
`-Branch X` run from another checkout reads that checkout's record.

**Limits, stated rather than hidden.** The check sees pushed work, plus a local branch wherever a
repository has no `origin` or `origin` has no ref for that feature; another developer's unpushed commits are invisible to any git-based check,
which is why a clean run names what it compared. A local branch that the remote no longer has still
counts as that feature's work in a repository, so a finished feature whose governance branch is still
open can keep reporting a live overlap until the stale local branch is deleted. The "local branches
only" note is in the text form, not in `-Json`. Not covered by a fixture: your own branch existing only
as `origin/<branch>`, and a claim with no branch in a declared code repository. The `not-a-repository`
test is a copy of the scope check's, so the two can drift until the shared test is built.

<!-- digest: territory-check now reads declared code repos and ends UNGRADED, not CLEAN, on a comparison it could not make. -->
<!-- digest: UNGRADED from territory-check exits 0: read the verdict word; governance-only CI will always print it for code repos. -->

### Flow-down note: the 2026-10-11 spec-directory single source (kit feature 019 — no constitution amendment)

**What was wrong.** `CLAUDE.md` ("Feature Structure") called its seven-entry list "exactly these names",
while `docs/sdlc/branch-strategy.md` ("Spec Directory Contents") lists the full set, including `notes.md`,
the per-feature AI review and human review files and `rollback.md`. An agent reading `CLAUDE.md` alone
could decline to create a file the lane requires (a Critical feature's rollback plan has no path in the
short list). Two documents each read as law, and the shorter one was the one always loaded.

**What changed.** `CLAUDE.md` now says its list is the core, names `docs/sdlc/branch-strategy.md` as the
authoritative file set, and keeps the branch-to-directory mapping, the three core documents, the fallback
for a partly installed kit and the Micro exception. Nothing in the kit's behaviour changed: no script,
check or fixture, and the `## Feature Structure` heading that the enforcement laws cite is the same.

**What flows down.** `CLAUDE.md` is a surgical file: `scripts/update-kit.ps1` reports it and never
overwrites your copy, which carries your slot fills. Nothing else flows down. Make the edit by hand in
your `CLAUDE.md`, in the "Feature Structure" section:

1. Change "always, with exactly these names:" to "always. The core documents, with exactly these names:".
2. After the file tree, add the paragraph "That list is the core, not the whole set. `docs/sdlc/branch-strategy.md`
   ("Spec Directory Contents") is the authoritative file set: it also holds `notes.md`, `quickstart.md`,
   `checklists/`, and the per-feature AI review, human review and rollback files from `specs/_templates/`.
   Create whatever the lane requires; never decline a file because this summary omits it."
3. In the next paragraph, change "create this exact structure manually" to "create the core structure manually"
   and "This structure is law" to "The layout is law".

Skipping the edit breaks nothing: the old list stays as wrong as it was, and the doctor does not check it.

<!-- digest: CLAUDE.md Feature Structure now points at branch-strategy for the full spec-directory set; edit your copy by hand. -->

### Flow-down note: the 2026-10-11 rendered-structure lint (kit feature 020 — no constitution amendment)

**What was wrong.** Nothing in the kit renders Markdown, so a layout mistake that changes what a reader sees
was invisible to every check. A comment line (a `digest:` marker is one) or a blank line placed between two
rows of a table ends the table at that line, and the rows after it render as a stray line of pipes; a comment
at column zero between two items of a list starts a new list. Both left `doc-lint.ps1`, the digest check and
the whole ritual chain green. The kit had one such table of its own in `docs/roadmap.md`: GAP-025 onward in
the inventory rendered as plain text until feature 020 repaired it.

**What it does now.** `scripts/doc-lint.ps1` reads the block structure of the documents it already scans
(`CLAUDE.md`, `AGENTS.md`, `README.md`, the constitution, and everything under `docs/`, `adoption/`,
`modules/` and `specs/_templates/`) and fails the run, naming the file and line, on:

| Finding | What it means | The fix |
|---|---|---|
| `severed-row` | a table row after a blank or comment line is cut off from its table | move the comment or blank line out of the table; a `digest:` marker goes **after** the table |
| `severed-delimiter` | a delimiter row (the row of dashes) that is not directly under a header row, so no table starts | put it directly under the header |
| `ragged-row` | a row, or the delimiter row, whose cell count differs from its header's | add or remove the cell; write a literal pipe as `\|` (an unescaped pipe in a code span is still a cell boundary on GitHub) |
| `severed-list` | a list item after a comment line at column zero starts a new list | put the comment after the list, or indent it into the item; a blank line between items is fine |

A finding **fails the run in an adopted project too**, as every other `doc-lint.ps1` rule does: the owner
decided there would be no information-only release. The `doc-lint: OK` line is unchanged and now also means
no structure finding.

**What flows down.** Verbatim files only, nothing surgical and nothing in your constitution:
`scripts/doc-lint.ps1`, `scripts/markdown-lib.ps1` (`doc-lint.ps1` now dot-sources it, so the two must
arrive together; `update-kit.ps1` copies every `scripts/*.ps1`), `docs/sdlc/review-process.md` (the AI
review checklist gains a block-structure item) and this document. Expect the review digest to gain one line
and the adoption digest two; run `scripts/build-digests.ps1`. A half-applied update is the one way this goes
wrong: `markdown-lib.ps1` is not new to you, but its structure reader is, so a new `doc-lint.ps1` beside an
old `markdown-lib.ps1` stops with an unrecognized-function error and `doc-lint.ps1` and `ritual-checks.ps1`
stay red until the other file arrives. An old `doc-lint.ps1` beside a new library is harmless.

**What does NOT change.** The path, slot and manifest checks and their output, every exit code, and the
`doc-lint: OK` line. The check is **not a Markdown renderer**: it grades the four rules above and nothing
more, GitHub-flavoured rendering is its reference, and where renderers disagree it stays silent. A comment that
is never closed hides the rest of its document from the structure check, as it does from a renderer.

**What was measured** (SC-004). Each of FitForge, FlowBoard and ExpenseTracker was cloned from its local
directory (nothing in place touched, no network), the kit before this feature was applied with
`update-kit.ps1`, then the kit as it stands, and `doc-lint.ps1` and `ritual-checks.ps1` were run in the
installed state and after each application. The documents scanned were 38, 42 and 54. **No verdict moved and
no finding was reported**: `doc-lint.ps1` was `OK` and `ritual-checks.ps1` was `RESULT OK` in every
state of every project. The check was shown to be live in the same clones by adding a severed table row and a
severed list to a roadmap there, which it named by line (the change was discarded). Not exercised, and said
so: no real adopter document was flagged, so the fixes in the table above are proved by the kit's fixtures, not
by an adopter's case.

**What to do about it.** Take the update. If `doc-lint.ps1` now names a file and line, apply the fix in the
table; the most likely cause is a `digest:` marker or a blank line inside a table. One report may look
wrong: a line made only of pipes and dashes (for example a placeholder row of dashes) that sits directly after
a blank line, a comment or plain text, with no header row above it, is read as a delimiter row and reported as
`severed-delimiter`; give it a header row, or write it without the leading pipe. Ordinary prose that starts with
a pipe is not reported. A wrapper that treated a `doc-lint.ps1` pass as covering layout should
stop doing so for anything the four rules do not name.

<!-- digest: doc-lint now fails a table or list severed by a comment or blank line, and a ragged table row; fix it where named. -->
<!-- digest: A doc-lint structure finding fails an adopted project too: put a digest marker after a block, never inside one. -->
### Flow-down note: the 2026-10-12 load-bearing developer roster (kit feature 021 — no constitution amendment)

**What was wrong.** The `developers` array in `kit-adoption.json` was only ever counted: it chose the Critical lane's
evidence arm and nothing else read it. The Reviewer named in a Critical feature's human review, and the Owner of a
roadmap row, were free text that the kit compared with each other, never with the people the project had declared; and
the one-active-feature rule in `docs/sdlc/team-workflow.md` was prose with no counter (GAP-024, GAP-004).

**What it does now.** `scripts/adoption-lib.ps1` (the one reader of the record) returns the declared **roster**, and three
checks read it. Each entry of `developers` is still a name, and may now also be an object
`{ "name": "grace", "repos": ["api"], "canApproveCritical": false }`; the forms mix, only `name` is required, a missing
`canApproveCritical` means permitted, and a value that is not a boolean is read as not permitted. `repos` is validated and
recorded and **read by no check**. Names compare after trimming, exactly and case-insensitively.

| Check | Newly fails when | The fix |
|---|---|---|
| Critical evidence, team arm (`scripts/enforcement-pack.ps1`) | the human review's Reviewer is not on the roster, or its entry says `canApproveCritical: false` | write the Reviewer exactly as the roster does (`Grace Hopper` does not match `grace`), add the person, or choose a permitted Reviewer |
| Roadmap Owner (`scripts/roadmap-claim-check.ps1`) | a claim on `origin` has a non-`idea` row whose Owner cell is not a roster name | the Owner cell carries one roster name and nothing else (`ada, grace`, `**ada**`, `@ada` and `TBD` are strangers); or add the person |
| WIP counter (the same script) | one Owner holds more than two claims whose Status is `specified` or `in progress` and whose branch tip has a commit in the last 14 days | finish or release a claim, or let a stale one lapse |

Not a failure: exactly two active claims for an Owner is **noted** (lawful only under the pipelining conditions, which a
human confirms); a blank or `—` Owner and the branch being checked are not graded; and where the machine cannot read what it
needs the verdict is `UNGRADED` with the reason: a tip commit the clone does not have, a claim named by rows with
different Owners, or a claim written in a form that binds to no row (inside a longer name, say). `scripts/ritual-checks.ps1`
already lifts that word. A roster declared over a roadmap with no `Owner` column, or a claim whose only rows sit in a table
without one, prints a `not graded` line saying the Owners and counts were not checked, and the run stays `OK`. `scripts/verify-kit.ps1` reports each malformed
entry by position and cause and prints the roster it read, only when an entry is an object with a usable `name`, so the doctor's output for a
record of names is unchanged.

**All of the Owner and WIP reading is graded only where a roster is declared** (a non-empty `developers`, after every entry that
is neither a non-blank name nor an object with a usable `name` is dropped): a project that declares none gets byte-identical output and verdicts, with no new line. The
Critical reading applies in the team arm only, as before; the solo arm is untouched and never reads the human review.

**What membership proves.** It catches a stranger, a typo, a name the project did not declare and a developer the record
says may not judge. It does **not** prove the person is who the name says, that the review was independent, or that a pull
request is open: those stay a human's to judge (`docs/sdlc/team-workflow.md`, "What the machine counts, and what it cannot
see"). Assignment authority, matching developers to repositories, is deliberately not built.

**What flows down.** Verbatim files only, nothing surgical and nothing in your constitution: `scripts/adoption-lib.ps1`,
`scripts/verify-kit.ps1`, `scripts/enforcement-pack.ps1`, `scripts/roadmap-claim-check.ps1`, `scripts/ritual-checks.ps1`,
`docs/sdlc/critical-delivery.md`, `docs/sdlc/team-workflow.md`, `adoption/greenfield.md` and this document. Run
`scripts/build-digests.ps1` after the update, as after every update that moves a digest marker: until you do, the digests
member of `ritual-checks.ps1` reports the affected digests as stale. No script is new and no file needs a manifest
entry.

**What an owner may newly see.** On a project that declares **two or more** developers: a Critical feature whose Reviewer is
spelled differently from the roster, a roadmap Owner cell that is not exactly a roster name, and a third active claim
for one Owner. On a project that declares **one** name, a roadmap Owner or claim that is not that name (a full name or a
handle where the record says `me`), because any declared roster now counts; a solo project that wrote
`"developers": ["me"]` once and spells its Owners otherwise is the likeliest first red run. A project with a string-only
roster whose names already match its Owners and Reviewers sees no verdict move, and its doctor and mode are exactly what
they were; only its roadmap-claims OK line now says the Owners were graded.

**What does NOT change.** Every existing exit code, the `Mode` and count the record produces, the doctor's output for a
record of names, and any project that declares no `developers`. The Owner and WIP lines print only when a roster is
declared, and the roadmap-claims OK line gains `, Owners and claim counts graded against the declared roster` only when it
graded them.

**What was measured** (SC-003, FR-011). Each of FitForge, FlowBoard and ExpenseTracker was cloned from its local directory
with its nested code repositories (nothing in place touched, no network), the kit before this feature (`85b944f`) was
applied with `update-kit.ps1`, `build-digests.ps1` was run, then the kit as it stands was applied and the digests rebuilt, and
`verify-kit.ps1`, `enforcement-pack.ps1`, `roadmap-claim-check.ps1` and `ritual-checks.ps1` were run in the installed state
and after each application. **No verdict moved**: once the digests were rebuilt every member was `OK` (`n/a` for `scope-check` and `scope-repos` on the
trunk, as before) in every state of every project and `ritual-checks.ps1` was `RESULT OK`, `doc-lint.ps1` included. As applied,
before `build-digests.ps1`, the `digests` member reports the digests stale and the run is `RESULT FAIL`: that is the existing
flow-down step, and it fails identically after the kit as it stood before this feature, so it is not a verdict this feature
moves. Every line that changed between the two states is listed in the notes of feature 021 in the kit repository; the only output a project
could read as a difference is FitForge's, the one project that declares a roster (`anas.m`, `ahmad`, matching its roadmap
Owners): its roadmap-claims line gained `, Owners and claim counts graded against the declared roster`. The Owner check was
shown live in the same clone by writing a roadmap Owner `Anas M.`, which it named with the roster (exit 1; discarded).
Not exercised, and said so: no adopted project has a Critical feature, two claims for one Owner or a claim whose tip
date cannot be read, so the Reviewer reading, the counter and the UNGRADED paths are proved by the kit's fixtures, not by an
adopter's case.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. If you
declare a roster, write each name exactly as your roadmap Owner cells and review Reviewer lines do, one name per cell.

<!-- digest: Declaring developers makes them a roster: a Reviewer or roadmap Owner not on it fails, and a third active claim fails. -->
<!-- digest: Roster checks are graded only where a roster is declared; names match exactly (one name per Owner cell), case aside. -->

### Flow-down note: the 2026-10-12 verdicts that say what was compared (kit feature 022 — no constitution amendment)

**What was wrong.** Two scripts told the truth about part of a run and left the rest to the reader (GAP-030,
GAP-029). `scripts/scope-check-repos.ps1` printed its run-level `UNGRADED` only when nothing at all was graded, so when
one declared code repository graded and another applied and graded nothing, the run printed no run-level verdict,
exited 0, and `ritual-checks.ps1` showed `scope-repos` as `OK`. The line it printed for a repository with no
resolvable trunk told you to pass `-BaseRef <ref>` alone, which does nothing without `-All` and, without `-Repo`,
would have replaced the trunk of every declared repository. And the four refusals of `scripts/territory-check.ps1`
(not inside a git repository; a branch that is not `NNN-name`; a failed `git fetch origin`; a base branch that cannot
be diffed against) used `Write-Error` under `$ErrorActionPreference = 'Stop'`, which throws before the `exit 1`
written after it, so a caller that was not a terminal got an error record and whatever exit code the last git call
left behind, never the script's.

**What it does now.** Under `-All`, a declared code repository that applies (present, the root of a repository of its
own, carrying the feature branch) and graded no commit is named by a run-level line,
`scope-repos: UNGRADED (N declared code repositories applied to '<feature>' and graded nothing: <names> — the reason is on
the line(s) above; graded: <names>)`, whether or not another repository graded, and also beside a `FAIL`. It never
changes an exit code: `0` unless a repository fails. The line for a run that graded nothing anywhere is unchanged word
for word, a run in which every applicable repository graded prints exactly what it printed before, and without `-All`
(the per-phase tip command) nothing new prints. A repository that is `n/a` or `not applicable` for the reasons it
always was (absent, not a repository of its own, no branch for the feature) does not make the run `UNGRADED`. The
no-trunk line now ends `to grade it, run: pwsh -File scripts/scope-check-repos.ps1 -All -Repo <repo> -BaseRef <trunk>`.
`scripts/ritual-checks.ps1` is unchanged: it already lifts a line beginning `scope-repos: UNGRADED`, so a partly graded
run now shows the member `UNGRADED` and the run `RESULT UNGRADED`, exit 0, and it still does not pass `-BaseRef`
through. The four refusals print the same message, unchanged in wording, on the error stream and exit `1` from the
script itself. At a terminal under `pwsh -File` the exit code was already `1`; what goes is PowerShell's error-record
header (the script path, a line number, a caret rule) around the message.

**What flows down.** Verbatim files: `scripts/scope-check-repos.ps1`, `scripts/territory-check.ps1` and this document.
One surgical file: `docs/sdlc/review-process.md`, whose step 3 now says what the run-level line guarantees; the update
reports it, and you copy that one passage into your own copy by hand. Nothing in your constitution. Run
`scripts/build-digests.ps1` after the update, as after every update that moves a digest marker: until you do, the
digests member of `ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** On a project that declares `codeRepos`: when you run `scripts/scope-check-repos.ps1
-All`, or `scripts/ritual-checks.ps1`, in a checkout where some declared code repository carries the feature branch and
grades a commit while another carries it and grades none (no trunk found, no commits since the merge base, every commit a
merge or without a `phase N` token), the `scope-repos` member now says `UNGRADED` where it said `OK`. That is the one
verdict that can move, and it moves from a clean word to the honest one: the repository it names was never graded. It
exits 0, so no pipeline turns red on it; read the repository's own line above for the reason and fix that
(`-All -Repo <repo> -BaseRef <trunk>` for a trunk that is not `main`/`master`). A project that declares no `codeRepos`,
a governance-only CI run (no code repository present), and a run in which every repository graded see no change.

**What does NOT change.** Every exit code of both scripts. The verdict for a run that graded everything, for one that
graded nothing, and for tip mode. `scripts/ritual-checks.ps1` and its vocabulary. Territory-check's overlap detection, its
exit `2`, its `UNGRADED` accumulator and its `no remote` note.

**What was measured** (SC-003, FR-010). Each of FitForge, FlowBoard and ExpenseTracker (all three declare `codeRepos`) was
cloned from its local directory with its code repositories cloned in beside it and their branches made local (nothing in
place touched, no network). The kit before this feature (`b4987a1`) was applied with `update-kit.ps1`, `build-digests.ps1`
was run and committed, then the kit as it stands was applied and the digests rebuilt; `doc-lint.ps1`,
`scope-check-repos.ps1 -All` and `ritual-checks.ps1` were run in each state, on `main` and, for each project, on its
feature branches named with `-Branch` from `main`, so the applied scripts ran and not a feature branch's older copy.
**Exit codes: none moved, in any run. Verdicts: no `ritual-checks` member word moved in any project**, and `doc-lint` was
`OK` in every state, as applied and after the rebuild. As applied, before `build-digests.ps1`, the `digests` member
reports the digests stale and the run is `RESULT FAIL`: that is the existing flow-down step, identical after the kit
as it stood before this feature. **One output line was added.** ExpenseTracker with `-Branch 003-expense-entry`: its
`expense-tracker-web` repository already `FAIL`ed the territory check on its phase 2 commits (unchanged), and
`expense-tracker-api` had no commits since its merge base, so `scope-repos` now prints, beside that `FAIL`, the run-level
line `UNGRADED (1 declared code repository applied to '003-expense-entry' and graded nothing: expense-tracker-api — …;
graded: expense-tracker-web)`. The member said `FAIL` before and after. FitForge's `002-identity-member-profile` (both
repositories graded `PASS`) and the FlowBoard and ExpenseTracker probes where nothing was graded anywhere printed what they
printed before. Everything else that differed between the two states is the second update's own bookkeeping: two more
digest markers, the recorded kit commit, and one more commit for the amendment-authority check to read. Every line that
changed is listed in the notes of feature 022 in the kit repository. Not exercised, and said so: no adopted project had
a run in which one repository graded clean and another graded nothing with no `FAIL` beside it, which is the case where the
member word goes from `OK` to `UNGRADED`; that path, the `-All -Repo <repo> -BaseRef <trunk>` hint and the four
territory-check refusals are proved by the kit's fixtures, not by an adopter's case.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. If
`scope-repos` now says `UNGRADED`, `UNGRADED` is still not a pass: read the repository named on the line and say in the
review why the phase is safe to approve without that repository's grade, or grade it.

<!-- digest: Under -All a code repo that graded nothing is named by a run-level UNGRADED beside a graded one; exit stays 0. -->
<!-- digest: territory-check's four refusals print their message and exit 1 themselves; the no-trunk hint names -All -Repo. -->

### Flow-down note: the 2026-10-13 claim refusals that reach their own message and exit (kit feature 023 — no constitution amendment)

**What was wrong.** `scripts/claim-feature.ps1`, the command that takes a feature number, reported seven refusals with `Write-Error`
followed by `exit 1`: not inside a git repository; a working tree that is not clean; a branch other than `main`; a failed
`git fetch origin`; a missing stock `create-new-feature.ps1`; that script failing; and losing the allocation race three times. The
script runs under `$ErrorActionPreference = 'Stop'`, where `Write-Error` throws, so the `exit 1` after it never ran. Started with
`pwsh -File`, which is how a terminal, a CI job or an agent starts a script, the exit was still 1, with a PowerShell error record
(the script path, a line number, a caret rule) around the message. Called in-process from another PowerShell script, the refusal was a
terminating error: the caller's `catch` fired, `$LASTEXITCODE` stayed 0, and the exit a launcher reported was the launcher's own choice
(the kit's test harness, which runs the script inside a try/catch, saw 97 or a leaked 128 from the last git call). It is the defect `scripts/territory-check.ps1` had until feature 022 (GAP-029, GAP-031).

**What it does now.** Each of the seven prints its existing message, unchanged in wording and in any text it carries (the dirty
paths of the working-tree refusal, the stock script's output), on the error stream, and exits 1 from the script itself. Under
`-Json` a refusal is still a message and exit 1 with no JSON object. A successful claim prints exactly what it printed before and
exits 0, whether it was made with an origin, without one, or with `-NoPush`; the warnings, the preflight order, the number
allocation, the delegation to the stock script and the push-and-renumber loop are untouched.

**What flows down.** One verbatim file, `scripts/claim-feature.ps1`, and this document. Nothing surgical and nothing in your
constitution. Run `scripts/build-digests.ps1` after the update, as after every update that moves a digest marker: until you do, the
digests member of `scripts/ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** Started with `pwsh -File`, the bare message instead of the error record around it; the exit was 1 and
still is. **Called in-process from another PowerShell script, a refusal no longer throws:** there is no exception to catch,
`$LASTEXITCODE` is 1, and a caller that relied on the throw (a `catch`, or `$ErrorActionPreference = 'Stop'` halting it) now carries on
past a refused claim unless it checks `$LASTEXITCODE`. The message is written to the process's standard error rather than PowerShell's
error stream, so `2>$null` on the call no longer silences it and `2>&1` no longer captures it. There is no verdict word in this script,
so no `ritual-checks` member moves.

**What does NOT change.** The output and exit code of a successful claim, the `-Json` object and its fields, every message's
wording, the order of the checks, and the behaviour of the push-and-renumber loop, including its withdrawal of a remote branch it
pushed before it renumbers.

**Known limits, stated rather than hidden.** Two behaviours of the same script were found while fixing this one and are not changed
here. The helper that reads the remote ledger still ends in a terminating `throw` (`git ls-remote failed`) if the read fails, which
can also happen right after a push that succeeded, so a caller can see a failure for a claim that was in fact taken: check
`git ls-remote --heads origin` before retrying. And a push that the remote refuses while it can still be read (no write permission, a
server-side hook) is reported as the claim having been made concurrently, renumbered twice and ended with the lost-race message,
which passes over three numbers and misdiagnoses the cause: the push error itself is not shown. A push that fails because `origin` is
unreachable usually ends in the `ls-remote` throw instead. After either, the working copy is left on the new branch with its spec
directory: return to `main` and delete the local branch if the remote shows the claim did not land.

**What was measured** (US3, SC-001). Each of FitForge, FlowBoard and ExpenseTracker was cloned from its local directory (nothing in
place touched, no network; the clone's `origin` is the project on disk). The kit before this feature (`12e9a1f`) was applied with
`update-kit.ps1`, `build-digests.ps1` was run and committed, then the kit as it stands was applied the same way. In each state, on a
fresh clone of `main`, a successful claim made with `-NoPush` (`claim-feature.ps1 -NoPush -ShortName probe "a probe"`), three refusals
(a dirty working tree, a branch other than `main`, an `origin` that cannot be fetched), `doc-lint.ps1` and
`ritual-checks.ps1 -Branch main` were run, the clone reset to a clean `main` between runs. **A successful claim printed the same
bytes before and after in all three projects, and exited 0. Each of the three refusals run exited 1 in both states; what changed is
the text around the message**: before, a PowerShell error record (the script path, a line number, a caret rule) with the message last; after, the
message alone, and the dirty-tree refusal lists each dirty path on its own line. No `ritual-checks` member word moved, `doc-lint.ps1`
was `OK`, and `ritual-checks.ps1 -Branch main` was `RESULT OK`, in every project and every state. Everything else that differed
between the two states is the second update's own bookkeeping: two more digest markers, the recorded kit commit, and one more commit
for the enforcement pack to read. Every line that changed is listed in the notes of feature 023 in the kit repository. Not
exercised, and said so: the other four refusals (not a git repository, the stock script missing, the stock script failing, the lost
race) were not run in an adopted project, nothing was run through a wrapper that starts the script as a child process, and a claim
with a push was not run, since it would push to the project's real origin; those are proved by the kit's fixtures, which run the
script as a child process through the enforcement harness.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. If a wrapper of
yours parsed the PowerShell error record around a refusal, it now gets the message alone. If a script of yours calls the claim
in-process and relied on its throwing, check `$LASTEXITCODE` after the call.

<!-- digest: claim-feature's seven refusals now print their message and exit 1 themselves; a successful claim is unchanged. -->

### Flow-down note: the 2026-10-13 Critical branch that is not red from its first commit (kit feature 024 — no constitution amendment)

**What was wrong.** `scripts/enforcement-pack.ps1` demanded a Critical feature's independence artifact on every commit of its
branch: `human-pr-review.md` in team mode, `second-model-review.md` plus the 24-hour cooling-off in solo mode. That artifact cannot
exist before the final phase is written and reviewed (`docs/sdlc/definition-of-done.md`, item 6: once per feature, at merge), so
`ritual-checks` failed on a Critical branch from spec approval to the last commit, on a member whose subject did not yet exist.
An owner trained that red is normal stops reading the other six members, which are the ones a Critical feature most needs read on
every phase (GAP-022; observed on a ten-phase Critical feature in an adopted project).

**What it does now.** While a Critical branch is evidently mid-feature (by a heuristic over `tasks.md` and commit subjects, below), the check prints one
`WARNING: CriticalEvidence: <artifact> is not yet due - the branch is at phase K of N ...` line and does not fail for the
artifact. Mid-feature means: the committed `tasks.md` declares phase headings whose distinct numbers are exactly `1..N` (a heading such as
`## Phase 1 amendment requests` repeats a number and is allowed; a gap is not); some commit subject carries a phase token below `N`
anywhere in it (`phase k`, `phasek`, `phase ka`, `phases k`, case-insensitive, so `tasks: phase 4 done` counts); no commit subject
carries a token naming phase `N` or beyond; and the active arm's artifact is not yet committed. From the final phase on, or
once the artifact is committed, the check behaves exactly as before, in both arms, with the same messages. Wherever mid-feature
cannot be shown (no diff base, a shallow clone, `tasks.md` unreadable, with no phase heading, with a gap or with a number too large to
read, or no commit subject with a phase token yet) it stays strict and prints a `not treated as mid-feature` line saying why. The two arms
themselves were not edited.

**What flows down.** Four verbatim files: `scripts/enforcement-pack.ps1`, `docs/sdlc/critical-delivery.md`,
`docs/sdlc/definition-of-done.md` and this document. The kit's own test fixtures stay in the kit. Nothing surgical and nothing in
your constitution. Run `scripts/build-digests.ps1` after the update: until you do, the digests member of `scripts/ritual-checks.ps1`
reports the affected digests as stale.

**What an owner may newly see.** On a Critical feature mid-flight, a `WARNING: CriticalEvidence` line where there was a failure, and
a green `enforcement-pack` verdict that used to be red. **Committing the artifact early puts it under the arm's grading from that commit on:** the branch is red until the artifact is valid (team mode) or 24 hours old (solo mode, where the cooling-off clock starts at that commit), and passes once it is. An artifact left
uncommitted mid-feature warns where it used to fail. An unusable `kit-adoption.json` selects the solo arm, so a committed team-arm
file does not end the pending state there. A branch the check cannot show to be mid-feature (a depth-1 CI checkout, a `tasks.md`
without `## Phase N` headings) is exactly as red as before, now with the reason on a `WARNING` line. Non-Critical features and the
other members of the pack are untouched.

**What does NOT change.** The messages and conditions of both arms, the requirement that the artifact exist and be valid before
merge, the human review at merge, and everything a Standard, Lite or Micro feature sees.

**Known limit, stated rather than hidden.** A final commit whose subject is not read as naming the final phase (no phase word at
all; a separator the pattern does not read, such as `phase-3`, `phase: 3`, `phase #3` or `Phase III`; a list or range whose first
number is lower, such as `phase 1 and 3`, `phases 2-3` or `phase 2/3`), on a branch with no artifact committed yet, still reads as
mid-feature and stays on the warning. What stands behind it is gate 6, the human review at merge, which a person holds, and the
warning is printed on every run so the pending artifact is not forgotten silently. Name the final commit `phase N: ...`.

**A second limit, found by measuring on a real adopted Critical feature rather than by the kit's own fixtures.** Phases that land out
of order, or are never named in a commit subject, defeat the heuristic. "Final landed" is read as a phase token at
or above the highest declared phase, so a feature that does a high-numbered phase early reads as final too soon and stays strict for
that stretch, and a subject such as `declare phase 17` reads as phase 17 landed; a rule requiring every declared phase to be named
would instead warn at the end. The first effect is in the safe direction (relief the feature does not get); the first limit above is
the unsafe one (an unnamed final commit can get a warning where it should fail), which is why gate 6 stays behind it. A better merge-ready
signal than a commit-subject token is a separate piece of work, on the kit's roadmap.

**What was measured.** Each of FitForge, FlowBoard and ExpenseTracker was cloned from its local directory (nothing in place touched,
no network, nothing pushed; the clone's `origin` is the project on disk). The kit before this feature was applied with
`update-kit.ps1`, `build-digests.ps1` was run and committed, then the kit as it stands was applied the same way. In each state
`ritual-checks.ps1` and `enforcement-pack.ps1` were run on `main` and on every `NNN-*` branch (with the updated `main` merged into
the branch first, which is how an adopter meets a kit update on a live branch; no merge conflicted), and `doc-lint.ps1`.
**`doc-lint.ps1` was byte-identical and `OK`, and `main` was `RESULT OK`, in all three projects. ExpenseTracker's non-Critical
`003-expense-entry` kept the same member verdicts; only the second update's own bookkeeping moved (one more commit graded, the
changed-file count). The one Critical branch, FitForge's `002-identity-member-profile`, was strict before and is strict now at its
tip, which is correct (its phase 17 has landed), and at the two earlier points probed (after phases 4 and 9) it is still strict:
that feature's phase 11 ran before phases 4 to 9, which this heuristic reads as the final phase having landed.** A fresh-context
reviewer ran the pack at all 43 commits of that branch: it warns at 17, is strict for the out-of-order stretch (19 commits), strict
with a printed reason at 4 and strict at 3 others (two near the end, one early at `declare phase 17`). So on the one real Critical feature the relaxation reaches part of its history, not
all of it; that is the second limit above. The first measuring pass was discarded: its driver ran each branch with the branch's
own older scripts, so a branch could not move between states. FlowBoard has no feature branch, so no branch probe ran there.
Not exercised: a Critical branch in the solo arm, and any run in the adopted projects' own CI.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. On a Critical feature
in flight, expect the warning in place of the failure until the final phase lands. Commit the independence artifact when it exists, not
before. If you have a Critical branch that stays on the warning at its last commit, check that the commit is named `phase N: ...`.

<!-- digest: A Critical branch now warns, not fails, for a not-yet-due independence artifact while evidently mid-feature. -->
<!-- digest: An early-committed Critical independence artifact is graded at once, red until valid; name the last commit phase N. -->

### Flow-down note: the 2026-10-14 merge-readiness declaration for a Critical feature (kit feature 025 — no constitution amendment)

**What was wrong.** Feature 024 stopped a Critical branch being red from its first commit by reading, from commit subjects, whether the
final phase had landed. Measured on a real adopted Critical feature, that guess reaches only part of its history: phases that land out of
order, or are never named, defeat it (the second limit of the 024 note above). The question the check cannot answer from subjects, "has
the work finished?", is one the owner can answer in one line.

**What it does now.** A Critical feature's `plan.md` may carry one header line, `**Merge Readiness**: pending` or
`**Merge Readiness**: ready`. `scripts/enforcement-pack.ps1` reads it from the committed `plan.md` (a comment, a fence or a code span
hides it) before it consults the subjects, so it needs no history. `pending`: one
`WARNING: CriticalEvidence: <artifact> is not yet due - specs/NNN/plan.md declares **Merge Readiness**: pending (...)` line and no failure
for the missing artifact, whatever the subjects, headings or clone depth say (the run still exits 1 in a shallow clone, because the amendment check cannot grade one); an artifact that is committed is still graded by its arm.
`ready`: the arm grades the artifact exactly as for a merge-ready branch, so a missing one fails ("owed now", not "approved"). Two marker
lines, a value other than lower-case `pending` or `ready` (including `Pending`), or an empty value: strict, with the
`not treated as mid-feature` line saying why. No marker, or a hidden one: feature 024's behaviour, byte for byte. A Standard, Lite or
Micro feature ignores the line. On a branch feature 024 already reads as mid-feature, `pending` gives the same verdict with different
warning text.

**What flows down.** Five verbatim files: `scripts/enforcement-pack.ps1`, `docs/sdlc/critical-delivery.md`,
`docs/sdlc/definition-of-done.md`, `.specify/templates/plan-template.md` (an optional, commented-out `**Merge Readiness**` line, declared
nowhere) and this document. The kit's own test fixtures stay in the kit. Nothing surgical and nothing in your constitution. Run
`scripts/build-digests.ps1` after the update: until you do, the digests member of `scripts/ritual-checks.ps1` reports the affected digests
as stale.

**What an owner may newly see.** Nothing, until a plan declares the line. Adding it to an **existing approved plan is an amendment**, so
it needs `**Amendment approved by**: <name>, <YYYY-MM-DD>` in the amended section and the same name in the commit message, and so does
flipping `pending` to `ready` (constitution I). On a branch that declares `pending`, a `WARNING: CriticalEvidence ... declares
**Merge Readiness**: pending` line where there was a failure or the 024 warning.

**What does NOT change.** The messages and conditions of both arms, the requirement that the artifact exist and be valid before merge,
the human review at merge, feature 024's heuristic for a plan that declares nothing, and everything a Standard, Lite or Micro feature sees.

**Known limits, stated rather than hidden.** (1) `pending` is a claim. An owner who sets it and never flips it merges with only the
warning on this check; gate 6, the human review at merge, stands behind it, and the warning prints on every run. (2) The approver on the
flip is a recorded name, a written claim a reviewer can falsify and not proof of who approved. (3) The amendment check skips merge commits
(feature 014, D7), so a `pending` added inside a merge commit carries no approver check at all; this feature states that rather than
changing the check, and no fixture pins it. (4) `ready` is "owed now": it demands the artifact, it does not certify the work.

**What was measured.** On FitForge 002's real history (a scratch clone made from the project's local directory; nothing in place touched,
nothing pushed), this kit's scripts were run at each of the branch's 43 commits. **That is a simulation:** the marker does not exist in
that history, so a throwaway commit injects it, which shows the mechanism on real shapes and not that an owner will use it. With no marker
the current kit gives what feature 024 gave: `WARN` at 17 of 43, a failure at 22, strict with a printed reason at 4. With
`**Merge Readiness**: pending` injected into the plan at every commit that has one, the check warns at **41 of 43** and the run exits 0 at
each of those 41 (none of the branch's 43 commits carries the amendment check in its own committed scripts, so the injected, unapproved
plan amendments were never graded; in an updated project the same unapproved addition fails AmendmentAuthority); the other two are the first two commits, which precede `plan.md` and so cannot carry the line. With `ready` injected at
the tip, the arm demands the missing review and fails, as intended. On the non-Critical branches of FlowBoard (`main`) and ExpenseTracker
(`main`, `003-expense-entry`), cloned the same way, the kit's `enforcement-pack.ps1` before and after this feature printed byte-identical
output and exit codes. Not exercised: a Critical branch in the solo arm on a real project, and any run in an adopted project's own CI.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. On a Critical feature in
flight whose phases land out of order, or whose commits do not name phases, add `**Merge Readiness**: pending` to the plan as an
amendment with its approver, and flip it to `ready` (another amendment) when the final phase is done, before you commit the independence
artifact. A plan that declares nothing behaves as it did.

<!-- digest: A Critical plan may declare Merge Readiness pending or ready, overriding the subject heuristic; it needs no history. -->
<!-- digest: Merge Readiness pending is the owner's claim, not proof; adding or flipping it on an approved plan is an amendment. -->

### Flow-down note: the 2026-10-14 merge commit that authors a spec change (kit feature 026 — no constitution amendment)

**What was wrong.** The amendment-authority check (feature 014) skipped every commit with more than one parent on the reasoning that "a merge commit
authored nothing". That is true of a merge that only brings two histories together and false of one that resolves a conflict by hand or edits a document
while merging: the content it carries is in no parent, so no commit granted it. An approved `spec.md`, `plan.md`, `tasks.md` or `contracts/*` file changed
**inside** a merge carried no approver check. Feature 025 made that matter: a `**Merge Readiness**: pending` added inside a merge turned a strict failure
into a warning, and one review reproduced it (a Critical branch the heuristic would fail ended on `enforcement-pack: OK`, exit 0).

**What it does now.** For each merge commit in the branch's range, `scripts/enforcement-pack.ps1` asks, per graded document, whether the merged result is
something a parent already had. A document is **not** authored by the merge when it is absent in every parent (a creation), when it equals a parent's
version, or when it equals what git's own automatic merge of the two parents produces (`git merge-tree --write-tree`; a conflict leaves marker text in that
result, so a hand-resolved conflict differs from it and is graded). If nothing is authored the merge is skipped and counted under `merge commit(s)` exactly as
before. If a document is authored, the merge is graded like any amendment: the document must carry `**Amendment approved by**: <name>, <YYYY-MM-DD>` that is
new against **every** parent, and the merge commit message must name the approver. Both failure texts (no record; approver not named in the message) are the existing ones with one
clause appended for a merge. The task-tick and `**Status**` exemptions apply to a merge only when the change is of that kind against **every** parent; in the
usual merge of `main` into a branch, `main` holds no copy of the feature's documents, so no exemption applies there (tick tasks in an ordinary commit). A
document the merge **removes** is graded unless git's automatic merge removes it too (a deletion on one side stays a non-event), so a main merged into a branch
cannot delete or rename-and-rewrite an approved contract unseen. A merge whose parent or tree cannot be read is refused, with the same "fetch the full history" wording as an
unreadable commit, never skipped on a wrong reason.

**What flows down.** Three verbatim files: `scripts/enforcement-pack.ps1`, `docs/sdlc/critical-delivery.md` (its limits paragraph for the merge-readiness
declaration) and this document. The kit's own test fixtures stay in the kit. Nothing surgical and nothing in your constitution. Run `scripts/build-digests.ps1` after the update: until you do, the digests member of
`scripts/ritual-checks.ps1` reports the affected digests as stale. **Requires git 2.38 or newer** for the automatic-merge comparison; on an older git, or when
`git merge-tree` fails for any reason other than a conflict, the check does not skip, it grades the merge the strict way (below).

**What an owner may newly see.** On a branch whose merges only combine histories: nothing. On a branch with a merge that wrote a spec document (a conflict
resolved by hand, a document edited while merging, an octopus merge): an
`AmendmentAuthority: commit <sha> amends <files> after approval with no conforming approver record ... (this commit is a merge: its own change is what is
graded, because no parent holds this content)` line, fixed the way any such line is fixed: add the record to the merged file and name the approver in the
merge message. **A merge that combines two parents that were each approved on their own branch needs a fresh record when it had to be hand-merged:** a record
a parent already carried approved that parent's change, not the merge's. **A document removed or renamed inside a merge is graded too, and no record can
satisfy it:** the record is read from the merged file, where a removed path does not exist and a renamed document's new path is a creation. Make the move in
an ordinary commit instead, where a pure rename passes (deleting an approved document has no passing path in an ordinary commit either, feature 014).

**What does NOT change.** The record and the approver-in-the-message rule (constitution I), the grading of every ordinary commit (its code path and its
messages), the roll-up line for a branch whose merges authored nothing (byte-identical), the shallow-clone refusal, and the Lite lane (`fix/`, `chore/` and `docs/` branches do not run this check). Micro and Critical `NNN-*` branches are
graded for merge-authored documents exactly as Standard ones are, not only for a merge-readiness flip.

**Known limits, stated rather than hidden.** (1) **A merge that keeps one parent's version of a document whole is trusted on that parent's content,** even
when the only grading that content ever had was an exemption (the commit that created the file is a first appearance, or predates the check). So taking the
other side's `plan.md` in a conflict replaces an approved plan with no record, and the run ends on OK; gate 6, the human review at merge, stands behind it.
This is not new (before this feature every merge was skipped) and was weighed and left as stated rather than narrowing the comparison. (2) An octopus merge,
a git older than 2.38, or a failing `git merge-tree` is graded the strict way, which grades a clean combination of two amended parents as authored; a record
satisfies it. (3) The record is still a written claim, not proof of who approved. (4) `git merge-tree --write-tree` writes tree and blob objects into the
repository's object database (unreferenced, collected by `git gc`); it changes no ref and no working-tree file, and where a CI forbids the write the call
fails and the merge is graded the strict way. (5) Each merge costs a few extra git calls, about 170 ms on the Windows machine where a review measured it (the replay below was not timed per merge); a
branch with dozens of merges takes seconds longer. (6) **A document removed or renamed inside a merge cannot be made to pass** (see above): a removal has no
record to read, and a rename's new path is a creation, so even a pure rename (which passes in an ordinary commit) is graded as the removal of the old path. The
feature's spec lists a pure rename among the exemptions that apply to a merge while its plan decided that a rename is not detected inside a merge; the plan was
followed and the disagreement is recorded for the owner.

**What was measured.** Clones of FitForge, FlowBoard and ExpenseTracker made from their local directories (nothing in place touched, nothing pushed), and of
the kit's own repository, were replayed merge commit by merge commit in the shape CI grades a pull request: the range from the merge's first parent to the
merge, the branch being each `specs/NNN-*` feature the merged side touched, the boundary lifted (an analysis switch no gate passes), the previous version of
`scripts/enforcement-pack.ps1` against this one, each run against the clone as its project root. Across the four histories there are **131 merge commits**
(FitForge 10, FlowBoard 10, ExpenseTracker 10, the kit 101 in the clone, which holds the source's local branches and not its remote-tracking refs; counting
those too, a review found 102 in the kit and 132 in all); 87 of them merged a side that touched no feature directory (docs, claims and kit updates) and the
other 44 gave **46 feature runs** (one merge touched three features), with **72 merge commits inside those ranges**, summed over the runs. **No merge was newly graded, no run printed a new failure, and every
run's output was byte-identical between the two versions.** The slowest run, 49 commits, took 5.3 s against 5.0 s. **What that does and does not show:**
history before this feature carries no approver record for a merge, so "none newly failed" is true because every one of those merges authored nothing for
its feature, which an earlier combined-diff count over 131 merges had also found; it is not evidence that an owner will find a newly failing merge easy to
satisfy, and it cannot say how often a hand-merged conflict will occur from now on. Not exercised: a real merge that wrote a spec document, an octopus merge
(none exists in these histories), a git older than 2.38, and any run in an adopted project's own CI.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. If a merge of yours is graded, add the record
to the merged document and name the approver in the merge message (or avoid the hand-merge: take one side's version whole, or merge so that git's own
automatic merge produces the result; neither helps a removed or renamed document, which needs an ordinary commit). On a git older than 2.38 expect the strict grading of any merge whose result matches no parent.

<!-- digest: A merge commit is graded for the spec documents it authored; one that only combines two histories is skipped as before. -->
<!-- digest: A graded merge needs the approver record new against every parent and the approver named in the merge message. -->

### Flow-down note: the 2026-10-15 amendment of another feature's approved document (kit feature 027 — no constitution amendment)

**What was wrong.** The amendment-authority check (feature 014) read one directory, `specs/<branch>/`, and ran only on `NNN-*` branches. Constitution I says a change to "**that
feature's** `spec.md`, `plan.md`, `tasks.md` or `contracts/`" needs a record and an approver, for every approved feature; the check enforced it for the branch's own feature only.
A branch that amended an **earlier** feature's approved document, and every `fix/`, `chore/` and `docs/` branch (the Lite lane ran no amendment check), carried no approver
check at all: one review reproduced an unapproved line in an earlier feature's plan printing `enforcement-pack: OK`, and a real `docs/` branch had carried its record only because the
owner's process asked for one.

**What it does now.** `scripts/enforcement-pack.ps1` grades a commit's change to a `spec.md`, `plan.md`, `tasks.md` or `contracts/**` file of **any** `specs/NNN-*` directory
that **exists at the diff base** (approved on the integration branch), on a numbered branch (ordinary commits and merges, by feature 026's authored-content rule) **and** on a
`fix/`, `chore/` or `docs/` branch **whose diff touches such a document**. The grading is the one you know: `**Amendment approved by**: <name>, <YYYY-MM-DD>` in the amended
document, the same approver named in the commit message, the task-tick and `**Status**` exemptions, a creation exempt, a whole feature directory renumbered exempt. **The record goes in
the document that was amended**: a record in the branch's own files approves nothing for another feature's document. A failure about another feature's document appends a clause
saying so. A Lite branch that changes no spec document prints exactly what it printed before, in a shallow clone too. A Lite branch that touches one and cannot be graded (shallow
clone, an unreadable commit or tree) prints an `UNGRADED:` line and still exits 0: the Lite lane is never newly failed on a condition the machine cannot compute (feature 014, FR-009).
When the roll-up line prints on a `docs/` branch, the lane line names both checks.

**What flows down.** Three verbatim files: `scripts/enforcement-pack.ps1`, this document and `docs/sdlc/branch-strategy.md` (one sentence on the Lite lane). The kit's test
fixtures stay in the kit. Nothing surgical and nothing in your constitution. Run `scripts/build-digests.ps1` after the update: until you do, the digests member of
`scripts/ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** On a numbered branch that amended another feature's approved document: the usual `AmendmentAuthority: commit <sha> amends <files> after approval with
no conforming approver record ...` line, now with `; the amended file(s) outside this branch's own directory (<files>) belong to feature(s) <NNN-name> ...`. On a `fix/`, `chore/` or
`docs/` branch that edits an approved spec document (a correction to an earlier feature's plan, a spec fix on a docs branch): the same failure, fixed by adding the record to
that document and naming the approver in the commit message. A branch that only creates a spec document, or changes none, is not asked for anything. This **supersedes** feature
026's edge case "a document the merge changes for another feature: not graded", and its statement that the Lite lane does not run this check, for documents that exist at the base.

**What does NOT change.** The record and the approver-in-the-message rule (constitution I), the grading of the branch's own directory (the same code, byte-identical output for a
branch that changes no other feature's document), the exemptions, the shallow-clone and unreadable-commit refusals on a numbered branch, the boundary that grades only commits made
after the check arrived in your project, and the Lite lane's other checks.

**Known limits, stated rather than hidden.** (1) **"Exists at the base" stands in for "approved":** a document that reached the integration branch as a draft is graded as approved,
as the own-directory rule already does. (2) A document moved **out of** the branch's own directory in an ordinary commit is not graded; a whole directory moved **inside a merge** is
graded as a removal (make the move in an ordinary commit). A single document moved between feature directories, and a document removed, are graded and **no record can satisfy
them**. (3) The Lite gate reads the changed-file list, which is empty when `git diff` fails (roadmap GAP-034): a Lite branch with an unreadable diff is not graded and prints as before. So is a Lite branch with no base at all: this check is silent, and only the lane's existing no-base warning and the review-provenance `UNGRADED` line print.
(4) A branch that amends a document and reverts it before the merge is silent, because the Lite gate reads the net diff. (5) A branch that only creates a spec document, in a
shallow clone that still has a base, prints an `UNGRADED` refusal where it printed nothing. (6) The record is still a written claim, not proof of who approved.

**What was measured.** Clones of FitForge, FlowBoard and ExpenseTracker made from their local directories (nothing in place touched, nothing pushed), and of the kit's own
repository, were replayed merge by merge in the shape CI grades a pull request (`<merge>^1..<merge>`), the branch being the one the merge subject names, `-IgnoreAmendmentBoundary` on
(an analysis switch no gate passes), the previous `scripts/enforcement-pack.ps1` against this one. Of 137 merge commits, **110 matched the subject patterns that name a merged branch** (37 numbered, 73 `fix/`, `chore/` or
`docs/`); **107 runs were byte-identical, including every run in the three adopted projects.** Two runs in the kit's history are **newly failing**, both Lite: one amends an
earlier feature's spec with the record in the document but without the approver named in the commit message, one amends a spec with no record at all, before the rule existed. A
third run (an `NNN-*` branch that already failed) prints the same 18 lines, three of which now name more documents and carry the cross-feature clause. "Byte-identical" is not
"not graded": four kit branches amended another feature's approved document; the one that passed with its record (feature 026) prints what it printed before, and the 007 branch already failed. **That shows** that no unrelated
branch would have changed; per-run time was one sample per version, old script first, and moved by a few per cent either way, so it shows no large cost, not that there is none.
**It does not show** how easy a newly failing branch is to satisfy, how often a Lite branch will amend a spec from now on, or anything about your own CI, a shallow clone or an
octopus merge; **and the three adopted projects' histories contain no amendment of another feature's approved document, so their identical runs exercise none of the new path.**

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. If a branch of yours is graded for another feature's document, add
`**Amendment approved by**: <name>, <YYYY-MM-DD>` to **that** document and name the approver in the commit message; to move or remove an approved document, use an ordinary commit and
expect the removal to need the owner's decision rather than a record.

<!-- digest: The amendment check grades any feature's approved spec document, Lite lane too; the record goes in that document. -->
<!-- digest: A Lite branch that cannot be graded prints UNGRADED and exits 0; one touching no spec document is unchanged. -->

### Flow-down note: the 2026-10-15 unreadable diff (kit feature 028 — no constitution amendment)

**What was wrong.** `scripts/enforcement-pack.ps1` read the branch's diff in three places with `git diff ... 2>$null`: the changed-file list (feeding the Lite-lane abuse guard and
feature 027's Lite amendment gate), review-provenance's list of review files added, and the amendment gate's own second read. A diff git cannot compute (an unreadable tree or blob
on the branch) exits non-zero, and every one of the three read that as an empty list. The run printed `diff base '<sha>', 0 changed file(s)` and, on a `fix/` branch carrying a
dependency manifest and a migration, `enforcement-pack: OK`, exit 0 (reproduced for this feature's spec on a throwaway repository; the roadmap row had said it was not reproduced on a `fix/` branch). Feature 027's note said so as a limit.

**What it does now.** The three reads go through one reader, and a diff git cannot compute against a **present** base is a named state, never an empty list. The count line reads
`diff unreadable (git diff exited <n>)` instead of `0 changed file(s)`. On a numbered branch (`NNN-*`) the run fails once with
`DiffUnreadable: git diff against '<base>' failed on '<branch>' (exit <n>), so the changed-file list is unknown ...`: a second reader of the same damage adds no second line. On a
`fix/`, `chore/` or `docs/` branch each check that graded nothing prints one `UNGRADED:` line (`LiteAndAbuse` on `fix/` and `chore/`; `ReviewProvenance` and `AmendmentAuthority`, the
Lite amendment gate, on all three), the run ends `enforcement-pack: UNGRADED (<n> check(s) formed no opinion)` and the exit code is **0**: the Lite lane is never newly failed on a condition the
machine cannot compute (feature 014, FR-009). A partial list from a failing diff is discarded.

**What flows down.** Two verbatim files: `scripts/enforcement-pack.ps1` and this document; the kit's test fixtures stay in the kit. Nothing surgical and nothing in your
constitution. Run `scripts/build-digests.ps1` after the update: until you do, the digests member of `scripts/ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** On any branch whose diff against the base can be read: nothing, byte for byte. On a repository with a damaged object (a truncated or missing tree or blob
the branch's diff must read): on a numbered branch, one `DiffUnreadable` failure and a count line that says `diff unreadable`; on a Lite branch, `UNGRADED` lines and exit 0. The fix is
the same either way: repair the repository (a clone with a missing object is re-cloned; a shallow or partial clone is fetched in full: `fetch-depth: 0` on `actions/checkout`). A trunk branch (`main`, `master`) whose diff against its base cannot be read also prints the `diff unreadable` count line where it printed `0 changed file(s)`; its verdict and exit code do not change, because no scripted check applies there.
A pre-existing case the owner of a numbered branch may recognise: an unreadable **merge parent** (feature 026's refusal) now also prints `DiffUnreadable`, first, because the same damage
stops the diff; both lines stay, one saying the changed-file list is unknown and the other that the amendment check cannot grade the merge.

**What does NOT change.** The output and exit code of every branch whose diff is readable, empty, has no base (the dispatch's existing `WARNING` and `UNGRADED` lines, printed once and
not doubled), is in a shallow clone with a base, or is a trunk branch's (apart from that one count line, when its diff is unreadable); the verdict words (no new one); the amendment check's grading; and every other member of the pack. This
**supersedes** the first sentence of feature 027's flow-down limit (3), "a Lite branch with an unreadable diff is not graded and prints as before"; its second sentence, the silence of a Lite branch with no base at all, is still true. 027's note is history and is not edited.

**Known limits, stated rather than hidden.** (1) `scripts/territory-check.ps1` has two reads of the same kind that stay unchecked (the uncommitted-tree diff and an open branch's diff),
so an unreadable diff of another open branch is read as "no overlap", and an unreadable uncommitted-tree diff drops the branch's own uncommitted files from the set it checks; both are in roadmap row GAP-035. (2) A non-zero exit of `git diff` is taken as the whole truth: a
diff that exits 0 with wrong content (silent corruption) is not detectable here. (3) **The pack's other `git` reads are not changed, and at least one swallows a failure the same way.** `git show --numstat` in the Micro lane's phase walk and in `PhaseSizeWarning`
reads zero lines when a commit's blob is unreadable: a feature 028 review reproduced a Micro-declared branch with a 700-line phase commit whose hard 400-line failure turned into
`enforcement-pack: OK`, exit 0, and the phase-size warning disappeared. The reads of the same shape that were not probed (`git cat-file` and `git show HEAD:...` of the plan, tasks and
review blobs, `git log`, `git rev-list`, `git show -U0`, `ls-tree`) are open, with `territory-check.ps1`'s two, as roadmap row GAP-035. (4) git's own message is not shown, only its exit code, so the output is deterministic. (5) A partial result from a
failing diff is discarded, but no fixture can show it: git builds the whole tree diff before it prints, so a failing diff prints nothing. (6) The state is entered only with a base:
a missing base keeps the dispatch's existing warning. (7) The `docs/` lane line still says review-provenance is the only scripted check that applies, while the
UNGRADED lines list the checks that graded nothing.

**What was measured.** Clones of FitForge, FlowBoard and ExpenseTracker made from their local directories (nothing in place touched, nothing pushed), and of the kit's own repository,
were replayed merge by merge in the shape CI grades a pull request (the clone detached at the merge, `main` at its first parent, `-ReplayBase` and `-ReplayTip` set), the branch being
the one the merge subject names, `-IgnoreAmendmentBoundary` on (an analysis switch no gate passes), the previous `scripts/enforcement-pack.ps1` against this one. Of **143 merge commits**
(FitForge 10, FlowBoard 10, ExpenseTracker 10, the kit 113), **113 named a merged branch** (38 numbered, 75 `fix/`, `chore/` or `docs/`) and were replayed; the other 30 are `main`
merged into a branch or `governance:` commits and have no branch to grade. **No output differed, in any of the 113 runs, and no exit code changed.** Time per run was one sample per
version, old script first: 92 kit runs took 116.7 s with the old script and 110.5 s with the new, the largest (50 commits) 5.7 s against 5.1 s, so no cost was seen and none can be
claimed. **That shows** that no branch with a readable diff changes, on four real histories. **It does not show** how the new state reads on a damaged repository (the fixtures show that:
no branch in these histories has an unreadable diff), how often it will occur, or anything about your own CI, a shallow clone or a platform other than the one the replay ran on.

**What to do about it.** Take the update, run `scripts/build-digests.ps1` and `scripts/ritual-checks.ps1`. If a run now prints `diff unreadable` or `UNGRADED` where it printed
`0 changed file(s)` and `OK`, the repository has a damaged or missing object that the run could not read: repair it (re-clone, or fetch the full history), then re-run. Nothing in
your code or configuration needs to change.

<!-- digest: An unreadable git diff is a named state: count line, a numbered failure, UNGRADED on the Lite lane, never empty. -->
<!-- digest: A Lite branch whose diff cannot be read prints UNGRADED per check and exits 0; a numbered branch fails once. -->

### Flow-down note: the 2026-10-16 unchecked git reads (kit feature 029 — no constitution amendment)

**What was wrong.** After feature 028 named the unreadable diff, `scripts/enforcement-pack.ps1` and `scripts/territory-check.ps1` still held fourteen graded reads of `git` that discarded stderr
and read an empty result as "nothing": `git show --numstat` in the Micro lane's phase walk and in `PhaseSizeWarning` (a Micro-declared branch with a 700-line phase commit and a damaged blob ended
`enforcement-pack: OK`, exit 0, instead of the hard 400-line failure), the amendment check's history reads (`git log` batches, `rev-list`, `git show <ref>:<path>`, `git show -U0`, `ls-tree`), a rename
compared with two failing `rev-parse` calls (`$null -eq $null` read as "content came across intact"), the Critical cooling-off date, a Surface Exception's date (a failure fell back to the runner's clock),
and in `territory-check.ps1` the uncommitted-tree diff, `git ls-remote`, and an open branch's date and diff (read as "no overlap").

**What it does now.** Every one of those reads goes through an exit-checked reader and is a named state. On a numbered branch (`NNN-*`) a failed read is one `GitReadUnreadable: <read> failed on '<branch>'
(git exited <n>), so <what graded nothing> - repair the repository ...` failure, once per read per run; inside the amendment check it is that check's existing refusal text, and a failed pair of `rev-parse`
calls grades the rename instead of skipping it. On a `fix/`, `chore/` or `docs/` branch, and for the advisory `PhaseSizeWarning`, it is one `UNGRADED:` line naming the read and exit 0: the Lite lane is
never newly failed on a condition the machine cannot compute (feature 014, FR-009). `territory-check.ps1` keeps its own vocabulary: an unreadable uncommitted diff or remote listing is a refusal (the script's
existing `Stop-Refused`, exit 1); an unreadable open-branch comparison is an `ungraded` record, never "no overlap" (exit unchanged).

**What flows down.** Two verbatim files, `scripts/enforcement-pack.ps1` and `scripts/territory-check.ps1`, and this document; the kit's test fixtures stay in the kit. Nothing surgical and nothing in your
constitution. Run `scripts/build-digests.ps1` after the update: until you do, the digests member of `scripts/ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** On any repository whose git reads succeed: nothing, byte for byte. On a repository with a damaged object a read must touch: on a numbered branch a `GitReadUnreadable`
failure (or the amendment check's refusal) where a green or a silent skip stood; on a Lite branch `UNGRADED` lines and exit 0. The fix is the same: repair the repository (re-clone; a shallow or partial
clone is fetched in full, `fetch-depth: 0` on `actions/checkout`).

**What does NOT change.** The output and exit code of every run whose reads succeed; the verdict words (no new one); the grading rules; the lane split; and every other member of the pack. This
**supersedes** the open-limit wording of feature 028's note, limits (1) and (3) ("territory-check has two reads that stay unchecked"; "the pack's other `git` reads are not changed"). 028's note is history
and is not edited.

**Known limits, stated rather than hidden.** (1) `git cat-file -e` and `git rev-parse --verify --quiet` give the same exit code for absent and for unreadable, so they cannot be graded on the exit code; the
arm that follows each is strict by design. (2) A non-zero exit is taken as the whole truth: silent corruption (exit 0, wrong content) is not detectable here. (3) Eleven reads have no reachable data state
(seven fail only when a commit object is damaged, which breaks `git merge-base` first; three read objects a successful earlier read just read; `git ls-remote` fails only after a successful fetch), so they are guarded by their mutation or an injected failure, recorded in the feature's `notes.md`, not by a failing fixture
(plan Amendments 1 to 3). (4) One code path, "the code repositories are still compared after a governance diff failure", is correct by reading and shown by no fixture. (5) git's own message is not
shown, only its exit code, so the output is deterministic. (6) `territory-check.ps1` is not in the replay below (it fetches and lists the live remote); its fixtures cover it. (7) GAP-029 (the script's
four terminating refusals speak none of the kit's vocabulary) stays open.

**What was measured.** The same method as 028: clones of FitForge, FlowBoard, ExpenseTracker and the kit, replayed merge by merge in the shape CI grades a pull request, the parent
`enforcement-pack.ps1` against this one. Of **145 merge commits**, **115 named a merged branch** (39 numbered, 76 Lite) and were replayed; the other 30 are `main` merged into a branch or
`governance:` commits. **No output differed in any of the 115 runs and no exit code changed**; the new reader ran **14,035 times** across them (largest run 1,173 reads). Time per run was one sample per
version, old first, no cost seen and none can be claimed. **That shows** that no branch whose reads succeed changes, on four real histories. **It does not show** how the new states read on a damaged
repository (the fixtures do), how often it will occur, or anything about your own CI, a shallow clone or another platform.

**What to do about it.** Take the update, run `scripts/build-digests.ps1` and `scripts/ritual-checks.ps1`. If a run now prints `GitReadUnreadable` or an `UNGRADED` line naming a read where it printed `OK`,
the repository has a damaged or missing object: repair it, then re-run. Nothing in your code or configuration needs to change.

<!-- digest: A failed git read in the pack or territory-check is a named state: a numbered failure, UNGRADED on Lite. -->
<!-- digest: territory-check refuses on an unreadable uncommitted diff or remote list; never "no overlap" unread. -->

### Flow-down note: the 2026-10-16 claim ledger read and refused push (kit feature 030 — no constitution amendment)

**What was wrong.** After feature 023 gave `scripts/claim-feature.ps1`'s seven refusals their own message and exit, the race loop and the helper that reads the remote ledger still held
five silent or wrong states. (1) `Get-RemoteFeatureHeads` ended in a terminating `throw` when `git ls-remote --heads origin` failed. Started with `pwsh -File` the exit was 1 with a PowerShell error record
around the message; through a wrapper that runs the script in-process it was a terminating error and, in the kit's harness, a leaked exit 128. (2) That read also runs **after every push**, so after a push that
succeeded the claim was already live on `origin` while the script reported an error: a wrapper that read the failure as "no claim" and retried from a fresh checkout took a second number. (3) A push the remote
**rejected** (no write permission, a server-side hook), with no rival, was read as a lost race: a `WARNING: Number NNN was claimed concurrently ()` with an empty list of claimants, a renumbering, and a retry, three times,
ending on advice (renumber by hand) that does not apply, with git's own error never shown. (4) The `git push origin --delete` that withdraws a lost-race branch discarded its result, so a failed withdrawal left
an abandoned claim on `origin` while the script renumbered past it. (5) The re-fetch before renumbering discarded its result, so a failed one went on to allocate from refs it had not refreshed. Items (1) to (3) are GAP-036 and the
two "known limits" feature 023's note stated; (4) and (5) are the same loop.

**What it does now.** A failed ledger read is a refusal in the script's own words, on the error stream, exit 1, from each of its three callers: `git ls-remote failed — cannot read the remote ledger. Nothing was claimed.` before any push;
`git ls-remote failed after pushing <branch> — the claim may already be live on origin. Check origin (git ls-remote --heads origin <branch>) before claiming again; nothing on origin was changed.` after a push that succeeded (the
branch is left alone); and, after a lost race and a withdrawal, the first message plus whether `<branch> was withdrawn from origin` or `never reached origin`. A push the remote rejects, with no rival, is refused **once** with
git's own text (`git push of <branch> was rejected:` then git's lines, then `Nothing was claimed; the local branch and its spec directory remain. If the push may have landed, check origin ... before claiming again.`), with no
concurrent-claim warning and no renumbering. A withdrawal that fails refuses with `Lost the allocation race but could not withdraw <branch> from origin — delete it by hand: git push origin --delete <branch>.`; a re-fetch
that fails refuses with the first fetch's message and the state of our branch. A genuine rival, a successful claim with or without an origin or `-NoPush`, and the seven refusals of feature 023 are unchanged.

**What flows down.** One verbatim file, `scripts/claim-feature.ps1`, and this document; the kit's test fixtures and the three new harness fields stay in the kit. Nothing surgical and nothing in your constitution. Run
`scripts/build-digests.ps1` after the update: until you do, the digests member of `scripts/ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** On a claim whose reads and pushes succeed: nothing, byte for byte. **A push that errors after the remote accepted it** (`origin`'s branch of your branch's name is at your own commit, and `git push` exited non-zero) is now read as landed: with no rival, a `WARNING` carrying git's `error:` lines and then the claim is made, exit 0, where it used to be refused as rejected with `Nothing was claimed` (and, beside a rival, its branch is now withdrawn like any landed push, not left on `origin`); a wrapper that took every `git push` error as a failed claim now sees exit 0 after that warning. On a failed ledger read, the refusal where an error record stood, and **after a push that succeeded, a refusal that says the claim may be
live**: check `git ls-remote --heads origin` before claiming again, and delete your own branch if it should not stand. On a rejected push, one refusal showing git's error where three renumberings stood; a wrapper that matched the text
`Lost the allocation race 3 times` to detect a rejected push will no longer see it (that text now means three genuine rivals). On a lost race whose withdrawal fails, a refusal naming the branch left on `origin` (delete it by hand: `git push origin --delete <branch>`) where the claim used to renumber past it; on one whose re-fetch fails, the first fetch's refusal where the claim used to go on. Git's own reason is not shown for those two (only for a rejected push). Called in-process, as in 023's note, a refusal does not throw: check `$LASTEXITCODE`.

**What does NOT change.** The output and exit code of every successful claim, the `-Json` object and its fields (a refusal is still a message and exit 1 with no object), the seven messages of feature 023, the preflight order, the number
allocation, the delegation to the stock script, and the genuine lost-race loop (warn, withdraw, renumber, push again, up to three attempts), except that a withdrawal or a re-fetch that fails now ends it with a refusal, including on the last attempt where it replaces the lost-race text. This **supersedes** the "known limits" paragraph of feature 023's note above, which stands as history
and is not edited, with one exception: one digest marker of that note (`claim-feature still dies in a throw if ls-remote fails...`), which this feature makes false, was removed from it to keep the adoption digest within its 40-line bound.

**Known limits, stated rather than hidden.** (1) A push that reports failure but landed is read as landed from the ledger the script reads after the push; only when that ledger cannot be read is the exit code the whole truth, and the rejected-push message then says to check `origin` for the branch. (This replaces the limit as first written: the review of feature 030's phase 1 found it closable, finding F1.) Landing is decided by the commit and not by the branch name: a branch of the same name at another commit (a second claimant who chose the same number and short name at the same moment) is theirs, so a push rejected for it is refused as rejected and that branch is never withdrawn (the review of the amendment, finding F1). The one case it cannot tell apart: two claimants who chose the same number and short name from the same `main` tip hold branches at the same commit, and their pushes behave as they always did. (2) The
`git for-each-ref` in the number allocation still reads a failure as "no local branches"; the remote ledger and `specs/` still bound the number, so it can lower the choice but not below a number they show. (3) The local `git branch -m` and the
spec directory rename of a renumbering are unchecked. (4) The wording of the messages is not machine-parsed and may change in a later update. (5) After any refusal the working copy is left on the new branch with its spec directory: return to
`main` and delete the local branch if the remote shows the claim did not land.

**What was measured.** Each of FitForge, FlowBoard and ExpenseTracker was cloned from its local directory (nothing in place touched, no network, and nothing pushed to the real projects: each clone's `origin` was a bare copy made in a scratch area,
which is what let a claim **with a push** be run, as feature 023's measurement could not). The kit before this feature (`1d5914c`) was applied with `update-kit.ps1`, `build-digests.ps1` was run and committed, then the kit as it stands was applied the
same way. In each state, on a fresh clone of `main`, with the clone reset between runs: a successful claim with `-NoPush` and one with a push; three refusals of feature 023 (a dirty working tree, a branch other than `main`, an `origin` that cannot be fetched);
three states this feature names (the first ledger read failing, the read after a push that succeeded failing, a push rejected); `doc-lint.ps1`; and `ritual-checks.ps1 -Branch main`. **Both successful claims and the three refusals of 023 printed the same
bytes before and after in all three projects, and `doc-lint.ps1` was `OK` and byte-identical.** The three new states differ, as intended, and identically in the three projects: a failed first read went from a PowerShell error record to
`git ls-remote failed — cannot read the remote ledger. Nothing was claimed.`; a failed read after a push that succeeded went from the error record, **with the claim live on `origin`**, to the refusal that says so and names the branch; a rejected push went from
three concurrent-claim warnings and `Lost the allocation race 3 times` to one refusal showing git's text. Every one of them exited 1 before and after (at a terminal; the 128 is particular to the kit's harness launcher). No `ritual-checks` member word
moved and `ritual-checks.ps1 -Branch main` was `RESULT OK` in every project and state; the only line that moved was the recorded kit commit in `verify-kit`. The real projects were checked afterwards: no `probe` branch in any of them and the same working-tree
state as before. **Not exercised, and said so:** the withdrawal and re-fetch refusals (they need a rival claim to appear between allocation and the push, which no adopted project can be made to do; the kit's fixtures prove them), anything run through a wrapper
that starts the script as a child process, and the push a *rejected-for-permission* remote would answer with (the rejection measured here is an unreachable push URL). Every line that changed is listed in the notes of feature 030 in the kit repository.

**What to do about it.** Take the update, run `scripts/build-digests.ps1` and `scripts/ritual-checks.ps1`. If a wrapper of yours matched `Lost the allocation race 3 times` or the error record of a failed ledger read, match the new messages
instead. If a claim ends on `could not withdraw <branch> from origin`, delete that branch from `origin` and claim again. If a claim ends on `the claim may already be live on origin`, check `git ls-remote --heads origin` before you claim again. Nothing in your configuration needs to change.

<!-- digest: claim-feature names a failed ledger read, rejected push, withdrawal or re-fetch (exit 1); after a push: may be live. -->

### Flow-down note: the 2026-10-16 same-base rival (kit feature 031 — no constitution amendment)

**What was wrong.** A claim leaves its branch at `main`'s own commit: `create-new-feature.ps1` makes the branch and the spec directory and commits nothing. Two claimants who chose the same number and short name from the same `main` commit therefore pushed the same ref value to the same name. The second push answered `Everything up-to-date` with exit 0, and `scripts/claim-feature.ps1` printed `CLAIMED: <branch> (pushed to origin — the claim is live)` for a branch it had not pushed. Both owners then worked on one branch under one number and found out at merge. The ledger read after the push could not help: it shows the same name at the same commit either way, and the rival filter excludes the claim's own name. Feature 030's review (finding F1 of its phase 3) stated this as a limit; this feature closes it (GAP-037). A push that failed, a branch of the same name at another commit, and a rival with another short name were already handled and are unchanged.

**What it does now.** The push is `git push --porcelain -u origin <branch>`. A push that exits 0 and reports our own branch with the `=` status (`[up to date]`, where a push that creates the ref reports `*` `[new branch]`) created nothing: the branch was already on `origin`, at our commit, so another claimant pushed it first. The claim is then not made: the script warns `Number NNN was claimed concurrently by a claimant of the same short name (<branch> was already on origin; it is theirs and is left alone) — renumbering.`, drops the upstream that `-u` pointed at their branch, **withdraws nothing** (the branch is not ours), and takes the next free number through its existing loop. A claim with no rival, with `-NoPush`, with no `origin`, one beside a rival of another short name, and each refusal of features 023 and 030 print what they printed before (the git lines quoted in a rejected push's refusal excepted, below). When a rival of another short name is also there, the warning continues `; so did <rivals>` after `left alone`.

**What flows down.** One verbatim file, `scripts/claim-feature.ps1`, and this document; the kit's test fixture (`CLF-018`) stays in the kit. Nothing surgical and nothing in your constitution. No digest marker changed, so `scripts/build-digests.ps1` has nothing to regenerate for this update.

**What an owner may newly see.** On a claim that succeeds with no same-name rival: nothing, byte for byte. When a second claimant of the same number and short name pushed first: the warning above, then `Renumbered: <branch> -> <next>` and the claim on the next number, where the script used to say `CLAIMED` for a branch that was not yours. **One text moved:** the git lines quoted inside a rejected push's refusal (`git push of <branch> was rejected:`) are git's `--porcelain` lines now: `error: failed to push some refs to '<url>'`, `To <url>`, a tab-separated `!` line (`!<TAB>refs/heads/<branch>:refs/heads/<branch><TAB>[rejected] (non-fast-forward)`) and `Done`, where they were `To <url>`, ` ! [rejected] <branch> -> <branch> (non-fast-forward)` and `error: ...`. The script's own sentences around them are unchanged. A wrapper that matched the human ` ! [rejected]` line of that refusal must match the new one.

**What does NOT change.** The output and exit code of every successful claim, the `-Json` object and its fields, the seven messages of feature 023, the named states of feature 030, the preflight order, the number allocation, the delegation to the stock script, and the genuine lost-race loop (warn, withdraw our own landed branch, renumber, push again, up to three attempts).

**Known limits, stated rather than hidden.** (1) Two claimants that create the ref at the same moment, where our push then **exits non-zero**, are not told apart: the same-name test needs an exit 0, and feature 030's rule that reads a failed push as landed when `origin`'s branch of our name is at our commit sees the same commit and reads the claim as ours, with its warning and exit 0. The window is the push itself; it was traced in the review (finding F2) and not reproduced. This narrows, and does not remove, the limit that feature 030's note states for two claimants from the same `main` tip, and supersedes, for a push that exits 0, that note's sentence that their pushes "behave as they always did" (that note stands above as history and is not edited). (2) A same-name branch at **another** commit is not this state: it ends as the rejected-push refusal of feature 030, as before. (3) The test reads git's `--porcelain` status column (`=`), measured on git 2.55 for Windows; the status lines of `--porcelain` are documented, and the branch's CI run is the second git. (4) The wording of the messages is not machine-parsed and may change in a later update.

**What was measured.** The same method as feature 030: each of FitForge, FlowBoard and ExpenseTracker cloned from its local directory (nothing in place touched, no network, nothing pushed to the real projects: each clone's `origin` was a bare copy made in a scratch area). The kit before this feature (`7d933f4`) was applied with `update-kit.ps1`, `build-digests.ps1` was run and committed, then the kit as it stands (`38da677`) was applied the same way. In each state, on a fresh copy of the clone: a successful claim with `-NoPush`, one with a push, one in which a rival pushes the same name at the same commit just before the claim's own push (a `git` shim placed first on `PATH` that pushes the claim's branch to `origin` ahead of it), `doc-lint.ps1`, and `ritual-checks.ps1 -Branch main`. **The two successful claims and `doc-lint.ps1` were byte-identical before and after in all three projects, and `ritual-checks.ps1 -Branch main` was `RESULT OK` in every state, with only two lines moving: the diff base commit and the recorded kit commit in `verify-kit`.** The race moved as intended and identically in the three: before, `CLAIMED: <branch> (pushed to origin — the claim is live)` with one branch on `origin`; now the warning, `Renumbered`, and the claim on the next number, with both branches on `origin` and the rival's left alone (`002`/`003` in FitForge, `010`/`011` in FlowBoard, `004`/`005` in ExpenseTracker). The real projects were checked afterwards: no `probe` branch in any of them and the same working-tree state as before. **Not exercised, and said so:** a push that exits non-zero beside a simultaneous create (limit 1), anything run through a wrapper that starts the script as a child process, the Linux platform (the CI run), and a real remote's server-side hooks. Every line that changed is in the notes of feature 031 in the kit repository.

**What to do about it.** Take the update and run `scripts/ritual-checks.ps1`. If a wrapper of yours matched git's ` ! [rejected]` line inside a rejected-push refusal, match the `--porcelain` line instead. If a claim ends in `claimed concurrently by a claimant of the same short name`, it was renumbered for you: nothing needs doing, and the other claimant's branch is theirs. If the same warning printed three times and the claim then ended in `Lost the allocation race 3 times`, it was refused: nothing was claimed, so claim again. Nothing in your configuration needs to change.

### Flow-down note: the 2026-10-16 unreadable commit in the scope check (kit feature 032 — no constitution amendment)

**What was wrong.** `scripts/scope-check.ps1`, the machine check behind constitution X's territory rule, learned what a phase commit touched from one read, `git show --name-status`, in two places: `Get-CommitPaths` in `scripts/scope-lib.ps1` and the guard that refuses a commit deleting or renaming a feature's `tasks.md` or `spec.md`. Both discarded git's errors and never read the exit code, so a commit git could not read produced an **empty list of paths**, which is also what a commit that touches nothing produces. A phase commit whose tree could not be read printed `PASS phase N commit <sha> (0 file(s))` and exited 0, so an out-of-territory change passed; a commit with no phase token that deleted `tasks.md` printed `not applicable` and `UNGRADED` and exited 0, so the guard stood down exactly when it should fire. `scripts/scope-check-repos.ps1` calls the same function. It is the species feature 028 closed in `enforcement-pack.ps1` (GAP-034), in the other grader (GAP-038).

**What it does now.** The two reads go through one function, `Get-CommitStatusRows`, which reports a failed read on a flag of its own (`$script:CommitReadFailed`), because an empty list is a valid answer. `scope-check.ps1` ends the commit in `scope-check: ERROR commit <sha7>: its changed files could not be read (git show --name-status failed), so nothing about it was graded - the object store may be damaged: run git fsck.` and exit 1: in the delete guard (so a commit with no phase token is named too), and on the Standard and the Micro lane. `scope-check-repos.ps1` reads the same flag and ends the repository's commit in `<repo>: ERROR cannot read the changed files of <sha7>` (today the read of the committer date fails first on a damaged commit, so that line is defence in depth). A read that succeeds and returns nothing, a readable empty commit, still prints `PASS ... (0 file(s))`.

**What flows down.** Three verbatim files, `scripts/scope-lib.ps1`, `scripts/scope-check.ps1` and `scripts/scope-check-repos.ps1`, and this document; the kit's fixtures and the new self-test stay in the kit. Nothing surgical and nothing in your constitution. No digest marker changed, so `scripts/build-digests.ps1` has nothing to regenerate for this update.

**What an owner may newly see.** On a repository whose commits git can read: nothing, byte for byte. On a branch with a **damaged commit**: the `ERROR` line and exit 1 where the check printed `PASS (0 file(s))` or `not applicable`; with `-All`, a line for each commit git cannot read, which can include commits that share the damaged object (a removed tree gave four lines in the review's repository: the commit, an empty commit sharing the tree, and two later commits), and the run goes on to the next commit. **A wrapper that matched `PASS` or `not applicable` for such a commit now sees the `ERROR` line and exit 1.** `ritual-checks.ps1` reports its `scope-check` member as failed, as for any failing commit. The remedy is the one the line names: repair or re-fetch the object store (`git fsck`, a fresh clone) before trusting any verdict about that commit.

**What does NOT change.** The output and exit code of every readable commit, merge commits and commits with no phase token included, the territory grammar, the `tasks.md` and `spec.md` blob reads, the committer-date read of `scope-check-repos.ps1`, `-All`, `-Commit` and `-Phase`, and the `-Json`-less console format of a passing run.

**Known limits, stated rather than hidden.** (1) A commit whose **object is missing altogether**, not only its tree, can still end a `-All` run before the changed-file read: `Get-DiffBase` and the `git rev-list` of the commit list discard their errors, so `scope-check.ps1 -All` can print `UNGRADED could not resolve a merge base` and exit 0 (and `ritual-checks.ps1`, and so CI, runs `-All`, so a branch with a missing commit object can be green with that line) (the review of feature 032's phase 1, finding F3; `-Commit` on the same commit gives the new `ERROR`). That is recorded as GAP-040. (2) The reads of the parent's `tasks.md` and `spec.md` blobs are unchanged: an unreadable one FAILs, but names the wrong cause (a prior commit "deleted the territory declaration"); it never passes. (3) The new test of the check was measured on git 2.55; the CI run of the branch is the second git. (4) The wording of the messages is not machine-parsed and may change in a later update.

**What was measured.** The same method as features 030 and 031: each of FitForge, FlowBoard and ExpenseTracker cloned from its local directory (nothing in place touched, no network, nothing pushed). The kit before this feature (`989411f`) was applied with `update-kit.ps1`, `build-digests.ps1` was run and committed, then the kit as it stands was applied the same way. In each state, on a fresh copy of the clone: `scope-check.ps1 -Commit <sha> -Branch <feature>` on four commits chosen once from each project's own history (the two newest with a phase token, the newest without one, the newest merge: ExpenseTracker graded two phase commits with PASS, FitForge one, and FlowBoard none, only a WARN for a phase with no declared territory, so its comparison has no PASS line), `doc-lint.ps1`, and `ritual-checks.ps1 -Branch main`; and a probe of the damage itself: a fresh feature branch with a phase commit that adds one file inside its Territory and one outside, graded intact and then with that commit's tree object made unreadable. **All four commits in each project and `doc-lint.ps1` printed the same bytes before and after, `ritual-checks.ps1 -Branch main` was `RESULT OK` in every state, and only two lines moved: the enforcement-pack diff base commit and `verify-kit`'s recorded kit commit.** The damaged commit moved as intended and identically in the three: intact, `FAIL phase 1 commit <sha>: elsewhere/outside.txt not in territory`, exit 1; with the tree unreadable, `PASS phase 1 commit <sha> (0 file(s))` and exit 0 before, and the `ERROR` line and exit 1 now. The real projects were checked afterwards: no `probe` branch in any of them and the same working-tree state as before. **Not exercised, and said so:** the Micro lane and the delete guard on a project's own history (the kit's fixtures prove them), the nested-repository grader (no adopted project declares a code repository that is damaged), the Linux platform (the CI run), and a damaged object store that is not a loose tree. Every line that changed is in the notes of feature 032 in the kit repository.

**What to do about it.** Take the update and run `scripts/ritual-checks.ps1`. If a branch of yours now ends on `its changed files could not be read`, the object store of that commit is damaged: run `git fsck`, re-fetch or re-clone, and run the check again; do not merge on the strength of an earlier PASS. Nothing in your configuration needs to change.

### Flow-down note: the 2026-10-17 unknown recorded kit commit in the update script (kit feature 033 — no constitution amendment)

**What was wrong.** `scripts/update-kit.ps1` reports, for each surgical file (the project-filled documents it never overwrites), the upstream kit commits since the kit commit your project recorded in `.kit-version`, and it reads that log with `git log <recorded>..HEAD` with its errors discarded. When the recorded commit is not a commit of the kit clone you ran it from (a shallow clone, a rewritten history, another fork than the one that last updated your project) `git log` failed, the list was empty, and the file was reported as unchanged. The surgical section was simply not printed; if none of your verbatim files differed from the kit's, the run ended `Result: up to date` with exit 0; and a real run then advanced `.kit-version` to the kit's HEAD, so the report, which is delivered once, was lost without a word. With no `.kit-version` at all the same script already said `no baseline — review all`; the unknown-commit case was the one that disagreed with it (GAP-039).

**What it does now.** The script checks once, with `git cat-file`, whether the recorded commit is a commit of the kit clone. When it is not, every surgical file is reported exactly as when `.kit-version` is absent (`no baseline — review all`), and one line in text mode says why: `NOTE: the recorded kit commit <sha> is not in the kit clone (a shallow or rewritten clone, or another fork), so every surgical file is listed as having no baseline - the verbatim files below could not be compared to a baseline either.` The exit code is the existing rule for a pending surgical file (2), a real run prints the "delivered once" note, and `-Json` keeps its keys with the same entries. A recorded commit the kit clone has, a project with no `.kit-version` and one whose `.kit-version` is not valid JSON print what they printed before.

**What flows down.** One verbatim file, `scripts/update-kit.ps1`, and this document; the kit's test (`UpdateKit.Tests.ps1`) stays in the kit. Nothing surgical and nothing in your constitution. No digest marker changed, so `scripts/build-digests.ps1` has nothing to regenerate for this update.

**What an owner may newly see.** Only when the recorded commit is unknown to the kit clone: the NOTE line, a Surgical section listing every surgical file with `no baseline — review all` (20 files on the three adopted projects), exit 2, and, on a real run, the delivered-once note; where the script printed `Result: up to date` and exit 0 it no longer does. A wrapper that matched `Result: up to date`, or read an empty `surgical` array of `-Json` (whose `result` was the string `up to date` and is now an object with the kit version and commit), as "nothing to do" for such a project now sees the entries and exit 2. `.kit-version` is still rewritten to the kit's HEAD by a real run (the version-ratchet fix stands): review the listed files in that session.

**What does NOT change.** The output and exit code of a recorded commit the kit has, of an absent `.kit-version` and of a malformed one; the verbatim pass and its `differs - no baseline (unknown provenance)` conflicts; `-Force`; the preflight refusals; the `-Json` keys; the adoption doctor verdict.

**Known limits, stated rather than hidden.** (1) With an unknown recorded commit the verbatim files cannot be compared to a baseline either: a verbatim file that differs is a conflict even if you had not edited it, as before; that is the conflicts' existing reason, `unknown provenance`. (2) When the manifest lists no surgical file the NOTE is followed by `Result: up to date` if nothing else is pending; no kit manifest lacks surgical files. (3) What counts as unknown is a value that does not resolve to a commit of the kit clone: an unresolvable value, a tree sha (which `git log` used to accept and list commits for), a value that is not a string. A value that does resolve to a commit, an abbreviated sha or a ref name, counts as known, as before. The shortened form in the delivered-once note was made safe for a short or non-string value in the review of this feature's phase 1. (4) The test was measured on git 2.55; the CI run of the branch is the second git. (5) The wording of the messages is not machine-parsed and may change in a later update.

**What was measured.** The same method as features 030 to 032: each of FitForge, FlowBoard and ExpenseTracker cloned from its local directory (nothing in place touched, no network, nothing pushed). The script of the kit before this feature (`280be34`) and the script as it stands (`574b958`) were each run **against the same kit content**, so that only the script differed, on fresh copies of each clone in three recorded-commit states (the project's own recorded commit, no `.kit-version`, and an unknown commit), as a dry run, as `-Json -DryRun`, and, for the unknown commit, as a real run. **The recorded-commit-known and the absent states printed the same bytes before and after, as a dry run and as `-Json`, in all three projects.** The unknown state moved as intended and identically in the three: before, no Surgical section, 22 conflicts, `surgical` with 0 entries in `-Json`, a real run with no delivered-once note; now, the NOTE, `Surgical ... (20)`, the same 22 conflicts, `surgical` with 20 entries, exit 2, and the delivered-once note on a real run. **Not exercised, and said so:** real runs of the recorded-commit-known and absent states (only the unknown state was run for real), `-Force` together with an unknown commit, a small kit whose verbatim files are all current, the case where the old script ended `Result: up to date` with exit 0 (the kit's test builds exactly that state, and the notes of feature 033 measured it), a shallow kit clone in place, and the Linux platform (the CI run). Every line that changed is in the notes of feature 033 in the kit repository.

**What to do about it.** Take the update. If a run ends with the NOTE about a recorded kit commit, your kit clone does not have the commit your project recorded (the NOTE names it). Best, before a real run: make a dry run (`-DryRun`) after giving the kit clone the history it lacks (`git fetch --unshallow` for a shallow clone, or fetch from the kit repository that last updated your project) to get the real list, then run it for real. If you already ran it for real, `.kit-version` has advanced to the kit's HEAD and a second run lists nothing: take the list from a kit clone that has the commit the NOTE named, with `git log <that commit>..HEAD --oneline -- <surgical file>` for each surgical file, or review the listed files against the kit as a whole. A recorded commit that came from a rewritten history is in no clone: review the surgical files against the kit as a whole. Nothing in your configuration needs to change.

### Flow-down note: the 2026-10-17 unreadable merge base and commit list in the scope checks (kit feature 034 — no constitution amendment)

**What was wrong.** `scripts/scope-check.ps1 -All` and `scripts/scope-check-repos.ps1 -All` (the form `scripts/ritual-checks.ps1`, and so CI, runs) find the feature branch's merge base with the trunk and list the commits since it. Both reads, `git merge-base` (in `Get-DiffBase`, and in `Get-RepoMergeBase` of `scripts/scope-lib.ps1`) and `git rev-list`, discarded git's errors and took any non-zero exit for "none". A branch whose commit objects git could not read therefore ended `UNGRADED could not resolve a merge base with main - nothing checked` (or, for a code repository, `UNGRADED could not resolve a merge base with a trunk ... NOTHING WAS GRADED`) with exit 0: the same words and the same exit as a branch that legitimately shares no history with the trunk, so CI was green on a branch the check had not read. Feature 032 had made an unreadable *commit* an error; this is the read before it (GAP-040).

**What it does now.** The scripts read git's own answers. `git rev-parse --verify --quiet` exits 1 for a missing ref and `git merge-base` exits 1 for "no shared history": both are answers, and keep their `UNGRADED` text and exit 0, as does an empty range. Any other non-zero exit is a failure to read: `scope-check.ps1` prints `scope-check: ERROR could not read the merge base with main (git merge-base failed with exit <n>), so nothing on the branch was graded - the object store may be damaged: run git fsck.` and exits 1, and a failed `git rev-list` prints `scope-check: ERROR could not list the commits since the merge base (git rev-list failed with exit <n>) ...` and exits 1. `scope-check-repos.ps1` prints the same two sentences worded for a repository (`scope-repos: <repo>: ERROR could not read the merge base with a trunk (...) (git merge-base failed with exit <n>), so nothing in this repository was graded ...`), fails that repository, and goes on to the others. `Get-RepoMergeBase` returns `Failed` and `FailedWith` beside its existing members, which `territory-check.ps1` keeps reading unchanged. When a later trunk candidate gives a base, it wins over an earlier candidate's failure.

**What flows down.** Three verbatim files, `scripts/scope-lib.ps1`, `scripts/scope-check.ps1` and `scripts/scope-check-repos.ps1`, and this document; the kit's fixtures and the new `commitGraph` recipe field stay in the kit. Nothing surgical and nothing in your constitution. No digest marker changed, so `scripts/build-digests.ps1` has nothing to regenerate for this update.

**What an owner may newly see.** On a branch whose objects git reads: nothing, byte for byte. On a branch with a **damaged commit object**: the `ERROR` line and exit 1 where the check printed `UNGRADED ... merge base` or `UNGRADED (no commits since merge base ...)` and exit 0; `ritual-checks.ps1` reports its `scope-check` (and `scope-repos`) member as failed, so a CI run that passed on a damaged branch (`ritual-checks` printed `RESULT UNGRADED` with exit 0, which CI counts as passing) is **red**. Three states that are not "readable" in git's sense also move: an unborn `HEAD` with an `origin/main` present, a trunk ref that names a tag of a tree, and a project root that git cannot open as a repository at all (no `.git`, or a `safe.directory` refusal), now give the `ERROR` (git exits 128; for the last it reads `git rev-parse of origin/main failed with exit 128`, and the `git fsck` hint does not fit it: the cause is the repository itself) where they gave `UNGRADED`.

**What does NOT change.** `-Commit`, `-Phase` and tip mode; the `UNGRADED` text and exit 0 for a missing trunk, a branch with no shared history and an empty range; the territory grammar; the reads of the parent's `tasks.md` and `spec.md`; the committer-date read; the console format of a passing run; `territory-check.ps1`.

**Known limits, stated rather than hidden.** (1) `scripts/enforcement-pack.ps1` has its own `Get-DiffBase` with the same discarded read: a numbered branch with no resolvable base still fails there (`cannot grade ... no integration branch to diff against`), but the cause named is the wrong one for a damaged branch, and a Lite-lane branch only warns; that is GAP-041. (2) A **depth-1 clone**, which is the default `actions/checkout`, has no merge base with the trunk: git answers exit 1, so `-All` stays `UNGRADED` and exit 0 there as before; CI needs `fetch-depth: 0` for the check to read a merge base at all. (3) A corrupt ref file (for example a garbage `refs/heads/main`) makes `git rev-parse --verify --quiet` exit 1, which reads as "no such ref"; git itself gives that answer. (4) `territory-check.ps1` reads the same function and was deliberately not changed. (5) The fixtures pin `git merge-base failed with exit 128` for a truncated tip commit, measured on git 2.55; the CI run of the branch is the second git, and a git that exits 1 for a failure would fall back to the old `UNGRADED`, never to a false error. (6) The wording of the messages is not machine-parsed and may change in a later update.

**What was measured.** The same method as features 030 to 033, with the lesson of 033: the script of the kit before this feature (`07b7ed1`) and the script as it stands (`336c410`) were each run against the same fresh clones of FitForge, FlowBoard and ExpenseTracker (nothing in place touched, no network, nothing pushed), with `-Root <clone>`, `-All`, on three probe branches made in each clone: an intact feature branch with a spec commit and a phase commit, an orphan branch (no history in common with `main`), and the intact branch with its tip commit object truncated (the real projects were checked afterwards: no probe branch in any of them and the same working-tree state as before; the clones were made with `--no-hardlinks`; a first run was discarded because truncating one clone's object corrupted the intact one through a hardlink). **The intact branch and the orphan branch printed the same bytes before and after in all three projects** (`not applicable` then `PASS` for the first, `UNGRADED could not resolve a merge base with main - nothing checked` and exit 0 for the second). **The damaged branch moved as intended and identically in the three**: before, `UNGRADED could not resolve a merge base with main - nothing checked`, exit 0; now, `ERROR could not read the merge base with main (git merge-base failed with exit 128) ...`, exit 1. `scope-check-repos.ps1 -All` was also run, read-only and in place, on the real FitForge, FlowBoard and ExpenseTracker, whose code repositories are present (FitForge `002-identity-member-profile`, FlowBoard `008-realtime-sync`, ExpenseTracker `003-expense-entry`), with the script before and after this feature: **byte-identical** in all three (FitForge 14 `PASS` lines, exit 0; FlowBoard the empty-range `UNGRADED` lines of a merged branch, exit 0; ExpenseTracker its own pre-existing result, exit 1, the same before and after), and the working-tree state of each project unchanged. **Not exercised, and said so:** the damaged-branch state of `scope-check-repos.ps1` on an adopted project (its code repositories are separate repositories and were not copied; the kit's fixtures prove it, including the nested code repository), the commit-list `ERROR` on a project clone (it needs a commit-graph; the fixtures prove it), and the Linux platform (the CI run). Every line that changed is in the notes of feature 034 in the kit repository.

**What to do about it.** Take the update and run `scripts/ritual-checks.ps1`. If a CI run now ends on `ERROR could not read the merge base` or `could not list the commits`, the object store of that branch is damaged: run `git fsck`, re-fetch or re-clone, and run the check again; do not merge on the strength of an earlier green. If your CI used to print `UNGRADED ... merge base` and you want it to grade, check out the full history (`fetch-depth: 0`). Nothing in your configuration needs to change.

### Flow-down note: the 2026-10-17 unreadable diff base in the enforcement pack (kit feature 035 — no constitution amendment)

**What was wrong.** `scripts/enforcement-pack.ps1` finds the diff base with its own `Get-DiffBase` (`git merge-base HEAD origin/main`, then `main`) and, like the scope checks before feature 034, took any non-zero exit for "no base". A branch whose commit objects git could not read therefore got the words of a branch with no integration branch: a dispatch `WARNING` about a missing integration branch, an `AmendmentAuthority` failure that says the check "does not distinguish" the causes, and a `ReviewProvenance` `UNGRADED` line that advises `fetch-depth: 0`. The verdicts were already right (a numbered branch failed, a Lite-lane branch was `UNGRADED` at exit 0); the **cause** named was wrong, and fetching more history is no remedy for a damaged object store (GAP-041).

**What it does now.** `Get-DiffBase` reads git's own answers. `git rev-parse --verify --quiet` exits 1 for a missing ref and `git merge-base` exits 1 for "no shared history": both are answers and print what they printed before. Any other non-zero exit is a failure to read. When no candidate gives a base and git failed, three messages say so: the dispatch warning reads `enforcement-pack: the diff base could not be read (git merge-base failed with exit <n>), so nothing on '<branch>' was compared ... The object store may be damaged: run git fsck, or re-clone.`; the numbered lane's `AmendmentAuthority` failure reads `cannot grade '<branch>' — the diff base could not be read (...), so what the branch changed is unknown. The object store may be damaged: run git fsck, or re-clone ...`; and the `ReviewProvenance` `UNGRADED` line reads `the diff base could not be read (...), so no review file on '<branch>' was inspected ...` and no longer advises `fetch-depth: 0`. The cause in the parentheses reads `git rev-parse of <ref> failed with exit <n>` instead when it was `git rev-parse` of the trunk ref, not `git merge-base`, that failed. When a later trunk candidate gives a base, it wins over an earlier candidate's failure.

**What flows down.** One verbatim file, `scripts/enforcement-pack.ps1`, and this document; the kit's fixtures stay in the kit. Nothing surgical and nothing in your constitution. No digest marker changed, so `scripts/build-digests.ps1` has nothing to regenerate for this update.

**What an owner may newly see.** On a branch whose objects git reads: nothing, byte for byte. On a branch with a **damaged commit object**: the three sentences above instead of the missing-integration-branch wording. **No verdict moves**, in the states measured and by construction (the code changes only the text printed once no base was found): a numbered branch is red (exit 1) with either wording, and a Lite-lane branch is `UNGRADED` at exit 0 with either wording; only the cause named, and the repair advised, differ. Any other state git answers with exit 1 keeps its text.

**What does NOT change.** Every verdict and exit code; the shallow-clone failure and its text (it is asked first); a missing trunk, a branch with no shared history and every readable repository; the other "no diff base" lines (`MicroLane`, `PhaseSizeWarning` and `LiteAndAbuse` still state a consequence that is true of a damaged branch too); `-ReplayBase`, `-ReplayTip` and `-IgnoreAmendmentBoundary`; the unreadable-diff and unreadable-read states of features 028 and 029.

**Known limits, stated rather than hidden.** (1) A **depth-1 clone**, the default `actions/checkout`, has no merge base with the trunk: git answers exit 1, so the pack keeps its `fetch-depth: 0` advice there; the new wording is for a read git failed, not for missing history. (2) A corrupt ref file (for example a garbage `refs/heads/main`) makes `git rev-parse --verify --quiet` exit 1, which reads as "no such ref"; git itself gives that answer. (3) The fixtures pin `git merge-base failed with exit 128` for a truncated tip commit, measured on git 2.55 and, through the kit's CI, on the Linux runner's git; a git that exits 1 for a failure falls back to the old wording, never to a false cause. (4) The wording of the messages is not machine-parsed and may change in a later update.

**What was measured.** The method of features 030 to 034: the pack of the kit before this feature and as it stands were each run with `-Root <clone> -Branch <probe>` against the same fresh clones of FitForge, FlowBoard and ExpenseTracker (nothing in place touched, no network, nothing pushed; clones made with `--no-hardlinks`), on probe branches made in each clone: a numbered branch and a Lite-lane (`docs/`) branch, each intact, each an orphan (no history in common with `main`), and each with its tip commit object truncated. **The intact and orphan probes, on both lanes, printed the same bytes and the same exit code before and after in all three projects.** **The damaged probes moved as intended and identically in the three:** the dispatch warning and the `ReviewProvenance` line (and, on the numbered branch, the `AmendmentAuthority` failure) changed to the new wording; the exit code stayed 1 for the numbered branch and 0 for the Lite branch. The real projects were checked afterwards: the same branches and working-tree state as before. Not exercised, and said so: the commit-graph shape (the pack's base read is `merge-base` alone; the kit's fixtures prove the states it reaches). Every line that changed is in the notes of feature 035 in the kit repository.

**What to do about it.** Take the update and run `scripts/ritual-checks.ps1`. If a run now says `the diff base could not be read`, the object store of that branch is damaged: run `git fsck`, re-fetch or re-clone, and run the check again; do not merge on the strength of an earlier result. If your CI printed the `fetch-depth: 0` advice and you want the check to grade, check out the full history. Nothing in your configuration needs to change.

### Flow-down note: the 2026-10-18 `pending` merge-readiness claim the tasks contradict (kit feature 036 — no constitution amendment)

**What was wrong.** Feature 025 let a Critical plan declare `**Merge Readiness**: pending`, a claim the owner makes and the check cannot test. An owner who set it and then finished every task, and never flipped it, merged with only the deferral warning on `CriticalEvidence`, and gate 6, the human review at merge, was all that stood behind it. Separately, a plan that declares nothing still gets feature 024's commit-subject heuristic, and where that heuristic gave up (no base, a shallow clone, a `tasks.md` it could not read) the message did not tell the owner that one line in the plan answers the question.

**What it does now.** `scripts/enforcement-pack.ps1` reads the committed `tasks.md` when the plan says `pending`. If it holds at least one checkbox task (a `-`, `*` or `+` list item at any indent whose box is `[ ]`, `[x]` or `[X]`, a bare box with nothing after it included; a numbered `1. [ ]` item is not read) and **none is unticked**, `pending` is not honoured: the check prints the `not treated as mid-feature` line with `declares **Merge Readiness**: pending but ... has all N of its tasks ticked, so the branch is treated as ready`, and the arm demands the independence artifact exactly as for `ready`. Comments, fenced blocks and code spans are not read as tasks. A `pending` beside any unticked task, beside a `tasks.md` with no checkbox task, or beside a file git cannot read keeps feature 025's warning, byte for byte. Where the 024 heuristic produced the message (a plan with no marker), the message now ends with `; the plan can state the answer with **Merge Readiness**: pending or ready (docs/sdlc/critical-delivery.md item 5)`; a plan with a marker, valid or not, gets no suffix.

**What flows down.** Verbatim: `scripts/enforcement-pack.ps1`, `docs/sdlc/critical-delivery.md` and this document. The kit's own fixtures stay in the kit. Nothing surgical and nothing in your constitution. Two digest markers were added to `docs/sdlc/critical-delivery.md`: run `scripts/build-digests.ps1` after the update, until you do the digests member of `scripts/ritual-checks.ps1` reports the affected digests as stale.

**What an owner may newly see.** (1) On a Critical branch whose plan says `pending` while every task in `tasks.md` is ticked: a **failure** where there was a warning, naming the missing artifact. The repair is on the line: set `**Merge Readiness**: ready` (an amendment: `**Amendment approved by**: <name>, <YYYY-MM-DD>` in the plan, the approver named in the commit message, no exemption) and file the review, or untick the work that is not done. (2) On a plan with no marker, the existing 024 messages with the suffix above. Nothing else moves: a branch that declares nothing and is judged by the heuristic keeps every verdict and exit code.

**What does NOT change.** Every verdict a plan without `pending`, or with an unticked task, sees; the 025 and 026 amendment rules; the arms, their messages and conditions; and everything a Standard, Lite or Micro feature sees.

**Known limits, stated rather than hidden.** (1) A tick is a proxy for "complete", and the rule only ever demands the artifact **earlier**, never later. A project that never ticks, or whose `tasks.md` has no checkbox tasks, keeps `pending` as a claim, and gate 6 stands behind it. (2) A stray unterminated `<!--` hides every line after it, so a ticked list above it can read as all the tasks there are and an unticked task below it is not seen. (3) A box with text glued to it (`- [x]done`) is not a task. (4) The approver on the flip is a recorded name, a written claim a reviewer can falsify.

**What was measured.** On FitForge 002's real history (a scratch clone made with `--no-hardlinks`; nothing in place touched, nothing pushed), the branch's 43 commits were replayed with `**Merge Readiness**: pending` injected by a throwaway commit at each (**a simulation**: the marker does not exist in that history). The check before and after this feature printed the same `pending` warning at all 41 commits that carry a plan, so the verdict changed at **0 of 43**. The reason is in the task list: the count of unticked tasks was never 0, and at the tip it was 6 of 128, among them the filing of the independent review itself, so the rule stayed silent. Ticks in that list were not reliable either: three of the six open tasks carry a later "record corrected: was `[x]`" note (one says its test does not exist), and at two commits (32 and 33) a single open task, the review filing, was all that stood between the list and the rule firing. That shows the reader on a real 128-task file, and the proxy limit (a tick is not proof the work is done) in a real history; it does not show a branch where every task is ticked and `pending` is left in place, because this history has none. On the kit's own last features the same reader counts features 033 and 034 as complete and 035 as never complete (its tasks were never ticked), which is the proxy limit above in numbers.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. If a finished Critical branch now fails on `has all N of its tasks ticked`, set the plan to `ready` as an amendment with its approver and file the review. If you declare `pending` for a feature in flight, keep unfinished work unticked, and flip the line when the final phase is done.


### Flow-down note: the 2026-10-18 review claim and the fit note (kit feature 037 — no constitution amendment)

**What was wrong.** Feature 021 made the developer roster load-bearing for names, and left two things with the people they concern (GAP-024 b and c). The owner chose their own cross-reviewer: the Reviewer named in a Critical feature's `human-pr-review.md` was checked against the roster and against the Owner, but nothing recorded how that person came to be the Reviewer, so a friendly nominee satisfied every machine check. And a roster entry's `repos` was validated and recorded and read by nothing, so in a multi-repository project the top roadmap row went to whoever was free.

**What it does now.** `scripts/claim-review.ps1 -Feature NNN-name [-As <roster name>]` is how a reviewer takes a Critical feature's review: it pushes the ref `review/NNN-name/<slug>` to `origin` under the reviewer's own name (the slug is the roster name made safe for a ref). `scripts/enforcement-pack.ps1`, in the team arm of the Critical evidence check and only after the feature 021 conditions hold, then requires that claim: a Reviewer with none fails naming the command; a claim whose name slugs to the Owner's, or whose commit was authored under the Owner's name or email, does not count; and the existing "human-pr-review.md is missing" failure says when nobody has pulled the review. A ledger or a claim author the check cannot read is an `UNGRADED` line with the cause, exit unchanged. Separately, `scripts/claim-feature.ps1` takes `-Row <fragment of the roadmap row's Feature cell>` and `-As <roster name>`: when the row's optional `Repos` column lists a repository the claimant's roster `repos` do not, it prints one advisory `Fit` line before allocating, and the claim proceeds unchanged. The fit reading is **advisory**: it never refuses, delays or alters a claim, and the kit proposes, ranks and assigns no one.

**What flows down.** Verbatim: `scripts/adoption-lib.ps1`, `scripts/claim-feature.ps1`, `scripts/enforcement-pack.ps1`, the new `scripts/claim-review.ps1`, `docs/sdlc/team-workflow.md`, `docs/sdlc/critical-delivery.md` and this document. `specs/_templates/roadmap-template.md` (verbatim, like all of `specs/_templates/`) gained a paragraph about the optional `Repos` column; your own `docs/roadmap.md` is not touched, and needs the column only if you want the note. The kit's own fixtures stay in the kit. Nothing in your constitution. Three digest markers were added (`docs/sdlc/team-workflow.md` two, `docs/sdlc/critical-delivery.md` one): run `scripts/build-digests.ps1` after the update, until you do the digests member of `scripts/ritual-checks.ps1` reports the affected digests stale.

**What an owner may newly see.** Only in a project whose `kit-adoption.json` declares a roster of two or more developers (the team arm), and only on a Critical feature whose review is owed: (1) a **failure** when the Reviewer named in `human-pr-review.md` has no review claim (the line names `scripts/claim-review.ps1` and the exact command), when the claim's name or its commit author is the Owner's, or, beside the missing-review failure, a clause saying nobody has pulled the review. The repair is to run the command as the Reviewer; (2) an **`UNGRADED`** line, not a failure, when the check cannot read `origin` (no remote, a failed `ls-remote`, a claim whose author cannot be fetched), when two roster names write as one ref name, or when the Owner's name has no usable characters; (3) the `Fit` lines of a claim that passed `-Row`. A project with no roster, one developer, or no Critical feature sees none of this.

**What does NOT change.** The solo arm (it never reads a claim); every Standard, Lite and Micro verdict; the feature 021 conditions, their messages and their order (a stranger, the Owner as Reviewer and a denied reviewer are named as before and the claim is not graded a second time); the claim counter, the number allocator and the territory check (a `review/` ref cannot match an `NNN-*` pattern); and a claim made without `-Row`, except the one parameter-binding limit below.

**Known limits, stated rather than hidden.** (1) A review claim is a written claim: someone who can push to `origin` wrote a roster name. The roster maps no name to a git identity, so the author test catches the owner pushing a claim from their own identity and nothing more; it does not show who the person is, that the review happened or that it was independent. Gate 6, the human review at merge, stands behind it. (2) An unreadable ledger is `UNGRADED`, not red, so a Critical team feature can reach merge with that line on a CI that cannot read `origin`; while the review file itself is missing, an unreadable ledger adds neither the clause nor an `UNGRADED` line, and the missing-review failure stands alone. (3) The check reads no dates: an abandoned claim keeps counting until the Reviewer named in the review file is someone else; any ref at that slug is a claim. (4) To read a claim's author the check may fetch the ref into the clone it is grading (objects and `FETCH_HEAD`). (5) The fit reads the working tree's `docs/roadmap.md` and roster, so claim from an up-to-date `main`; it compares names only. (6) `-Row` and `-As` bind by prefix: an **unquoted** dash-led word in a feature description (`claim-feature.ps1 -ShortName x fix the -Row handling`) is taken as a parameter, and one that ends the line fails with "Missing an argument". A description passed as one quoted argument, the documented form, is unaffected, so a claim made as documented and without `-Row` is byte-identical (spec FR-011). (7) The roadmap table is read by a second, smaller reader in `scripts/adoption-lib.ps1` beside `scripts/roadmap-claim-check.ps1`'s own; they are not merged.

**What was measured.** On fresh `--no-hardlinks` clones of FitForge, FlowBoard and ExpenseTracker (nothing in place touched, nothing pushed), the kit's scripts were overlaid as an update would, once as of the commit before this feature and once as of its tip, and `enforcement-pack.ps1` and `roadmap-claim-check.ps1` were run each way. On `main` the output of all three projects was **byte-identical** (the pack applies no scripted checks to the trunk, so this shows no script broke, not that a claim was graded). On FitForge's real Critical branch `002-identity-member-profile` (43 commits; `human-pr-review.md` not yet written there) the verdict is the same `FAIL`, exit 1, before and after, and the only change is the clause appended to the existing missing-review failure: `nobody has pulled the review of 002-identity-member-profile yet - a reviewer takes it with: …`. A reviewed Critical feature carrying a claim was not available in any of the three, so the claim grading itself is shown by the kit's own fixtures (`CRIT-R05` to `CRIT-R09`), not by a real history.

**What to do about it.** Take the update, run `scripts/build-digests.ps1`, and run `scripts/ritual-checks.ps1`. On a Critical team-arm feature, the Reviewer runs `pwsh -File scripts/claim-review.ps1 -Feature NNN-name` (as themselves, `-As <roster name>` if their `git user.name` is not a roster name) before the review is filed; the owner does not nominate. If you want the fit note, add a `Repos` column to your roadmap table and claim with `-Row`. If your CI cannot read `origin`, expect the `UNGRADED` line and read it as ungraded.

## 3. Other surgical files

Not every surgical report is a constitution amendment. `docs/sdlc/gate-command.md`,
`docs/sdlc/repository-strategy.md`, `docs/sdlc/review-process.md`,
`docs/sdlc/rollback-process.md`, and `docs/sdlc/deployment-standards.md` carry
project-filled content (your gate commands, your repository layout, your customizations)
that an update must never overwrite. `docs/rulebooks/` and `modules/` are the same story
at a larger scale — instantiated tier rules and worked examples, replaced with your own
content at adoption. **`.github/workflows/project-gate.yml.template`** (deletable) is
surgical for the same reason: your copy is `project-gate.yml`, filled with your gate
chain. Updates only *report* changes to surgical paths — they never write them — so a
changed template is refreshed by hand into your filled copy; a project adopted before
the template existed (pre-008) never receives it through the update channel at all and
installs it the first time by copying it from a kit clone.

For these, read the commits the report names, and re-apply by hand only what's relevant:
most kit-side changes to these files are structural or illustrative and don't require any
action in your project at all. When one does apply — a new required section, a changed
convention — add it to your own version the same way you'd make any other governance
edit: reviewed, committed, no different from hand-written project documentation.

<!-- digest: Surgical files carry project-filled content: re-apply by hand only what applies — an ordinary governance edit. -->

## 4. The adoption doctor and its records

`pwsh -File scripts/verify-kit.ps1` audits your project's kit integrity any time (structure
essentials, unfilled slots in project-owned files, constitution ratification, declared-tier
rulebooks + gate proof, declared code repositories, `.kit-version`). It runs automatically at the end of `init-kit.ps1`
and of every `update-kit.ps1` apply, and as part of the `ritual-checks` CI in adopted
projects. It is read-only: it reports, you repair.

<!-- digest: verify-kit.ps1 is the adoption doctor: read-only, runs at init end, update end, and in adopted-project CI. -->

**kit-adoption.json** (project root) is its source of truth for what you declared.
`init-kit.ps1` writes it; you own it afterwards — adding a tier later means adding it here
*and* instantiating the rulebook. Projects adopted before the doctor existed create it by
hand:

```json
{
  "schemaVersion": 1,
  "projectName": "your project",
  "topology": "single",
  "tiers": ["backend", "database"],
  "initDate": "2026-09-08",
  "kitVersionAtInit": "copy",
  "gateProof": [
    { "gate": "default", "command": "your gate chain", "exitCode": 0,
      "date": "2026-09-08", "recordedBy": "you" }
  ]
}
```

`topology` is `single` or `multi`; `tiers` are the menu tiers (backend, frontend, mobile,
database, integration) **or any custom tier** (lowercase name — worker, cli, …; custom
tiers are first-class, `docs/rulebooks/README.md`) — every declared tier must have its
instantiated `docs/rulebooks/<tier>-rules.md`; `codeRepos` is the multi-repo-only list of
nested code repositories the machine scope check reaches into
(`scripts/scope-check-repos.ps1`) — plain directory names, one level under this repository,
never paths; `developers` names the people who work on the project, and is what selects
the Critical lane's evidence rule (below); `kitVersionAtInit` is informational — the kit's constitution
version at init time, or `copy` (the doctor never validates it); `gateProof` is your
attestation that the gate has been green at least once (adoption step 3) — record the
exact command (never with secrets in it), the exit code, the date, and who ran it. No
tool writes proof entries for you, and `init-kit.ps1` never overwrites an existing
record — your attestation survives a re-init.

**Multi-repo projects adopted before feature 012** add `codeRepos` by hand — one line, no
migration tool. Put it after `topology`, keeping the record valid JSON:

```json
  "topology": "multi",
  "codeRepos": ["your-api", "your-web"],
```

Until it is there, the doctor WARNs and `scripts/scope-check-repos.ps1` reports `n/a`: the
code phase commits in those repositories are graded by a reviewer's eye, not by a machine
(GAP-016). An empty array counts as "not there" — same WARN, same silence. A single-repo project omits the field entirely — its code lives in this
repository, where `scripts/scope-check.ps1` already reaches it.

**Declaring `developers` (feature 013)** — one line, and it changes exactly one thing:
which evidence a **Critical** feature must produce for independent approval
(`docs/sdlc/critical-delivery.md` item 5).

```json
  "developers": ["ada", "grace"],
```

| What the record says | What a Critical feature must produce |
|---|---|
| nothing (the default) | `second-model-review.md` + the 24-hour cooling-off — the solo substitute |
| one name | the same; one developer *is* the solo case |
| two or more names | a committed `specs/NNN-name/human-pr-review.md` with a filled `## Review Provenance` block — Reviewer, Owner (not the same person), and the verbatim attestation line the template carries — and **no** cooling-off |

Read the table in the direction that matters: **declaring nothing changes nothing.** Every
project adopted before this feature keeps the behaviour it has today, forever, without
touching its record. The field only ever moves a project *off* the substitute, and only when
it says two or more people are here — because the substitute is what a solo developer does
*instead of* independent review, and a second person is not a substitute for anything.

Declare it when your project genuinely has two or more people who review each other's work.
Do not declare it to make a check pass: a team declaration on a one-person project removes
the cooling-off period and asks a reviewer line you will end up filling with your own name,
which the check rejects — correctly.

The count is taken **after** blank entries, numbers and other non-names are dropped (an object with a usable `name` is a
developer since feature 021) and duplicates collapsed case-insensitively — so `["Ada","ada"]` is one developer and stays solo,
`["ada","grace"," "]` is two and is team, and `["ada",5,"grace"]` is also two, because the
number is discarded rather than counted. A value that is not an array at all, or a file whose
root is not a JSON object, is ignored entirely and the project falls back to solo.

Every one of those fallbacks is safe — they all land on the stricter arm — but they are
**silent** in the check itself, so the doctor reports each as a FAIL *and* prints the mode
the record actually produces — on every one of those paths, including the not-an-array case.
The doctor and the check read the record through the same function
(`scripts/adoption-lib.ps1`), so the mode it prints is the mode you will be held to. Without both halves, a project could believe it declared a team for
months while being checked as solo.

<!-- digest: kit-adoption.json is project-owned: every declared tier needs an instantiated rulebook; gateProof is your attestation. -->

**.kit-version** is written by `update-kit.ps1` (a JSON record of the kit version/commit
you're on). A project adopted by copy that has never run an update can create it as a bare
kit commit sha, or simply run `update-kit.ps1` once. One caveat while both files are
absent: if your `docs/roadmap.md` still carries the kit's own title line, the doctor
cannot tell your project from the kit template and declines to audit — creating either
file (or retitling your roadmap) makes you auditable.

## Partial-install note

If `update-kit.ps1` refuses your target as a partial install, your kit copy is missing
one of the required paths doc-lint checks for — most often a dot-directory
(`.specify/`, `.claude/`) that a file manager or a naive copy silently skipped. Finish
the install (see `adoption/`, step 0) before updating.
