<!--
SYNC IMPACT REPORT
==================
Version change: kit template 0.8.0 → 1.0.0 (first ratification for booking-api)
Source: agentic-sdlc-kit constitution 0.8.0, kit commit 2d3e5bd (.kit-version).
Bump rationale: MAJOR — initial ratification. The kit template's slots are filled for this
  project; its version history is the kit's own and lives in the kit repository.
Project-specific decisions taken at ratification (owner: anas.m, 2026-10-18):
  - Principle II: rungs 1-2 (visual references, UI guidelines) deleted — booking-api is a
    REST API with no UI and no authoritative visual reference. The ladder now starts at
    spec.md; rung numbers shifted, so project documents cite rungs by name, not number.
  - Principle III: kept as a NOT APPLICABLE stub rather than deleted and renumbered.
    booking-api is a single repository; verbatim kit documents and scripts cite principles
    IV-X by number, and renumbering would make those citations point at the wrong
    principle. Every principle number therefore matches the kit's.
  - Principle V: domain invariants pack is docs/domain/booking-invariants.md (5 invariants).
  - Developers declared in kit-adoption.json: anas.m (solo — Critical features use the solo
    evidence rule, docs/sdlc/critical-delivery.md item 5).

Principles defined (10):
  I.    Specification First
  II.   Source of Truth Hierarchy
  III.  Repository Separation            (NOT APPLICABLE — single repository; number kept)
  IV.   Architecture Consistency
  V.    Domain Invariants                (docs/domain/booking-invariants.md)
  VI.   Security
  VII.  External Integration Governance
  VIII. Testing Requirements
  IX.   Human Review Requirement
  X.    Controlled Delivery

Templates requiring updates when this file changes:
  - .specify/templates/plan-template.md (Constitution Check gate must mirror the principles 1:1)
  - .specify/templates/tasks-template.md (test-policy language must not contradict Principle VIII)
  - CLAUDE.md (strict rules must not contradict this file)
  - scripts/enforcement-pack.ps1 (encodes constitutional constants — batch-phase cap,
    Critical cooling-off hours, the Gate Certification legal values `user-run`/`ci-held`
    and the Critical ci-held exclusion, the Micro-lane bounds (territory-file cap 5,
    phase-line hard bound 400, single-phase rule), the Delivery Level legal values, the four
    Level Rationale trigger keys and the `**Rationale Rule**` marker value)
  Kit-owned (verbatim) files among these change only through the kit update channel
  (adoption/updating.md); a project amendment touching their constants is reported to the
  kit rather than patched locally.

Follow-up TODOs: none.
-->

# booking-api Constitution

## Core Principles

### I. Specification First

All work MUST begin with specification and planning before implementation. The required
workflow is: (1) create or update `spec.md`; (2) create or update `plan.md`; (3) create or
update `tasks.md`; (4) implement one approved phase only; (5) run the project gate; (6) review
changes; (7) commit the approved phase. Implementation MUST NOT start before requirements are
documented.

**Micro arm**: a feature declared **Micro** (Principle X, Micro lane) satisfies this
principle with an approved **single-page mini-spec** — its `spec.md`, authored from
`.specify/templates/micro-spec-template.md` — alone: steps (2) and (3) are skipped, and no
`plan.md` or `tasks.md` exists while the feature remains Micro. Every other step is
unchanged. Absent a Micro declaration, the full workflow above applies.

**Rationale**: Documented intent prevents rework, makes review meaningful, and ties every code
change to an approved requirement. The Micro arm keeps all of that — intent is still written
and approved before implementation — while dropping only the planning ceremony that adds
nothing to a change small enough to fit the lane's machine-policed bounds.

**Amendment authority**: once a feature's `spec.md` or `plan.md` has been approved, any
later change to that feature's `spec.md`, `plan.md`, `tasks.md` or `contracts/` — a new
package, a changed value, an added phase, a widened Territory, a reinterpreted contract
clause — MUST record who approved it. The amended section carries an
`**Amendment approved by**: <name>, <YYYY-MM-DD>` line, and the amendment commit names the
same approver. **An implementing agent MUST NOT approve its own amendment.** Amending
before implementing satisfies the sequence; it does not satisfy this rule.

