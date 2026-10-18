<#
.SYNOPSIS
    Enforcement pack: mechanically checks the kit's delivery-level non-negotiables.

.DESCRIPTION
    Converts previously-prose rules into CI-agnostic checks, run against the current
    branch's diff versus main:

      - Structure       (NNN-* branches): spec.md/plan.md/tasks.md exist; Delivery Level
                         header, when present, is filled with Lite, Micro, Standard, or
                         Critical (not the template placeholder), read from VISIBLE text
                         (a commented-out decoy never sets the lane). A Micro feature
                         requires spec.md only (constitution X, Micro lane — the
                         mini-spec is the lane's whole specification).
      - MicroLane       (NNN-* branches declared Micro): exactly one phase (distinct
                         'phase N' numbers on the branch), no plan.md/tasks.md in the
                         tree (promotion is all-or-nothing), a **Territory** block of at
                         most $Config.MicroTerritoryMaxFiles literal file entries (no
                         globs — a glob defeats the cap), at most
                         $Config.MicroPhaseMaxLines changed lines in TOTAL across the
                         phase's commits (a hard failure where other lanes get a
                         per-commit PhaseSizeWarning — summed so remediation commits
                         cannot split the bound), and no '**Gate Batching**'
                         declaration (one phase — nothing to batch). Every failure names
                         the promotion remediation (constitution X, Micro lane).
      - LevelSurface     (NNN-* branches declared Standard or Micro; feature 017, constitution X
                         Level declaration): the machine floor under the written claim of the
                         delivery level. The project names its critical surfaces, path globs, in
                         the 'criticalSurfaces' array of kit-adoption.json; a Territory entry
                         that reaches one fails, unless the spec carries an approved Surface
                         Exception for that exact path. Territory is read from tasks.md (the
                         union of every phase) or, for Micro, from spec.md, and compared by
                         literal prefix, which over-reports by design. A Critical feature is
                         never failed here. A project that declares nothing sees ONE
                         informational line and no change of verdict. Every way the check
                         cannot grade - an unusable or unreadable record, a Territory it cannot
                         read - adds an UNGRADED line instead of passing.
      - LevelRationale   (NNN-* branches declared Standard or Critical; feature 017): the
                         written half of the level claim. A spec carrying '**Rationale Rule**: 1'
                         (the spec template stamps it) answers the four Critical triggers in a
                         '## Level Rationale' section, each 'applies' or 'does not apply' with a
                         reason; the check fails an absent or incomplete section, a Standard spec
                         that answers a trigger 'applies', and a Critical spec that answers every
                         trigger 'does not apply' with no '**Critical because**' reason. A spec
                         without the marker predates the rule and is exempt. It is a claim a
                         reviewer can falsify, not proof that the claim is true.
      - LiteAndAbuse     (fix/*, chore/* branches): no changed file matches a prohibited
                         category (dependency manifest, auth, schema/migration, contracts,
                         domain invariants); migrations are always prohibited on this lane
                         regardless of file count; more than $Config.AbuseGuardFileCount
                         changed files fails as well, suggesting promotion to a feature.
      - CriticalEvidence (NNN-* branches declared Critical): the independence evidence
                         docs/sdlc/critical-delivery.md item 5 requires, in one of two
                         MODES selected by the 'developers' array in kit-adoption.json.
                         SOLO (one developer declared, or nothing usable declared):
                         second-model-review.md exists and was first committed at least
                         $Config.CoolingOffHours ago — the solo substitute, unchanged.
                         TEAM (two or more declared): human-pr-review.md carries a filled
                         '## Review Provenance' block naming a Reviewer who is not the
                         Owner, plus the verbatim attestation; no cooling-off applies,
                         because the independence is real rather than substituted.
                         Absence of any kind selects SOLO — the stricter branch — so a
                         project that declares nothing keeps the behaviour it has today.
                         The team artifact is read from the COMMITTED blob, never the
                         working tree: uncommitted edits are not evidence.
                         How strong is TEAM? Two names written by the same team, in one
                         file: it converts a silent omission into a written claim a human
                         reviewer can falsify, and it is worth exactly that much — the
                         strength of the Reviewer Provenance block, no more (FR-007). The
                         declared roster is COUNTED to pick the mode and is never compared
                         against either name.
      - PhaseSizeWarning (NNN-* branches): non-blocking warning when a single commit's
                         diff exceeds the configured line/file thresholds.
      - GateCertification (NNN-* branches): the '**Gate Certification**' declaration —
                         read from plan.md, or from spec.md when the feature is Micro
                         (the lane has no plan.md; constitution X, Micro lane) — when
                         present, must be 'user-run' or 'ci-held', and 'ci-held' is
                         prohibited on Critical features (constitution X, CI-held
                         certification; docs/sdlc/critical-delivery.md item 4). An
                         absent line means 'user-run' — plans from before the clause
                         remain valid.
      - ReviewProvenance (all recognized lanes): every specs/**/ai-code-review*.md ADDED
                         (or arriving as a rename target) in the branch's diff must carry
                         a '## Reviewer Provenance' section whose OWN Reviewer line is
                         filled and is neither the implementer nor an unfilled
                         placeholder, plus the verbatim non-implementer attestation
                         (DoD gate 5, feature 006). Pre-existing reviews at their
                         historical paths are grandfathered by construction.
      - GateBatching     (NNN-* branches): the plan.md '**Gate Batching**' declaration,
                         when present, must be 'none' or 'phases N-M' spanning at most
                         $Config.MaxBatchPhases consecutive phases, and is prohibited
                         outright on Critical features (constitution X, Batched gates;
                         docs/sdlc/critical-delivery.md item 4). An absent line means
                         'none' — plans from before the clause remain valid.

    THE UNGRADED STATE (feature 015, FR-009/FR-022). A check in this pack can RUN AND FORM NO
    OPINION: there is no integration branch to diff against (a shallow clone is the usual
    cause), or the commit range it was handed holds no commits. That is not a pass. It is not
    a failure either - but AmendmentAuthority, the one check that must never be silent about an
    amendment, FAILS rather than going ungraded on a missing base, on a shallow clone, and on
    commits it cannot read. Such a check adds a line to
    $ungraded, every one of those lines is printed as 'UNGRADED: <what>', and the run ends on
    'enforcement-pack: UNGRADED (N check(s) formed no opinion)' instead of 'OK'.

    It is a VERDICT change and not an exit-code change: the run still exits 0, deliberately and
    on the record (feature 015 plan D6, FR-011), because feature 014's FR-009 forbids a new hard
    failure on the Lite lane and that constraint stands. What changes is that nobody can read
    such a run as clean. Whether UNGRADED should ever block is a later feature's question, with
    its own evidence; it is not answered here by the back door.

    A run can be both FAIL and ungraded. The UNGRADED lines are printed before the verdict and
    independently of it, the way warnings are, because a reader needs to know that the failure
    count is not the whole story. The word for the whole vocabulary — OK, FAIL, WARN, N/A,
    UNGRADED, PENDING — is defined once, in scripts/ritual-checks.ps1.

    See specs/002-enforcement-pack/research.md for the rationale behind every default below.

.EXAMPLE
    pwsh -File scripts/enforcement-pack.ps1
    pwsh -File scripts/enforcement-pack.ps1 -Branch fix/my-branch
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Branch,
    # ANALYSIS ONLY (014 plan D2c): lift the amendment-authority boundary so the check grades
    # commits made before it existed. Used to replay the check over real history (SC-002).
    # No gate, no CI workflow and no ritual-checks invocation passes this — enforcement stays
    # bounded by D2b. Passing it in a gate would grade commits nobody could have complied with.
    [switch]$IgnoreAmendmentBoundary,
    # ANALYSIS ONLY (014 plan D2c), like -IgnoreAmendmentBoundary: grade an explicit commit
    # range instead of the branch's own. Used to replay the amendment check over history it
    # does not govern (SC-002, SC-004). No gate, CI workflow or ritual-checks invocation
    # passes these; with both empty the check reads the branch exactly as before.
    [string]$ReplayBase,
    [string]$ReplayTip
)

