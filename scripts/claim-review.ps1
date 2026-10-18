<#
.SYNOPSIS
    Take the review of a Critical feature: push a review claim under your own name.

.DESCRIPTION
    Feature 037 (GAP-024 b). On a team project, the person who judges a Critical feature is not
    chosen by its owner: the reviewer pulls the review, the way a developer pulls a feature
    (docs/sdlc/team-workflow.md). A review claim is the remote ref

        refs/heads/review/<feature>/<slug>

    where <feature> is the feature's NNN-name and <slug> is the claimant's roster name made safe
    for a ref (ConvertTo-ReviewSlug in scripts/adoption-lib.ps1). It points at one commit: the
    feature tip's tree, the feature tip as its parent, the message 'review claim: <feature> by
    <name>', authored by whoever pushes it. No coordinator, no queue, nothing anyone must write
    for others to proceed; a pushed ref is the claim, as a pushed NNN-* branch is.

    The check that reads claims is Invoke-CriticalTeamEvidence in scripts/enforcement-pack.ps1.
    A claim is a written claim: it shows that someone who can push to origin wrote a roster name,
    not who they are, and not that the review happened or was independent.

    This command only writes. It never selects, ranks or proposes a reviewer, and it does not
    compare the claimant with the feature's Owner: the Owner is named in the roadmap row and in
    the review file, and the check refuses the Owner's own claim when it grades the review.

    Refusals (message on the error stream, exit 1):
      1. not inside a git repository
      2. no origin remote
      3. the claim ledger, or the feature, cannot be read from origin
      4. the feature is not a branch on origin
      5. no team roster is declared (the solo arm uses no review claim)
      6. -As is not on the roster, or two roster entries slug alike
      7. -As is a developer whose entry does not permit approving Critical features
      8. the claim could not be built or its push was rejected

    A claim that already exists is not pushed again: the command says so and exits 0.

.EXAMPLE
    pwsh -File scripts/claim-review.ps1 -Feature 007-payments -As grace
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Feature,
    [string]$As,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$adoptionLib = Join-Path $PSScriptRoot 'adoption-lib.ps1'
if (-not (Test-Path -LiteralPath $adoptionLib)) { [Console]::Error.WriteLine("scripts/adoption-lib.ps1 not found beside this script - partial kit install? Run scripts/doc-lint.ps1."); exit 1 }
. $adoptionLib

# A refusal: the claim cannot be made, so it says why on the error stream and exits 1. Not Write-Error:
# under ErrorActionPreference = Stop that throws, the 'exit 1' beneath it never runs and the exit code is
# whatever the launcher or the last git call left behind (feature 023, GAP-031; the same function as
# claim-feature.ps1).
function Stop-Refused {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 1
}

# The two refusals that carry git's own words are one site each, so each can be proved by a fixture: the
# ledger or the feature cannot be read, and the claim could not be built or pushed.
function Stop-LedgerUnreadable {
    param([Parameter(Mandatory)][string]$Detail)
    Stop-Refused "$Detail - cannot read the remote ledger. Nothing was claimed."
}
function Stop-NotMade {
    param([Parameter(Mandatory)][string]$Detail)
    Stop-Refused "The review claim was not made: $Detail"
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Refused 'Not inside a git repository.' }
Push-Location $repoRoot
try {

# --- 1. The ledger --------------------------------------------------------------------------
git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Stop-Refused 'No origin remote - a review claim lives on the remote ledger, so there is nothing to claim against.' }

$featureHeads = @(git ls-remote --heads origin "refs/heads/$Feature" 2>$null)
$featureExit = $LASTEXITCODE
if ($featureExit -ne 0) { Stop-LedgerUnreadable "git ls-remote --heads origin failed (git exited $featureExit)" }
$featureSha = $null
foreach ($line in $featureHeads) {
    if ("$line" -match ('^([0-9a-fA-F]+)\s+refs/heads/' + [regex]::Escape($Feature) + '$')) { $featureSha = $matches[1] }
}
$existing = Get-ReviewClaims -Root $repoRoot -Feature $Feature
if ($existing.Failed) { Stop-LedgerUnreadable $existing.Cause }
if (-not $featureSha) { Stop-Refused "'$Feature' is not a branch on origin - nothing to take the review of. Check the name against: git ls-remote --heads origin" }