**Progress is not amendment**: a change to `tasks.md` that alters nothing but task
completion state — a checkbox moving in **either** direction — records progress against work
already approved and requires no approver. Un-ticking is progress too: it records that work
proved incomplete, and changes nothing about what was agreed. Every other change to an
approved document is an amendment, including any task whose **text** changes — re-worded,
re-scoped, or annotated. The test is the text, not the intent behind it: an annotation is an
amendment because it changes what the document says, and no reader has to judge why. This
exemption is
part of the rule rather than a detail of whatever grades it: without it the rule would demand
an approval for finishing a task, and a rule that is absurd in its commonest case is one
people route around.

**What can be verified, and what cannot**: a machine can grade that a record exists, is
well-formed, and names the same approver as the commit carrying it. Three things it cannot.
It cannot verify that the named person agreed — on a solo project the approver will be the
same human who drove the session. It does not enforce the self-approval prohibition: the kit records no
link between a commit and the session that produced its diff, so **that half of this rule is
held by review alone**, and saying otherwise would be the pretence this clause exists to
remove. And it does
not observe approval — a document counts as approved once it exists, because this kit has no
separate approval token; the proxy is deliberate and it is the reason a document's first
appearance owes no record. What the rule buys is that an amendment is now *visible in the
diff and gradeable*, not that consent is proven: a determined implementer can still write a
name. The record is a written claim a reviewer can falsify — the strength of the Reviewer
Provenance block, which `docs/sdlc/critical-delivery.md` describes the same way about its
team arm.

**Rationale**: added after the 2026-09-10 AI review of an adopting project's feature 001
(governance finding F3) found that every amendment following that feature's single owner
approval had been written by the implementing session and implemented against minutes later
— twenty-nine seconds, in one case — with no approver anywhere. Five rule changes: a new
package, a changed contract value, two widened Territory blocks, an added phase. No machine
check caught it, because `scripts/scope-check.ps1`, `scripts/scope-check-repos.ps1`,
`scripts/enforcement-pack.ps1` and `scripts/doc-lint.ps1` grade paths, tokens and dates, and
none of them grades authority — so an agent that widens its own Territory passes the scope
check by construction, because the check reads the Territory that same agent just wrote.
Every one of those amendments happened to be correct, which is exactly why the mechanism
would have survived one that was not. Getting the order right — amend, then
implement — is a check on retroactivity, not a check on consent, and the two had been
quietly conflated.

### II. Source of Truth Hierarchy

The following order of precedence MUST always be respected:

1. `spec.md`
2. `plan.md`
3. API contracts
4. Data model
5. `tasks.md`
6. Research documents
7. Notes

booking-api is a REST API with no UI: it has no visual-reference or UI-guidelines rungs. If
a UI is ever added, those rungs are restored above `spec.md` by amendment.

If a higher rung and a lower rung conflict, implementation MUST stop and the conflict MUST be
reported. Lower-fidelity artifacts MUST NOT silently override higher-fidelity intent.

**Rationale**: A single, ordered source of truth removes ambiguity and prevents lower-fidelity
artifacts from silently overriding higher-fidelity intent.

### III. Repository Separation

**NOT APPLICABLE** — booking-api is a single repository: this repository is the only
repository. The principle keeps its number so that every citation of principles IV–X in the
kit's documents and scripts stays correct. If a second repository is ever added, this
principle is re-ratified with its content by amendment before that repository receives code.

**Rationale**: Deleting and renumbering would silently re-point every numbered citation in
kit-owned files; a stub keeps one numbering everywhere.

### IV. Architecture Consistency

The existing architecture is the source of truth. New features MUST follow the existing
architecture. New architectural patterns, new frameworks, new UI libraries, and new persistence
approaches MUST NOT be introduced unless explicitly approved in the technical plan.

**Bootstrap clause**: at project creation there is no existing architecture to follow. During
the initial scaffold feature (the project's first numbered feature — see
`adoption/greenfield.md`, step 4), "the existing architecture" means the architecture selected
and approved in that feature's `plan.md`, which MUST record the decision ADR-style: options
considered, the decision, and its consequences. Once the scaffold feature is merged, that
architecture becomes the existing architecture and this principle applies in full.

**Rationale**: Consistency lowers maintenance cost and keeps the system reviewable by the whole
team. Without the bootstrap clause, "follow the existing architecture" is undefined on an empty
repository — the clause anchors the rule to an approved plan instead of leaving the agent to
improvise one.

### V. Domain Invariants