$ErrorActionPreference = 'Stop'
# git emits UTF-8 paths (quotepath is disabled where needed); align pwsh's native-output
# decoding so non-ASCII filenames round-trip on Windows consoles too (phase 2 review, F2).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}
$Root = (Resolve-Path $Root).Path
. (Join-Path $PSScriptRoot 'adoption-lib.ps1')
# Territory parsing comes from the same file scope-check.ps1 uses (feature 015, T020a).
# It used to be a copy here, and phase 2 widened one and not the other: a decorated marker
# left the Micro file cap, the duplicate check and the glob check all passing vacuously
# while scope-check enforced the very same block. Nothing in this file may parse that
# marker again.
. (Join-Path $PSScriptRoot 'scope-lib.ps1')
Push-Location $Root
try {

$Config = @{
    DependencyManifestGlobs = @('package.json', 'package-lock.json', '*.csproj', 'requirements*.txt', 'Pipfile*', 'go.mod', 'go.sum', 'Gemfile*')
    AuthPathGlobs           = @('*auth*')
    SchemaMigrationGlobs    = @('*migrations*', '*migration*.sql', '*migration*.ps1', '*migration*.py')
    ContractsGlob           = '*contracts*'
    DomainInvariantsPath    = '{{DOMAIN_INVARIANTS_PATH}}'
    AbuseGuardFileCount     = 25
    CoolingOffHours         = 24
    PhaseWarnLines          = 400
    PhaseWarnFiles          = 15
    MaxBatchPhases          = 3
    # Micro-lane bounds — constitutional constants (constitution X, Micro lane; sync-listed
    # in the constitution's mirror list — change only in lockstep with an amendment).
    MicroTerritoryMaxFiles  = 5
    MicroPhaseMaxLines      = 400
    MicroMaxPhases          = 1
}

$failures = @()
$warnings = @()
# The third accumulator, and the one this feature exists to add. A member appends here when it
# RAN AND FORMED NO OPINION - not a pass, not a warning, and not 'does not apply'. See the
# verdict vocabulary in scripts/ritual-checks.ps1. It never changes the exit code (plan D6).
$ungraded = @()
$script:AmendRollupPrinted = $false   # feature 027: set when AmendmentAuthority printed its roll-up line

function Get-CurrentBranch {
    param([string]$Override)
    if ($Override) { return $Override }
    (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
}

# The merge base of HEAD with the integration branch. git's own exit codes tell "there is none" from "could not read":
# rev-parse --verify --quiet exits 1 for a missing ref and merge-base exits 1 for no shared history (both answers, handled
# as before), and any other non-zero exit is a failure to read, kept in $script:DiffBaseFailure when no candidate gave a
# base, so the messages can name the cause (feature 035, GAP-041; the recipe of feature 034). A later candidate's base wins
# over an earlier failure.
function Get-DiffBase {
    $script:DiffBaseFailure = $null
    $failed = $null
    $candidates = @('origin/main', 'main')
    foreach ($c in $candidates) {
        git rev-parse --verify --quiet $c *> $null
        $verifyExit = $LASTEXITCODE
        if ($verifyExit -eq 1) { continue }
        if ($verifyExit -ne 0) { if (-not $failed) { $failed = "git rev-parse of $c failed with exit $verifyExit" }; continue }
        # No .Trim() on the bare call: `merge-base` prints nothing when the two histories
        # share no commit — a truncated clone that still carries origin/main — and the
        # method call on null killed the whole pack before any member ran. The exit code is read on the next
        # statement, before the filter below can reset it.
        $mergeBaseOut = git merge-base HEAD $c 2>$null
        $mergeBaseExit = $LASTEXITCODE
        $base = @($mergeBaseOut | Where-Object { $_ })
        if ($mergeBaseExit -eq 0 -and $base.Count -gt 0) { return $base[0].Trim() }
        if ($mergeBaseExit -ne 0 -and $mergeBaseExit -ne 1) { if (-not $failed) { $failed = "git merge-base failed with exit $mergeBaseExit" } }
    }
    $script:DiffBaseFailure = $failed
    return $null
}

# Feature 028 (GAP-034, plan D1): the one place the pack reads a `git diff` it grades. A diff git
# cannot compute (an unreadable tree or commit on the branch) exits non-zero; reading that as an empty
# list made a damaged branch look like an empty one. The exit code is captured in the statement that
# follows the call, before any pipeline can reset it, and a failing diff returns NO lines whatever git
# printed, so a partial list is never graded.
function Read-DiffLines {
    param([string[]]$GitArguments)
    $lines = @(& git @GitArguments 2>$null)
    $code = $LASTEXITCODE
    if ($code -ne 0) { return @{ Ok = $false; Lines = @(); Exit = $code } }
    return @{ Ok = $true; Lines = @($lines | Where-Object { $_ }); Exit = 0 }
}

# Feature 028 (plan D3): what an unreadable diff does, by lane. The numbered lane keeps its refusals as
# failures (once per run: a second reader of the same damage adds no second line); the Lite lane
# (fix/, chore/, docs/) names each check that graded nothing UNGRADED and is never newly failed on a
# condition it cannot compute (feature 014 FR-009). git's own message is not shown: the exit code is.
$script:DiffFailureReported = $false
# Initialised so a caller that runs before Get-ChangedFiles (none does today) reads "Ok", never an
# unset value whose .Ok is falsy and would be taken for a failed read (phase 2 review F5).
$script:ChangedFilesRead = @{ Ok = $true; Exit = 0 }
function Add-DiffUnreadable {
    param([string]$Reader, [string]$Branch, [string]$Base, [int]$Exit, [string]$Consequence)
    if ($Branch -match '^\d{3}-') {
        if ($script:DiffFailureReported) { return }
        $script:DiffFailureReported = $true
        $script:failures += "DiffUnreadable: git diff against '$Base' failed on '$Branch' (exit $Exit), so $Consequence - repair the repository (a damaged object, or fetch the full history: 'fetch-depth: 0' on actions/checkout)"
    } else {
        $script:ungraded += "${Reader}: the diff of '$Branch' against '$Base' could not be read (git diff exited $Exit), so $Consequence"
    }
}

# Feature 029 (GAP-035, plan D1): the generic sibling of Read-DiffLines, for every other `git` read
# the pack grades from. A failing command returns NO lines whatever git printed (a partial result is
# never graded), and the exit code is captured in the statement after the call, before any pipeline can
# reset it. On success Lines is the output exactly as the call site received it, so a healthy read is
# byte-identical; each site applies its own filter. Read-DiffLines is left as it is: it filters empty
# entries, which the other sites do not.
function Read-GitLines {
    param([string[]]$GitArguments, [switch]$KeepPartial)
    $lines = @(& git @GitArguments 2>$null)
    $code = $LASTEXITCODE
    # -KeepPartial (feature 029 phase 2, the per-commit name-status batch only): the rows git printed for
    # the commits it finished are complete records of those commits, so the caller may grade them.
    if ($code -ne 0) { return @{ Ok = $false; Lines = $(if ($KeepPartial) { $lines } else { @() }); Exit = $code } }
    return @{ Ok = $true; Lines = $lines; Exit = 0 }
}

# Feature 029 (plan D2): what a failed git read does, by lane. On a numbered branch it is a failure
# naming the read and what graded nothing, once per reader and read per run (-Key). On the Lite lane
# (fix/, chore/, docs/), and for a check that is advisory today (-Advisory: PhaseSizeWarning, plan D3),
# it is one UNGRADED line and the exit code is unchanged (feature 014 FR-009). git's own message is not
# shown: the exit code is, so the output is deterministic.
$script:GitReadReported = @{}
function Add-GitReadUnreadable {
    param([string]$Reader, [string]$Read, [string]$Key, [string]$Branch, [int]$Exit, [string]$Consequence, [switch]$Advisory)
    $dedupe = "$Reader|$Key"
    if ($script:GitReadReported.ContainsKey($dedupe)) { return }
    $script:GitReadReported[$dedupe] = $true
    if ($Branch -match '^\d{3}-' -and -not $Advisory) {
        $script:failures += "GitReadUnreadable: $Read failed on '$Branch' (git exited $Exit), so $Consequence - repair the repository (a damaged object, or fetch the full history: 'fetch-depth: 0' on actions/checkout)"
    } else {
        $script:ungraded += "${Reader}: $Read could not be read (git exited $Exit), so $Consequence"
    }
}

# Feature 029 phase 2 (plan D2, D3, D4): the amendment check reads git in many places, deep inside
# helpers that return lists. A failed read there used to be an empty list: no name-status rows, no added
# lines, no blob content. Read-AmendmentGit goes through Read-GitLines and records the FIRST failure;
# Test-AmendmentReadFailed turns it into the check's own refusal at the next boundary of the walk, and
# the walk then stops (grading what could be read would pass an unread amendment on a wrong reason).
# The refusal begins 'AmendmentAuthority: cannot grade ', so the Lite lane converts it to UNGRADED by the
# prefix rule in Invoke-AmendmentAuthority (feature 027 D8, 014 FR-009): never a new Lite failure.
$script:AmendmentReadFailure = $null
function Set-AmendmentReadFailure {
    param([string]$Read, [int]$Exit)
    if (-not $script:AmendmentReadFailure) { $script:AmendmentReadFailure = @{ Read = $Read; Exit = $Exit } }
}
function Read-AmendmentGit {
    param([string[]]$GitArguments, [string]$Read)
    $r = Read-GitLines -GitArguments $GitArguments
    if (-not $r.Ok) { Set-AmendmentReadFailure -Read $Read -Exit $r.Exit }
    return $r
}
function Test-AmendmentReadFailed {
    param([string]$Branch)
    if (-not $script:AmendmentReadFailure) { return $false }
    $f = $script:AmendmentReadFailure
    $script:failures += "AmendmentAuthority: cannot grade '$Branch' — $($f.Read) failed (git exited $($f.Exit)), so what the branch's commits changed is unknown; grading what could be read would pass an unread amendment on a wrong reason. Repair the repository (a damaged object), or fetch the full history: 'fetch-depth: 0' on actions/checkout"
    $script:AmendmentReadFailure = $null
    return $true
}

# The changed-file list, and beside it $script:ChangedFilesRead: Ok is false only when a diff WAS
# attempted against a base and git failed. No base is a different, already-named state (the dispatch
# warns and the Lite lane says UNGRADED), so it stays Ok here and nothing is named twice.
function Get-ChangedFiles {
    param([string]$Base)
    $script:ChangedFilesRead = @{ Ok = $true; Exit = 0 }
    if (-not $Base) { return @() }
    $read = Read-DiffLines -GitArguments @('diff', '--name-only', $Base, 'HEAD')
    if (-not $read.Ok) {
        $script:ChangedFilesRead = @{ Ok = $false; Exit = $read.Exit }
        return @()
    }
    $read.Lines
}

# Plan-header declarations must be parsed from VISIBLE text only: a declaration hidden in
# an HTML comment block must never win first-match over the rendered one (008 phase 2
# review, F1 — a commented-out decoy could otherwise defeat the Critical exclusions of
# both Gate Batching and Gate Certification). Closed comment blocks are removed wholesale;
# the per-line trailing strip in each parser still handles the template's own same-line
# comment openings.
function Get-VisiblePlanLines {
    param([string]$PlanPath)
    $raw = "$(Get-Content -LiteralPath $PlanPath -Raw)"
    return ([regex]::Replace($raw, '(?s)<!--.*?-->', '')) -split "`r?`n"
}

# Delivery Level of a numbered feature, from spec.md's first VISIBLE '**Delivery Level**:'
# line — comment-stripped, so a commented-out 'Micro' (or 'Critical') decoy never sets the
# lane (contract M13; same rule as the plan-header parsers above). Returns the trimmed
# value string, '' when the file or the line is absent.
function Get-DeliveryLevel {
    param([string]$SpecPath)
    if (-not (Test-Path -LiteralPath $SpecPath)) { return '' }
    $line = (Get-VisiblePlanLines -PlanPath $SpecPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
    if (-not $line) { return '' }
    return ($line -replace '^\*\*Delivery Level\*\*:\s*', '' -replace '<!--.*$', '').Trim()
}

function Test-GlobAny {
    param([string]$Path, [string[]]$Globs)
    foreach ($g in $Globs) {
        if ($Path -like $g) { return $true }
        if (($Path -split '/') -contains ($g -replace '\*', '')) { return $true }
    }
    return $false
}

# --- Structure check (FR-002) ---
function Invoke-StructureCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    $level = Get-DeliveryLevel -SpecPath $specPath
    # A Micro feature's whole specification is the mini-spec: spec.md alone is required
    # here; MicroLane separately fails plan.md/tasks.md PRESENCE on the lane (contract M7).
    $required = if ($level -match '^Micro\b') { @('spec.md') } else { @('spec.md', 'plan.md', 'tasks.md') }
    foreach ($f in $required) {
        $p = Join-Path $dir $f
        if (-not (Test-Path $p)) {
            $script:failures += "Structure: $dir/$f is missing (every NNN-* branch requires spec.md, plan.md, and tasks.md — or spec.md alone when declared Micro; CLAUDE.md Feature Structure)"
        }
    }
    if (Test-Path $specPath) {
        $line = (Get-VisiblePlanLines -PlanPath $specPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
        if (-not $line) {
            $script:failures += "Structure: $dir/spec.md has no **Delivery Level** header"
        } elseif ($level -notmatch '^(Lite|Micro|Standard|Critical)\b') {
            $script:failures += "Structure: $dir/spec.md's **Delivery Level** header is unfilled or invalid: '$level' (legal values: Lite, Micro, Standard, Critical — constitution X)"
        }
    }
}

# --- Lite-lane prohibition + abuse guard (FR-003, FR-004) ---
function Invoke-LiteAndAbuseCheck {
    param([string]$Branch, [string[]]$ChangedFiles)
    if ($Branch -notmatch '^(fix|chore)/') { return }

    $categories = [ordered]@{
        'dependency manifest' = $Config.DependencyManifestGlobs
        'auth code'           = $Config.AuthPathGlobs
        'schema/migration'    = $Config.SchemaMigrationGlobs
        'contracts'           = @($Config.ContractsGlob)
    }
    if ($Config.DomainInvariantsPath -and $Config.DomainInvariantsPath -notmatch '^\{\{') {
        $categories['domain invariants'] = @($Config.DomainInvariantsPath)
    }

    $migrationHit = $false
    foreach ($file in $ChangedFiles) {
        foreach ($cat in $categories.Keys) {
            if (Test-GlobAny -Path $file -Globs $categories[$cat]) {
                $script:failures += "LiteAndAbuse: $Branch touches '$file', a prohibited category for the Lite lane ($cat) — promote to a numbered feature (docs/sdlc/critical-delivery.md)"
            }
        }
        if (Test-GlobAny -Path $file -Globs $Config.SchemaMigrationGlobs) { $migrationHit = $true }
    }

    if ($ChangedFiles.Count -gt $Config.AbuseGuardFileCount) {
        $script:failures += "LiteAndAbuse: $Branch changes $($ChangedFiles.Count) files, exceeding the Lite-lane abuse guard ($($Config.AbuseGuardFileCount)) — promote to a numbered feature"
    }
    if ($migrationHit) {
        $script:failures += "LiteAndAbuse: $Branch touches a migration path — migrations are always prohibited on the Lite lane regardless of file count"
    }
}

# The evidence mode comes from scripts/adoption-lib.ps1, dot-sourced above, so this check and
# the adoption doctor read the record through the SAME function. They were two copies until
# phase 5 and drifted twice inside one feature (013 phase 4 re-review, docs NEW-1).
function Get-EvidenceMode { return (Get-DeveloperMode -Root $Root) }

# --- Critical-evidence check (FR-005; modes added by 013) ---
#
# MERGE-READINESS (feature 024, GAP-022). The independence artifact cannot exist before the final
# phase is written and reviewed (definition-of-done.md item 6, "at merge"), so demanding it on
# every commit made a Critical branch red from its first commit to its last. While the branch is
# provably MID-FEATURE the check now says so with one WARN and does not fail; from the final-phase
# commit on it behaves exactly as before, and wherever mid-feature cannot be shown it stays strict
# and says why. The two arms below are not edited, so their messages cannot drift.
#
# Mid-feature means ALL of: the active arm's artifact is not committed at HEAD (one that is ends the
# pending state: whoever produced it has said the work is ready whatever the last commit was
# called, and the arm then grades it as it always did - review F1, F3); a diff base resolves and
# the clone is not shallow; the committed tasks.md has phase headings whose DISTINCT numbers are
# exactly 1..N (a repeated number such as '## Phase 1 amendment requests' invents no phase and is
# allowed; a gap is not); some commit subject carries a phase token below N ANYWHERE in it
# ('tasks: phase 4 done' counts: real branches are mostly bookkeeping commits and almost none
# begin 'phase k'); and no subject carries a token naming phase N or beyond (so 'feat: phase 3'
# is seen as final). One token reads both evidence and finality (plan D3, current reading).
# Anything else - no diff base, a shallow clone, tasks.md unreadable, no phase heading, a gap, a
# number too large to read, no phase token yet - is strict, with the reason.
#
# LIMITS, disclosed rather than hidden:
#   1. A final commit that names no phase (or one this token does not read: 'phase-3',
#      'phase: 3', 'phase 1 and 3'), on a branch with no artifact committed yet, still reads as
#      mid-feature, so a branch can stay on the WARN by not naming it.
#   2. Phases that land OUT OF ORDER, or are never named, defeat the heuristic. Measured on a real
#      Critical feature (FitForge 002): a token at or above the highest declared phase reads as
#      "final landed", so phase 11 done before phases 4 to 9 kept the branch strict for that
#      stretch; phases 14 to 16 were never named at all, so requiring every phase would have
#      wrongly warned at the tip. Strict is the safe direction: it costs relief, not safety.
# What stands behind both is gate 6, the human review at merge, which a person holds; the WARN is
# printed on every run so the pending artifact cannot be forgotten silently.
#
# DECLARATION (feature 025): a plan.md may carry '**Merge Readiness**: pending' or 'ready', which
# decides before the heuristic above is consulted and needs no history. 'pending' is a CLAIM the
# owner makes: an owner who sets it and never flips it merges with only the deferral WARN on this
# check, and gate 6 stands behind it - except, since feature 036, in the evident case: a plan that
# says 'pending' while its committed tasks.md has at least one checkbox task and none unticked
# (Get-TaskTickCount) is not treated as pending, and the arm demands the artifact. Ticks are a
# proxy for "complete", so a forgotten 'pending' beside an unticked task, or a tasks.md without
# checkbox tasks, is still only a claim. Flipping it is a plan amendment, so it carries a recorded
# approver (constitution I), a written claim a reviewer can falsify, not proof of who approved.
#   A 'pending' added inside a merge commit IS graded since feature 026: AmendmentAuthority asks of a
#   merge whether its result equals what a parent already had, or what git's automatic merge of two
#   parents makes, and grades the documents it authored like any amendment. What stays open:
#   a merge that keeps a document whole from one parent is trusted on that parent's content, EVEN
#   when the only grading that content ever had was an exemption (the commit that created the
#   file is a first appearance, or predates the check), so a conflict resolved by taking the other
#   side's version of an approved plan replaces it with no record (feature 026 review F2, recorded
#   as a limit, not a regression: before 026 every merge was skipped); an octopus merge, a git
#   older than 2.38, or a failing merge-tree is graded fail-closed (a record satisfies it); and the
#   record is still a written claim, not proof of who approved. The warning therefore still calls
#   the declaration a claim; gate 6 stands behind it.
function ConvertTo-PhaseNumber {
    # A number too large to parse is not an error: it is "beyond any declared phase" (review F2).
    param([string]$Text)
    $n = [long]0
    if ([long]::TryParse($Text, [ref]$n)) { return $n }
    return [long]::MaxValue
}

function Get-CriticalMergeReadiness {
    param([string]$Branch, [string]$Base, [string]$Artifact)
    $tasksRel = "specs/$Branch/tasks.md"
    # An artifact committed at HEAD ends the pending state (plan D3 as amended): no WARN, and the arm
    # grades it exactly as it does today. The './' is the 013 phase 5 rule: resolve against the
    # current directory, not the repository root.
    git cat-file -e "HEAD:./$Artifact" 2>$null
    if ($LASTEXITCODE -eq 0) { return @{ Pending = $false; Why = $null } }
    # An explicit declaration (feature 025, plan D1, D2) is read from the committed plan.md and
    # decides before any history is consulted, so a shallow clone, a missing tasks.md and out-of-order
    # phases cannot overrule it. 'ready' is the arm's own grading; 'pending' is the deferral warning;
    # anything else is strict with the reason. Absent, hidden (comment or fence) or unreadable falls
    # through to the heuristic below, byte for byte.
    $planBlob = @(git show "HEAD:./specs/$Branch/plan.md" 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $planVisible = @(Get-VisibleFromText -Lines $planBlob)
        $planFenced = Get-FencedLineMap -Lines $planVisible
        $declarations = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $planVisible.Count; $i++) {
            if (-not $planFenced[$i] -and $planVisible[$i] -match '^\*\*Merge Readiness\*\*:\s*(.*?)\s*$') {
                $declarations.Add($matches[1])
            }
        }
        if ($declarations.Count -gt 1) {
            return @{ Pending = $false; Why = "specs/$Branch/plan.md declares **Merge Readiness** more than once"; Marked = $true }
        }
        if ($declarations.Count -eq 1) {
            switch -CaseSensitive ($declarations[0]) {
                'ready'   { return @{ Pending = $false; Why = $null; Marked = $true } }
                'pending' {
                    # Feature 036 (GAP-022, E1): a declaration the tasks contradict is not a deferral. At
                    # least one task, and none unticked, reads the work as done; anything the check cannot
                    # read as that (no file, no task, any unticked task) leaves 'pending' exactly as 025 did.
                    $ticks = Get-TaskTickCount -Path $tasksRel
                    if ($ticks.Total -gt 0 -and $ticks.Unticked -eq 0) {
                        return @{ Pending = $false; Why = "specs/$Branch/plan.md declares **Merge Readiness**: pending but $tasksRel has all $($ticks.Total) of its tasks ticked, so the branch is treated as ready; set it to ready (an amendment with an approver record) and supply the review, or untick the work that is not done"; Marked = $true }
                    }
                    return @{ Pending = $true; Why = $null; Declared = $true; Marked = $true }
                }
                ''        { return @{ Pending = $false; Why = "specs/$Branch/plan.md declares **Merge Readiness** with no value, which is neither pending nor ready"; Marked = $true } }
                default   { return @{ Pending = $false; Why = "specs/$Branch/plan.md declares **Merge Readiness**: '$($declarations[0])', which is neither pending nor ready"; Marked = $true } }
            }
        }
    }
    if (-not $Base) {
        return @{ Pending = $false; Why = 'there is no diff base to read the branch history against, as in a shallow clone'; Marked = $false }
    }
    if ("$(git rev-parse --is-shallow-repository 2>$null)".Trim() -eq 'true') {
        return @{ Pending = $false; Why = 'this is a shallow clone, so the branch history may be incomplete'; Marked = $false }
    }
    $blob = @(git show "HEAD:./$tasksRel" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @{ Pending = $false; Why = "$tasksRel is not committed or cannot be read"; Marked = $false }
    }
    # Headings are read the way a renderer shows them: comments removed, and a heading inside a
    # fenced block is example text, not a phase.
    $visible = @(Get-VisibleFromText -Lines $blob)
    $fenced = Get-FencedLineMap -Lines $visible
    $declared = [System.Collections.Generic.List[long]]::new()
    for ($i = 0; $i -lt $visible.Count; $i++) {
        if (-not $fenced[$i] -and $visible[$i] -match '^##\s+Phase\s+(\d+)\b') {
            $n = ConvertTo-PhaseNumber $matches[1]
            if ($n -eq [long]::MaxValue) {
                return @{ Pending = $false; Why = "a '## Phase N' heading number in $tasksRel is too large to read"; Marked = $false }
            }
            $declared.Add($n)
        }
    }
    if ($declared.Count -eq 0) {
        return @{ Pending = $false; Why = "$tasksRel declares no '## Phase N' heading"; Marked = $false }
    }
    $final = ($declared | Measure-Object -Maximum).Maximum
    # DISTINCT numbers exactly 1..N: with the maximum being N and the minimum 1, N distinct values is the full set.
    # A duplicate heading ("## Phase 1 amendment requests") is allowed; a gap is not (plan D2 as amended).
    $distinct = @($declared | Sort-Object -Unique)
    $contiguous = ($distinct.Count -eq $final) -and ($distinct[0] -eq 1)
    if (-not $contiguous) {
        return @{ Pending = $false; Why = "the '## Phase N' headings of $tasksRel are not numbered 1 to N without a gap (found $((@($declared | Sort-Object)) -join ', '))"; Marked = $false }
    }
    $subjects = @(git log --format=%s "$Base..HEAD" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @{ Pending = $false; Why = "the commit subjects of '$Branch' cannot be read"; Marked = $false }
    }
    $tip = [long]0
    foreach ($s in $subjects) {
        # The final phase has landed if ANY phase token in a subject names it or beyond (plan D3 as
        # amended): 'phase 3', 'phase3', 'phase 3a' and 'phases 3' all count. The noisy direction is a
        # subject that merely mentions it early, which is strict.
        foreach ($m in [regex]::Matches($s, '(?i)\bphases?\s*(\d+)')) {
            $k = ConvertTo-PhaseNumber $m.Groups[1].Value
            if ($k -ge $final) {
                return @{ Pending = $false; Why = $null; Final = $final; Tip = $final; Marked = $false }
            }
            # The same token below N is the evidence that the branch is mid-feature at all.
            if ($k -gt $tip) { $tip = $k }
        }
    }
    if ($tip -eq 0) {
        return @{ Pending = $false; Why = 'no commit on the branch carries a phase subject yet'; Marked = $false }
    }
    return @{ Pending = $true; Why = $null; Final = $final; Tip = $tip; Marked = $false }
}

# The tasks of a committed tasks.md, as the readiness decision counts them (feature 036, plan P2): a
# visible, unfenced checkbox list item at any indent, read the way the phase-heading read above reads
# the file (comments removed, a fenced block is example text). A file git cannot read, or one with no
# such item, answers Total 0, which the caller treats as "no evidence": the rule only ever tightens on
# a positive reading. A project that does not use checkbox tasks therefore reads as zero tasks.
function Get-TaskTickCount {
    param([string]$Path)
    $total = 0
    $unticked = 0
    $blob = @(git show "HEAD:./$Path" 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $visible = @(Get-VisibleFromText -Lines $blob)
        $fenced = Get-FencedLineMap -Lines $visible
        for ($i = 0; $i -lt $visible.Count; $i++) {
            if (-not $fenced[$i] -and $visible[$i] -match '^\s*[-*+]\s+\[([ xX])\](\s|$)') {
                $total++
                if ($matches[1] -eq ' ') { $unticked++ }
            }
        }
    }
    return @{ Total = $total; Unticked = $unticked }
}
function Invoke-CriticalEvidenceCheck {
    param([string]$Branch, [string]$Base)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if (-not (Test-Path $specPath)) { return }
    if ((Get-DeliveryLevel -SpecPath $specPath) -notmatch '^Critical\b') { return }

    $mode = Get-EvidenceMode
    $artifact = if ($mode.Mode -eq 'team') { "$dir/human-pr-review.md" } else { "$dir/second-model-review.md" }
    $readiness = Get-CriticalMergeReadiness -Branch $Branch -Base $Base -Artifact $artifact
    if ($readiness.Pending -and $readiness.Declared) {
        if ($mode.Mode -eq 'team') {
            $script:warnings += "CriticalEvidence: $dir/human-pr-review.md is not yet due - $dir/plan.md declares **Merge Readiness**: pending (the owner's declaration in the plan, a claim and not a verified approval; gate 6 stands behind it) and the independent human review is owed once it is set to ready (team mode ($($mode.Why)); docs/sdlc/critical-delivery.md item 5; a WARN, not a pass)"
        } else {
            $script:warnings += "CriticalEvidence: $dir/second-model-review.md is not yet due - $dir/plan.md declares **Merge Readiness**: pending (the owner's declaration in the plan, a claim and not a verified approval; gate 6 stands behind it) and the second-model review is owed once it is set to ready (solo mode; docs/sdlc/critical-delivery.md item 5; a WARN, not a pass)"
        }
        return
    }
    # Feature 036 (plan P4): where the answer came from the commit-subject heuristic and not from a
    # declaration, the message names the declaration as the repair. A plan that carries a marker, valid or
    # not, already knows it, so it gets no suffix.
    $declareHint = if ($readiness.Marked) { '' } else { '; the plan can state the answer with **Merge Readiness**: pending or ready (docs/sdlc/critical-delivery.md item 5)' }
    if ($readiness.Pending) {
        if ($mode.Mode -eq 'team') {
            $script:warnings += "CriticalEvidence: $dir/human-pr-review.md is not yet due - the branch is at phase $($readiness.Tip) of $($readiness.Final) and the independent human review is owed once the phase $($readiness.Final) commit lands (team mode ($($mode.Why)); docs/sdlc/critical-delivery.md item 5; a WARN, not a pass)$declareHint"
        } else {
            $script:warnings += "CriticalEvidence: $dir/second-model-review.md is not yet due - the branch is at phase $($readiness.Tip) of $($readiness.Final) and the second-model review is owed once the phase $($readiness.Final) commit lands (solo mode; docs/sdlc/critical-delivery.md item 5; a WARN, not a pass)$declareHint"
        }
        return
    }
    if ($readiness.Why) {
        $script:warnings += "CriticalEvidence: not treated as mid-feature - $($readiness.Why); the independence artifact is demanded now (docs/sdlc/critical-delivery.md item 5)$declareHint"
    }
    if ($mode.Mode -eq 'team') {
        Invoke-CriticalTeamEvidence -Dir $dir -Why $mode.Why -Roster $mode.Roster
    } else {
        Invoke-CriticalSoloEvidence -Dir $dir
    }
}

# SOLO: the substitute. Moved verbatim from the pre-013 check — same order, same
# conditions, same message strings, so a solo project cannot tell this feature happened.
function Invoke-CriticalSoloEvidence {
    param([string]$Dir)
    $reviewPath = Join-Path $Dir 'second-model-review.md'
    if (-not (Test-Path $reviewPath)) {
        $script:failures += "CriticalEvidence: $dir/second-model-review.md is missing (required for Critical features — docs/sdlc/critical-delivery.md item 5)"
        return
    }
    # Feature 029 phase 3 (G11): a failed read is not "no history". The file is committed (the guard above
    # and the team arm check that), so a failing `git log --follow` is an unreadable object, and the old
    # message ("has no git history ... commit it") sent the owner to fix the wrong thing.
    $recordedRead = Read-GitLines -GitArguments @('log', '--follow', '--format=%aI', '--', $reviewPath)
    if (-not $recordedRead.Ok) {
        Add-GitReadUnreadable -Reader 'CriticalEvidence' -Read "git log --follow of $Dir/second-model-review.md" -Key 'log-follow' -Branch $Branch -Exit $recordedRead.Exit -Consequence 'the cooling-off period of the independence review could not be verified'
        return
    }
    $recorded = $recordedRead.Lines | Select-Object -Last 1
    if (-not $recorded) {
        $script:failures += "CriticalEvidence: $dir/second-model-review.md has no git history — cannot verify the cooling-off period (commit it to start the clock)"
        return
    }
    $recordedTime = [DateTimeOffset]::Parse($recorded)
    $elapsedHours = ([DateTimeOffset]::UtcNow - $recordedTime).TotalHours
    if ($elapsedHours -lt $Config.CoolingOffHours) {
        $remaining = [math]::Ceiling($Config.CoolingOffHours - $elapsedHours)
        $script:failures += "CriticalEvidence: $dir/second-model-review.md was recorded $([math]::Round($elapsedHours, 1))h ago — cooling-off requires $($Config.CoolingOffHours)h ($remaining h remaining, docs/sdlc/critical-delivery.md item 5)"
    }
}

# TEAM: the real thing rather than the substitute — item 5's actual requirement, that the
# human reviewer is not the feature's owner. No cooling-off: the period exists to give a
# solo developer distance from their own work, and a second person already is that.
#
# Three parsing rules, each of which a phase-3 fresh-context review demonstrated was needed:
#   1. The file must be COMMITTED. A Critical feature cannot use ci-held, so its authoritative
#      gate is a human's local run — precisely where an untracked file on one developer's disk
#      would otherwise satisfy the only machine enforcement of item 5. The solo arm has always
#      had this guard; the team arm shipped without it (logic review, BLOCKING 1).
#   2. HTML comments are stripped FIRST, including an unterminated one, because that is what a
#      renderer does. A provenance block wrapped in <!-- --> renders as nothing and used to
#      pass — contract M13's rule, which Get-VisiblePlanLines already states, applied here
#      (logic review, BLOCKING 2).
#   3. Both names AND the attestation are read from inside the section slice only. The document
#      header carries its own '**Reviewer**:' field (006 phase-2 F1), and matching the
#      attestation against the whole file let it be satisfied from an unrelated comment.
#
# The roster in kit-adoption.json selects the mode, and (feature 021) the Reviewer is checked
# against it: a Reviewer who is not on the roster fails, and so does one whose entry sets
# canApproveCritical to false. The Owner is not compared here. What membership proves is that the
# name is one the project declared and may approve — it catches a stranger, a typo, a person the
# record says may not judge. It does NOT prove the person is who the name says: cross-checking
# free-text names against a free-text roster reads as verification while providing little, which
# is why feature 013 declined it, and independence stays the human reviewer's to judge (021
# plan D9). Anyone who can edit the record can add a name to it; the record is reviewed code.
function Invoke-CriticalTeamEvidence {
    param([string]$Dir, [string]$Why, [object[]]$Roster = @())
    $attestation = 'This reviewer is not the owner of the feature under review.'
    $reviewPath = Join-Path $Dir 'human-pr-review.md'

    if (-not (Test-Path -LiteralPath $reviewPath)) {
        # Feature 037 (plan P4, FR-006a): a review nobody has pulled says so, beside the missing review. A ledger that
        # cannot be read adds nothing here: the failure already stands, and the claim reading names the unreadable ledger
        # where it can be graded.
        $pulled = Get-ReviewClaims -Root $Root -Feature ($Dir -replace '^specs/', '')
        $nobodyPulled = (-not $pulled.Failed) -and @($pulled.Claims).Count -eq 0
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md is missing — team mode ($Why) requires the independent human review itself, not the solo substitute (docs/sdlc/critical-delivery.md item 5)$(if ($nobodyPulled) { "; nobody has pulled the review of $($Dir -replace '^specs/', '') yet - a reviewer takes it with: pwsh -File scripts/claim-review.ps1 -Feature $($Dir -replace '^specs/', '') -As <roster name> (docs/sdlc/team-workflow.md)" })"
        return
    }
    # Read the COMMITTED blob, not the working tree. A history check alone only proved the
    # PATH was committed: copy the template in early, fill it locally at review time, never
    # commit, and the check passed on content the branch does not carry (013 phase 4
    # re-review, N1). Critical forbids ci-held, so the authoritative gate is the human's
    # local run — the one place that hole mattered most.
    # $Dir is built with forward slashes ("specs/$Branch"), which is what git wants — no
    # separator translation, and therefore no regex to get wrong.
    # The './' matters. Without it git resolves HEAD:<path> against the REPOSITORY root, while
    # every other path here is relative to $Root — so a governance repo living in a
    # subdirectory reported a correctly committed review as uncommitted. With it, git resolves
    # against the current directory, which Push-Location $Root already set (013 phase 5
    # review, NEW-A). Exit code alone decides: a committed but EMPTY file yields $null and
    # must not be called uncommitted (NEW-C) — it fails the section check instead, correctly.
    $blob = (git show "HEAD:./$Dir/human-pr-review.md" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md is not committed — evidence that exists only in a working tree is not evidence (commit it; FR-006 requires the identities to be read from committed artifacts)"
        return
    }
    $content = ConvertTo-VisibleText -Text ($blob -join "`n")
    if ($content -notmatch '(?m)^##\s+Review Provenance') {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md has no visible '## Review Provenance' section — team mode ($Why) needs the reviewer and owner named in the review itself (specs/_templates/human-pr-review-template.md). Content inside an HTML comment does not count, and an UNTERMINATED '<!--' anywhere earlier in the file hides everything after it — check for a comment missing its '-->'"
        return
    }
    $slice = if ($content -match '(?ms)^##\s+Review Provenance\s*$(.*?)(?=^##\s|\z)') { $matches[1] } else { '' }
    # Code inside the section is illustration, not a declaration — in every form it can take:
    # backtick fences, tilde fences, and 4-space-indented blocks (013 phase 3 review NIT 7,
    # phase 4 re-review N3, which found the first fix caught only the backtick form).
    $slice = [regex]::Replace($slice, '(?ms)^(?:```|~~~).*?(^(?:```|~~~)|\z)', '')
    # An indented code block requires a preceding blank line; 4 spaces INSIDE a list is a
    # nested item, not code, and dropping those lines hid legitimate values (013 phase 5
    # review, NEW-B). Only strip an indented run that opens after a blank line.
    $sliceLines = $slice -split "`n"
    $kept = [System.Collections.Generic.List[string]]::new()
    $inIndentedCode = $false
    for ($i = 0; $i -lt $sliceLines.Count; $i++) {
        $line = $sliceLines[$i]
        $isIndented = $line -match '^(?: {4,}|	)\S'
        if ($isIndented -and -not $inIndentedCode) {
            $prev = if ($i -gt 0) { $sliceLines[$i - 1] } else { '' }
            $inIndentedCode = [string]::IsNullOrWhiteSpace($prev)
        } elseif (-not $isIndented -and -not [string]::IsNullOrWhiteSpace($line)) {
            $inIndentedCode = $false
        }
        if (-not ($isIndented -and $inIndentedCode)) { $kept.Add($line) }
    }
    $slice = $kept -join "`n"

    $reviewer = Get-ProvenanceValue -Slice $slice -Field 'Reviewer'
    $owner = Get-ProvenanceValue -Slice $slice -Field 'Owner'

    # A bare [bracketed] value is the template placeholder; '[Name](mailto:...)' is a
    # perfectly ordinary markdown link and must not be mistaken for one (logic review, NIT 6).
    $placeholder = '^\[[^\]]*\]\s*$'
    foreach ($pair in @(@{ N = 'Reviewer'; V = $reviewer }, @{ N = 'Owner'; V = $owner })) {
        if (-not $pair.V) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md has no filled '**$($pair.N)**:' line inside its Review Provenance section (team mode — $Why)"
        } elseif ($pair.V -match $placeholder) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md leaves '**$($pair.N)**: $($pair.V)' as a template placeholder — team mode ($Why) needs the actual name"
        }
    }
    if ($reviewer -and $owner -and $reviewer -notmatch $placeholder -and $owner -notmatch $placeholder) {
        if ($reviewer -ieq $owner) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$reviewer' as both reviewer and owner — the human reviewer of a Critical feature MUST NOT be its owner (docs/sdlc/critical-delivery.md item 5; docs/sdlc/team-workflow.md rule 4)"
        }
    }
    # The Reviewer must be a developer the project declared, and one its record permits to approve a
    # Critical feature (feature 021, FR-006). An empty or placeholder Reviewer was already failed above
    # and is not graded a second time. The match is exact and case-insensitive, through the same
    # ordinal comparer the reader deduplicates with (plan D3), never a second one.
    $entry = $null
    if ($reviewer -and $reviewer -notmatch $placeholder) {
        foreach ($d in @($Roster)) {
            if ([string]::Equals($d.Name, $reviewer, [StringComparison]::OrdinalIgnoreCase)) { $entry = $d; break }
        }
        if (-not $entry) {
            $names = (@($Roster) | ForEach-Object { $_.Name }) -join ', '
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$reviewer' as its reviewer, who is not on the developer roster in kit-adoption.json ($names) — team mode ($Why) needs a reviewer the project declared (docs/sdlc/critical-delivery.md item 5; docs/sdlc/team-workflow.md)"
        } elseif (-not $entry.CanApproveCritical) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$reviewer' as its reviewer, whose roster entry in kit-adoption.json does not permit approving Critical features (canApproveCritical is not true) — name a reviewer who may (docs/sdlc/critical-delivery.md item 5; docs/sdlc/team-workflow.md)"
        }
    }
    if ($slice -notmatch [regex]::Escape($attestation)) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md is missing the verbatim attestation sentence '$attestation' from its Review Provenance section (team mode — $Why)"
    }
    # Feature 037 (plan P4): the Reviewer must also have PULLED the review. Graded only once the 021 conditions hold
    # (a stranger, the Owner and a denied reviewer are named above and not graded a second time, FR-005).
    if ($entry -and $entry.CanApproveCritical -and $owner -and $owner -notmatch $placeholder -and $reviewer -ine $owner) {
        Invoke-ReviewClaimCheck -Dir $Dir -Reviewer $reviewer -Owner $owner -Entry $entry -Roster $Roster
    }
}

