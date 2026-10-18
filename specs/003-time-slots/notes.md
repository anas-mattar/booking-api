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
