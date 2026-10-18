<#
.SYNOPSIS
    One-command feature claim: remote-aware number allocation, branch + spec creation,
    immediate push, race recovery.

.DESCRIPTION
    Automates the claim ritual in docs/sdlc/branch-strategy.md ("Number Allocation") and
    docs/sdlc/team-workflow.md (rule 2) — the ritual itself is unchanged:

      1. Preflight: clean working tree, current branch is main.
      2. git fetch origin; allocate the next feature number free across local branches,
         remote branches, and specs/ directories.
      3. Delegate branch + spec-directory creation to the stock Spec Kit script
         (.specify/scripts/powershell/create-new-feature.ps1 -Number).
      4. git push -u origin <branch> immediately — the remote branch IS the claim.
      5. If another claim reached the remote first with the same number, renumber the
         branch and spec directory and push again (max 3 attempts).

    With no remote configured (or -NoPush), the claim is created locally and a warning
    states it is not team-visible.

    Contract: specs/003-flow-efficiency-pack/contracts/claim-feature-cli.md

.EXAMPLE
    pwsh -File scripts/claim-feature.ps1 -ShortName user-invitations "Invite users by email"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ShortName,
    [switch]$Json,
    [switch]$NoPush,
    # Feature 037 (GAP-024 c): the roadmap row this claim is for (a fragment of its first cell) and who is claiming (a
    # roster name; default the git user.name). Together they ask for one ADVISORY reading of whether the row's declared
    # repositories fit the claimant's. Without -Row nothing here runs and the output is byte-identical to before.
    [string]$Row,
    [string]$As,
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$FeatureDescription
)

$ErrorActionPreference = 'Stop'
$MaxAttempts = 3

function Write-Info([string]$Message) {
    if (-not $Json) { Write-Host $Message }
}
# An advisory fit line (feature 037): never a refusal, never an exit code, silent under -Json.
function Write-Fit([string]$Message) { Write-Info $Message }

# Set by every Get-RemoteFeatureHeads call: $true when the ledger could not be read. It is a flag and not a return
# value because an empty ledger is a valid read, and PowerShell unrolls an empty array returned from a function to
# $null, so a failure signalled by returning $null could not be told from a repository with no NNN-* branch
# (feature 030, plan P1). Every caller checks it before it trusts the list.
$script:LedgerReadFailed = $false
# The commit each NNN-* branch on origin points at, from the same read (name -> sha), so a caller can tell our own push
# from another claimant's branch of the same name without a second call (feature 030, phase 3 review finding F1).
$script:LedgerShas = @{}

function Get-RemoteFeatureHeads {
    # Returns the NNN-* branch names currently on origin (authoritative ledger). A failed read returns nothing and
    # sets $script:LedgerReadFailed; the caller refuses, in words that depend on what is already on origin.
    $script:LedgerReadFailed = $false
    $script:LedgerShas = @{}
    $heads = git ls-remote --heads origin 2>$null
    if ($LASTEXITCODE -ne 0) { $script:LedgerReadFailed = $true; return @() }
    $names = @()
    foreach ($line in $heads) {
        if ($line -match 'refs/heads/(\d{3,}-\S+)$') { $names += $matches[1]; $script:LedgerShas[$matches[1]] = ("$line" -split '\s+')[0] }
    }
    return $names
}

function Get-NextFreeNumber {
    param([string[]]$RemoteHeads)
    [long]$highest = 0
    $localBranches = git for-each-ref --format='%(refname:short)' refs/heads 2>$null
    $specDirs = if (Test-Path 'specs') {
        Get-ChildItem 'specs' -Directory | ForEach-Object Name
    } else { @() }
    foreach ($name in @($localBranches) + @($RemoteHeads) + @($specDirs)) {
        if ($name -match '^(\d{3,})-' -and $name -notmatch '^\d{8}-\d{6}-') {
            [long]$num = 0
            if ([long]::TryParse($matches[1], [ref]$num) -and $num -gt $highest) { $highest = $num }
        }
    }
    return $highest + 1
}