# Feature 037 (GAP-024 b, plan P2 to P4): the review claim of a Critical team-arm feature. A claim is the ref
# refs/heads/review/<feature>/<slug> on origin (scripts/claim-review.ps1, read by Get-ReviewClaims in
# scripts/adoption-lib.ps1). It counts for the Reviewer when its slug is the Reviewer's, is not the Owner's, and its
# commit was not authored under the Owner's name or email. A claim is a written claim: it shows that someone who can
# push to origin wrote a roster name, not who they are, that the review happened or that it was independent, and the
# author test catches only the owner pushing from their own identity. A reading the check cannot make is UNGRADED
# with its cause (never a pass, and never read as 'no claims').
function Invoke-ReviewClaimCheck {
    param([string]$Dir, [string]$Reviewer, [string]$Owner, [object]$Entry, [object[]]$Roster = @())
    $feature = $Dir -replace '^specs/', ''
    $docs = '(docs/sdlc/critical-delivery.md item 5; docs/sdlc/team-workflow.md)'
    $slug = ConvertTo-ReviewSlug $Entry.Name
    $ownerSlug = ConvertTo-ReviewSlug $Owner
    $alike = @((Get-RosterBySlug -Roster $Roster)[$slug])
    $cannot = $null
    if (-not $slug) {
        $cannot = "the roster name '$($Entry.Name)' has no character a ref can hold, so a claim cannot be written for it"
    } elseif (-not $ownerSlug) {
        # The Owner tests compare slugs, and an Owner with none would make every one of them silently pass (phase 2
        # review F1): the reading cannot be made, and it says so.
        $cannot = "the Owner '$Owner' has no character a ref can hold, so a claim by the Owner cannot be told from the Reviewer's"
    } elseif ($alike.Count -gt 1) {
        $cannot = "roster names $((@($alike) | ForEach-Object { "'$($_.Name)'" }) -join ' and ') write as one ref name ('$slug'), so their claims cannot be told apart"
    } else {
        $read = Get-ReviewClaims -Root $Root -Feature $feature -WithAuthors
        if ($read.Failed) { $cannot = $read.Cause }
    }
    if ($cannot) {
        $script:ungraded += "CriticalEvidence: the review claim of $feature was not graded: $cannot (docs/sdlc/team-workflow.md)"
        return
    }
    $mine = @($read.Claims | Where-Object { $_.Slug -ceq $slug })
    if ($mine.Count -eq 0) {
        $ownerHint = if (@($read.Claims | Where-Object { $ownerSlug -and $_.Slug -ceq $ownerSlug }).Count -gt 0) { "; the review claim by the Owner ('$Owner') does not count" } else { '' }
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$Reviewer' as its reviewer, but '$Reviewer' has no review claim for $feature on origin (review/$feature/$slug) - the reviewer takes the review with: pwsh -File scripts/claim-review.ps1 -Feature $feature -As '$Reviewer'$ownerHint $docs"
        return
    }
    if ($ownerSlug -and $slug -ceq $ownerSlug) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$Reviewer' as its reviewer, but the review claim review/$feature/$slug is the Owner's: its name slugs to the Owner's ('$Owner') - a claim by the Owner does not count $docs"
        return
    }
    $claim = $mine[0]
    $mailLocal = ("$($claim.AuthorEmail)" -split '@', 2)[0]
    # first.last@ is read as the hyphen the Owner's name slugs with (phase 2 review F2): both forms are compared.
    if ($ownerSlug -and ((ConvertTo-ReviewSlug $claim.AuthorName) -ceq $ownerSlug -or (ConvertTo-ReviewSlug $mailLocal) -ceq $ownerSlug -or (ConvertTo-ReviewSlug ($mailLocal -replace '\.', '-')) -ceq $ownerSlug)) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$Reviewer' as its reviewer, but the review claim review/$feature/$slug was authored as '$($claim.AuthorName) <$($claim.AuthorEmail)>', which is the Owner ('$Owner') - a claim pushed under the Owner's identity does not count $docs"
    }
}

# A file as a reader sees it: HTML comments removed, closed ones first and then an
# UNTERMINATED '<!--' through to end of file — a renderer swallows the rest of the document,
# so a check that keeps reading is reading text nobody can see. Get-VisiblePlanLines applies
# the same rule line-wise for plan headers (contract M13); this returns whole text because
# the provenance parser needs to slice sections out of it.
function ConvertTo-VisibleText {
    param([string]$Text)
    $stripped = [regex]::Replace($Text, '(?s)<!--.*?-->', '')
    # Ordinal: the culture-sensitive overload can match a marker a renderer never sees — a
    # soft hyphen inside '<!--' is enough (013 phase 4 re-review, N4).
    $dangling = $stripped.IndexOf('<!--', [StringComparison]::Ordinal)
    if ($dangling -ge 0) { $stripped = $stripped.Substring(0, $dangling) }
    return $stripped
}

function Get-ProvenanceValue {
    param([string]$Slice, [string]$Field)
    $line = $Slice -split "`n" | Where-Object { $_ -match "^\s*[-*]?\s*\*\*$Field\*\*:\s*(\S.*)$" } | Select-Object -First 1
    if ($line -match "\*\*$Field\*\*:\s*(.+)$") { return $matches[1].Trim() }
    return ''
}

# --- Gate-batching check (003 FR-008/FR-009: constitution X, Batched gates) ---
function Invoke-GateBatchingCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $planPath = Join-Path $dir 'plan.md'
    if (-not (Test-Path $planPath)) { return }   # missing plan.md is StructureCheck's failure

    $line = (Get-VisiblePlanLines -PlanPath $planPath | Where-Object { $_ -match '^\*\*Gate Batching\*\*:' } | Select-Object -First 1)
    if (-not $line) { return }                   # absent line means 'none' (backward compatible)

    # Strip any trailing HTML comment (the template ships one) before parsing the value.
    $value = ($line -replace '^\*\*Gate Batching\*\*:\s*', '' -replace '<!--.*$', '').Trim()
    if ($value -eq '' -or $value -eq 'none') { return }

    if ($value -notmatch '^phases\s+(\d+)\s*[-–]\s*(\d+)$') {
        $script:failures += "GateBatching: $dir/plan.md declares '**Gate Batching**: $value' — must be 'none' or 'phases N-M' (constitution X, Batched gates)"
        return
    }
    $from = [int]$matches[1]; $to = [int]$matches[2]
    if ($to -lt $from) {
        $script:failures += "GateBatching: $dir/plan.md declares 'phases $from-$to' — the span is reversed (N must not exceed M)"
        return
    }
    $span = $to - $from + 1
    if ($span -gt $Config.MaxBatchPhases) {
        $script:failures += "GateBatching: $dir/plan.md declares 'phases $from-$to' ($span phases) — a batch covers at most $($Config.MaxBatchPhases) consecutive phases (constitution X, Batched gates)"
    }

    if ((Get-DeliveryLevel -SpecPath (Join-Path $dir 'spec.md')) -match '^Critical\b') {
        $script:failures += "GateBatching: $dir declares a gate batch on a Critical feature — Critical features never batch; every phase keeps its own human-executed gate (docs/sdlc/critical-delivery.md item 4)"
    }
}

# --- Gate-certification check (008: constitution X, CI-held certification) ---
# Legal values are constitutional constants (sync-listed): 'user-run' | 'ci-held'.
# Absent line means 'user-run' (plans from before the clause remain valid). Critical
# features MUST NOT declare ci-held (constitution X; docs/sdlc/critical-delivery.md item 4).
function Invoke-GateCertificationCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    $level = Get-DeliveryLevel -SpecPath $specPath
    # On a Micro feature the mini-spec is the declaration's home — the lane has no plan.md
    # (constitution X, Micro lane; contract M9).
    $declPath = if ($level -match '^Micro\b') { $specPath } else { Join-Path $dir 'plan.md' }
    $declName = "$dir/$(Split-Path -Leaf $declPath)"
    if (-not (Test-Path $declPath)) { return }   # a missing declaration file is StructureCheck's failure

    $line = (Get-VisiblePlanLines -PlanPath $declPath | Where-Object { $_ -match '^\*\*Gate Certification\*\*:' } | Select-Object -First 1)
    if (-not $line) { return }                   # absent line means 'user-run' (backward compatible)

    # Strip any trailing HTML comment (the template ships one) before parsing the value.
    $value = ($line -replace '^\*\*Gate Certification\*\*:\s*', '' -replace '<!--.*$', '').Trim()
    if ($value -eq '' -or $value -eq 'user-run') { return }

    if ($value -ne 'ci-held') {
        $script:failures += "GateCertification: $declName declares '**Gate Certification**: $value' — must be 'user-run' or 'ci-held' (constitution X, CI-held certification)"
        return
    }

    if ($level -match '^Critical\b') {
        $script:failures += "GateCertification: $dir declares '**Gate Certification**: ci-held' on a Critical feature — Critical features MUST NOT use CI-held certification; every certifying gate stays human-executed, locally (constitution X, CI-held certification; docs/sdlc/critical-delivery.md item 4)"
    }
}

