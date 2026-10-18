# Notes: 002-resource-catalog

Evidence and observations. Ungraded by design (`docs/sdlc/branch-strategy.md`): recording it
never costs an approval.

## Phase 1

- **Test-first**: the tests were written against a signature-only skeleton whose `Create`
  throws: 18 of 19 failed (the 19th is the existing dependency-rule test). Implementation
  then made them pass. After remediation: 24 Domain tests, 39 across the solution.
- **Review F1 fixed** (phase 1 remediation commit): `CreateResourceResult` is built only by the
  factory (private constructor, internal `Success`/`Failure`), so a result with both a value
  and errors, or neither, cannot exist; the error list is a read-only copy.
- **Review F3, F4, F6 fixed**: tests pin trimming of NBSP, U+3000 and control whitespace;
  headers cite the contract; failure tests assert a null `Value`.
- **Review F2 (CONFIRM, for phase 3): `CK_Resources_Name_Trimmed` in `data-model.md` is
  weaker than documented.** Verified by `SELECT` on LocalDB (nothing created): `N'Room A '`
  (trailing space) and a tab-padded name both satisfy `Name = LTRIM(RTRIM(Name))`; only a
  leading space is rejected. T-SQL `=` ignores trailing spaces and `LTRIM`/`RTRIM` trim
  only plain spaces. The domain trims all Unicode whitespace, so the domain can never
  produce a name the check rejects; the check simply does not guard what it says. A
  stronger check, `DATALENGTH(Name) = DATALENGTH(LTRIM(RTRIM(Name))) AND LEN(Name) > 0`,
  rejects leading and trailing spaces and all-space names (verified by `SELECT`), but no SQL
  expression of this kind catches tab or no-break-space padding. Fixing the approved data
  model is an amendment needing the owner's approver record; it is raised before phase 3.
- **Review F5 (owner decision)**: an empty-string description is kept as `""`, not
  normalized to null. The spec does not decide it and no test pins it.
- **Review F7 (DOC DRIFT)**: plan.md and tasks.md name the third parameter `nowUtc`; the
  code takes `DateTimeOffset now` (converted to UTC inside), which suits
  `TimeProvider.GetUtcNow()`. Phase 3 also needs a UTC converter: EF reads `datetime2` back
  with `Kind` Unspecified.
