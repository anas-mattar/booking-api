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
