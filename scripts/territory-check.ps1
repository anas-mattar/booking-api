<#
.SYNOPSIS
    One-command territory check: reports file overlap between the current feature branch
    and every open remote NNN-* feature branch.

.DESCRIPTION
    Automates docs/sdlc/team-workflow.md rule 5 — the stance is unchanged: overlap is
    SEQUENCED, not forbidden. On any live overlap the owners must agree merge order and
    record it in both features' plan.md.

    The touched set of each branch is its committed diff versus the base branch (the
    claim lives in git, not in plan.md prose); for the branch under check, tracked
    uncommitted changes are included too.

    Where kit-adoption.json declares codeRepos, each declared code repository is read the same
    way, as a sibling working tree: the branch carrying the same name in it, diffed against its
    merge base with that repository's own trunk. Its files are reported prefixed with the
    repository directory name, so a path can be pasted into a Territory block unchanged. A
    feature's status is judged from its latest commit in ANY repository it has a branch in.
    Tracked uncommitted changes count in a code repository only when that repository is checked
    out on the branch under check (any other checkout's edits belong to another feature); this
    holds even when -Branch names a branch the governance repository is not on, where the
    governance half reads committed work only. The branch under check is read from its local head
    and its remote-tracking ref together, so a stale remote-tracking ref can over-report a file
    the developer has since dropped, never miss one.

    Exit codes: 0 no live overlap · 2 live overlap found · 1 execution error. A comparison
    that could not be made (a claim with no remote-tracking ref; a declared code repository
    that is absent, not a repository of its own, without a trunk or unfetchable; another
    feature's branch that cannot be compared; a codeRepos declaration that cannot be read) is
    listed as UNGRADED: the run then ends UNGRADED, never CLEAN, still exit 0 unless a live
    overlap exists. With -Json, CLEAN is false whenever anything was not compared and
    UNGRADED lists the entries.
    Overlaps with stale claims (no commits for -StaleDays) are reported as reclaimable
    per team-workflow rule 3 and do not by themselves cause exit 2.

    Contract: specs/003-flow-efficiency-pack/contracts/territory-check-cli.md, extended by
    specs/018-cross-repo-territory-reach/contracts/territory-check-output.md

.EXAMPLE
    pwsh -File scripts/territory-check.ps1
    pwsh -File scripts/territory-check.ps1 -Branch 011-reports -Json
#>
[CmdletBinding()]
param(
    [string]$Branch,
    [string]$BaseBranch = 'main',
    [int]$StaleDays = 14,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'adoption-lib.ps1')   # Get-CodeRepos: the one reader of codeRepos (feature 018)
. (Join-Path $PSScriptRoot 'scope-lib.ps1')      # Get-RepoMergeBase / Get-RepoTrunkCandidates: one trunk order

# A refusal: the run cannot be answered, so it says why on the error stream and exits 1. Not
# Write-Error: under ErrorActionPreference = Stop that THROWS, the 'exit 1' beneath it never runs,
# and the reader gets a PowerShell error record (a position, a caret rule) and an exit code that
# is whatever the launcher or the last git call left behind, not the rule's (feature 022, GAP-029).
function Stop-Refused {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 1
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Refused 'Not inside a git repository.' }
Push-Location $repoRoot
try {

$checkingCurrent = $false
if (-not $Branch) {
    $Branch = git branch --show-current
    $checkingCurrent = $true
}
if ($Branch -notmatch '^\d{3,}-') {
    Stop-Refused "Branch '$Branch' is not a numbered feature branch (NNN-name) — the territory check applies to the feature lane only."
}

git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    if ($Json) { [PSCustomObject]@{ BRANCH = $Branch; CLEAN = $true; OVERLAPS = @() } | ConvertTo-Json -Compress }
    else { Write-Host 'no remote — nothing to check against' }
    exit 0
}
git fetch origin --prune 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Stop-Refused 'git fetch origin failed.' }

# --- Touched set of the branch under check ---------------------------------------------
$ownRef = if ($checkingCurrent) { 'HEAD' } else {
    if (git branch --list $Branch) { $Branch } else { "origin/$Branch" }
}
$ownFiles = @(git diff --name-only "$BaseBranch...$ownRef" 2>$null)
if ($LASTEXITCODE -ne 0) { Stop-Refused "Cannot diff $BaseBranch...$ownRef — does '$BaseBranch' exist?" }
if ($checkingCurrent) {
    # Feature 029 phase 4 (G13a): a failed read is not "no uncommitted files". The committed diff above needs
    # trees only; this one compares file content, so an unreadable object fails here alone, and reading the
    # failure as an empty list let the branch's own dirty files drop out of the overlap check.
    $dirty = @(git diff --name-only HEAD 2>$null)   # tracked, uncommitted
    $dirtyExit = $LASTEXITCODE
    if ($dirtyExit -ne 0) { Stop-Refused "Cannot read the uncommitted changes of '$Branch' — git diff --name-only HEAD failed (git exited $dirtyExit), so the branch's own uncommitted files would drop out of the overlap check." }
    $ownFiles += $dirty
}
$ownFiles = @($ownFiles | Sort-Object -Unique)

# --- Compare against every other open remote feature branch ----------------------------
$openBranches = @()
# Feature 029 phase 4 (G13b): a failed listing is not "no open branches".
$remoteHeads = @(git ls-remote --heads origin 2>$null)
$remoteHeadsExit = $LASTEXITCODE
if ($remoteHeadsExit -ne 0) { Stop-Refused "Cannot list the open feature branches — git ls-remote --heads origin failed (git exited $remoteHeadsExit), so no open claim would be compared." }
foreach ($line in $remoteHeads) {
    if ($line -match 'refs/heads/(\d{3,}-\S+)$' -and $matches[1] -ne $Branch) { $openBranches += $matches[1] }
}

$overlaps = @()
$ungraded = @()   # comparisons not made: a skipped comparison must never read as CLEAN
$notes = @()      # limits of a comparison that was made (a code repository with no origin)
$liveOverlap = $false
$nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# --- Code repositories (feature 018) -----------------------------------------------------
# Each declared code repository is a sibling working tree with its own claim ledger. Everything
# git-shaped about one is read here; what it cannot give is an ungraded entry naming the repository
# and the cause, never a silent skip. A project declaring none never enters this block's loops.
function Add-Ungraded {
    param([string]$Repo, $Feature, [string]$Cause, $Detail)
    $script:ungraded += [PSCustomObject]@{ repo = $Repo; feature = $Feature; cause = $Cause; detail = $Detail }
}

function Test-CodeRef {
    param([string]$Path, [string]$Ref)
    git -C $Path show-ref --verify --quiet $Ref *> $null   # the ref itself, never its object: a corrupt tip must still "exist"
    return ($LASTEXITCODE -eq 0)
}

# What one ref touched in a code repository: its diff against the merge base with the repository's
# own trunk (candidate order shared with the scope check). --no-renames, so a rename counts at both
# paths; core.quotepath=off, so a non-ASCII path arrives verbatim.
function Read-CodeRef {
    param([string]$Path, [string]$Ref)
    $mb = Get-RepoMergeBase -RepoPath $Path -Ref $Ref
    if (-not $mb.Base) { return @{ Ok = $false; Why = "no merge base with $(@($mb.Existing) -join ', '): unrelated history or an unreadable ref" } }
    $files = @(git -C $Path -c core.quotepath=off diff --no-renames --name-only $mb.Base $Ref -- 2>$null)
    if ($LASTEXITCODE -ne 0) { return @{ Ok = $false; Why = 'diff against the merge base failed' } }
    $count = [int](git -C $Path rev-list --count "$($mb.Base)..$Ref" 2>$null)
    if ($LASTEXITCODE -ne 0) { return @{ Ok = $false; Why = 'commit count against the merge base failed' } }
    $epoch = 0L
    if ($count -gt 0) {
        $epoch = [long](git -C $Path log -1 --format=%ct $Ref 2>$null)
        if ($LASTEXITCODE -ne 0) { return @{ Ok = $false; Why = 'last commit unreadable' } }
    }
    return @{ Ok = $true; Files = $files; Count = $count; Epoch = $epoch }
}

# The branch under check in a code repository: its local head and its remote-tracking ref (a
# developer's unpushed commits are in the first, a colleague's in the second), plus tracked
# uncommitted changes ONLY when the repository is checked out on this branch, since any other
# checkout's edits belong to some other feature (research R7).
function Get-OwnCodeTouched {
    param([string]$Path)
    $files = @()
    foreach ($ref in @("refs/heads/$Branch", "refs/remotes/origin/$Branch")) {
        if (-not (Test-CodeRef $Path $ref)) { continue }
        $read = Read-CodeRef $Path $ref
        if (-not $read.Ok) { return @{ Ok = $false; Why = $read.Why } }
        $files += $read.Files
    }
    if ((git -C $Path branch --show-current 2>$null) -eq $Branch) {
        $dirty = @(git -C $Path -c core.quotepath=off diff --no-renames --name-only HEAD -- 2>$null)
        if ($LASTEXITCODE -ne 0) { return @{ Ok = $false; Why = 'working-tree diff failed' } }
        $files += $dirty
    }
    return @{ Ok = $true; Files = @($files | Where-Object { $_ } | Sort-Object -Unique) }
}

$declared = Get-CodeRepos -Root $repoRoot
if ($declared.Unusable) {
    Add-Ungraded 'codeRepos' $null 'declaration-unusable' ((@($declared.Warnings) | ForEach-Object { $_ -replace '^WARN ', '' }) -join '; ')
}
$codeReady = @()
$declaredNames = @($declared.Repos | Select-Object -Unique)   # a repeated entry is one repository, not two comparisons
$seenGitDirs = @()
foreach ($name in $declaredNames) {
    $path = Join-Path $repoRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        Add-Ungraded $name $null 'not-present' 'the declared directory does not exist'; continue
    }
    # A plain directory inside the governance tree makes git walk UP and answer for the governance
    # repository, grading the wrong history: the declared directory must be the root of its own
    # repository. The same test scripts/scope-check-repos.ps1 applies.
    $top = git -C $path rev-parse --show-toplevel 2>$null
    $isOwnRepo = $false
    if ($LASTEXITCODE -eq 0 -and $top) {
        $seps = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $isOwnRepo = ((Resolve-Path "$top".Trim()).Path.TrimEnd($seps) -eq (Resolve-Path $path).Path.TrimEnd($seps))
    }
    if (-not $isOwnRepo) {
        Add-Ungraded $name $null 'not-a-repository' 'the directory is not the root of a git repository of its own'; continue
    }
    # The same repository spelled two ways (api and API on a case-insensitive filesystem) is one comparison:
    # git reports its canonical git directory, so identity is read from that and not from the declared name.
    $gitDir = "$(git -C $path rev-parse --absolute-git-dir 2>$null)".Trim()
    if ($gitDir -and $seenGitDirs -ccontains $gitDir) { continue }
    $seenGitDirs += $gitDir
    git -C $path remote get-url origin *> $null
    if ($LASTEXITCODE -eq 0) {
        git -C $path fetch origin --prune *> $null
        if ($LASTEXITCODE -ne 0) { Add-Ungraded $name $null 'fetch-failed' 'git fetch origin failed in the repository'; continue }
    } else {
        $notes += "compared ${name}: local branches only"
    }
    $trunks = @(Get-RepoTrunkCandidates)
    $hasTrunk = $false
    foreach ($candidate in $trunks) {
        git -C $path rev-parse --verify --quiet $candidate *> $null
        if ($LASTEXITCODE -eq 0) { $hasTrunk = $true; break }
    }
    if (-not $hasTrunk) { Add-Ungraded $name $null 'no-trunk' "tried $($trunks -join ', ')"; continue }
    $own = Get-OwnCodeTouched -Path $path
    if (-not $own.Ok) { Add-Ungraded $name $Branch 'branch-uncomparable' $own.Why; continue }
    $codeReady += [PSCustomObject]@{ Name = $name; Path = $path; Own = $own.Files }
}