# --- Micro-lane check (009: constitution X, Micro lane) ---
# Applies only when spec.md's VISIBLE Delivery Level is Micro (a commented-out decoy never
# sets the lane — contract M13). The bounds are constitutional constants ($Config above);
# every failure names the promotion remediation. Reads the branch's CURRENT tree state, so
# a promoted branch (level re-declared Standard) exits these rules from the promotion
# commit onward (contract M11) — scope-check separately attributes each historical commit
# against its parent's declaration.
function Invoke-MicroLaneCheck {
    param([string]$Branch, [string]$Base)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if ((Get-DeliveryLevel -SpecPath $specPath) -notmatch '^Micro\b') { return }
    $promote = 'promote to Standard — expand spec.md to the full template (level re-declared Standard), add plan.md + tasks.md (Territory moves there), in a commit before the next phase commit (constitution X, Micro lane)'

    # Halfway promotion is illegal: the full set arrives together or not at all (M7).
    foreach ($f in @('plan.md', 'tasks.md')) {
        if (Test-Path (Join-Path $dir $f)) {
            $script:failures += "MicroLane: $dir/$f exists while spec.md still declares Micro — promotion is all-or-nothing; $promote"
        }
    }

    # One phase means nothing to batch (M8).
    $batchLine = (Get-VisiblePlanLines -PlanPath $specPath | Where-Object { $_ -match '^\*\*Gate Batching\*\*:' } | Select-Object -First 1)
    if ($batchLine) {
        $script:failures += "MicroLane: $dir/spec.md declares '**Gate Batching**' — a Micro feature is exactly one phase; there is nothing to batch (constitution X, Micro lane); delete the line, or $promote"
    }

    # Territory cap (M5). The block is parsed by scope-lib's Get-Territory — the SAME function
    # scope-check.ps1 uses — because this was a copy of that grammar until T020a, and a copy of a
    # parser is a parser that drifts: phase 2 widened the original to accept a decorated marker
    # and left this one strict, so a Micro spec could break the file cap while reporting OK.
    # Entries must still be literal file paths; one glob or subtree entry defeats the cap outright.
    $territory = Get-Territory -TasksLines (Get-VisiblePlanLines -PlanPath $specPath) -Global
    $tEntries = @($territory.Entries)
    $tMarkers = $territory.MarkerCount
    if ($territory.NearMiss.Count -gt 0) {
        # A line that starts like a declaration and breaks the grammar FAILs rather than vanishing
        # (feature 015, T019a in scope-check and T020a here — the two graders say the same thing
        # about the same malformed line).
        foreach ($nm in $territory.NearMiss) {
            $script:failures += "MicroLane: $dir/spec.md line $nm begins '**Territory**' but has no ':' on that line — an annotation that wraps declares nothing the parser can see; keep the marker and its colon on one line"
        }
    }
    if ($tMarkers -gt 1) {
        # scope-check FAILs duplicates too — kept aligned so the two scripts never diverge
        # on the same spec (phase 2 review, F7). They now share the parser, so they cannot.
        $script:failures += "MicroLane: $dir/spec.md carries $tMarkers **Territory** markers — a Micro feature declares exactly one feature-global block; merge them, or $promote"
    }
    foreach ($bad in @($territory.Invalid)) {
        # Get-Territory routes an absolute or '..' entry to Invalid, NOT to Entries. Sharing the
        # parser in T020a therefore did something the task did not intend: an escaping entry
        # stopped counting toward the file cap and was reported by nobody, while scope-check.ps1
        # — the same function, the same block — FAILs it. That is the divergence T020a exists to
        # remove, reappearing one field over, so the caller reads the field rather than the task
        # being called done. Reporting is enough: no spec carrying one can reach the cap check
        # green, so the under-count cannot be spent.
        $script:failures += "MicroLane: territory entry '$bad' in $dir/spec.md is not repo-relative — Micro territory entries must be repo-relative paths with no '..'; scope-check.ps1 FAILs the same entry in the same block; fix the entry, or $promote"
    }
    if ($tEntries.Count -gt $Config.MicroTerritoryMaxFiles) {
        $script:failures += "MicroLane: $dir/spec.md declares $($tEntries.Count) territory entries — a Micro feature's Territory covers at most $($Config.MicroTerritoryMaxFiles) files (constitution X, Micro lane); shrink the territory, or $promote"
    }
    foreach ($e in $tEntries) {
        if ($e -match '\*' -or $e -match '/\s*$') {
            $script:failures += "MicroLane: territory entry '$e' in $dir/spec.md is a glob or subtree — Micro territory entries must be literal file paths, or the $($Config.MicroTerritoryMaxFiles)-file cap is unenforceable; list the files, or $promote"
        }
    }

    # Exactly one phase (M6) + the hard size bound (M12 — PhaseSizeWarning stays a
    # non-blocking per-commit warning on every other lane). Distinct phase NUMBERS are
    # counted, not commits, so in-phase remediation commits ('phase 1 fixes: …') stay
    # legal exactly as they are on Standard features — but their lines COUNT: the bound
    # is the phase's TOTAL across every commit carrying its token, so splitting a change
    # over remediation commits cannot defeat it (phase 2 review, F1 — owner-resolved
    # 2026-09-09; constitution X wording matches).
    if (-not $Base) {
        $script:ungraded += "MicroLane: no diff base, so the phase walk enforcing 'exactly one phase' and the line bound compared nothing on '$Branch'"
        return
    }
    $phaseNums = @{}
    $phaseTotal = 0
    $phaseCommitCount = 0
    # Feature 029 (plan D3, G1-G2): each read goes through Read-GitLines; a failed read is named
    # and graded nothing, never read as "no commit" or "zero lines" (a damaged blob once turned the
    # hard 400-line failure into OK).
    $walkConsequence = "the phase's size could not be measured and the Micro lane's $($Config.MicroPhaseMaxLines)-line bound graded nothing"
    $walk = Read-GitLines -GitArguments @('rev-list', '--no-merges', "$Base..HEAD")
    if (-not $walk.Ok) {
        Add-GitReadUnreadable -Reader 'MicroLane' -Read "git rev-list of $Base..HEAD" -Key 'rev-list' -Branch $Branch -Exit $walk.Exit -Consequence $walkConsequence
        return
    }
    $commits = $walk.Lines | Where-Object { $_ }
    foreach ($commit in $commits) {
        $subjectRead = Read-GitLines -GitArguments @('log', '-1', '--format=%s', $commit)
        if (-not $subjectRead.Ok) {
            Add-GitReadUnreadable -Reader 'MicroLane' -Read "git log of $($commit.Substring(0, 7))" -Key 'log' -Branch $Branch -Exit $subjectRead.Exit -Consequence $walkConsequence
            continue
        }
        $subject = ($subjectRead.Lines -join "`n")
        if ($subject -notmatch '(?i)\bphase\s+(\d+)\b') { continue }
        $phaseNums[[int]$matches[1]] = $true
        $phaseCommitCount++
        $numstatRead = Read-GitLines -GitArguments @('show', '--numstat', '--format=', $commit)
        if (-not $numstatRead.Ok) {
            Add-GitReadUnreadable -Reader 'MicroLane' -Read "git show --numstat of $($commit.Substring(0, 7))" -Key 'numstat' -Branch $Branch -Exit $numstatRead.Exit -Consequence $walkConsequence
            continue
        }
        $numstat = $numstatRead.Lines
        foreach ($row in $numstat) {
            if (-not $row) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -lt 3) { continue }
            if ($parts[0] -match '^\d+$') { $phaseTotal += [int]$parts[0] }
            if ($parts[1] -match '^\d+$') { $phaseTotal += [int]$parts[1] }
        }
    }
    if ($phaseTotal -gt $Config.MicroPhaseMaxLines) {
        $script:failures += "MicroLane: the phase's $phaseCommitCount commit(s) change $phaseTotal line(s) in total — a Micro phase changes at most $($Config.MicroPhaseMaxLines) lines across all its commits, a hard bound on this lane (constitution X, Micro lane); shrink the change, or $promote"
    }
    if ($phaseNums.Keys.Count -gt $Config.MicroMaxPhases) {
        $nums = ($phaseNums.Keys | Sort-Object) -join ', '
        $script:failures += "MicroLane: the branch carries commits for phases $nums — a Micro feature has exactly $($Config.MicroMaxPhases) phase; $promote"
    }
}

# --- Level surface floor (feature 017; constitution X, Level declaration) ---
# The delivery level selects how much rigour a feature gets, and until this check nothing graded
# it: a Standard feature that rewrote authentication was green by construction. This is the
# machine floor under the written claim. A project names its critical surfaces (path globs) in
# kit-adoption.json; a Standard or Micro feature whose Territory reaches one fails, unless the
# spec carries an approved Surface Exception for that exact path. A Critical feature is never
# failed here. A project that declares nothing sees ONE informational line and no change of
# verdict, so updating the kit cannot turn an adopted project red.
#
# Every way this check can fail to grade is NAMED, never passed (spec FR-012, the GAP-027 lesson):
# an unusable or unreadable record, and a Territory it cannot read, each add an UNGRADED line.

$script:SurfaceExceptionPattern = '^\*\*Surface Exception\*\*:\s*`([^`]+)`\s*(?:[—–]|-{1,2})\s*(\S.*)$'
$script:ExceptionApprovalPattern = '^\*\*Exception approved by\*\*:\s*(.+?)\s*,\s*(\d{4}-\d{2}-\d{2})\s*\.?\s*$'

# One reading of a path for both sides of the comparison: backslash is a slash (a Territory
# written on Windows must match the same on a Linux runner) and a leading './' is nothing.
# Case is not folded here, the matchers below are case-insensitive by design (scope-lib).
function ConvertTo-LevelPath {
    param([string]$Path)
    $p = ("$Path".Trim() -replace '\\', '/')
    while ($p.StartsWith('./')) { $p = $p.Substring(2) }
    return $p
}

function Test-LevelPathIsPattern {
    param([string]$Path)
    return ($Path.EndsWith('/') -or $Path.IndexOfAny([char[]]@('*', '?')) -ge 0)
}

# The literal directory prefix of a pattern: everything up to the last '/' before its first
# wildcard. '' for a pattern with no literal prefix, which therefore intersects everything.
function Get-LevelPathPrefix {
    param([string]$Path)
    # The wildcard test comes FIRST. A pattern that ends in '/' is a subtree, but it may also
    # hold a wildcard ('**/auth/', 'src/*/auth/'), and returning it whole as a literal prefix
    # compared the string '**/auth/' against 'src/' and called the two disjoint: a Territory of
    # 'src/**' came out clean against a surface it can plainly reach (phase 3 review F1, a
    # fail-open). Only a pattern with no wildcard at all is its own prefix.
    $w = $Path.IndexOfAny([char[]]@('*', '?'))
    if ($w -lt 0) { return $Path }
    $head = $Path.Substring(0, $w)
    $slash = $head.LastIndexOf('/')
    if ($slash -lt 0) { return '' }
    return $head.Substring(0, $slash + 1)
}

# Do two path patterns overlap (research R1)? A literal path is tested with the kit's own
# matcher. Two patterns are compared by literal prefix, which is CONSERVATIVE on purpose: it
# over-reports (src/**/*.md against src/auth/*.ps1) and never under-reports, because a false
# positive costs one written exception and a false negative costs the whole point.
function Test-LevelPathsIntersect {
    param([string]$A, [string]$B)
    $a = ConvertTo-LevelPath $A
    $b = ConvertTo-LevelPath $B
    if (-not (Test-LevelPathIsPattern $a)) { return (Test-InTerritory -Path $a -Globs @($b)) }
    if (-not (Test-LevelPathIsPattern $b)) { return (Test-InTerritory -Path $b -Globs @($a)) }
    $pa = Get-LevelPathPrefix $a
    $pb = Get-LevelPathPrefix $b
    return ($pa.StartsWith($pb, [StringComparison]::OrdinalIgnoreCase) -or $pb.StartsWith($pa, [StringComparison]::OrdinalIgnoreCase))
}

# The feature's whole declared Territory as one list. Standard: the union of every phase's
# block in tasks.md. Micro: the one feature-global block in spec.md. Read from the working
# tree, comment-stripped, through scope-lib's Get-Territory and nothing else, so this check and
# the scope check cannot disagree about what a declaration looks like.
# Returns @{ Readable; Entries; Why }; not Readable names why, and the caller says UNGRADED.
function Get-FeatureTerritory {
    param([string]$Dir, [string]$Level)
    $r = @{ Readable = $false; Entries = @(); Why = '' }
    $entries = @()
    $found = $false
    if ($Level -match '^Micro\b') {
        $t = Get-Territory -TasksLines (Get-VisiblePlanLines -PlanPath (Join-Path $Dir 'spec.md')) -Global
        if ($t.NearMiss.Count -gt 0) { $r.Why = 'a **Territory** marker has no colon, so the block cannot be read (keep the marker and its colon on one line)'; return $r }
        $found = $t.Found
        $entries = @($t.Entries)
        if (-not $found) { $r.Why = 'spec.md declares no **Territory** block'; return $r }
    } else {
        $tasksPath = Join-Path $Dir 'tasks.md'
        if (-not (Test-Path -LiteralPath $tasksPath)) { $r.Why = 'tasks.md does not exist yet'; return $r }
        $lines = @(Get-VisiblePlanLines -PlanPath $tasksPath)
        $phases = @($lines | ForEach-Object { if ($_ -match '^##\s+Phase\s+(\d+)\b') { [int]$matches[1] } } | Sort-Object -Unique)
        if ($phases.Count -eq 0) { $r.Why = 'tasks.md has no "## Phase N" heading'; return $r }
        foreach ($n in $phases) {
            $t = Get-Territory -TasksLines $lines -PhaseNumber $n
            if ($t.NearMiss.Count -gt 0) { $r.Why = 'a **Territory** marker has no colon, so the block cannot be read (keep the marker and its colon on one line)'; return $r }
            if ($t.Found) { $found = $true; $entries += @($t.Entries) }
        }
        if (-not $found) { $r.Why = 'no phase in tasks.md declares a **Territory** block'; return $r }
    }
    if ($entries.Count -eq 0) { $r.Why = 'the **Territory** block lists no entries'; return $r }
    $r.Readable = $true
    $r.Entries = @($entries)
    return $r
}

# Surface Exceptions as the spec writes them: a backticked path and a reason, then, on the next
# non-blank line, the approval. Approval is validated by Get-ConformingRecord, the amendment
# check's own function. The author's own day is the ceiling for the date, as it is there (H6):
# the runner's clock would make the same record green locally and red in CI.
function Get-SurfaceExceptions {
    param([string]$SpecPath)
    # Feature 029 phase 3 (G12): the author's day is the ceiling for a Surface Exception's date (H6). A failed
    # read fell back to the runner's clock without a word, which is the thing the comment above says the
    # ceiling exists to prevent; the fallback stays (git printing no date is a different, old case) and a
    # FAILED read now says so, on every lane, as an advisory UNGRADED line.
    $dayRead = Read-GitLines -GitArguments @('log', '-1', '--date=format:%Y-%m-%d', '--format=%ad', 'HEAD')
    if (-not $dayRead.Ok) {
        Add-GitReadUnreadable -Reader 'LevelSurface' -Read 'git log of HEAD' -Key 'surface-day' -Branch $Branch -Exit $dayRead.Exit -Consequence 'a Surface Exception was dated against the runner''s clock, not the author''s day' -Advisory
    }
    $day = "$($dayRead.Lines)".Trim()
    if (-not $day) { $day = (Get-Date).ToString('yyyy-MM-dd') }
    $lines = @(Get-VisiblePlanLines -PlanPath $SpecPath)
    $out = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch $script:SurfaceExceptionPattern) { continue }
        $path = ConvertTo-LevelPath $matches[1]
        $reason = $matches[2].Trim()
        $approver = $null
        $approvedOn = ''
        $why = ''
        if ($reason -match '^[\[<].*[\]>]$' -or $reason -match '^(TODO|TBD|FIXME|XXX)\b') {
            $why = "the reason '$reason' is a placeholder, not a reason"
        } else {
            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j] -match '^\s*$') { $j++ }
            if ($j -ge $lines.Count -or $lines[$j] -notmatch '^\*\*Exception approved by\*\*') {
                $why = 'no **Exception approved by** line directly beneath it'
            } else {
                $rec = Get-ConformingRecord -AddedLines @($lines[$j]) -CommitDay $day -Pattern $script:ExceptionApprovalPattern
                if ($rec.Name) {
                    $approver = $rec.Name
                    if ($lines[$j] -match $script:ExceptionApprovalPattern) { $approvedOn = $matches[2] }
                } elseif ($rec.Malformed.Count -gt 0) {
                    $why = ($rec.Malformed -join '; ')
                } else {
                    $why = 'the approval line is not in the shape **Exception approved by**: <name>, <YYYY-MM-DD>'
                }
            }
        }
        $out += @{ Path = $path; Reason = $reason; Approver = $approver; ApprovedOn = $approvedOn; Why = $why }
    }
    return $out
}

function Invoke-LevelSurfaceCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if (-not (Test-Path -LiteralPath $specPath)) { return }          # the Structure check owns a missing spec
    $level = Get-DeliveryLevel -SpecPath $specPath
    # Critical is never failed here (FR-011); Lite has no spec; an unfilled or invalid level is
    # the Structure check's finding, and guessing a level for it would grade a decoy.
    if ($level -notmatch '^(Micro|Standard)\b') { return }
    # Canonical spelling: the level matches case-insensitively, and a message that echoed the
    # spec's own 'standard' would read as a different level than the one every other check names.
    $levelName = if ($matches[1] -ieq 'Micro') { 'Micro' } else { 'Standard' }

    $surfaces = Get-CriticalSurfaces -Root $Root
    if ($surfaces.State -in @('absent', 'empty')) {
        Write-Host "LevelSurface: not armed — kit-adoption.json declares no critical surfaces, so $Branch ($levelName) was not checked against any (adoption/updating.md)"
        return
    }
    if ($surfaces.State -eq 'unreadable') {
        $script:ungraded += "LevelSurface: criticalSurfaces in kit-adoption.json is unusable: the record exists but cannot be read, so whether a floor was declared is unknown — $Branch ($levelName) was not checked against a critical surface, which is not the same as passing it"
        return
    }
    if ($surfaces.State -eq 'malformed') {
        $script:ungraded += "LevelSurface: criticalSurfaces in kit-adoption.json is unusable: $($surfaces.Why) — $Branch ($levelName) was not checked against a critical surface, which is not the same as passing it"
        return
    }

    $territory = Get-FeatureTerritory -Dir $dir -Level $levelName
    if (-not $territory.Readable) {
        $script:ungraded += "LevelSurface: no readable Territory for $Branch ($levelName): $($territory.Why) — the surface floor could not be checked, which is not the same as passing it"
        return
    }

    $exceptions = @(Get-SurfaceExceptions -SpecPath $specPath)
    $reached = 0
    $excepted = 0
    $reachedPaths = @{}
    foreach ($entry in $territory.Entries) {
        $hit = $null
        foreach ($glob in $surfaces.Globs) {
            if (Test-LevelPathsIntersect -A $entry -B $glob) { $hit = $glob; break }
        }
        if (-not $hit) { continue }
        $reached++
        $key = (ConvertTo-LevelPath $entry).ToLowerInvariant()
        $reachedPaths[$key] = $true
        $named = @($exceptions | Where-Object { (ConvertTo-LevelPath $_.Path) -ieq (ConvertTo-LevelPath $entry) })
        $good = @($named | Where-Object { $_.Approver } | Select-Object -First 1)
        if ($good.Count -gt 0) {
            $excepted++
            $g = $good[0]
            Write-Host "LevelSurface: exception live for '$entry' in $dir/spec.md — approval recorded by $($g.Approver), $($g.ApprovedOn): $($g.Reason)"
            continue
        }
        $script:failures += "LevelSurface: $Branch is declared $levelName but its Territory reaches critical surface '$hit' via '$entry' — a $levelName feature may not touch a critical surface unannounced (constitution X, Level declaration). Promote it to Critical, narrow the Territory so it no longer reaches the surface, or record a Surface Exception in $dir/spec.md: '**Surface Exception**: ``$entry`` — <reason>' with '**Exception approved by**: <name>, <YYYY-MM-DD>' on the next line"
        foreach ($bad in $named) {
            $script:failures += "LevelSurface: exception not counted for '$entry' in $dir/spec.md — $($bad.Why); the path is graded as if it had no exception"
        }
    }
    # An exception that suppresses nothing is reported and never failed (FR-010): the Territory
    # narrowed, or the path was never on a surface. Left in a spec it would read as protection.
    foreach ($ex in $exceptions) {
        if ($reachedPaths.ContainsKey((ConvertTo-LevelPath $ex.Path).ToLowerInvariant())) { continue }
        Write-Host "LevelSurface: exception stale for '$($ex.Path)' in $dir/spec.md — it names no Territory entry that reaches a critical surface, so it suppresses nothing and can be removed"
    }
    $n = @($territory.Entries).Count
    $noun = if ($n -eq 1) { 'entry' } else { 'entries' }
    Write-Host "LevelSurface: graded $Branch ($levelName) — $n Territory $noun against $(@($surfaces.Globs).Count) critical surface(s): $reached reached, $excepted excepted"
}

# --- Level rationale (feature 017; constitution X, Level declaration) ---
# The written half of the level claim. A spec made from the current template carries
# '**Rationale Rule**: 1' and a '## Level Rationale' section that answers the four Critical
# triggers of docs/sdlc/critical-delivery.md, each 'applies' or 'does not apply' with a reason.
# The check fails an absent or incomplete section, and a section that contradicts the declared
# level. It is a claim a reviewer can falsify, not proof: an owner can still write 'does not
# apply', and the check says nothing about whether it is true.
#
# Only a spec that CARRIES the marker owes the section. A spec from before the rule has none,
# and failing it would fail every shipped feature and every adopted project's history (FR-008).
# The cost is stated in the constitution: a spec can omit the marker, as it can omit its
# Delivery Level, and the omission shows in the diff.
#
# Everything is read from VISIBLE text, trimmed. The phase 1 review's F3: the template ships
# placeholder lines, so text that starts with '[' is UNFILLED and never an answer, and the
# verdict is anchored to the start of the bullet, so an unedited template cannot read as four
# answers.

$script:RationaleKeys = @('domain-invariants', 'irreversible-data', 'authn-authz-payment', 'auditable-evidence')
$script:RationaleVerdictPattern = '^(applies|does not apply)\s*(?:[—–]|-{1,2})\s*(\S.*)$'

function Test-RationalePlaceholder {
    param([string]$Text)
    # Unfilled: a bracketed or angle-bracketed placeholder, a TODO-style word, or text with no word
    # of at least two characters in it ('x', '-', 'n/a'): the rule needs a reason, not a pixel.
    return [bool]($Text -match '^[\[<].*[\]>]$' -or $Text -match '^(TODO|TBD|FIXME|XXX)\b' -or $Text -notmatch '\w{2,}')
}