# A refusal: the claim cannot be made, so it says why on the error stream and exits 1. Not
# Write-Error: under ErrorActionPreference = Stop that THROWS, the 'exit 1' beneath it never runs, and
# the reader gets a PowerShell error record and an exit code that is whatever the launcher or the last
# git call left behind, not the script's (feature 023, GAP-031; the same function as territory-check.ps1).
function Stop-Refused {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 1
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Refused 'Not inside a git repository.' }
Push-Location $repoRoot
try {

# --- 1. Preflight (mirrors CLAUDE.md workflow step 1) ---------------------------------
$dirty = git status --porcelain
if ($dirty) {
    Stop-Refused "Working tree is not clean — commit or stash before claiming a feature.`n$($dirty -join "`n")"
}
$currentBranch = git branch --show-current
if ($currentBranch -ne 'main') {
    Stop-Refused "Claims start from main (currently on '$currentBranch'). Checkout main first."
}

# --- 2. Sync with the ledger -----------------------------------------------------------
$hasRemote = $false
git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $hasRemote = $true }

$remoteHeads = @()
if ($hasRemote) {
    git fetch origin --prune 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Refused 'git fetch origin failed — cannot claim against an unreachable ledger.' }
    $remoteHeads = @(Get-RemoteFeatureHeads)
    if ($script:LedgerReadFailed) { Stop-Refused 'git ls-remote failed — cannot read the remote ledger. Nothing was claimed.' }
} else {
    Write-Warning 'No origin remote configured — allocating from the LOCAL ledger only. This claim is NOT team-visible.'
}

# --- 2b. Fit of the row to the claimant (feature 037; advisory, only with -Row) --------------
if ($Row) {
    $adoptionLib = Join-Path $PSScriptRoot 'adoption-lib.ps1'
    if (Test-Path -LiteralPath $adoptionLib) {
        . $adoptionLib
        $who = if ($As) { $As } else { "$(git config user.name 2>$null)".Trim() }
        # A failure inside the reading is the 'not read' line and never an abort of the claim (phase 3 review F2).
        try { $fit = Get-ClaimFit -Root $repoRoot -Row $Row -Claimant $who }
        catch { $fit = @{ Kind = 'Unreadable'; Cause = "the fit reading failed: $($_.Exception.Message)" } }
    } else {
        $fit = @{ Kind = 'Unreadable'; Cause = 'scripts/adoption-lib.ps1 was not found beside this script (partial kit install?)' }
    }
    switch ($fit.Kind) {
        'Partial'    { Write-Fit "Fit: row '$($fit.RowName)' declares $($fit.Declared -join ', '); $($fit.Claimant) does not list $($fit.Uncovered -join ', '); listed by: $($fit.ListedBy)" }
        'Unplaced'   { Write-Fit "Fit: not read - cannot tell who is claiming ($(if ($fit.Claimant) { "'$($fit.Claimant)' against $($fit.Roster)" } else { "no -As and no git user.name; roster: $($fit.Roster)" }))" }
        'RowCount'   { Write-Fit "Fit: not read - $($fit.Count) roadmap rows match '$Row'" }
        'NoColumn'   { Write-Fit "Fit: not read - the roadmap table holding '$($fit.RowName)' has no Repos column" }
        'Unreadable' { Write-Fit "Fit: not read - $($fit.Cause)" }
    }
}

# --- 3+4. Allocate and create (delegated to the stock Spec Kit script) -----------------
$number = Get-NextFreeNumber -RemoteHeads $remoteHeads
Write-Info "Allocating feature number $('{0:000}' -f $number) (next free across local + remote + specs/)."

$createScript = Join-Path $repoRoot '.specify/scripts/powershell/create-new-feature.ps1'
if (-not (Test-Path $createScript)) {
    Stop-Refused "Stock script not found: $createScript — partial kit install? Run scripts/doc-lint.ps1."
}
$createOut = & $createScript -Json -Number $number -ShortName $ShortName ($FeatureDescription -join ' ')
if ($LASTEXITCODE -ne 0) { Stop-Refused "create-new-feature.ps1 failed:`n$createOut" }
$created = $createOut | ConvertFrom-Json
$branch = $created.BRANCH_NAME
$renumberedFrom = $null

# --- 5. Push immediately — the remote branch IS the claim ------------------------------
$pushed = $false
if ($hasRemote -and -not $NoPush) {
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        # Git writes the porcelain status lines to stdout and its errors to stderr, and the two arrive in no fixed order:
        # the lines it complains on come first, then the status lines, so the text quoted in a refusal is the same each run.
        $pushAll = @(git push --porcelain -u origin $branch 2>&1)
        $pushText = @(@($pushAll | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) +
                      @($pushAll | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) | ForEach-Object { "$_" })
        $pushOk = ($LASTEXITCODE -eq 0)
        # A push that exits 0 and reports our own branch as up to date created nothing: the name was already on origin
        # at our sha, which a claim leaves at main's own commit, so another claimant of the same number and short name
        # pushed first and the branch is theirs. Only the push can tell: the ledger shows the same name at the same sha
        # either way (feature 031, plan P1; GAP-037).
        $sameName = $pushOk -and (@($pushText | Where-Object { $_ -match ('^=\s+refs/heads/' + [regex]::Escape($branch) + ':') }).Count -gt 0)
        $rejection = "git push of $branch was rejected:`n$($pushText -join "`n")`nNothing was claimed; the local branch and its spec directory remain. If the push may have landed, check origin (git ls-remote --heads origin $branch) before claiming again."

        # Same-number races don't always reject the push (a different slug with the same
        # NNN pushes fine), so re-read the ledger and look for a rival with our number.
        $numPrefix = $branch -replace '^(\d{3,})-.*', '$1'
        $ledger = @(Get-RemoteFeatureHeads)
        if ($script:LedgerReadFailed) {
            # After a push that succeeded our claim is already live on origin: say so, and touch nothing. After one
            # that failed nothing of ours is there, and the older fact is the rejection (feature 030, plan P2/P3).
            if ($pushOk) { Stop-Refused "git ls-remote failed after pushing $branch — the claim may already be live on origin. Check origin (git ls-remote --heads origin $branch) before claiming again; nothing on origin was changed." }
            Stop-Refused "$rejection The ledger could not be read either."
        }
        $rivals = @($ledger | Where-Object { $_ -match "^$numPrefix-" -and $_ -ne $branch })

        # Did our push reach origin? A push can exit non-zero after the remote accepted it, so the ledger just read is
        # better evidence than the exit code: but only the COMMIT is ours. Our number was free when it was allocated, our
        # branch NAME is not (a second claimant with the same number and short name allocates the same one), so a branch
        # of our name at another commit is theirs: not landed, and never withdrawn (feature 030, plan P3 as amended;
        # review finding F1 of phase 1, and F1 of phase 3).
        $landed = $pushOk -and -not $sameName
        if (-not $landed -and -not $sameName -and $script:LedgerShas.ContainsKey($branch)) {
            $tip = @(git rev-parse --verify --quiet "refs/heads/$branch" 2>$null)
            $landed = ($LASTEXITCODE -eq 0) -and ("$($tip[0])".Trim() -eq $script:LedgerShas[$branch])
        }

        if ($landed -and $rivals.Count -eq 0) {
            if (-not $pushOk) {
                $said = @($pushText | Where-Object { $_ -match '^(error|fatal|remote):' })
                if ($said.Count -eq 0) { $said = $pushText }
                Write-Warning "git push of $branch reported an error, but $branch is on origin and no rival carries number $numPrefix — treating the claim as made. git said:`n$($said -join "`n")"
            }
            $pushed = $true; break
        }

        # A push the remote rejected, with no rival, is the remote's answer and not a lost race: renumbering and
        # pushing again would only repeat it, three times, and end on advice (renumber by hand) that does not apply.
        if (-not $landed -and -not $sameName -and $rivals.Count -eq 0) { Stop-Refused "$rejection" }

        # Lost the race. Withdraw our remote branch if it landed, then renumber.
        if ($sameName) {
            # The branch of our name on origin is the other claimant's: it is never withdrawn, and the upstream that -u
            # just pointed at it is dropped so the local branch does not track a branch it does not own (plan P2, P3).
            $also = if ($rivals.Count -gt 0) { "; so did $($rivals -join ', ')" } else { '' }
            Write-Warning "Number $numPrefix was claimed concurrently by a claimant of the same short name ($branch was already on origin; it is theirs and is left alone$also) — renumbering."
            git branch --unset-upstream $branch 2>$null | Out-Null
        } else {
            Write-Warning "Number $numPrefix was claimed concurrently ($($rivals -join ', ')) — renumbering."
        }
        # A withdrawal that fails leaves our abandoned number on origin as a live claim, so it is named and not
        # stepped over (feature 030, plan P4).
        if ($landed) {
            git push origin --delete $branch 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { Stop-Refused "Lost the allocation race but could not withdraw $branch from origin — delete it by hand: git push origin --delete $branch." }
        }
        if ($attempt -eq $MaxAttempts) {
            Stop-Refused "Lost the allocation race $MaxAttempts times — renumber manually (docs/sdlc/branch-strategy.md, Number Allocation)."
        }
        $gone = if ($landed) { "$branch was withdrawn from origin" } elseif ($sameName) { "$branch on origin is the other claimant's and was left alone" } else { "$branch never reached origin" }
        # The first fetch refuses on failure; this one used to go on and allocate from refs it had not refreshed.
        git fetch origin --prune 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Stop-Refused "git fetch origin failed — cannot claim against an unreachable ledger. $gone." }
        $remoteHeads = @(Get-RemoteFeatureHeads)
        if ($script:LedgerReadFailed) {
            Stop-Refused "git ls-remote failed — cannot read the remote ledger. $gone; nothing of ours is claimed, and the local branch and its spec directory remain."
        }
        $newNumber = Get-NextFreeNumber -RemoteHeads $remoteHeads
        $newBranch = $branch -replace '^\d{3,}', ('{0:000}' -f $newNumber)
        if (-not $renumberedFrom) { $renumberedFrom = $branch -replace '-.*$', '' }
        git branch -m $branch $newBranch
        if (Test-Path "specs/$branch") { Rename-Item "specs/$branch" $newBranch }
        Write-Info "Renumbered: $branch -> $newBranch"
        $branch = $newBranch
    }
} elseif ($NoPush) {
    Write-Warning 'Push skipped (-NoPush) — this claim is NOT team-visible until you push the branch.'
}

# --- Output ----------------------------------------------------------------------------
$specFile = Join-Path $repoRoot "specs/$branch/spec.md"
if ($Json) {
    [PSCustomObject]@{
        BRANCH_NAME     = $branch
        SPEC_FILE       = $specFile
        FEATURE_NUM     = ($branch -replace '-.*$', '')
        PUSHED          = $pushed
        RENUMBERED_FROM = $renumberedFrom
    } | ConvertTo-Json -Compress
} else {
    if ($pushed) { Write-Host "CLAIMED: $branch (pushed to origin — the claim is live)" }
    else { Write-Host "CLAIMED LOCALLY: $branch (not pushed — not team-visible)" }
    Write-Host "SPEC_FILE: $specFile"
    Write-Host "NEXT: flip the roadmap row for $branch (Status, Owner, Spec ``specs/$branch/``) in a main-side docs commit — ritual-checks fails while a claim's row still reads 'idea' (GAP-017)."
}
exit 0

} finally { Pop-Location }