foreach ($other in $openBranches) {
    $hasWork = $false
    $latestEpoch = 0L
    $shared = @()
    $commitCount = [int](git rev-list --count "$BaseBranch..origin/$other" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Skipping origin/${other}: cannot compare with $BaseBranch."
        git rev-parse --verify --quiet "origin/$other" 2>$null | Out-Null
        $why = if ($LASTEXITCODE -ne 0) { "no remote-tracking ref origin/$other" } else { "cannot compare with $BaseBranch" }
        $ungraded += [PSCustomObject]@{ repo = 'governance'; feature = $other; cause = 'claim-skipped'; detail = $why }
    } elseif ($commitCount -gt 0) {
        $hasWork = $true
        # Feature 029 phase 4 (G14): neither read may fail into "no overlap". An unreadable last commit
        # leaves the branch's status unknown (an epoch of 0 would call it stale), so it is not compared;
        # an unreadable diff is named and the branch's code repositories are still compared below.
        $epochRead = @(git log -1 --format=%ct "origin/$other" 2>$null)
        $epochExit = $LASTEXITCODE
        if ($epochExit -ne 0) { Add-Ungraded 'governance' $other 'last-commit-failed' "git log of origin/$other failed (git exited $epochExit)"; continue }
        $latestEpoch = [long]$epochRead[0]
        $otherFiles = @(git diff --name-only "$BaseBranch...origin/$other" 2>$null)
        $otherFilesExit = $LASTEXITCODE
        if ($otherFilesExit -ne 0) { Add-Ungraded 'governance' $other 'diff-failed' "git diff of $BaseBranch...origin/$other failed, git exited $otherFilesExit"; $otherFiles = @() }
        $shared = @($ownFiles | Where-Object { $otherFiles -contains $_ })
    }

    # The same claim in each code repository: its branch there, if it has one. No branch means that
    # feature did no work in this repository, which is neither an overlap nor a failure.
    foreach ($cr in $codeReady) {
        $ref = $null
        foreach ($candidate in @("refs/remotes/origin/$other", "refs/heads/$other")) {
            if (Test-CodeRef $cr.Path $candidate) { $ref = $candidate; break }
        }
        if (-not $ref) { continue }
        $read = Read-CodeRef $cr.Path $ref
        if (-not $read.Ok) { Add-Ungraded $cr.Name $other 'branch-uncomparable' $read.Why; continue }
        if ($read.Count -gt 0) {
            $hasWork = $true
            if ($read.Epoch -gt $latestEpoch) { $latestEpoch = $read.Epoch }
        }
        $shared += @($cr.Own | Where-Object { $read.Files -contains $_ } | ForEach-Object { "$($cr.Name)/$_" })
    }

    # No commits in any repository: freshly claimed, nothing to compare, never an error. Otherwise the
    # status is the latest commit anywhere (feature 018, research R4).
    if (-not $hasWork) { continue }
    $ageDays = [int](($nowEpoch - $latestEpoch) / 86400)
    $status = if ($ageDays -ge $StaleDays) { 'stale — reclaimable' } else { 'live' }
    if ($shared.Count -gt 0) {
        $overlaps += [PSCustomObject]@{ branch = $other; status = $status; files = $shared }
        if ($status -eq 'live') { $liveOverlap = $true }
    }
}