function Invoke-LevelRationaleCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if (-not (Test-Path -LiteralPath $specPath)) { return }          # the Structure check owns a missing spec
    $level = Get-DeliveryLevel -SpecPath $specPath
    # Micro's mini-spec has no such section (its eligibility checklist stands in), and Lite has no
    # spec. Standard and Critical are the levels that owe a rationale (spec FR-002).
    if ($level -notmatch '^(Standard|Critical)\b') { return }
    $levelName = if ($matches[1] -ieq 'Critical') { 'Critical' } else { 'Standard' }

    # Visible text with FENCED CODE removed (phase 4 review F1). A fence is an example, and an
    # example is not an answer, a reason or a marker: counting fenced lines would pass a spec whose
    # whole rationale is a quoted illustration, and would fail one that merely documents the rule.
    # Get-FencedLineMap is the CommonMark-shaped reader feature 015 built and the amendment check
    # already uses; this check does not grow a second idea of what a fence is.
    $visible = @(Get-VisiblePlanLines -PlanPath $specPath)
    $fenced = Get-FencedLineMap -Lines $visible
    $lines = @(for ($i = 0; $i -lt $visible.Count; $i++) { if (-not $fenced[$i]) { $visible[$i] } })

    # The marker is every header-shaped line, not the first one (review F3): with the first one
    # only, '1' then '2' graded under rule 1 and '2' then '1' did not, so the order of two lines
    # decided the verdict. A value this check does not know ANYWHERE leaves the spec UNGRADED.
    $markers = @($lines | Where-Object { $_ -match '^\*\*Rationale Rule\*\*:' } | ForEach-Object { ($_ -replace '^\*\*Rationale Rule\*\*:\s*', '').Trim() })
    if ($markers.Count -eq 0) {
        # A line that LOOKS like the marker and is not one (indented, quoted, a space before the
        # colon) is not "no marker": that would silently exempt a spec that tried to opt in (review
        # F4). It is UNGRADED by name, the way a Territory marker the parser cannot read already is.
        $near = $lines | Where-Object { $_ -match '^[\s>*+-]*\*\*\s*Rationale Rule\s*\*\*' } | Select-Object -First 1
        if (-not $near) { return }                                    # predates the rule: exempt (FR-008)
        $script:ungraded += "LevelRationale: $Branch spec.md has a line that looks like the '**Rationale Rule**' marker but cannot be read as one ('$($near.Trim())') — the Level Rationale was not checked, which is not the same as passing it"
        return
    }
    $unknown = $markers | Where-Object { $_ -ne '1' } | Select-Object -First 1
    if ($null -ne $unknown) {
        $script:ungraded += "LevelRationale: $Branch spec.md carries '**Rationale Rule**: $unknown', a version this check does not know — the Level Rationale was not checked, which is not the same as passing it"
        return
    }

    # Every '## Level Rationale' section counts, not the first (review F2): a second section that
    # contradicts the first makes the trigger answered twice, and neither answer wins silently.
    $answers = @{}
    foreach ($k in $script:RationaleKeys) { $answers[$k] = @() }
    $inSection = $false
    $sections = 0
    foreach ($line in $lines) {
        if ($line -match '^##\s+Level Rationale\b') { $inSection = $true; $sections++; continue }
        if ($line -match '^#{1,2}\s') { $inSection = $false; continue }   # a section ends at the next heading
        if ($inSection -and $line -match '^\s*[-*]\s+\*\*([A-Za-z-]+)\*\*:\s*(.*?)\s*$') {
            $key = $matches[1].ToLowerInvariant()
            if ($answers.ContainsKey($key)) { $answers[$key] += $matches[2] }
        }
    }
    if ($sections -eq 0) {
        $script:failures += "LevelRationale: $Branch spec.md has no Level Rationale — a spec carrying '**Rationale Rule**: 1' answers the four Critical triggers in a '## Level Rationale' section (domain-invariants, irreversible-data, authn-authz-payment, auditable-evidence; docs/sdlc/critical-delivery.md)"
        return
    }

    $verdicts = @{}
    $unanswered = 0
    foreach ($k in $script:RationaleKeys) {
        $texts = @($answers[$k])
        $why = ''
        if ($texts.Count -eq 0) {
            $why = 'no bullet for it in the Level Rationale section'
        } elseif ($texts.Count -gt 1) {
            $why = 'it is answered more than once'
        } elseif ($texts[0] -notmatch $script:RationaleVerdictPattern) {
            $why = "'$($texts[0])' is not 'applies' or 'does not apply' followed by a reason"
        } else {
            # Read the groups into locals BEFORE calling the helper, so what is tested is the
            # reason of THIS bullet whatever the helper does with its own match state.
            $verdict = $matches[1].ToLowerInvariant()
            $reason = $matches[2].Trim()
            if (Test-RationalePlaceholder $reason) {
                $why = "its reason '$reason' is a placeholder or says nothing"
            } else {
                $verdicts[$k] = $verdict
            }
        }
        if ($why) {
            $unanswered++
            $script:failures += "LevelRationale: $Branch spec.md leaves trigger '$k' unanswered: $why — answer it as '- **$k**: applies — <reason>' or '- **$k**: does not apply — <reason>'"
        }
    }
    if ($unanswered -gt 0) { return }

    $applying = @($script:RationaleKeys | Where-Object { $verdicts[$_] -eq 'applies' })
    Write-Host "LevelRationale: graded $Branch ($levelName) — 4 of 4 triggers answered, $($applying.Count) apply"
    if ($levelName -eq 'Standard' -and $applying.Count -gt 0) {
        $quoted = ($applying | ForEach-Object { "'$_'" }) -join ', '
        $script:failures += "LevelRationale: $Branch spec.md contradicts its level: declared Standard, but it answers $quoted as 'applies' — a feature that touches a Critical trigger is Critical (docs/sdlc/critical-delivery.md); declare it Critical, or correct the answer"
    }
    if ($levelName -eq 'Critical' -and $applying.Count -eq 0) {
        $because = @($lines | Where-Object { $_ -match '^\*\*Critical because\*\*:\s*(\S.*)$' -and -not (Test-RationalePlaceholder $matches[1].Trim()) })
        if ($because.Count -eq 0) {
            $script:failures += "LevelRationale: $Branch spec.md contradicts its level: declared Critical, but every trigger is answered 'does not apply' and there is no '**Critical because**: <reason>' line — say why it is Critical regardless, or declare it Standard"
        }
    }
}

# --- Review-provenance check (006 FR-006: DoD gate 5, reviewer separation) ---
# Inspects only AI-review files ADDED in the branch's diff vs base (--diff-filter=A), so
# reviews shipped before the verification pack — and every adopted project's history —
# are grandfathered automatically (006 research D4). Templates are exempt.
function Invoke-ReviewProvenanceCheck {
    param([string]$Branch, [string]$Base)
    # GAP-027, and the reason this feature has a phase 5. This used to be a bare `return`: the
    # machine half of gate 5 stopped before listing a single candidate, and the run still printed
    # OK. An AI review with no provenance section rode through on a depth-1 clone, the ordinary
    # actions/checkout shape. It still does not FAIL - FR-011 forbids a new hard failure on the
    # Lite lane - but the verdict can no longer be read as a graded pass.
    if (-not $Base) {
        if ($script:DiffBaseFailure) {
            $script:ungraded += "ReviewProvenance: the diff base could not be read ($($script:DiffBaseFailure)), so no review file on '$Branch' was inspected - the machine half of DoD gate 5 formed no opinion. The object store may be damaged: run git fsck, or re-clone"
            return
        }
        $script:ungraded += "ReviewProvenance: no diff base, so no review file on '$Branch' was inspected - the machine half of DoD gate 5 formed no opinion. Fetch the full history ('fetch-depth: 0' on actions/checkout)"
        return
    }
    # Runs on every recognized lane (self-scoping via the diff filter) so a review file
    # cannot be smuggled in through fix/chore/docs branches (phase 2 review, F7).
    # AR filter: rename TARGETS are inspected like additions — moving a grandfathered
    # review into the feature is not legitimate grandfathering (phase 2 review, F3).
    # quotepath=off so non-ASCII filenames cannot dodge the pattern (phase 2 review, F2).
    # Feature 028 (plan D5): read through the shared reader. A diff git could not compute is a named
    # state (a failure on the numbered lane, once per run; UNGRADED on the Lite lane), never an empty
    # list in which no review file exists to grade.
    $read = Read-DiffLines -GitArguments @('-c', 'core.quotepath=off', 'diff', '--name-status', '--diff-filter=AR', $Base, 'HEAD')
    if (-not $read.Ok) {
        Add-DiffUnreadable -Reader 'ReviewProvenance' -Branch $Branch -Base $Base -Exit $read.Exit -Consequence 'no review file added on this branch was inspected - the machine half of DoD gate 5 formed no opinion'
        return
    }
    $rows = $read.Lines
    $candidates = @()
    foreach ($row in $rows) {
        if (-not $row) { continue }
        $parts = $row -split "`t"
        if ($parts.Count -lt 2) { continue }
        $target = if ($parts[0] -match '^R' -and $parts.Count -ge 3) { $parts[2] } else { $parts[1] }
        if ($target -match '^specs/' -and $target -notmatch '^specs/_templates/' -and $target -match 'ai-code-review[^/]*\.md$') {
            $candidates += $target
        }
    }
    $attestation = 'This reviewer did not produce the diff under review.'
    foreach ($file in $candidates) {
        if (-not (Test-Path -LiteralPath $file)) {
            $script:failures += "ReviewProvenance: $file is in the branch diff but missing from the working tree — cannot verify provenance (fail-closed)"
            continue
        }
        $content = Get-Content -LiteralPath $file -Raw
        if ($content -notmatch '(?m)^##\s+Reviewer Provenance') {
            $script:failures += "ReviewProvenance: $file has no '## Reviewer Provenance' section — the AI review must be produced by a fresh-context agent or second model and say so (DoD gate 5; specs/_templates/ai-code-review-template.md)"
            continue
        }
        # Inspect ONLY the provenance section: the template's document header also carries
        # a '**Reviewer**:' field, which must never shadow the block's (phase 2 review, F1).
        $slice = if ($content -match '(?ms)^##\s+Reviewer Provenance\s*$(.*?)(?=^##\s|\z)') { $matches[1] } else { '' }
        $reviewerLine = $slice -split "`n" | Where-Object { $_ -match '^\s*[-*]?\s*\*\*Reviewer\*\*:\s*(\S.*)$' } | Select-Object -First 1
        $reviewerValue = if ($reviewerLine -match '\*\*Reviewer\*\*:\s*(.+)$') { $matches[1].Trim() } else { '' }
        if (-not $reviewerValue) {
            $script:failures += "ReviewProvenance: $file has no filled '**Reviewer**:' line inside its Reviewer Provenance section"
        } elseif ($reviewerValue -match '^(?i)implementer\b' -or $reviewerValue -match '^\[') {
            $script:failures += "ReviewProvenance: $file attests '$reviewerValue' as reviewer — the implementing agent must not review its own diff, and template placeholders must be filled (DoD gate 5)"
        }
        if ($content -notmatch [regex]::Escape($attestation)) {
            $script:failures += "ReviewProvenance: $file is missing the verbatim attestation sentence '$attestation'"
        }
    }
}

# --- Phase-commit diff-size warning (FR-006, non-blocking) ---
function Invoke-PhaseSizeWarningCheck {
    param([string]$Branch, [string]$Base)
    if ($Branch -notmatch '^\d{3}-') { return }
    if (-not $Base) {
        $script:ungraded += "PhaseSizeWarning: no diff base, so no commit on '$Branch' was measured against the phase-size guideline"
        return
    }
    # Feature 029 (plan D3, G3): the reads go through Read-GitLines. The check is advisory, so a failed
    # read is one UNGRADED line (-Advisory), never a failure: the warning that did not print is named.
    $sizeConsequence = 'that commit was not measured against the phase-size guideline'
    $walk = Read-GitLines -GitArguments @('rev-list', "$Base..HEAD")
    if (-not $walk.Ok) {
        Add-GitReadUnreadable -Reader 'PhaseSizeWarning' -Read "git rev-list of $Base..HEAD" -Key 'rev-list' -Branch $Branch -Exit $walk.Exit -Consequence 'no commit on the branch was measured against the phase-size guideline' -Advisory
        return
    }
    $commits = $walk.Lines | Where-Object { $_ }
    foreach ($commit in $commits) {
        $numstatRead = Read-GitLines -GitArguments @('show', '--numstat', '--format=', $commit)
        if (-not $numstatRead.Ok) {
            Add-GitReadUnreadable -Reader 'PhaseSizeWarning' -Read "git show --numstat of $($commit.Substring(0, 7))" -Key 'numstat' -Branch $Branch -Exit $numstatRead.Exit -Consequence $sizeConsequence -Advisory
            continue
        }
        $numstat = $numstatRead.Lines
        $fileCount = 0
        $lineCount = 0
        foreach ($row in $numstat) {
            if (-not $row) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -lt 3) { continue }
            $fileCount++
            if ($parts[0] -match '^\d+$') { $lineCount += [int]$parts[0] }
            if ($parts[1] -match '^\d+$') { $lineCount += [int]$parts[1] }
        }
        if ($lineCount -gt $Config.PhaseWarnLines -or $fileCount -gt $Config.PhaseWarnFiles) {
            $short = $commit.Substring(0, 7)
            $script:warnings += "PhaseSizeWarning: commit $short changes $lineCount line(s) across $fileCount file(s) — exceeds the phase-size guideline ($($Config.PhaseWarnLines) lines / $($Config.PhaseWarnFiles) files, constitution X). Non-blocking; consider whether this is one coherent slice."
        }
    }
}

# --- Amendment-authority check (014 FR-004; constitution I, Amendment authority) ---
# Grades commits, not the cumulative diff (plan D1): the record lives in a commit's diff AND
# its message, and a cumulative diff has no messages and cannot tell an amendment from a
# creation that was later edited.
#
# Bounded by plan D2b: a commit is graded only if THIS CHECK existed before that commit was
# made. Nothing earlier is graded, here or in an adopted project — so the update that delivers
# the check is silent, and no in-flight branch turns red at once. The boundary is not a
# convenience: D5 puts half of every record in an immutable commit message, so a retroactive
# rule would be one nobody could comply with.
$script:AmendmentRecordPattern = '^\*\*Amendment approved by\*\*:\s*(.+?)\s*,\s*(\d{4}-\d{2}-\d{2})\s*\.?\s*$'
$script:AmendmentRecordExample = '**Amendment approved by**: <name>, <YYYY-MM-DD>'

# --- Plumbing batches (phase 3, T024 / SC-006) --------------------------------------------
# The check's cost is dominated by CHILD PROCESSES, not by the work inside them. Measured on
# this branch, the per-commit shape of D1 asked git 66 questions — three quarters of every git
# call the whole pack made, and about a third of `ritual-checks`. Each batch below asks ONE
# question whose answer covers the range. None of them changes WHAT is graded: per-commit
# granularity is what makes D5's message test possible and it is untouched (plan, Complexity
# Tracking: "batch the plumbing calls, not the granularity").
$script:GitRS = [string][char]30   # ASCII record separator — line marker only, never a record split
$script:GitFS = [string][char]31   # ASCII unit separator

# sha -> @{ Parents; Day; Body; Trailers } for every commit in the range, in one git call.
# Replaces one `rev-list --parents -n 1` per commit plus three `show -s` calls per amendment.
#
# Records are separated by NUL (`-z`), not by a C0 byte picked for rarity. git REFUSES a NUL in
# a commit log message ("error: a NUL byte in commit log message not allowed") and carries 0x1E
# through untouched, so the old 0x1E split was injectable: one byte in a message deleted that
# commit from the graded set AND from the count's denominator, and a crafted record overwrote an
# earlier commit's parentage so it was skipped as a root (review B1).
#
# Field order is part of the fix. The two message-derived fields come LAST and the split is
# capped at five, so an injected 0x1F can only truncate them — never shift the sha, the parents
# or the date. Every corruption still reachable here loses message text, and losing message text
# can only make the D5 name test fail, never pass.
function Get-CommitMetaBatch {
    param([string]$Range)
    $fmt = "%H$script:GitFS%P$script:GitFS%ad$script:GitFS%B$script:GitFS%(trailers:only)"
    $read = Read-AmendmentGit -GitArguments @('log', '-z', '--reverse', '--date=short', "--format=$fmt", $Range) -Read "git log of $Range"
    $raw = ($read.Lines -join "`n")
    $meta = [ordered]@{}
    foreach ($rec in ($raw -split "`0")) {
        if (-not $rec.Trim()) { continue }
        $f = $rec -split $script:GitFS, 5
        if ($f.Count -lt 5) { continue }
        $meta[$f[0].Trim()] = @{
            Parents  = @($f[1].Trim() -split '\s+' | Where-Object { $_ })
            Day      = $f[2].Trim()
            Body     = @($f[3] -split "`r?`n")
            Trailers = @($f[4] -split "`r?`n" | Where-Object { $_.Trim() })
        }
    }
    return $meta
}

# sha -> the commit's raw name-status rows, for every commit in the range, in one git call.
# Merge commits produce no rows here exactly as `git show --name-status` produced none; D7
# discards them before this is read, so the two agree by construction.
function Get-NameStatusBatch {
    param([string]$Range)
    $map = @{}
    $current = $null
    # quotepath=off so a non-ASCII path arrives verbatim rather than quoted-octal: quoted, it
    # fails the "$dir/*" filter and the document is never graded at all (review B2). The pack
    # already carries this at scripts/scope-lib.ps1 (006 F3) and at line 577 (phase 2 F2); this
    # reader was the one that did not.
    # The rows of every commit git finished are complete (git builds a commit's whole output before it
    # prints it, so the commit it failed on prints nothing, measured on AMEND-009's fixture). So the rows
    # of a failing run are KEPT: the walk grades the commits that have a record (feature 027 pinned that a
    # genuine failure is kept beside a refusal), and Core refuses at the END of the walk if a graded commit
    # had none, unless a refusal of its own already ended the walk.
    $nsRead = Read-GitLines -KeepPartial -GitArguments @('-c', 'core.quotepath=off', 'log', '--reverse', "--format=$script:GitRS%H", '--name-status', $Range)
    $script:NameStatusRead = @{ Ok = $nsRead.Ok; Exit = $nsRead.Exit; Read = "git log --name-status of $Range" }
    foreach ($line in $nsRead.Lines) {
        # ORDINAL comparison, deliberately. String.StartsWith defaults to a CULTURE-SENSITIVE
        # comparison that treats a control character as ignorable, so every line — including
        # the empty ones — "starts with" the record separator and the parse collapses.
        if ($line.Length -gt 0 -and $line[0] -eq [char]30) {
            $current = $line.Substring(1).Trim()
            $map[$current] = @()
            continue
        }
        if (-not $current -or -not $line) { continue }
        $map[$current] += $line
    }
    return $map
}

