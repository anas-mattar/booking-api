<#
.SYNOPSIS
    Shared scope-check semantics: territory parsing, glob matching, commit path extraction.

.DESCRIPTION
    Dot-sourced by scripts/scope-check.ps1 (this repository's commits) and
    scripts/scope-check-repos.ps1 (the nested code repositories' commits — feature 012,
    GAP-016). One implementation, so the two graders cannot drift: the Micro lane, the
    rename handling and the literal-bracket matching each arrived as a separate fix, and
    a copied helper set would need every one of them applied twice.

    Contracts: specs/006-verification-pack/contracts/scope-check-cli.md and
    specs/012-cross-repo-scope-check/contracts/scope-check-repos-cli.md.

    Every function here is pure with respect to the working directory EXCEPT
    Get-CommitPaths, which shells out to git and therefore reads the caller's current
    location (or an explicit -GitDir/-C by the caller). Callers set their own location.

.NOTES
    Not a runnable script — dot-source it:
        . (Join-Path $PSScriptRoot 'scope-lib.ps1')
#>

# The `git show --name-status` rows of a commit, with a failed read reported on a channel of its own:
# $script:CommitReadFailed, which the caller reads on the very next statement. A commit git cannot read
# returns no rows, the same as a readable commit that touches nothing, and PowerShell unrolls an empty
# array to $null, so neither a return value nor a sentinel could tell the two apart (feature 032, GAP-038;
# the recipe of feature 030's $script:LedgerReadFailed). -Renames adds -M, which Get-CommitPaths reads and
# the delete guard of scope-check.ps1 does not.
function Get-CommitStatusRows {
    param([string]$Sha, [switch]$Renames)
    $script:CommitReadFailed = $false
    if ($Renames) { $rows = git -c core.quotepath=off show --name-status --format='' -M $Sha 2>$null }
    else          { $rows = git -c core.quotepath=off show --name-status --format='' $Sha 2>$null }
    $script:CommitReadFailed = ($LASTEXITCODE -ne 0)
    return $rows
}

# Paths a commit touches: renames contribute both sides, deletes the deleted path.
# quotepath=off so non-ASCII paths arrive verbatim, not quoted-octal (006 review F3).
# A failed read leaves $script:CommitReadFailed set and returns no paths: callers read the flag.
function Get-CommitPaths {
    param([string]$Sha)
    $paths = @()
    $rows = @(Get-CommitStatusRows -Sha $Sha -Renames)
    foreach ($row in $rows) {
        if (-not $row) { continue }
        $parts = $row -split "`t"
        if ($parts.Count -lt 2) { continue }
        if ($parts[0] -match '^[RC]') {
            if ($parts.Count -ge 3) { $paths += $parts[1]; $paths += $parts[2] }
        } else {
            $paths += $parts[1]
        }
    }
    $paths | Where-Object { $_ } | Select-Object -Unique
}

# Declarations are parsed from VISIBLE text only: a '**Delivery Level**: Micro' decoy
# inside an HTML comment block must never win first-match over the rendered one (same
# rule as enforcement-pack's Get-VisiblePlanLines — 008 phase 2 review, F1 precedent).
function Get-VisibleLines {
    param([string[]]$Lines)
    $raw = ($Lines -join "`n")
    return ([regex]::Replace($raw, '(?s)<!--.*?-->', '')) -split "`r?`n"
}

# Micro detection (constitution X, Micro lane): the first visible '**Delivery Level**:'
# line of the given spec.md blob has the value Micro. Absent blob, absent field, or any
# other value means NOT Micro — zero new behavior (006 contract M1).
function Test-IsMicro {
    param([string[]]$SpecLines)
    if (-not $SpecLines) { return $false }
    $line = Get-VisibleLines -Lines $SpecLines |
        Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1
    return [bool]($line -and $line -match '^\*\*Delivery Level\*\*:\s*Micro\b')
}

# Territory list for phase N, from a specific blob of tasks.md.
# Entries MUST be backtick-wrapped list items (`- `path``); collection starts at the first
# entry after the marker and ends at the first blank line or non-entry line once entries
# have begun — so a following task checklist can never be swallowed as territory (006 review F1).
# Returns @{ Found = bool; Duplicate = bool; Entries = string[]; Invalid = string[] }
# -Global (Micro lane): the block is feature-global in spec.md, not under a phase heading —
# the first '**Territory**' marker anywhere counts (decorated or not), and a second one is a
# duplicate. Lines are pre-stripped of HTML comments by the caller (Get-VisibleLines).
function Get-Territory {
    param([string[]]$TasksLines, [int]$PhaseNumber, [switch]$Global)
    $result = @{ Found = $false; Duplicate = $false; Entries = @(); Invalid = @(); NearMiss = @(); MarkerCount = 0 }
    $inPhase = [bool]$Global
    $collecting = $false
    $started = $false
    $lineNo = 0
    foreach ($line in $TasksLines) {
        $lineNo++
        if (-not $Global -and $line -match '^##\s+Phase\s+(\d+)\b') {
            $inPhase = ([int]$matches[1] -eq $PhaseNumber)
            $collecting = $false
            continue
        }
        if (-not $inPhase) { continue }
        # A DECORATED marker counts (GAP-026, FR-014): '**Territory** (widened by amendment …):'
        # is what feature 014 wrote twice while amending its own territory, and the old anchor —
        # the colon fixed hard against the marker — read it as no declaration at all. The phase
        # then reached the pre-006 compatibility WARN and the check exited 0 having graded
        # nothing, on the very branch that was widening its scope.
        #
        # Anything up to the first colon is allowed as annotation, deliberately the permissive
        # direction. The two errors are not symmetrical: reading a non-marker AS a marker ends in
        # a loud duplicate-marker or empty-list FAIL that names the line, while reading a real
        # marker as prose ends in silence. Only one of those can hide an undeclared change.
        if ($line -match '^\*\*Territory\*\*[^:]*:') {
            if ($result.Found) { $result.Duplicate = $true }         # exactly one marker per phase (006 review F8)
            # The COUNT as well as the fact, because enforcement-pack's Micro-lane message names
            # it ("carries 3 **Territory** markers"). Duplicate alone would have forced that
            # message to be reworded, and a caller that has to soften its wording to reuse a
            # shared parser is a caller that keeps its own copy instead — which is the defect
            # this function is being shared to fix.
            $result.MarkerCount++
            $result.Found = $true; $collecting = $true; $started = $false
            continue
        }
        # NEAR MISS, reported rather than ignored (phase 2 review F3, T019a). A line that begins
        # '**Territory**' and carries no colon is what an author writes when the annotation wraps
        # onto the next line — specs/014-amendment-authority/tasks.md:322 is still that shape. It
        # matches no anchor, so it declared nothing AND said nothing, with a perfectly good entry
        # list sitting two lines below it. Recording it lets the caller refuse; joining
        # continuation lines would be new machinery for a rare shape, and a parser that guesses
        # where a declaration ends is a worse trade than one that asks the author to be plain.
        if ($line -match '^\*\*Territory\*\*') {
            $result.NearMiss += $lineNo
            continue
        }
        if (-not $collecting) { continue }
        if ($line -match '^\s*$') {
            if ($started) { $collecting = $false }                   # blank line after entries ends the list
            continue                                                 # blank line(s) between marker and list are fine
        }
        if ($line -match '^\s*[-*]\s+`([^`]+)`\s*$') {               # backtick-wrapped bare path/glob only
            $started = $true
            $entry = $matches[1].Trim()
            if ($entry -match '^([A-Za-z]:|[/\\])' -or $entry -match '(^|[/\\])\.\.([/\\]|$)') {
                $result.Invalid += $entry
            } else {
                $result.Entries += $entry
            }
            continue
        }
        $collecting = $false                                         # anything else (incl. task checkboxes) ends the list
    }
    return $result
}

# True when ANY phase in this tasks.md blob declares a Territory (FR-015). The pre-006
# compatibility WARN was written for a document that predates the convention entirely; a
# document where one phase declares and another does not is not legacy, it is an omission, and
# treating the two alike is how an undeclared phase commit reached exit 0 having been graded
# against nothing. Same anchor as Get-Territory, so the two cannot disagree about what a
# declaration looks like.
function Test-AnyTerritoryDeclared {
    param([string[]]$TasksLines)
    foreach ($line in $TasksLines) {
        if ($line -match '^\*\*Territory\*\*[^:]*:') { return $true }
    }
    return $false
}

function Test-InTerritory {
    param([string]$Path, [string[]]$Globs)
    foreach ($g in $Globs) {
        $pattern = $g -replace '\*\*', '*'
        # D1 promises globs, not -like character classes: match [, ], ? literally (006 review F7).
        $pattern = $pattern.Replace('[', '`[').Replace(']', '`]').Replace('?', '`?')
        if ($pattern.EndsWith('/')) { $pattern += '*' }              # trailing slash = whole subtree
        if ($Path -like $pattern) { return $true }
    }
    return $false
}

# A code repository's trunk, by the one candidate order every kit script that walks the nested
# repositories uses (feature 012, shared since feature 018). Code repositories are pre-existing and
# independent, so their trunk is often master or develop, unlike the kit-created governance
# repository (012 phase 1 review, F5): it is RESOLVED, never assumed.
function Get-RepoTrunkCandidates {
    return @('origin/main', 'main', 'origin/master', 'master', 'origin/HEAD')
}

# The merge base of $Ref with the first trunk candidate that exists in the repository AND shares a
# history with it. $Candidates overrides the order (the scope check's -BaseRef).
#
# Returns:
#   Base      the merge-base sha, or $null when none resolved
#   Trunk     the candidate it resolved against, or $null
#   Tried     every candidate asked about, in order, for a caller's message
#   Existing  the candidates that exist in the repository, in order, up to and including the one it
#             resolved against; when NO base resolved, every candidate that exists at all
#
# Existing is returned separately because two different things look alike from outside. "No trunk":
# none of the candidates exists, so the repository cannot be compared with anything. "No merge base":
# a trunk exists and this ref shares no history with it. The scope check reports both as one message
# and may keep doing so; the territory check names them differently, because they send the owner to
# different places (feature 018, research R3). It reads Existing ONLY when Base is $null: on success
# the list stops at the candidate that resolved, so it is not a census of the repository's refs.
function Get-RepoMergeBase {
    param([Parameter(Mandatory)][string]$RepoPath, [Parameter(Mandatory)][string]$Ref, [string[]]$Candidates)
    if (-not $Candidates -or $Candidates.Count -eq 0) { $Candidates = Get-RepoTrunkCandidates }
    $existing = @()
    $failed = $null
    foreach ($c in $Candidates) {
        git -C $RepoPath rev-parse --verify --quiet $c *> $null
        $verifyExit = $LASTEXITCODE
        if ($verifyExit -eq 1) { continue }                  # git answered: there is no such ref
        if ($verifyExit -ne 0) { if (-not $failed) { $failed = "git rev-parse of $c failed with exit $verifyExit" }; continue }
        $existing += $c
        $b = git -C $RepoPath merge-base $Ref $c 2>$null
        $mergeBaseExit = $LASTEXITCODE
        if ($mergeBaseExit -eq 0 -and $b) {
            return @{ Base = "$b".Trim(); Trunk = $c; Tried = @($Candidates); Existing = @($existing); Failed = $false; FailedWith = $null }
        }
        # Exit 1 is git's answer that the two share no history; any other non-zero exit is a failure to read (feature 034, GAP-040).
        if ($mergeBaseExit -ne 0 -and $mergeBaseExit -ne 1) { if (-not $failed) { $failed = "git merge-base failed with exit $mergeBaseExit" } }
    }
    # Failed only when NO candidate gave a base and at least one could not be read: a later candidate's base wins over an earlier failure.
    return @{ Base = $null; Trunk = $null; Tried = @($Candidates); Existing = @($existing); Failed = [bool]$failed; FailedWith = $failed }
}
