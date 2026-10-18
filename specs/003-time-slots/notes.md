# Notes: 003-time-slots

Evidence and observations. Ungraded by design (`docs/sdlc/branch-strategy.md`): recording it
never costs an approval. Critical feature: this file also holds the audit evidence of
`docs/sdlc/critical-delivery.md` item 3 (gate command and exit code, scope-check verdict,
`git diff --stat`, review checklists).

## Phase 1

- **Test-first**: the tests were written against a throwing skeleton: 41 of 66 Domain tests failed
  (the 25 that passed are the existing Domain tests). The real implementation then made all 66 pass.
  Scoped test runs only (`dotnet test tests/BookingApi.Domain.Tests`), by the owner's ruling for this
  Critical feature (2026-10-19); the gate command itself was not run by the agent and no run is
  presented as certification.
- **Mutation checks** (restored, `git status` clean): `aStart <= bEnd` in the overlap predicate failed
  2 tests; `bStart <= aEnd` failed 3; `endUtc < startUtc` (allowing an empty interval) failed 1.
- **Scoped strict build**: `dotnet build src/BookingApi.Domain --warnaserror` - 0 warnings, 0 errors.
- **Scope check**: `scope-check: PASS phase 1 commit 36ad545 (3 file(s))`.
- **Diff stat** of the phase commit `36ad545`:

  ```text
   src/BookingApi.Domain/TimeSlot.cs                  | 113 +++++++++++++++++++
   tests/BookingApi.Domain.Tests/SlotIntervalTests.cs |  46 ++++++
   tests/BookingApi.Domain.Tests/TimeSlotTests.cs     | 116 +++++++++++++++++++
   3 files changed, 275 insertions(+)
  ```

- **Design note**: `CreateTimeSlotResult` follows `CreateResourceResult` (private constructor, internal
  `Success` and `Failure`, read-only error copy). The overlap rule lives in `SlotInterval.Overlaps`;
  `TimeSlot.Overlaps` delegates to it, and phase 2's fake repository and phase 3's trigger must state
  the same rule.

### Phase 1 gate run - NOT certified (owner, 2026-10-19)

Owner-run gate on commit `b33164b` (phase 1 is `36ad545`): `dotnet build BookingApi.slnx
--warnaserror && dotnet test BookingApi.slnx --no-build`, **`EXIT: 1`**: 181 tests, 179 succeeded, 2
failed, "Build failed with 2 error(s)". The two failing tests were not identified in the output the
owner pasted (it showed only the expected duplicate-name log of the concurrency test).
Agent scoped runs afterwards (not certification): Domain 66, Application 27, Infrastructure 26, Api
62, all passing (181 of 181), so the two failures were not reproduced on the agent's machine. The
failing test names are needed from the owner's run before any cause is claimed.

### Phase 1 review (fresh-context agent)

Verdict APPROVE with follow-ups, no blocker or major finding; all five invariants walked item by
item in `ai-code-review-phase1.md` (invariant 2 exercised; 1, 3, 4 cannot yet be exercised, no
booking exists; 5 prepared). Thirteen mutations applied, twelve caught.

- **F1 fixed**: `TimeSlot.Overlaps` was under-tested (passing `start` as the end still passed). Now a
  nine-row hand-worked theory and a one-tick test; three wrapper mutants (`start,start`, `end,end`,
  `StartUtc,StartUtc`) each fail 4 tests. 75 Domain tests.
- **F2 (carry to phase 2 review)**: `SlotInterval.Overlaps` does not check `DateTimeKind` or
  `start < end`, and `Create` does not validate `resourceId`; every caller must pass UTC values that
  came from `Create`.
- **F3 (carry to phases 2 and 3)**: the Domain predicate ignores retirement; the rule that retired
  slots do not block lives in the repository port (phase 2) and the trigger (phase 3).
- **F4 (accepted)**: tick precision matches `datetime2(7)`.
- **F5 (accepted)**: the test-first claim rests on the agent's report of the skeleton run (41 of 66
  failed); it cannot be re-verified from git history because the skeleton was never committed.

### Phase 1 gate certification

Gate 3 certified (user-run, Critical: human-executed): `dotnet build BookingApi.slnx --warnaserror &&
dotnet test BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (190 of 190
tests passed), on commit `f2a7a77` (phase 1 is `36ad545`, remediation `f2a7a77`) - anas.m, 2026-10-19.
The earlier run on `b33164b` (`EXIT: 1`, 2 failures, names not captured) was not reproduced: CI was green
on that commit and the agent's scoped runs passed, so it is recorded as an unexplained, possibly flaky,
local failure, not as a defect found. If it recurs, capture the failing test names.

## Phase 2

- **Test-first**: the tests were written against a skeleton whose handlers throw: 37 of 64 Application
  tests failed (the 27 that passed are the existing Application tests). The real handlers then made
  all 64 pass. Scoped test runs only (`dotnet test tests/BookingApi.Application.Tests`); the gate
  command was not run by the agent and no run is presented as certification.
- **Mutation checks** (ten, restored; the committed source was re-built and re-tested afterwards: 64
  pass, 0 warnings): removing the overlap check failed 6 tests; swapping the store's `Overlaps` answer
  for `Opened` failed 1; removing the resource check failed 2; checking overlap on resource 0 failed 6;
  not forwarding the token to `GetAsync` failed 1 and to `AddAsync` failed 1; a maximum page size of
  102 failed 1; listing resource 0 failed 4; using the wall clock instead of `TimeProvider` failed 1;
  removing the validity check failed 2.
- **Scoped strict build**: `dotnet build src/BookingApi.Application --warnaserror` - 0 warnings,
  0 errors.
- **Scope check**: `scope-check: PASS phase 2 commit b8ac1aa (7 file(s))`.
- **Diff stat** of the phase commit `b8ac1aa`:

  ```text
   src/BookingApi.Application/Slots/ISlotRepository.cs   |  58 ++++
   src/BookingApi.Application/Slots/Outcomes.cs          |  32 +++
   src/BookingApi.Application/Slots/SlotHandlers.cs      |  92 ++++
   .../Slots/GetSlotHandlerTests.cs                      |  67 +++
   .../Slots/ListSlotsHandlerTests.cs                    | 121 ++++
   .../Slots/OpenSlotHandlerTests.cs                     | 154 +++++
   .../Slots/TestDoubles.cs                              |  99 +++
   7 files changed, 623 insertions(+)
  ```

- **Design notes**: the resource is checked before anything else in all three handlers, so an unknown
  resource is 404 even when the instants or the paging would also be invalid; the API parses and
  rejects unparsable text before calling a handler (phase 4), so a request that cannot be parsed is 400
  regardless. The "resource not found" outcome has a type per use case (a record has one base type),
  named `OpenSlotResourceNotFound`, `GetSlotResourceNotFound`, `ListSlotsResourceNotFound`; plan.md
  used the informal name `ResourceNotFound`. `ListSlotsHandler` reuses the paging constants of
  `ListResourcesHandler`. The port states the phase 1 review follow-ups F2 and F3: instants arrive as
  UTC values from `TimeSlot.Create`, and retired slots are invisible and never block.

### Phase 2 gate certification

Gate 3 certified (user-run, Critical: human-executed): `dotnet build BookingApi.slnx --warnaserror &&
dotnet test BookingApi.slnx --no-build` run by anas.m from the repository root, `EXIT: 0` (227 of 227
tests passed), on the phase 2 code of commit `b8ac1aa` (branch tip `f1a3fc4` when run) - anas.m,
2026-10-19. Recorded before the phase 2 AI review returned: any code change that review causes needs a
new gate run.