# --- Report -----------------------------------------------------------------------------
# One word for the run: OVERLAP, else UNGRADED, else CLEAN. Ungraded lines print beside an
# overlap, never instead of it; an ungraded run with no overlap still exits 0.
if ($Json) {
    [PSCustomObject]@{ BRANCH = $Branch; CLEAN = (-not $liveOverlap -and $ungraded.Count -eq 0); OVERLAPS = $overlaps; UNGRADED = $ungraded } |
        ConvertTo-Json -Compress -Depth 4
} else {
    foreach ($n in $notes) { Write-Host $n }
    foreach ($o in $overlaps) {
        Write-Host "OVERLAP with $($o.branch) [$($o.status)]:"
        $o.files | ForEach-Object { Write-Host "  $_" }
    }
    foreach ($u in $ungraded) {
        $what = switch ($u.cause) {
            'not-present'          { 'not present in this checkout' }
            'not-a-repository'     { 'not a repository of its own' }
            'no-trunk'             { "no resolvable trunk ($($u.detail))" }
            'fetch-failed'         { 'fetch failed' }
            'declaration-unusable' { "declaration unusable — $($u.detail)" }
            default                { "cannot compare $($u.feature) ($($u.detail))" }
        }
        Write-Host "UNGRADED: $($u.repo): $what"
    }
    if ($liveOverlap) {
        Write-Host ''
        Write-Host 'Overlap is sequenced, not forbidden (docs/sdlc/team-workflow.md, rule 5):'
        Write-Host 'agree merge order with the other owner NOW and record it in BOTH features'' plan.md.'
    } else {
        if ($ungraded.Count -gt 0) {
            Write-Host "UNGRADED — '$Branch' was NOT fully compared ($($ungraded.Count) comparison(s) not made, listed above), so this is not a clean result."
        } elseif ($overlaps.Count -eq 0) {
            # A project declaring no code repositories keeps its original text byte for byte; one that
            # declares some says what it compared, so a clean run cannot be read as broader than it was.
            $comparedNote = if ($declaredNames.Count -gt 0) { " (compared governance and $($declaredNames -join ', ') against $($openBranches.Count) open claim(s))" } else { '' }
            Write-Host "CLEAN — '$Branch' shares no files with any open feature branch$comparedNote."
        }
        if ($overlaps.Count -gt 0) {
            Write-Host ''
            Write-Host 'Only stale claims overlap — consider adopting them per team-workflow rule 3.'
        }
    }
}
if ($liveOverlap) { exit 2 } else { exit 0 }

} finally { Pop-Location }