The non-negotiable rules of this project's domain are defined in
`docs/domain/booking-invariants.md` and carry constitutional force. Agents
and reviewers MUST treat a domain-invariant violation exactly like a violation of this file.

**Rationale**: Every serious domain has rules that must survive any refactor (immutability of
postings, consent trails, order-state machines). Naming them once, with constitutional force,
stops an agent from "creatively" violating them.

### VI. Security

Authentication is required for protected functionality. Authorization is required for protected
operations. Secrets MUST NEVER be stored in source code. Sensitive information MUST NOT be
logged. All external integrations MUST use secure authentication mechanisms.

**Rationale**: Security controls are non-negotiable architecture concerns, not cleanup tasks.

### VII. External Integration Governance

All external integrations require documented contracts. Each contract MUST define purpose,
authentication, endpoints, request schema, response schema, error schema, timeout policy, retry
policy, idempotency strategy, and audit requirements. Undocumented integrations are prohibited.

**Rationale**: Documented contracts make integrations testable, recoverable, and safe to change.

### VIII. Testing Requirements

Business-critical functionality requires automated tests. Business-critical calculations require
deterministic validation (golden fixtures where outputs must be exact). Changes affecting
business-critical logic require regression coverage.

**Rationale**: Deterministic, regression-covered tests are the only credible guarantee that
critical logic remains correct across changes — especially changes made by an AI agent.

### IX. Human Review Requirement

AI review alone is insufficient. Human review is required before merge. Human reviewers MUST
verify business requirements, domain correctness, security implications, visual-reference
compliance (where visual references exist), and architectural compliance.

**Rationale**: Business and architectural correctness require human accountability that
automated review cannot replace.

### X. Controlled Delivery

Work MUST be delivered incrementally. Only one approved phase MAY be implemented at a time.
Unrelated changes MUST NOT be included in the same feature implementation. Every completed phase
MUST pass project gates — run by the user, with the exit code confirmed by the user — before
proceeding. An AI agent MUST NOT claim success without that confirmation.

**Batched gates**: for a Lite or Standard feature, the approved plan MAY declare — before the
batch's first phase is implemented, as `**Gate Batching**: phases N-M` in `plan.md` — that a
run of at most **3 consecutive phases** shares one certifying user-run gate at the end of the
batch. Within a batch, every phase still requires its own commit, its own scope check, and its
own AI review, and the agent still runs the gate per phase for feedback; only the user-run
certification moves to batch end. Critical features MUST NOT declare batches — their per-phase
user-run gate obligation is unchanged. Absent a declaration, the per-phase user-run gate above
applies in full.