# A ref is pre-boundary only if the check is provably absent from a tree we could actually read.
# `git grep` exits 1 both for "searched it, no match" and for "could not read the blob" — it
# prints the error to stderr and exits 1 either way — so B3's `>= 2` guard never fires for an
# unreadable object and absence from the presence set is not evidence of absence. Measured on a
# fixture whose blob was deleted: the check graded 0 of 2 commits, let an unapproved amendment
# through, and reported "made before the check existed" about a tree that contained it (T080).
function Test-CheckAbsentForReal {
    param([string]$Ref)
    git cat-file commit "${Ref}^{commit}" *> $null
    if ($LASTEXITCODE -ne 0) { return $false }                       # the commit itself is gone
    $entry = @(git ls-tree --name-only "$Ref" -- 'scripts/enforcement-pack.ps1' 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    if (@($entry | Where-Object { $_ }).Count -eq 0) { return $true } # the script did not exist yet
    # Read the whole object, because anything less answers a different question (review G1).
    # `-e` asks only whether the store names it: exit 0 on a corrupt blob and on a truncated
    # one. `-s` inflates the HEADER only: still exit 0 on an object truncated mid-body, where
    # `git grep` exits 128. Only inflating the body fails wherever a reader fails — measured
    # across all three damage modes (deleted / garbage / truncated) at no measurable cost.
    # Stdout is suppressed as well as stderr: the content would otherwise join this function's
    # output stream and return an array whose truthiness is not the boolean the caller tests.
    git cat-file blob "${Ref}:scripts/enforcement-pack.ps1" *> $null
    return ($LASTEXITCODE -eq 0)                                     # readable and without it
}

# The set of refs that already carry the check (D2b), in one git call. `git grep` searches many
# trees at once and prints '<rev>:<path>' per hit, so the boundary question that cost one 39 KB
# blob read per ungraded commit now costs one process for the whole branch. Self-bootstrapping,
# as the per-ref version was: the test is whether that tree's copy of THIS script defines the
# check function.
function Get-CheckPresenceSet {
    param([string[]]$Refs)
    $set = @{}
    $unique = @($Refs | Where-Object { $_ } | Sort-Object -Unique)
    if ($unique.Count -eq 0) { return $set }
    # Chunked and error-checked, because this batch had two ways to come back empty without
    # saying so, and an empty presence set grades NOTHING while printing exactly what a
    # legitimately pre-boundary branch prints — J2's fail-open shape with a new trigger
    # (review B3). (a) `git grep` aborts the WHOLE search on one unresolvable ref (exit >= 2:
    # a shallow or partial clone, a grafted history, a missing object); (b) ~41 bytes per sha
    # against a 32 767-byte Windows command line puts the ceiling near 700 refs in one call.
    # On an error exit the pre-batching per-ref probe runs for that chunk: slower, never silent.
    for ($i = 0; $i -lt $unique.Count; $i += 200) {
        $chunk = @($unique[$i..([Math]::Min($i + 199, $unique.Count - 1))])
        $hits = @(git grep -l -F -e 'function Invoke-AmendmentAuthorityCheck' @chunk -- 'scripts/enforcement-pack.ps1' 2>$null)
        if ($LASTEXITCODE -ge 2) {
            foreach ($ref in $chunk) {
                $blob = @(git show "${ref}:scripts/enforcement-pack.ps1" 2>$null)
                if ($LASTEXITCODE -eq 0 -and @($blob -match 'function Invoke-AmendmentAuthorityCheck').Count -gt 0) {
                    $set[$ref] = $true
                }
            }
            continue
        }
        foreach ($hit in $hits) {
            if ($hit -match '^(.+):scripts/enforcement-pack\.ps1$') { $set[$matches[1]] = $true }
        }
    }
    return $set
}

# One blob, read at most once per run. The visibility test, the occurrence count and the
# checkbox comparison all want the same two blobs of the same tasks.md; without this they read
# each of them twice.
$script:AmendmentBlobCache = @{}
# Feature 029 phase 2 (plan D4, G9): "did this path's content come across intact" compares two
# `git rev-parse` results. When BOTH reads fail the old `$null -eq $null` was true, so a renamed approved
# document was read as unchanged and escaped grading. A failed read is never "the same": it returns
# false (so the path is graded) and Read-AmendmentGit records the failure for the walk's refusal.
function Test-SameBlobContent {
    param([string]$Commit, [string]$Path, [string]$Parent, [string]$OldPath)
    $now  = Read-AmendmentGit -GitArguments @('rev-parse', "${Commit}:${Path}") -Read "git rev-parse $($Commit.Substring(0, 7)):$Path"
    $then = Read-AmendmentGit -GitArguments @('rev-parse', "${Parent}:${OldPath}") -Read "git rev-parse $($Parent.Substring(0, 7)):$OldPath"
    if (-not $now.Ok -or -not $then.Ok) { return $false }
    return (@($now.Lines) -join '') -eq (@($then.Lines) -join '')
}

function Get-BlobLines {
    param([string]$Ref, [string]$Path)
    if (-not $Ref) { return @() }
    $key = "${Ref}:${Path}"
    if ($script:AmendmentBlobCache.ContainsKey($key)) { return $script:AmendmentBlobCache[$key] }
    # `git show <rev>:<path>` exits non-zero both for a path the commit does not hold (a deleted document:
    # an empty body is the right answer) and for a path it holds whose object cannot be read, and a
    # truncated blob and an absent path do not even exit alike (255 and 128). So a failed show is probed:
    # `git ls-tree` exits 0 with no output for an absent path, and anything else is an unreadable object.
    $shown = Read-GitLines -GitArguments @('show', $key)
    if ($shown.Ok) { $lines = @($shown.Lines) }
    else {
        $lines = @()
        $probe = Read-GitLines -GitArguments @('ls-tree', $Ref, '--', $Path)
        if (-not ($probe.Ok -and @($probe.Lines | Where-Object { $_ }).Count -eq 0)) { Set-AmendmentReadFailure -Read "git show $key" -Exit $shown.Exit }
    }
    $script:AmendmentBlobCache[$key] = $lines
    return $lines
}

# The Markdown-visibility helpers moved to scripts/markdown-lib.ps1 (feature 015, phase 2):
# build-digests.ps1 needed the same rule for GAP-025, and a copy would have to relearn
# every fix this one took. Disable-CommentMarkers, Convert-SpanText and Get-FencedLineMap
# arrive from there. This check uses Convert-SpanText, the per-line pairing, and NOT the
# whole-document Convert-CodeSpanMarkers the digest generator uses (016 plan D11). Three
# review rounds found that every reading that disarms more than per-line pairing let some
# record inside a real comment, or hidden by an attribute or title, count as a grant. So a
# code span that wraps across lines holding '<!--' still hides what follows it here (GAP-028):
# fail-closed, remedied by keeping such a span on one line.
. (Join-Path $PSScriptRoot 'markdown-lib.ps1')

# Visible lines of a text blob — HTML comments stripped, same rule as Get-VisiblePlanLines
# (008 phase-2 F1). Commented-out text is not law and is not a record (H1).
function Get-VisibleFromText {
    param([string[]]$Lines)
    # Markdown renders code as literal text, so a '<!--' inside a fenced block or an inline code
    # span is NOT a comment opener. Neutralise the markers inside code BEFORE the rules below.
    # Without this, T060's own description — which quotes a backticked `<!--` — made the
    # unterminated-comment rule truncate tasks.md from that line on, hiding every approver
    # record added after it. The rule became impossible to comply with in any document that
    # mentions the syntax, this feature's own included (B7, found while remediating B1-B6).
    # It fails closed, so it never passed a silent amendment — it just could not be satisfied.
    #
    # The code regions are found STRUCTURALLY, line by line (K1). The first fix used
    # '(?s)```.*?```' over the whole blob, which pairs triple-backtick runs left to right with
    # no regard for line starts: one stray fence run in prose re-paired every fence after it,
    # put a REAL comment inside a region the check called code, and made a record no reader can
    # see count as a grant — H1, reopened by its own fix.
    $raw = ($Lines -join "`n")
    # No marker anywhere means no comment anywhere: nothing to neutralise and nothing to strip.
    if ($raw -notmatch '<!--') { return $raw -split "`r?`n" }
    $fenced = Get-FencedLineMap -Lines $Lines
    $processed = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($fenced[$i]) { $processed.Add((Disable-CommentMarkers -Text $Lines[$i])) }
        else             { $processed.Add((Convert-SpanText -Text $Lines[$i])) }
    }
    $raw = ($processed -join "`n")
    $stripped = [regex]::Replace($raw, '(?s)<!--.*?-->', '')
    # An UNTERMINATED '<!--' hides everything after it in every renderer, so it must hide it
    # here too (J5). The pack's CriticalEvidence check already warns about this exact trap.
    $stripped = [regex]::Replace($stripped, '(?s)<!--.*$', '')
    return $stripped -split "`r?`n"
}

# Lines a commit ADDED to the given paths that are also VISIBLE in the resulting file, and
# that did not already exist in the parent (H1, H5). A record hidden in a comment renders as
# nothing; a record merely moved from elsewhere in the same file was not granted by this
# commit.
function Get-AddedRecordLines {
    param([string]$Commit, [string]$Parent, [string[]]$Paths)
    if (-not $Paths -or $Paths.Count -eq 0) { return @() }
    $result = @()
    foreach ($path in ($Paths | Sort-Object -Unique)) {
        $added = @((Read-AmendmentGit -GitArguments @('show', '-U0', '--format=', $Commit, '--', $path) -Read "git show -U0 of $($Commit.Substring(0, 7)) -- $path").Lines |
            Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' } |
            ForEach-Object { $_.Substring(1) })
        if ($added.Count -eq 0) { continue }
        # Only lines that LOOK like a record can be one. Filtering first keeps the expensive
        # visibility and occurrence work proportional to the number of candidate records
        # (normally one) instead of to the size of the commit — a 600-line commit was costing
        # seconds per file before this.
        $candidates = @($added | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match $script:AmendmentRecordPattern } | Sort-Object -Unique)
        if ($candidates.Count -eq 0) { continue }
        $visCount = @{}
        foreach ($l in (Get-VisibleFromText -Lines (Get-BlobLines -Ref $Commit -Path $path))) {
            $t = $l.Trim(); if ($t) { $visCount[$t] = 1 + [int]$visCount[$t] }
        }
        $beforeCount = @{}
        foreach ($l in (Get-VisibleFromText -Lines (Get-BlobLines -Ref $Parent -Path $path))) {
            $t = $l.Trim(); if ($t) { $beforeCount[$t] = 1 + [int]$beforeCount[$t] }
        }
        foreach ($line in $candidates) {
            # H1: a line added inside a comment renders as nothing, so it is not a record.
            if (-not $visCount.ContainsKey($line)) { continue }
            # H5/J1: a record counts when the file gained one. Counting occurrences separates a
            # RECYCLED record (moved within the file — count unchanged) from a legitimately
            # REPEATED one (a second amendment, same approver, same day — count increased).
            # The previous "absent from the parent" rule could not tell those apart and rejected
            # the honest case.
            if ([int]$visCount[$line] -le [int]$beforeCount[$line]) { continue }
            $result += $line
        }
    }
    return $result
}

# D3: a tasks.md change that alters nothing but checkbox state is progress, not amendment.
# Completion state moves in EITHER direction (constitution I; review finding F2). The test is
# the text: strip the marker from every added and removed line and compare the multisets.
# D3: progress, not amendment. Compares the WHOLE FILE with every checkbox marker neutralised,
# in order — not the diff hunks (H2, J6). A tick changes markers and nothing else, so the
# neutralised files are identical. Anything that moves, adds, removes or rewords a line changes
# the neutralised sequence and is an amendment. Reasoning about whole files rather than about
# paired hunks removes a class of bug rather than another special case: a line moved between
# phase blocks while being ticked defeated hunk pairing, and could not defeat this.
function Test-CheckboxOnlyChange {
    param([string]$Commit, [string]$Parent, [string]$Path, [string]$ParentPath)
    if (-not $ParentPath) { $ParentPath = $Path }
    $neutral = { param($lines)
        $out = [System.Collections.Generic.List[string]]::new()
        foreach ($l in $lines) { $out.Add(($l -replace '^(\s*(?:[-*]|\d+\.)\s*)\[[ xX]\]', '${1}[]').TrimEnd()) }
        return $out
    }
    $nowRaw  = Get-BlobLines -Ref $Commit -Path $Path
    $thenRaw = Get-BlobLines -Ref $Parent -Path $ParentPath
    # --name-status said this path was modified, so two empty reads are a FAILED read, not an
    # unchanged file. Returning $true there would call an unreadable amendment "checkbox-only"
    # and exempt it; return $false and it is graded like any other change (review B2, rider).
    if ($nowRaw.Count -eq 0 -and $thenRaw.Count -eq 0) { return $false }
    $now  = & $neutral $nowRaw
    $then = & $neutral $thenRaw
    if ($now.Count -ne $then.Count) { return $false }
    for ($i = 0; $i -lt $now.Count; $i++) { if ($now[$i] -ne $then[$i]) { return $false } }
    return $true
}

# D3d (owner decision 2026-09-16 on review finding B5): a diff whose only change is the
# **Status** line is the act of approval, not an amendment to an approved document. The
# constitution's own scope sentence — "once a feature's spec.md or plan.md has been APPROVED" —
# puts the approval act outside the rule it starts, and the kit's spec templates MANDATE the
# edit (Draft -> Approved before the phase begins). Without this the next feature's approval
# commit turned its own branch red, which the replay demonstrated forward, not just in history.
#
# Whole-file comparison — the same shape as the checkbox exemption, and for the same reason
# (H2, J6): reasoning about paired hunks let a line moved elsewhere in the file ride along on
# an exempt change. EXACTLY ONE line may differ, and it must be the approval transition itself.
#
# The first implementation neutralised everything after '**Status**:' on every line that began
# that way, which exempted far more than the approval act (K2): a payload appended to the status
# line rode in ('Approved 2026-09-16 (owner: ada). D2 is withdrawn; ...' compared equal to the
# line without it), any '**Status**:' line qualified including one inside a fenced block or on
# an ADR sub-section, and it fired in either direction at any time. So the new value is matched
# against a bounded approval vocabulary instead of being discarded, and only the document's
# FIRST status line outside code counts. That also puts the exemption inside the constitution's
# own scope sentence rather than beside it (K3): what is exempt is the Draft -> Approved
# transition, which is the act that STARTS the rule, not a later change to an approved document.
#
# The old side is required only to BE Draft; an annotation on it ('Draft — awaiting owner
# approval', the template's trailing guidance comment) may be dropped by the approval. New text
# cannot ride in, which is the direction a payload travels; a plan that puts normative text on
# its Draft status line is already misusing the line, and this is written into plan.md D3d
# rather than left for the next reviewer to discover.
$script:StatusDraftPattern = '^\s*\*\*Status\*\*:\s*Draft\b'
$script:StatusApprovedPattern =
    '^\s*\*\*Status\*\*:\s*Approved' +
    '(?:\s+\d{4}-\d{2}-\d{2})?' +
    '(?:\s+\(owner[:,]?\s*[A-Za-z0-9._@\- ]{1,40}(?:,\s*\d{4}-\d{2}-\d{2})?\))?' +
    '(?:\s*<!--[^\r\n]*-->)?\s*$'
function Test-StatusOnlyChange {
    param([string]$Commit, [string]$Parent, [string]$Path, [string]$ParentPath)
    if (-not $ParentPath) { $ParentPath = $Path }
    $nowRaw  = Get-BlobLines -Ref $Commit -Path $Path
    $thenRaw = Get-BlobLines -Ref $Parent -Path $ParentPath
    # Two empty reads are a failed read, not an unchanged file (the B2 rider, same reasoning).
    if ($nowRaw.Count -eq 0 -and $thenRaw.Count -eq 0) { return $false }
    if ($nowRaw.Count -ne $thenRaw.Count) { return $false }
    $diffAt = -1
    for ($i = 0; $i -lt $nowRaw.Count; $i++) {
        if ($nowRaw[$i].TrimEnd() -ne $thenRaw[$i].TrimEnd()) {
            if ($diffAt -ge 0) { return $false }
            $diffAt = $i
        }
    }
    if ($diffAt -lt 0) { return $false }
    # The status line of the document is the first one Markdown RENDERS — a '**Status**:' line
    # inside a fenced block is sample text, and an ADR's or a sub-section's status is prose that
    # gets graded like any other prose.
    $nowFence  = Get-FencedLineMap -Lines $nowRaw
    $thenFence = Get-FencedLineMap -Lines $thenRaw
    $nowFirst = -1; $thenFirst = -1
    for ($i = 0; $i -lt $nowRaw.Count; $i++) {
        if (-not $nowFence[$i] -and $nowRaw[$i] -match '^\s*\*\*Status\*\*:') { $nowFirst = $i; break }
    }
    for ($i = 0; $i -lt $thenRaw.Count; $i++) {
        if (-not $thenFence[$i] -and $thenRaw[$i] -match '^\s*\*\*Status\*\*:') { $thenFirst = $i; break }
    }
    if ($nowFirst -lt 0 -or $nowFirst -ne $thenFirst -or $diffAt -ne $nowFirst) { return $false }
    return ($thenRaw[$diffAt] -match $script:StatusDraftPattern) -and
           ($nowRaw[$diffAt]  -match $script:StatusApprovedPattern)
}

# D6: an unfilled or impossible record is no record.
# -Pattern defaults to the amendment record's shape. Feature 017 passes the Surface Exception
# approval's own pattern so that "what is a well-formed approver" has ONE definition: a second
# copy of this validation (placeholder names, real dates, not later than the commit) is exactly
# how two graders of one rule drift. Every AMEND-* fixture is the guard that the default is
# unchanged.
function Get-ConformingRecord {
    param([string[]]$AddedLines, [string]$CommitDay, [string]$Pattern = $script:AmendmentRecordPattern)
    $result = @{ Name = $null; Malformed = @() }
    foreach ($line in $AddedLines) {
        if ($line -notmatch $Pattern) { continue }
        $name = $matches[1].Trim()
        $dateText = $matches[2]
        if (-not $name -or $name -match '^\{\{.*\}\}$' -or $name -match '^TODO\(' -or
            $name -match '^\[.*\]$' -or $name -match '^<.*>$') {
            $result.Malformed += "approver name '$name' is a placeholder, not a name"
            continue
        }
        $parsed = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($dateText, 'yyyy-MM-dd',
                [globalization.cultureinfo]::InvariantCulture,
                [globalization.datetimestyles]::None, [ref]$parsed)) {
            $result.Malformed += "date '$dateText' is not a real YYYY-MM-DD date"
            continue
        }
        # String comparison of two YYYY-MM-DD values taken in the AUTHOR's own timezone (H6).
        # [datetime]::Parse of an ISO offset converts to the runner's local time, which made the
        # same commit green locally and red in CI — the machine-dependence D6 exists to forbid.
        if ($dateText -gt $CommitDay) {
            $result.Malformed += "date '$dateText' is later than the commit's own author date ($CommitDay)"
            continue
        }
        $result.Name = $name
        return $result
    }
    return $result
}

# --- Merge commits (feature 026) --------------------------------------------------------------
# A merge commit used to be skipped outright (feature 014 D7: "a merge authored nothing"). That is
# true of a merge that only brings two histories together and false of one that resolves a conflict
# by hand or edits a document while merging: the content it carries is in no parent, so no commit
# granted it (feature 025's review reproduction put '**Merge Readiness**: pending' into an approved
# plan inside a merge and the run ended on OK). The question asked of a merge is per document: does
# the merged result equal what a parent already had, or what git's own automatic merge of the
# parents makes? If so nothing was authored. If not, the merge authored that document and it is
# graded like any amendment (plan D1-D5).

# path -> blob id of the feature's graded documents in one commit, in one git call (plan D1). $null
# means the commit's tree could not be read, which the caller refuses rather than skips (D7).
# Feature 027 (plan D1): the documents the check grades, in EVERY feature directory and not only the
# branch's own. The first capture of the pattern is the feature directory's name; the function
# returns it as 'specs/NNN-name', or $null for any path that is not a graded document (a notes.md,
# a checklist, a screenshot, a path outside specs/NNN-*, a template).
$script:GradedDocPattern = '^specs/(\d{3}-[^/]+)/(?:spec\.md|plan\.md|tasks\.md|contracts/.+)$'
function Get-GradedDocFeature {
    param([string]$Path)
    if ($Path -match $script:GradedDocPattern) { return "specs/$($matches[1])" }
    return $null
}

# The graded documents that exist at a ref (plan D2: "exists at the diff base" is the line between a
# creation and an amendment of ANOTHER feature's document). One git call; $null when the tree cannot
# be read, so the caller refuses and never reads an unreadable base as "nothing was approved".
function Get-GradedDocSet {
    param([string]$Ref)
    $raw = (@(git -c core.quotepath=off ls-tree -r --name-only -z $Ref -- specs 2>$null) -join "`n")
    if ($LASTEXITCODE -ne 0) { return $null }
    $set = @{}
    foreach ($p in ($raw -split "`0")) {
        if ($p -and (Get-GradedDocFeature -Path $p)) { $set[$p] = $true }
    }
    return $set
}

# $Dir scopes the read (a feature directory, or 'specs' for every feature); which paths are graded
# documents is decided by Get-GradedDocFeature either way.
function Get-FeatureDocMap {
    param([string]$Commit, [string]$Dir)
    $raw = (@(git ls-tree -r -z $Commit -- $Dir 2>$null) -join "`n")
    if ($LASTEXITCODE -ne 0) { return $null }
    $map = @{}
    foreach ($rec in ($raw -split "`0")) {
        if ($rec -notmatch '(?s)^\d+ blob ([0-9a-f]{40,64})\t(.+)$') { continue }
        $blob = $matches[1]
        $path = $matches[2]
        if (-not (Get-GradedDocFeature -Path $path)) { continue }
        $map[$path] = $blob
    }
    return $map
}

# The tree git itself would make by merging two parents (plan D2), or $null when it cannot say: an
# old git (no --write-tree: an unknown-option exit, never assumed), a failure other than a conflict.
# A conflict (exit 1) still names a tree, with the conflict markers in it, so a hand resolution
# differs from it and is graded. Side effect, stated: this writes tree and blob objects into the
# object database (unreferenced, collected by gc); no ref and no working-tree file changes.
function Get-AutoMergeTree {
    param([string]$ParentA, [string]$ParentB)
    $out = @(git merge-tree --write-tree --no-messages $ParentA $ParentB 2>$null)
    if ($LASTEXITCODE -gt 1 -or $out.Count -eq 0) { return $null }
    $tree = "$($out[0])".Trim()
    if ($tree -notmatch '^[0-9a-f]{40,64}$') { return $null }
    return $tree
}