# --- 2. Who is claiming ---------------------------------------------------------------------
$mode = Get-DeveloperMode -Root $repoRoot
if ($mode.Mode -ne 'team') { Stop-Refused "No team roster is declared in kit-adoption.json ($($mode.Why)) - the solo arm uses a second-model review, not a review claim (docs/sdlc/critical-delivery.md item 5)." }

if (-not $As) { $As = "$(git config user.name 2>$null)".Trim() }
$entry = $null
foreach ($d in @($mode.Roster)) {
    if ([string]::Equals($d.Name, $As, [StringComparison]::OrdinalIgnoreCase)) { $entry = $d; break }
}
$rosterNames = (@($mode.Roster) | ForEach-Object { $_.Name }) -join ', '
if (-not $entry) {
    $shown = if ($As) { "'$As'" } else { '(no -As and no git user.name)' }
    Stop-Refused "$shown is not on the developer roster in kit-adoption.json ($rosterNames) - name a declared developer with -As, or add the person to the roster."
}
$slug = ConvertTo-ReviewSlug $entry.Name
$bySlug = Get-RosterBySlug -Roster $mode.Roster
if (-not $slug -or @($bySlug[$slug]).Count -ne 1) {
    $alike = if ($slug -and $bySlug.Contains($slug)) { (@($bySlug[$slug]) | ForEach-Object { "'$($_.Name)'" }) -join ' and ' } else { "'$($entry.Name)'" }
    Stop-Refused "Roster name(s) $alike have no unique ref name ('$slug') in kit-adoption.json - two roster names that slug alike, or a name with no usable characters, cannot be told apart by a claim. Rename one."
}
if (-not $entry.CanApproveCritical) {
    Stop-Refused "'$($entry.Name)' is a developer whose roster entry in kit-adoption.json does not permit approving Critical features (canApproveCritical is not true) - a review claim by them would not be accepted."
}

# --- 3. Already claimed? --------------------------------------------------------------------
$ref = "review/$Feature/$slug"
$already = @($existing.Claims | Where-Object { $_.Slug -ceq $slug }).Count -gt 0
if (-not $already) {
    # --- 4. Build the claim and push it. A claim is never forced: a name already taken is a push refused. ---
    git fetch --quiet origin $Feature 2>$null | Out-Null
    $fetchExit = $LASTEXITCODE
    $tree = if ($fetchExit -eq 0) { "$(git rev-parse "$featureSha^{tree}" 2>$null)".Trim() } else { '' }
    $treeExit = $LASTEXITCODE
    if ($fetchExit -ne 0 -or $treeExit -ne 0) {
        Stop-NotMade "the tip of $Feature could not be fetched from origin (git exited $(if ($fetchExit -ne 0) { $fetchExit } else { $treeExit })). Nothing was pushed."
    }
    $commit = @(git commit-tree $tree -p $featureSha -m "review claim: $Feature by $($entry.Name)" 2>&1)
    if ($LASTEXITCODE -ne 0) { Stop-NotMade "git could not create the claim commit (is a git identity configured?):`n$($commit -join "`n")`nNothing was pushed." }
    $pushOut = @(git push --porcelain origin "$("$($commit[0])".Trim()):refs/heads/$ref" 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) { Stop-NotMade "git push of $ref was rejected:`n$($pushOut -join "`n")`nCheck origin (git ls-remote --heads origin $ref) before claiming again." }
}

# --- Output ----------------------------------------------------------------------------------
if ($Json) {
    [PSCustomObject]@{ FEATURE = $Feature; REVIEWER = $entry.Name; REF = $ref; ALREADY = [bool]$already } | ConvertTo-Json -Compress
} elseif ($already) {
    Write-Host "ALREADY CLAIMED: $Feature by $($entry.Name) ($ref is on origin; nothing was pushed)"
} else {
    Write-Host "CLAIMED REVIEW: $Feature by $($entry.Name) ($ref pushed to origin - the claim is live)"
}
exit 0

} finally { Pop-Location }