**CI-held certification**: for a Lite, Micro, or Standard feature, the approved plan MAY
declare — as `**Gate Certification**: ci-held` in `plan.md` (for a Micro feature: in its
approved mini-spec `spec.md`, the lane's only specification document), before the first
phase it governs — that
gate certification is satisfied by the owner's **recorded approval on the evidence triplet**:
the CI run of the project gate on the **exact phase commit** (for a declared batch, the
batch-end commit), cited by run URL, green conclusion, and commit sha, recorded in the
feature's phase record. The approval is per phase (or per declared batch), never blanket;
a run on any other commit certifies nothing; the agent's obligations are unchanged — it
MUST NOT claim success, and under this mode it reports the evidence and requests the
owner's approval on it. The user-run gate remains lawful always. Critical features MUST NOT
declare or use CI-held certification. Absent a declaration, the value is `user-run` — the
gate law above applies in full.

**Micro lane**: a numbered feature MAY be declared **Micro** — `**Delivery Level**: Micro`
in its `spec.md` — when it fits the lane's bounds. A Micro feature has **exactly one
phase**; its specification is the approved single-page mini-spec (Principle I, Micro arm),
which carries the feature-global **Territory** block and, optionally, a
`**Gate Certification**` declaration; it MUST NOT declare `**Gate Batching**` (one phase —
nothing to batch). The measurable bounds are hard: the declared Territory covers at most
**5 files** (the feature's own `specs/NNN-name/**` excluded), and the phase changes at
most **400 lines in total** — counted across every commit carrying its `phase N` token,
so remediation commits cannot split the bound — a failure for Micro where other lanes
get a per-commit warning. The
non-measurable bounds — no schema or migration, no new packages, no architecture change,
no domain-invariant surface, no visual-reference UI — are affirmed in the mini-spec's
eligibility checklist and verified in human review. Every verification layer is unchanged:
user-held gate certification, the machine scope check (Territory read from `spec.md`),
fresh-context AI review, and human review at merge. Critical features MUST NOT use the
Micro lane. Absent a `**Delivery Level**` declaration, a numbered feature is Standard.
When work outgrows any bound, the feature is **promoted in place to Standard**: `spec.md`
is expanded to the full template (level re-declared Standard) and `plan.md` + `tasks.md`
are added (Territory moves under the phase headings), in a commit made **before** any
further phase commit; promotion is one-way and all-or-nothing.
`scripts/enforcement-pack.ps1` fails a Micro branch that violates any of these bounds.

**Level declaration**: the level a feature declares is a written claim, and the kit grades
it. A numbered feature's `spec.md` carries a **Level Rationale** that answers each of the
four triggers in `docs/sdlc/critical-delivery.md` — `domain-invariants`, `irreversible-data`,
`authn-authz-payment`, `auditable-evidence` — with *applies* or *does not apply* and a reason;
a Standard feature MUST NOT answer *applies* to any of them, and a Critical feature MUST
answer *applies* to at least one or state why it is Critical regardless. A project MAY
declare **critical surfaces** — path globs, repo-prefixed in a multi-repo project — in its
adoption record. A Standard or Micro feature whose Territory intersects a critical surface
MUST be promoted to Critical, narrow its Territory, or carry a **Surface Exception**: a
per-path statement with a recorded approver, which an implementing agent MUST NOT give to
itself. A Critical feature is never failed by this floor. A project that declares no surfaces
is unaffected, and the floor is then reported as not armed. A specification that carries the
rule's marker (`**Rationale Rule**: 1`, stamped by the spec template) owes the Level
Rationale; one that predates the rule does not. `scripts/enforcement-pack.ps1` grades all of
this. **What a machine cannot verify**: that a rationale is true — an owner can write *does
not apply* — or that a named approver agreed; the self-approval prohibition is held by review
alone, as in Principle I. And one evasion is accepted by design: a specification can omit
the marker, as it can omit its `**Delivery Level**` and read as Standard. The omission shows
in the diff, and the surface floor does not depend on the marker. What the rule buys is that
the decision which selects every other rule's rigour becomes a claim in writing that a
reviewer can falsify, with a floor under it for the case a claim cannot see.

**Rationale**: Small, gated increments keep changes reviewable, reversible, and low-risk; the
user-held exit code keeps the trust boundary human. Batching trades gate frequency — never
per-phase revertibility or review — for fewer owner interruptions on low-risk work, and only
when declared in an approved plan. CI-held certification moves the owner's approval input
from "I ran it" to "I read unforgeable evidence" — the agent cannot mint a green run on a
host it does not control — without ever removing the human approval itself; the trust
boundary stays human, asynchronously. The Micro lane trades specification ceremony — never
verification — for speed on provably small work: every measurable bound is machine-policed,
and outgrowing a bound forces promotion to Standard rather than quiet stretching.

## Governance

This constitution supersedes all other development practices. When any rule, document, or
generated artifact conflicts with this constitution, the constitution prevails. This file is the
project's ONLY constitution — do not create a second copy elsewhere in the repository; other
documents may point here.

**Amendment procedure**: Amendments MUST be proposed as a documented change to this file,
including rationale and impact on dependent templates (`plan-template.md`, `spec-template.md`,
`tasks-template.md`) and runtime guidance (`CLAUDE.md`, `docs/`). An amendment is adopted only
after human approval. Update the SYNC IMPACT REPORT header with every amendment.

**Versioning policy**: This constitution is versioned using semantic versioning.
MAJOR — backward-incompatible governance or principle removals or redefinitions.
MINOR — a new principle or section is added, or guidance is materially expanded.
PATCH — clarifications, wording, and non-semantic refinements.

**Compliance review**: All specs, plans, tasks, pull requests, and reviews MUST verify
compliance with these principles. The Constitution Check gate in `plan-template.md` MUST be
evaluated before Phase 0 research and re-evaluated after Phase 1 design. Any violation MUST be
justified in the plan's Complexity Tracking section or the work MUST stop and be reported. Use
`CLAUDE.md` and the `docs/` guidance files for runtime development guidance.

**Version**: 1.0.0 | **Ratified**: 2026-10-18 | **Last Amended**: 2026-10-18