# The feature documents a merge authored. Returns @{ Unreadable = <what could not be read> ; Paths }.
function Get-MergeAuthoredPaths {
    # $Dir is the branch's own feature directory ($null on a Lite branch). A document of ANOTHER feature
    # is considered only when it exists at the diff base ($AtBase, plan D2 and D4), so a merge of main
    # that brings other features' documents in is decided by the same comparison, and a creation is not.
    param([string]$Merge, [string[]]$Parents, [string]$Dir, [scriptblock]$LoadBase)
    $result = @{ Unreadable = $null; BaseUnreadable = $false; Paths = @() }
    # D7: each parent must be readable. A skipped merge on a wrong reason is GAP-027's shape.
    foreach ($p in $Parents) {
        git cat-file -e "${p}^{commit}" *> $null
        if ($LASTEXITCODE -ne 0) { $result.Unreadable = $p; return $result }
    }
    $mergeMap = Get-FeatureDocMap -Commit $Merge -Dir specs
    if ($null -eq $mergeMap) { $result.Unreadable = $Merge; return $result }
    $parentMaps = @()
    foreach ($p in $Parents) {
        $pm = Get-FeatureDocMap -Commit $p -Dir specs
        if ($null -eq $pm) { $result.Unreadable = $p; return $result }
        $parentMaps += , $pm
    }
    # The diff base is read only after the merge and its parents proved readable, so a damaged parent
    # is reported as itself (D7) and not as an unreadable base.
    $AtBase = & $LoadBase
    if ($null -eq $AtBase) { $result.BaseUnreadable = $true; return $result }
    $candidates = @($mergeMap.Keys)
    foreach ($pm in $parentMaps) { $candidates += @($pm.Keys) }
    $autoTree = $null; $autoTried = $false
    $paths = @()
    foreach ($path in ($candidates | Sort-Object -Unique)) {
        $feature = Get-GradedDocFeature -Path $path
        # Feature 027 (D4): another feature's document counts only when it exists at the diff base.
        if ($feature -ne $Dir -and -not ($AtBase -and $AtBase.ContainsKey($path))) { continue }
        $m = if ($mergeMap.ContainsKey($path)) { $mergeMap[$path] } else { '' }
        $inParents = [System.Collections.Generic.List[string]]::new()
        foreach ($pm in $parentMaps) { $inParents.Add($(if ($pm.ContainsKey($path)) { $pm[$path] } else { '' })) }
        # D2 (014): a document absent in every parent is created by the merge, a first appearance.
        if ($m -ne '' -and @($inParents | Where-Object { $_ -ne '' }).Count -eq 0) { continue }
        # D1: the merged result equals what a parent already had. Only a document the merge KEEPS can
        # equal a parent's: a removal is not "equal" to a parent that never had the file (a main
        # merged into the branch never holds the feature directory, so every deletion, and the old
        # path of a rename, would otherwise be exempt, review F1). A removal is silent only when git's
        # own automatic merge removes it too, below, so a deletion on one side stays a non-event.
        if ($m -ne '' -and $inParents.Contains($m)) { continue }
        # D2: or what git's own automatic merge of two parents makes.
        if ($Parents.Count -eq 2) {
            if (-not $autoTried) { $autoTried = $true; $autoTree = Get-AutoMergeTree -ParentA $Parents[0] -ParentB $Parents[1] }
            if ($autoTree) {
                $a = @(git rev-parse --verify --quiet "${autoTree}:${path}" 2>$null)
                $autoBlob = if ($LASTEXITCODE -eq 0 -and $a.Count -gt 0) { "$($a[0])".Trim() } else { '' }
                if ($autoBlob -eq $m) { continue }
            }
        }
        # D3: the exemptions are asked of EVERY parent; held against one only, a merge could carry a
        # substantive edit that happens to be tick-only relative to the other.
        if ($m -ne '') {
            $leaf = $path.Substring($feature.Length + 1)
            $exempt = $true
            foreach ($p in $Parents) {
                $ok = if ($leaf -eq 'tasks.md') { Test-CheckboxOnlyChange -Commit $Merge -Parent $p -Path $path }
                      elseif ($leaf -in @('spec.md', 'plan.md')) { Test-StatusOnlyChange -Commit $Merge -Parent $p -Path $path }
                      else { $false }
                if (-not $ok) { $exempt = $false; break }
            }
            if ($exempt) { continue }
        }
        $paths += $path
    }
    $result.Paths = $paths
    return $result
}

# The record lines a merge added (plan D4): visible in the merged file, matching the record
# pattern, and counted MORE times there than in EVERY parent. A record a parent already carried
# approved that parent's change, not the merge's. Get-AddedRecordLines reads `git show -U0` of a
# commit, which for a merge is a combined diff, so it is not reused (and is not edited): the
# occurrence count it applies to the lines a commit added is applied to the file directly, which
# is the same set (a line whose count rose in the file was added by any diff against a parent).
function Get-MergeRecordLines {
    param([string]$Merge, [string[]]$Parents, [string[]]$Paths)
    $result = @()
    foreach ($path in ($Paths | Sort-Object -Unique)) {
        # A candidate is a RAW line of the merged file, trimmed, that is the record pattern as
        # written (Get-AddedRecordLines reads the raw added line the same way: a record with a
        # trailing inline comment is no record), and it must also be visible (H1).
        $mergedRaw = Get-BlobLines -Ref $Merge -Path $path
        $candidates = @($mergedRaw | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match $script:AmendmentRecordPattern } | Sort-Object -Unique)
        if ($candidates.Count -eq 0) { continue }
        $visCount = @{}
        foreach ($l in (Get-VisibleFromText -Lines $mergedRaw)) {
            $t = $l.Trim(); if ($t) { $visCount[$t] = 1 + [int]$visCount[$t] }
        }
        $newAgainst = @{}
        foreach ($t in $candidates) { if ($visCount.ContainsKey($t)) { $newAgainst[$t] = $true } }
        if ($newAgainst.Count -eq 0) { continue }
        foreach ($p in $Parents) {
            $before = @{}
            foreach ($l in (Get-VisibleFromText -Lines (Get-BlobLines -Ref $p -Path $path))) {
                $t = $l.Trim(); if ($t) { $before[$t] = 1 + [int]$before[$t] }
            }
            foreach ($t in @($newAgainst.Keys)) {
                if ([int]$visCount[$t] -le [int]$before[$t]) { $newAgainst.Remove($t) }
            }
        }
        $result += @($newAgainst.Keys | Sort-Object)
    }
    return $result
}

# Feature 027 (plan D3): what one name-status row of ANOTHER feature's document means for the check.
# Returns the path to grade, or $null when the row is not an amendment: a creation, a document that
# does not exist at the diff base (never approved on the integration branch), a pure rename, a
# whole-directory renumbering, a task tick, a **Status** approval. A move out of the branch's own
# directory is not graded, as today. A move between feature directories is graded as the REMOVAL of
# the old path unless the whole directory moved, and a removal has no passing path (spec FR-007).
# The branch's own directory never reaches this function: its block keeps its own code.
function Get-OtherFeatureSubject {
    param([string]$Commit, [string]$Parent, [string]$Dir, [string]$Status,
          [string]$Path, [string]$OldPath, [hashtable]$AtBase)
    $pathFeature = Get-GradedDocFeature -Path $Path
    $isMove = $Status -match '^[RC]'
    if ($isMove) {
        $oldFeature = Get-GradedDocFeature -Path $OldPath
        if (-not $oldFeature) { return $null }                       # a document made from a non-document
        if ($oldFeature -eq $Dir) { return $null }                   # out of the own directory: as today
        if (-not $AtBase.ContainsKey($OldPath)) { return $null }     # never approved on the base
        if ($pathFeature -eq $oldFeature) {
            # Within one feature directory: creation only if the content came across intact (J3, H3).
            if (Test-SameBlobContent -Commit $Commit -Path $Path -Parent $Parent -OldPath $OldPath) { return $null }
            $subject = $Path
        } else {
            if ($pathFeature) {
                # Between feature directories: a renumbering only when the old directory holds no
                # graded document any more (the whole feature moved); otherwise a removal.
                $leftRead = Read-AmendmentGit -GitArguments @('-c', 'core.quotepath=off', 'ls-tree', '-r', '--name-only', $Commit, '--', $oldFeature) -Read "git ls-tree of $($Commit.Substring(0, 7)) -- $oldFeature"
                # A failed read is not "the old directory holds nothing": treat the move as a removal (graded).
                if (-not $leftRead.Ok) { return $OldPath }
                $left = @($leftRead.Lines | Where-Object { $_ -and (Get-GradedDocFeature -Path $_) })
                if ($left.Count -eq 0) { return $null }
            }
            return $OldPath
        }
    } else {
        if ($Status -match '^A') { return $null }                    # first appearance
        if (-not $pathFeature) { return $null }
        if (-not $AtBase.ContainsKey($Path)) { return $null }
        $subject = $Path
    }
    $leaf = $subject.Substring($pathFeature.Length + 1)
    if ($leaf -eq 'tasks.md' -and
        (Test-CheckboxOnlyChange -Commit $Commit -Parent $Parent -Path $Path -ParentPath $OldPath)) { return $null }
    if ($leaf -in @('spec.md', 'plan.md') -and
        (Test-StatusOnlyChange -Commit $Commit -Parent $Parent -Path $Path -ParentPath $OldPath)) { return $null }
    return $subject
}

# The clause a failure gains when an amended file belongs to another feature (plan D5), or '' for the
# branch's own files, so a failure about the own directory alone reads exactly as it did.
function Get-OtherFeatureNote {
    param([string[]]$Paths, [string]$Dir)
    $other = @($Paths | Where-Object { (Get-GradedDocFeature -Path $_) -ne $Dir } | Sort-Object -Unique)
    if ($other.Count -eq 0) { return '' }
    if (-not $Dir) {
        # A Lite branch has no own directory to be outside of; the document lives in its own feature.
        $lnames = (@($other | ForEach-Object { (Get-GradedDocFeature -Path $_).Substring(6) } | Sort-Object -Unique)) -join ', '
        return "; the amended file(s) ($($other -join ', ')) belong to feature(s) $lnames, and a document is amended where it lives: the record goes in that document"
    }
    $names = (@($other | ForEach-Object { (Get-GradedDocFeature -Path $_).Substring(6) } | Sort-Object -Unique)) -join ', '
    return "; the amended file(s) outside this branch's own directory ($($other -join ', ')) belong to feature(s) $names, and a document is amended where it lives: the record goes in that document, not in this branch's own files"
}

# Feature 027: the check grades a commit's change to a spec.md, plan.md, tasks.md or contracts/** file
# of ANY feature directory. The branch's own directory is graded as it has been since feature 014 (any
# change after the first commit, by the code below that is not edited); another feature's document is
# graded only when it exists at the diff base, because that is where a document has been approved.
# What stays open: "exists at the base" is a proxy for approved (a document that reached the base still
# a Draft counts as approved); a document moved OUT of the branch's own directory is not graded, as
# before; a whole feature directory moved inside a MERGE is graded as the removal of its documents
# (026: a rename is not detected inside a merge), so the move belongs in an ordinary commit; the Lite
# lane (fix/, chore/, docs/) runs this check only when its diff touches a spec document (plan D6), and
# names a condition it cannot compute UNGRADED instead of failing (plan D8), so a Lite branch which has
# no diff base is not graded and says nothing for want of a gate (the dispatch's no-base warning and the
# other members' UNGRADED lines name it); a Lite branch whose diff cannot be READ is named (GAP-034,
# feature 028: either read of the gate's list failing prints an UNGRADED line for this check through
# Add-DiffUnreadable and the check returns, instead of reading as "no spec document changed"); the gate
# list is read a second time without rename detection, so a spec document moved off specs/ is seen. Two more limits of the Lite gate: it reads
# the NET diff, so a branch that amends an approved document with no record and then reverts it, or a
# replay over a range whose net diff is empty, is silent (phase 2 review F2); and a branch that only CREATES a
# spec document, in a clone that is shallow but still has a base, prints an UNGRADED refusal where it used to
# print nothing, because the gate sees a spec path before the walk can tell a creation from an amendment (exit
# code unchanged; phase 2 review F1, accepted by the owner). The docs/ lane line names both checks only when the
# roll-up printed, so a run that ended on a refusal still reads "only review-provenance"; a document of another feature moved INTO
# the branch's own directory IS graded, as the removal of the old path (review F1), except that a sole
# graded document moved in and edited in the same commit is not (the renumbering exemption compares no
# content; second review F2); and the record is still a written claim. Cost: a merge reads `ls-tree -r` of specs per parent and for the base (about
# 100-200 ms per merge measured), growing with the number of features (review F5).
function Invoke-AmendmentAuthorityCheck {
    param([string]$Branch, [string]$Base, [string[]]$ChangedFiles, [switch]$IgnoreAmendmentBoundary,
          [string]$ReplayBase, [string]$ReplayTip)
    $lite = $Branch -match '^(fix|chore|docs)/'
    if ($Branch -notmatch '^\d{3}-' -and -not $lite) { return }
    if ($lite) {
        # Feature 027 (plan D6): a Lite branch has no feature directory and no reason to be graded
        # unless its diff touches a spec document, so the gate is the changed-file list and not the
        # lane. Silence on a branch that touches none is what keeps FR-009 true, including in a
        # shallow clone or with no base. The list is read again WITHOUT rename detection, because
        # git reports a moved document by its new path only, and a spec document moved to a path
        # outside specs/ would otherwise never reach the gate.
        $gate = @($ChangedFiles)
        # Feature 028 (plan D4): a gate that cannot be computed names itself, instead of reading as
        # "no spec document changed". Either read failing enters the state: the dispatch's list
        # (carried in $script:ChangedFilesRead) or this second read, taken through the shared reader.
        $gateExit = $null
        if (-not $script:ChangedFilesRead.Ok) { $gateExit = $script:ChangedFilesRead.Exit }
        elseif ($Base) {
            # This second read cannot fail alone today: with --no-renames git reads no more than the
            # dispatch's rename-detecting read, so it fails only when that one already has (phase 2
            # review F2; mutations M10 and M11 are equivalent for that reason). If the dispatch read
            # ever changes, both branches here become live and are guarded by no fixture.
            $second = Read-DiffLines -GitArguments @('-c', 'core.quotepath=off', 'diff', '--name-only', '--no-renames', $Base, 'HEAD')
            if ($second.Ok) { $gate += $second.Lines } else { $gateExit = $second.Exit }
        }
        if ($null -ne $gateExit) {
            Add-DiffUnreadable -Reader 'AmendmentAuthority' -Branch $Branch -Base $Base -Exit $gateExit -Consequence 'no spec document changed on this branch could be graded'
            return
        }
        if (-not @($gate | Where-Object { $_ -and (Get-GradedDocFeature -Path $_) })) { return }
    }
    $failuresBefore = @($script:failures).Count
    Invoke-AmendmentAuthorityCore -Branch $Branch -Base $Base -Lite:$lite -IgnoreAmendmentBoundary:$IgnoreAmendmentBoundary -ReplayBase $ReplayBase -ReplayTip $ReplayTip
    if ($lite -and @($script:failures).Count -gt $failuresBefore) {
        # Plan D8 (014 FR-009): a Lite branch is never NEWLY failed on a condition it cannot compute.
        # Each refusal of the numbered lane (a shallow clone, no base, an unreadable commit, tree or
        # merge, unparsed metadata) names itself UNGRADED here and leaves the exit code alone; a
        # failure that grades an amendment (no record, approver not in the message) stays a failure.
        $all = @($script:failures)
        $kept = @(); if ($failuresBefore -gt 0) { $kept = @($all[0..($failuresBefore - 1)]) }
        foreach ($f in @($all[$failuresBefore..($all.Count - 1)])) {
            if ($f -match '^AmendmentAuthority: (cannot grade|could not parse commit metadata) ') { $script:ungraded += $f }
            else { $kept += $f }
        }
        $script:failures = $kept
    }
}

function Invoke-AmendmentAuthorityCore {
    param([string]$Branch, [string]$Base, [switch]$Lite, [switch]$IgnoreAmendmentBoundary,
          [string]$ReplayBase, [string]$ReplayTip)
    # Silence is not compliance (phase 4 review F1). Two conditions make the boundary
    # uncomputable, and both used to `return` bare — printing nothing, exiting 0, and looking
    # exactly like a branch that is legitimately pre-boundary. Ask git directly rather than
    # inferring: a shallow clone can still resolve origin/main, so a base that looks fine says
    # nothing about whether the history behind it is present.
    if ("$(git rev-parse --is-shallow-repository 2>$null)".Trim() -eq 'true') {
        $script:failures += "AmendmentAuthority: cannot grade '$Branch' — this is a shallow clone, so the boundary (plan D2b) would be computed from history that is not present, and every commit would report as predating the check. Fetch the full history: 'fetch-depth: 0' on actions/checkout, or 'git fetch --unshallow' on a build agent (constitution I, Amendment authority)"
        return
    }
    if (-not $Base) {
        if ($script:DiffBaseFailure) {
            # git could not read the base (feature 035): the cause is the object store, not a missing integration branch.
            $script:failures += "AmendmentAuthority: cannot grade '$Branch' — the diff base could not be read ($($script:DiffBaseFailure)), so what the branch changed is unknown. The object store may be damaged: run git fsck, or re-clone (constitution I, Amendment authority)"
            return
        }
        $script:failures += "AmendmentAuthority: cannot grade '$Branch' — no integration branch to diff against. Either neither 'origin/main' nor 'main' resolves here, or one of them resolves but shares no commit with HEAD (a truncated clone, or unrelated histories) — this check does not distinguish them, and says so rather than naming a cause it did not test. Fetch the full history ('git fetch origin main', 'fetch-depth: 0' on actions/checkout), or run the check where it is reachable (constitution I, Amendment authority)"
        return
    }
    # A Lite branch has no own directory (plan D6): every graded document is another feature's.
    $dir = if ($Lite) { '' } else { "specs/$Branch" }
    $range = if ($ReplayTip) { "$ReplayBase..$ReplayTip" } else { "$Base..HEAD" }
    # Plan D2: where another feature's documents are tested for existence. The merge base moves
    # forward when main is merged in, so a document that arrived by that merge exists at it.
    $existBase = if ($ReplayTip) { $ReplayBase } else { $Base }
    $ab = @{ Set = $null; Tried = $false }
    $loadBase = {
        if (-not $ab.Tried) { $ab.Tried = $true; $ab.Set = Get-GradedDocSet -Ref $existBase }
        return $ab.Set
    }
    $baseUnreadable = "AmendmentAuthority: cannot grade '$Branch' — the tree of the diff base $existBase is not readable in this clone, so whether another feature's document was approved there is unknown; reading it as 'nothing was approved' would pass an amendment on a wrong reason. Fetch the full history: 'fetch-depth: 0' on actions/checkout, or 'git fetch --unshallow'; if the history is complete, an object is damaged (constitution I, Amendment authority)"
    # Three git calls now answer everything the walk below used to ask commit by commit: the
    # commits and their parents, dates, messages and trailers; every commit's name-status; and
    # which parents already carried the check (T024 — the walk itself is unchanged).
    $script:AmendmentReadFailure = $null
    $meta = Get-CommitMetaBatch -Range $range
    if (Test-AmendmentReadFailed -Branch $Branch) { return }
    # The commit SET comes from the object graph, never from the message stream. Taking it from
    # the parsed metadata let a commit delete itself by writing one byte into its own message
    # (review B1); rev-list reads commit objects and cannot be written to from a message.
    $commitsRead = Read-AmendmentGit -GitArguments @('rev-list', '--reverse', $range) -Read "git rev-list of $range"
    if (Test-AmendmentReadFailed -Branch $Branch) { return }
    $commits = @($commitsRead.Lines | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($commits.Count -eq 0) {
        # An empty range is a check that ran and graded nothing - GAP-027's shape, and until the
        # phase 6 review (F6) it ended the run on OK. It is named, not failed: a branch with no
        # commits of its own yet is lawful, it is only not evidence (FR-010, plan D6).
        if ($Lite) { return }                                       # plan D7: an empty range on a Lite branch prints nothing
        $script:ungraded += "AmendmentAuthority: no commits in $range — nothing to grade, so no amendment on '$Branch' was checked for its approval record"
        return
    }
    # A commit git lists but the batch did not parse is a parse failure, not a commit to skip.
    # Skipping silently is the whole of B1; this is the assertion whose absence made it work.
    $missing = @($commits | Where-Object { -not $meta.Contains($_) })
    if ($missing.Count -gt 0) {
        $names = ($missing | ForEach-Object { $_.Substring(0, 7) }) -join ', '
        $script:failures += "AmendmentAuthority: could not parse commit metadata for $($missing.Count) commit(s) in $range ($names) — the check refuses to grade a range it cannot read in full, because a commit missing from the batch would otherwise be silently ungraded (review B1). Re-run; if it persists the repository or the range is unreadable and the branch must not be certified on this check"
        return
    }
    # Report what was actually graded. A run that grades nothing must not be output-identical
    # to a run that grades everything and finds it clean: that silence is what let a fail-open
    # boundary (J2) and two broken fixtures pass for green.
    $gradedCount = 0
    # Counted per reason, so the count line reports what actually happened instead of naming
    # causes it never established (review N3, and B1's action on the same string).
    $skipMerge = 0; $skipRoot = 0; $skipBoundary = 0
    $touchedApproved = $false        # plan D6: did any commit touch a document that exists at the base?

    # D2b. The boundary is evaluated PER COMMIT against that commit's own parent. An earlier
    # version short-circuited on HEAD^ alone to save blob reads (SC-006); that failed open,
    # silently, on every pull_request run, because GitHub checks out a merge preview whose first
    # parent is the base branch — so HEAD^ was `main`, which has no check, and the required CI
    # graded nothing while printing exactly what a clean branch prints (J2). Correctness over
    # the second: the sticky flag below still stops re-testing once the boundary is crossed.
    # -IgnoreAmendmentBoundary lifts the boundary for ANALYSIS ONLY (SC-002's replay over real
    # history); no gate, no ritual-checks and no CI workflow passes it.
    $graded = $IgnoreAmendmentBoundary.IsPresent

    $script:NameStatusRead = @{ Ok = $true; Exit = 0; Read = '' }
    $nameStatusMissing = $false
    $nameStatus = Get-NameStatusBatch -Range $range
    # Every first parent in the range, tested in one call. The sticky flag below still decides
    # PER COMMIT whether that commit is graded — the batch changes who is asked, not what for.
    $presence = @{}
    if (-not $graded) { $presence = Get-CheckPresenceSet -Refs @($commits | ForEach-Object { @($meta[$_].Parents)[0] }) }

    foreach ($commit in $commits) {
        # Feature 029 phase 2: a read that failed while the previous commit was graded refuses here.
        if (Test-AmendmentReadFailed -Branch $Branch) { return }
        $parents = @($meta[$commit].Parents)
        $isMerge = $parents.Count -gt 1
        $mergePaths = @()
        if ($isMerge) {
            # Feature 026: a merge is skipped only when it authored nothing for this feature (plan
            # D1-D3). One that cannot be read is refused (D7), never skipped on a wrong reason.
            $mp = Get-MergeAuthoredPaths -Merge $commit -Parents $parents -Dir $dir -LoadBase $loadBase
            if ($mp.BaseUnreadable) { $script:failures += $baseUnreadable; return }
            if (@($mp.Paths).Count -gt 0) { $touchedApproved = $true }
            if ($mp.Unreadable) {
                $script:failures += "AmendmentAuthority: cannot grade '$Branch' — $($mp.Unreadable.Substring(0, 7)) (the merge $($commit.Substring(0, 7)) or one of its parents) is not readable in this clone, so what the merge authored is unknown; skipping it would pass a merge on a wrong reason. Fetch the full history: 'fetch-depth: 0' on actions/checkout, or 'git fetch --unshallow'; if the history is complete, an object is damaged (constitution I, Amendment authority)"
                return
            }
            if ($mp.Paths.Count -eq 0) { $skipMerge++; continue }     # authored nothing: counted as before
            $mergePaths = @($mp.Paths)
        }
        if ($parents.Count -eq 0) { $skipRoot++; continue }           # a root commit creates; D2
        $parent = $parents[0]
        if (-not $graded) {
            if (-not $presence.ContainsKey($parent)) {
                # Absence must be proven, not inferred (T080). An unreadable parent is unknown,
                # and "unknown" reported as "predates the check" is a wrong reason printed green.
                if (-not (Test-CheckAbsentForReal -Ref $parent)) {
                    $script:failures += "AmendmentAuthority: cannot grade '$Branch' — parent commit $($parent.Substring(0, 7)) of $($commit.Substring(0, 7)) is not readable in this clone, so whether it predates the check is unknown; treating it as pre-boundary would skip a commit on a wrong reason. Fetch the full history: 'fetch-depth: 0' on actions/checkout, or 'git fetch --unshallow' (constitution I, Amendment authority)"
                    return
                }
                $skipBoundary++; continue                             # D2b
            }
            $graded = $true                                          # monotonic: stop re-testing
        }
        $gradedCount++
        $short = $commit.Substring(0, 7)

        $amended = @()
        # A merge has no name-status rows (it is a combined diff): its amended set is what
        # Get-MergeAuthoredPaths decided above. An ordinary commit's comes from its rows.
        if ($isMerge) { $amended = $mergePaths }
        # Feature 029 phase 2 (G5): a commit git never reached has no record in the name-status batch; its
        # changed files are unknown, which is not the same as "changed nothing". Noted here and refused after
        # the walk, so the commits that do have a record are graded and a refusal of the walk's own wins.
        elseif (-not $script:NameStatusRead.Ok -and -not $nameStatus.ContainsKey($commit)) {
            $nameStatusMissing = $true
        }
        foreach ($row in $(if ($isMerge) { @() } else { @($nameStatus[$commit]) })) {
            if (-not $row) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -lt 2) { continue }
            $status = $parts[0]
            $path = $parts[$parts.Count - 1]                          # renames: the NEW path
            $oldPath = if ($status -match '^[RC]' -and $parts.Count -ge 3) { $parts[1] } else { $path }
            $oldDocFeature = if ($status -match '^R') { Get-GradedDocFeature -Path $oldPath } else { $null }
            if ((Get-GradedDocFeature -Path $path) -ne $dir -or ($oldDocFeature -and $oldDocFeature -ne $dir)) {
                # Plan D3: another feature's document, a graded document moved away, or (review F1)
                # another feature's document moved INTO the own directory, which removes it from
                # where it was approved. The own directory's block below is not edited.
                if (-not ((Get-GradedDocFeature -Path $path) -or $status -match '^[RC]')) { continue }
                $atBase = & $loadBase
                if ($null -eq $atBase) { $script:failures += $baseUnreadable; return }
                if ($atBase.ContainsKey($path) -or $atBase.ContainsKey($oldPath)) { $touchedApproved = $true }
                $subject = Get-OtherFeatureSubject -Commit $commit -Parent $parent -Dir $dir -Status $status -Path $path -OldPath $oldPath -AtBase $atBase
                if ($subject) { $amended += $subject }
                continue
            }
            $leaf = $path.Substring($dir.Length + 1)
            if ($leaf -notin @('spec.md', 'plan.md', 'tasks.md') -and $leaf -notlike 'contracts/*') { continue }
            if ($status -match '^A') { continue }                     # D2: first appearance
            # A rename is creation at the new path when the CONTENT came across — decided by
            # comparing the blobs, not by git's similarity percentage (J3). A renumbered branch
            # whose spec.md also gained its mandated header edit is R080, not R100, and the
            # percentage rule graded it as an unapproved amendment with no legal path to green.
            if ($status -match '^[RC]') {
                # FR-010 and the spec's Edge Cases name ONE rename that must never be graded:
                # a branch renumbered by a lost claim race, where the whole specs/NNN-name
                # directory moves and every document is added at a new path — header edits
                # included, since claim-feature.ps1 mandates them. Detect exactly that: the
                # feature-directory segment changed (J3).
                $oldFeatureDir = if ($oldPath -match '^(specs/[^/]+)/') { $matches[1] } else { '' }
                if ($oldFeatureDir -and $oldFeatureDir -ne $dir) { continue }
                # A rename WITHIN the same feature directory is not renumbering. It is creation
                # only if the content came across intact; otherwise it is an amendment wearing a
                # new path (H3 — a contract renamed and reinterpreted in one commit).
                $sameContent = Test-SameBlobContent -Commit $commit -Path $path -Parent $parent -OldPath $oldPath
                if ($sameContent) { continue }
            }
            if ($leaf -eq 'tasks.md' -and
                (Test-CheckboxOnlyChange -Commit $commit -Parent $parent -Path $path -ParentPath $oldPath)) { continue }
            if ($leaf -in @('spec.md', 'plan.md') -and
                (Test-StatusOnlyChange -Commit $commit -Parent $parent -Path $path -ParentPath $oldPath)) { continue }
            $amended += $path
        }
        if (Test-AmendmentReadFailed -Branch $Branch) { return }
        if ($amended.Count -eq 0) { continue }

        $commitDay = $meta[$commit].Day
        if (-not $commitDay) { $commitDay = (Get-Date).ToString('yyyy-MM-dd') }
        # H4: the record must be added to a file this commit actually AMENDED — a record in
        # notes.md cannot approve a silent change to plan.md, and the failure message says
        # "on the amended section", which this now means.
        $mergeNote = if ($isMerge) { ' (this commit is a merge: its own change is what is graded, because no parent holds this content)' } else { '' }
        # Feature 027 (plan D5): the branch's own amended files are one group, read as they always
        # were (a record in any of them covers them); each amended document of ANOTHER feature is its
        # own group and needs its own record in that document, so a record in this branch's own files
        # approves nothing there (spec FR-005, 014 H4).
        $groups = @()
        $ownPaths = @($amended | Where-Object { (Get-GradedDocFeature -Path $_) -eq $dir })
        if ($ownPaths.Count -gt 0) { $groups += , @($ownPaths) }
        foreach ($op in @($amended | Where-Object { (Get-GradedDocFeature -Path $_) -ne $dir } | Sort-Object -Unique)) { $groups += , @($op) }
        $verdicts = @()
        foreach ($g in $groups) {
            $lines = if ($isMerge) { Get-MergeRecordLines -Merge $commit -Parents $parents -Paths $g }
                     else          { Get-AddedRecordLines -Commit $commit -Parent $parent -Paths $g }
            $verdicts += [pscustomobject]@{ Paths = @($g); Record = (Get-ConformingRecord -AddedLines $lines -CommitDay $commitDay) }
        }
        if (Test-AmendmentReadFailed -Branch $Branch) { return }
        $bad = @($verdicts | Where-Object { -not $_.Record.Name })

        if ($bad.Count -gt 0) {
            $badPaths = @($bad | ForEach-Object { $_.Paths })
            $files = ($badPaths | Sort-Object -Unique) -join ', '
            $malformed = @($bad | ForEach-Object { $_.Record.Malformed })
            $why = if ($malformed.Count -gt 0) { " Rejected record(s): $($malformed -join '; ')." } else { '' }
            $otherNote = Get-OtherFeatureNote -Paths $badPaths -Dir $dir
            $script:failures += "AmendmentAuthority: commit $short amends $files after approval with no conforming approver record.$why Add '$script:AmendmentRecordExample' to the amended section and name the same approver in the commit message (constitution I, Amendment authority). Ticking a task off is exempt — in either direction — but rewriting a task's text while ticking it is not: record what was done in notes.md, and leave the task saying what was agreed (plan D3c)$otherNote$mergeNote"
            continue
        }
        # Whole-word match over the message with git's OWN trailers removed — a mandated
        # 'Co-Authored-By: Claude' trailer must not auto-satisfy an approver named Claude, and
        # an unanchored search let 'Al' match the word 'Also'. Asking git which lines are
        # trailers, instead of dropping every 'Word: ' line, keeps the SUBJECT ('docs: …',
        # 'spec: …') and ordinary body lines ('Note: approved by bob') in the message (J4).
        $full = @($meta[$commit].Body)
        $trailers = @($meta[$commit].Trailers)
        $message = (@($full | Where-Object { $trailers -notcontains $_ })) -join "`n"
        foreach ($approver in @($verdicts | ForEach-Object { $_.Record.Name } | Sort-Object -Unique)) {
            if ($message -notmatch ('(?<![\w-])' + [regex]::Escape($approver) + '(?![\w-])')) {
                $theirPaths = @($verdicts | Where-Object { $_.Record.Name -eq $approver } | ForEach-Object { $_.Paths })
                $files = ($theirPaths | Sort-Object -Unique) -join ', '
                $otherNote = Get-OtherFeatureNote -Paths $theirPaths -Dir $dir
                $script:failures += "AmendmentAuthority: commit $short records '$approver' as the approver of its change to $files, but its commit message does not name them — the message is fixed at commit time and is the half a later edit cannot fake (constitution I; plan D5)$otherNote$mergeNote"
            }
        }
    }
    if (Test-AmendmentReadFailed -Branch $Branch) { return }
    if ($nameStatusMissing) {
        Set-AmendmentReadFailure -Read $script:NameStatusRead.Read -Exit $script:NameStatusRead.Exit
        Test-AmendmentReadFailed -Branch $Branch | Out-Null
        return
    }
    $skipped = $commits.Count - $gradedCount
    $reasons = @()
    if ($skipMerge -gt 0)    { $reasons += "$skipMerge merge commit(s)" }
    if ($skipRoot -gt 0)     { $reasons += "$skipRoot root commit(s)" }
    if ($skipBoundary -gt 0) { $reasons += "$skipBoundary made before the check existed (plan D2b)" }
    $why = if ($skipped -gt 0) { " ($skipped not graded: $($reasons -join '; '))" } else { '' }
    # Plan D6: a Lite branch whose spec changes are all creations has nothing to report; the roll-up
    # is printed only when a commit touched a document that exists at the base.
    if ($Lite -and -not $touchedApproved) { return }
    $script:AmendRollupPrinted = $true
    Write-Host "AmendmentAuthority: graded $gradedCount of $($commits.Count) commit(s) in $range$why"
}

# --- Dispatch ---
$Branch = Get-CurrentBranch -Override $Branch
$diffBase = Get-DiffBase
$changedFiles = Get-ChangedFiles -Base $diffBase

if ($script:ChangedFilesRead.Ok) {
    Write-Host "enforcement-pack: branch '$Branch', diff base '$diffBase', $($changedFiles.Count) changed file(s)"
} else {
    # Feature 028: a diff git could not compute is not an empty branch, and '0 changed file(s)' said so.
    Write-Host "enforcement-pack: branch '$Branch', diff base '$diffBase', diff unreadable (git diff exited $($script:ChangedFilesRead.Exit))"
}

# Silence is not compliance in the other lanes either (review G2). With no computable base the
# pack still speaks, but nothing it says is a comparison, and the three dispositions differ by
# member: Get-ChangedFiles returns an empty list, so the Lite-lane check grades nothing; the
# members taking -Base (review-provenance, phase-size, the Micro phase walk) return without
# grading; AmendmentAuthority fails rather than grading. On a baseless clone a 'fix/' branch
# touching anything at all therefore went green. Where origin/main resolves but shares no
# commit, the phase 5 fix that replaced the Get-DiffBase crash is what made that state
# reachable rather than fatal; where neither ref resolves the loop was never entered and it was
# always this quiet (review H1). FR-009 forbids newly FAILING a Lite branch on a null base, so
# this names the condition instead of failing on it — the run reports itself as ungraded rather
# than as clean. An NNN-* branch still fails, in the check.
if (-not $diffBase -and $Branch -notin @('main', 'master')) {
    if ($script:DiffBaseFailure) {
        # git could not read the base: not "no integration branch", and fetching more history is no remedy (feature 035).
        $script:warnings += "enforcement-pack: the diff base could not be read ($($script:DiffBaseFailure)), so nothing on '$Branch' was compared — each check that reads the diff either graded an empty file list, returned without grading, or failed for want of a base. This run is not evidence that the branch is clean — it is evidence that nothing was compared. The object store may be damaged: run git fsck, or re-clone."
    } else {
        $script:warnings += "enforcement-pack: no integration branch to diff against, so nothing on '$Branch' was compared — each check that reads the diff either graded an empty file list, returned without grading, or failed for want of a base. This run is not evidence that the branch is clean — it is evidence that nothing was compared. Fetch the full history ('git fetch origin main', or 'fetch-depth: 0' on actions/checkout)."
    }
}

if ($Branch -in @('main', 'master')) {
    Write-Host "enforcement-pack: '$Branch' is the trunk, not a feature/fix/chore/docs branch — no scripted checks apply"
} elseif ($Branch -match '^\d{3}-') {
    if (-not $script:ChangedFilesRead.Ok) {
        Add-DiffUnreadable -Reader 'enforcement-pack' -Branch $Branch -Base $diffBase -Exit $script:ChangedFilesRead.Exit -Consequence 'the changed-file list is unknown and the checks that read it graded nothing'
    }
    Invoke-StructureCheck -Branch $Branch
    Invoke-LevelSurfaceCheck -Branch $Branch
    Invoke-LevelRationaleCheck -Branch $Branch
    Invoke-MicroLaneCheck -Branch $Branch -Base $diffBase
    Invoke-CriticalEvidenceCheck -Branch $Branch -Base $diffBase
    Invoke-GateBatchingCheck -Branch $Branch
    Invoke-GateCertificationCheck -Branch $Branch
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Invoke-AmendmentAuthorityCheck -Branch $Branch -Base $diffBase -IgnoreAmendmentBoundary:$IgnoreAmendmentBoundary -ReplayBase $ReplayBase -ReplayTip $ReplayTip
    Invoke-PhaseSizeWarningCheck -Branch $Branch -Base $diffBase
} elseif ($Branch -match '^(fix|chore)/') {
    # The one member here that does not DECLINE on a null base - it grades, and grades an empty
    # list, which passes for the same reason an empty accusation is never proved. The comment
    # above says it plainly: a baseless 'fix/' branch touching anything at all went green. A
    # vacuous grade reaches the same wrong verdict as a skipped one, so it is named the same way.
    if (-not $diffBase) {
        $ungraded += "LiteAndAbuse: no diff base, so the prohibited-category and file-count guards graded an EMPTY file list on '$Branch' - every prohibited change this lane forbids would have passed"
    }
    # Feature 028 (plan D6): a list known not to be the branch's is never handed to the guards; an
    # EMPTY list graded here is how a damaged fix/ branch carrying a manifest and a migration went green.
    if (-not $script:ChangedFilesRead.Ok) {
        Add-DiffUnreadable -Reader 'LiteAndAbuse' -Branch $Branch -Base $diffBase -Exit $script:ChangedFilesRead.Exit -Consequence 'the prohibited-category and file-count guards had no file list to grade - every prohibited change this lane forbids would have passed'
    } else {
        Invoke-LiteAndAbuseCheck -Branch $Branch -ChangedFiles $changedFiles
    }
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Invoke-AmendmentAuthorityCheck -Branch $Branch -Base $diffBase -ChangedFiles $changedFiles -IgnoreAmendmentBoundary:$IgnoreAmendmentBoundary -ReplayBase $ReplayBase -ReplayTip $ReplayTip
} elseif ($Branch -match '^docs/') {
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Invoke-AmendmentAuthorityCheck -Branch $Branch -Base $diffBase -ChangedFiles $changedFiles -IgnoreAmendmentBoundary:$IgnoreAmendmentBoundary -ReplayBase $ReplayBase -ReplayTip $ReplayTip
    # The line names what ran: both checks when AmendmentAuthority printed its roll-up, so it is never false.
    $docsChecks = if ($script:AmendRollupPrinted) { 'review-provenance and amendment-authority are the scripted checks that apply' } else { 'review-provenance is the only scripted check that applies' }
    Write-Host "enforcement-pack: '$Branch' is the lightweight docs/ lane — $docsChecks"
} else {
    $script:failures += "Branch naming: '$Branch' does not match a known taxonomy (NNN-*, fix/*, chore/*, docs/*) — see docs/sdlc/branch-strategy.md"
}

foreach ($w in $warnings) { Write-Host "WARNING: $w" }
# Listed before the verdict and independently of it, the way warnings are: a run can both fail
# and have graded nothing, and the reader needs to know that the FAIL count is not the whole
# story. What the verdict word does is stop 'OK' being printed over the top of it.
foreach ($u in $ungraded) { Write-Host "UNGRADED: $u" }
if ($failures.Count -gt 0) {
    Write-Host "enforcement-pack: FAIL ($($failures.Count) issue(s)):"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}
if ($ungraded.Count -gt 0) {
    # Exit 0, deliberately and on the record (plan D6, FR-011). Feature 014's FR-009 forbids a
    # new hard failure on the Lite lane, and that constraint stands. What changes is that no one
    # can read this run as clean. Whether UNGRADED should ever block is a later feature's
    # question with its own evidence; it is not answered here by the back door.
    Write-Host "enforcement-pack: UNGRADED ($($ungraded.Count) check(s) formed no opinion)"
    exit 0
}
Write-Host 'enforcement-pack: OK'
exit 0

} finally {
    Pop-Location
}
