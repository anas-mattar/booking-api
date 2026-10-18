<#
.SYNOPSIS
    Roadmap-claim visibility check: every NNN-* claim on origin must have a non-idea
    roadmap row, so main's roadmap never lies about in-flight work (GAP-017).

.DESCRIPTION
    The remote NNN-* branch IS the claim (docs/sdlc/branch-strategy.md, Number
    Allocation; scripts/claim-feature.ps1). But the roadmap status flip used to live on
    the feature branch, invisible from main until merge: in the first post-010 field use
    a feature sat 13 days with an approved spec and a gated phase while main's row still
    read idea — an agent orienting from main would have re-specced it.

    This check makes that lie fail the gate. For every NNN-name branch on origin, the
    roadmap table in docs/roadmap.md (any table under a Status-bearing header) must hold
    a row mentioning NNN-name whose Status is not 'idea'. The remedy is the ritual this
    enforces: flip the row (Status, Owner, Spec path) in a MAIN-SIDE docs commit at
    claim time — never only on the feature branch.

    Deliberate n/a states (exit 0, never synthetic failures — verify-kit precedent):
      - no origin remote, or the ledger unreachable (offline)
      - no docs/roadmap.md, or no table with a Status column (adopter roadmaps are
        adopter-authored and may not follow the kit's shape)

    The branch currently being checked is exempt for its OWN number, so a fresh claim's
    first CI run cannot deadlock on its not-yet-flipped row. Cell parsing counts only
    unescaped pipes (the GAP-015 lesson). Read-only.

    Where kit-adoption.json declares a usable developer roster (feature 021, scripts/adoption-lib.ps1)
    two further readings run, and only then: a claim's non-idea row must name an Owner on the
    roster (blank and em-dash Owners are not graded), and no Owner may hold more than two active,
    non-stale claims (Status specified or in progress; no commit for 14 days is stale). Exactly two
    is noted, never failed. The date of a tip is read only for an Owner with two or more candidate
    claims; if it cannot be read the Owner's count is UNGRADED, said out loud, never counted and
    never dropped. With no usable roster neither reading runs and the output is byte-identical to
    what it was before. The own claim of the checked branch is exempt from both, as from visibility.

    These two readings bind a claim to its row by a delimited token, case-insensitively (the name
    not run into more letters, digits, '_' or '-', or into a dot that is followed by one; a final
    full stop is not part of the name), preferring the row whose Spec cell holds specs/<claim>: a
    row that merely MENTIONS another claim in free text does not take it, and a claim whose name is a
    prefix of another does not match the longer one. The set of characters is the common one, not
    every character a branch name may hold: where two claims still collide the answer is the safe
    one, not graded. If the rows left name different Owners the claim is not graded, said out loud
    and UNGRADED; so is a claim the visibility reading found but that no token binds to a row (its
    name appears only inside a longer one); a claim whose only rows sit in a table with no Owner
    column is likewise said not to have been graded. The visibility reading is unchanged.

.EXAMPLE
    pwsh -File scripts/roadmap-claim-check.ps1
    pwsh -File scripts/roadmap-claim-check.ps1 -Branch 011-roadmap-claim-check
#>
[CmdletBinding()]
param(
    [string]$Branch,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path
$adoptionLib = Join-Path $PSScriptRoot 'adoption-lib.ps1'
if (Test-Path -LiteralPath $adoptionLib) { . $adoptionLib }   # Get-DeveloperMode: the one reader of the roster (feature 021)

function Get-Cells {
    # GAP-015: an escaped \| is cell content, not a boundary. Shield it before splitting.
    param([string]$Line)
    $shield = [string][char]1
    $cells = $Line.Trim().Trim('|').Replace('\|', $shield) -split '\|'
    return @($cells | ForEach-Object { $_.Replace($shield, '\|').Trim() })
}

# --- 1. The claim ledger ----------------------------------------------------------------
git -C $Root remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'roadmap-claims: n/a (no origin remote — no claim ledger to check against)'
    exit 0
}
$heads = git -C $Root ls-remote --heads origin 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'roadmap-claims: n/a (origin unreachable — cannot read the claim ledger)'
    exit 0
}
$claims = @()
$claimShas = @{}
foreach ($line in $heads) {
    # Same shape claim-feature.ps1 allocates; datestamped Spec Kit branches are not claims.
    if ($line -match 'refs/heads/(\d{3,}-\S+)$' -and $matches[1] -notmatch '^\d{8}-\d{6}-') {
        $claims += $matches[1]
        $claimShas[$matches[1]] = ("$line" -split '\s+')[0]
    }
}
if ($claims.Count -eq 0) {
    Write-Host 'roadmap-claims: OK (no NNN-* claims on origin)'
    exit 0
}

# --- 2. Own-number exemption -------------------------------------------------------------
if (-not $Branch) { $Branch = (git -C $Root rev-parse --abbrev-ref HEAD 2>$null).Trim() }
$ownNumber = $null
if ($Branch -match '^(\d{3,})-') { $ownNumber = $matches[1] }

# --- 3. The roadmap table(s) --------------------------------------------------------------
$roadmapPath = Join-Path $Root 'docs/roadmap.md'
if (-not (Test-Path $roadmapPath)) {
    Write-Host 'roadmap-claims: n/a (no docs/roadmap.md in this tree)'
    exit 0
}
$lines = Get-Content $roadmapPath

# Collect data rows from every table whose header carries a Status column.
$rows = @()   # each: @{ Text = raw line; Status = trimmed status cell or $null; Owner = trimmed Owner cell or $null }
$statusIdx = -1
$ownerIdx = -1
$ownerColumnSeen = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -notmatch '^\s*\|') { $statusIdx = -1; $ownerIdx = -1; continue }
    if ($line -match '^\s*\|[\s:|-]+\|?\s*$') { continue }   # separator row
    $cells = Get-Cells $line
    $next = if ($i + 1 -lt $lines.Count) { $lines[$i + 1] } else { '' }
    if ($next -match '^\s*\|[\s:|-]+\|?\s*$') {
        # Header row: remember where Status sits (or mark the table as not ours).
        $statusIdx = [array]::IndexOf(@($cells | ForEach-Object { "$_" }), 'Status')
        $ownerIdx = [array]::IndexOf(@($cells | ForEach-Object { "$_" }), 'Owner')
        if ($statusIdx -ge 0 -and $ownerIdx -ge 0) { $ownerColumnSeen = $true }
        continue
    }
    if ($statusIdx -lt 0) { continue }
    $status = if ($statusIdx -lt $cells.Count) { $cells[$statusIdx] } else { $null }
    $owner = if ($ownerIdx -ge 0 -and $ownerIdx -lt $cells.Count) { $cells[$ownerIdx] } else { $null }
    $rows += @{ Text = $line; Status = $status; Owner = $owner; HasOwnerColumn = ($ownerIdx -ge 0) }
}
if ($rows.Count -eq 0) {
    Write-Host 'roadmap-claims: n/a (docs/roadmap.md has no table with a Status column)'
    exit 0
}

# --- 4. Every claim must be visible ------------------------------------------------------
$failures = @()
$checked = 0
foreach ($claim in $claims) {
    if ($ownNumber -and $claim -match "^$ownNumber-") { continue }   # own claim: flip may ride this very change
    $checked++
    $matching = @($rows | Where-Object { $_.Text -like "*$claim*" })
    if ($matching.Count -eq 0) {
        $failures += "roadmap-claims: claim '$claim' is on origin but no roadmap row mentions it — flip the row (Status, Owner, Spec ``specs/$claim/``) in a main-side docs commit at claim time (GAP-017)"
    } elseif (-not ($matching | Where-Object { $_.Status -and $_.Status -ne 'idea' })) {
        $failures += "roadmap-claims: claim '$claim' is on origin but its roadmap row still reads 'idea' — flip the row (Status, Owner, Spec path) in a main-side docs commit at claim time (GAP-017)"
    }
}

# --- 5. The Owner and the claim count, where a roster is declared (feature 021) -----------
# Graded only with a usable roster; with none this section prints nothing and changes nothing.
$roster = @()
if (Get-Command Get-DeveloperMode -ErrorAction SilentlyContinue) { $roster = @((Get-DeveloperMode -Root $Root).Roster) }
$graded = $roster.Count -gt 0
$skippedNoOwner = $false   # a claim whose only rows sit in a table with no Owner column
$ungraded = @()   # one clause per reading that could not be made: an Owner's count, or a claim's Owner
$visibilityFailures = $failures.Count
if ($graded -and -not $ownerColumnSeen) {
    Write-Host 'roadmap-claims: not graded — a roster is declared but docs/roadmap.md has no Owner column, so neither the Owners nor the claim counts were checked'
}
if ($graded -and $ownerColumnSeen) {
    $rosterNames = @($roster | ForEach-Object { "$($_.Name)" })
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $staleAfter = 14 * 24 * 3600
    $candidates = [ordered]@{}   # lower-cased Owner -> @{ Name; Claims }
    foreach ($claim in $claims) {
        if ($ownNumber -and $claim -match "^$ownNumber-") { continue }   # own claim: exempt, as from visibility
        $ci = [Text.RegularExpressions.RegexOptions]::IgnoreCase
        $token = [regex]::new("(?<![A-Za-z0-9_-])(?<![A-Za-z0-9]\.)$([regex]::Escape($claim))(?![A-Za-z0-9_-])(?!\.[A-Za-z0-9])", $ci)
        $bound = [regex]::new("specs/$([regex]::Escape($claim))(?![A-Za-z0-9_-])(?!\.[A-Za-z0-9])", $ci)
        $named = @($rows | Where-Object { $token.IsMatch($_.Text) })
        if ($named.Count -eq 0) {
            # The visibility reading (section 4) matches loosely; a claim it passed that no token binds to a row
            # would otherwise leave this section in silence while the OK line says Owners were graded.
            if (@($rows | Where-Object { $_.Text -like "*$claim*" -and $_.Status -and $_.Status -ne 'idea' }).Count -gt 0) {
                Write-Host "roadmap-claims: not graded — claim '$claim' is on a roadmap row only in a form this check cannot bind to the claim (inside a longer name, say), so its Owner and its place in a count were not graded"
                $ungraded += "the Owner of '$claim' was not graded"
            }
            continue
        }
        $mine = @($named | Where-Object { $bound.IsMatch($_.Text) })
        if ($mine.Count -eq 0) { $mine = $named }
        $live = @($mine | Where-Object { $_.Status -and $_.Status -ne 'idea' })
        if ($live.Count -gt 0 -and @($live | Where-Object { $_.HasOwnerColumn }).Count -eq 0) {
            Write-Host "roadmap-claims: not graded — claim '$claim' is in a roadmap table with no Owner column, so its Owner and its place in a count were not graded"
            $skippedNoOwner = $true
            continue
        }
        $owned = @($live | Where-Object { $_.Owner -and $_.Owner -ne '—' })
        $distinctOwners = @($owned | ForEach-Object { $_.Owner.Trim() } | Sort-Object -Unique)
        if ($distinctOwners.Count -gt 1) {
            Write-Host "roadmap-claims: not graded — claim '$claim' is named by rows with different Owners ($($distinctOwners -join ', ')), so its Owner and its place in a count were not graded"
            $ungraded += "the Owner of '$claim' was not graded"
            continue
        }
        foreach ($ownerName in @($owned | ForEach-Object { $_.Owner } | Select-Object -Unique)) {
            if ($rosterNames -notcontains $ownerName.Trim()) {
                # -notcontains is case-insensitive; the roster is already deduplicated the same way (plan D3).
                $failures += "roadmap-claims: claim '$claim' is owned by '$ownerName', who is not on the developer roster in kit-adoption.json ($($rosterNames -join ', ')) — name a declared developer as Owner, or add the person to the roster (feature 021)"
            }
        }
        foreach ($row in @($owned | Where-Object { $_.Status -in 'specified', 'in progress' })) {
            $key = $row.Owner.Trim().ToLowerInvariant()
            if (-not $candidates.Contains($key)) { $candidates[$key] = @{ Name = $row.Owner.Trim(); Claims = @() } }
            if ($candidates[$key].Claims -notcontains $claim) { $candidates[$key].Claims += $claim }
        }
    }
    foreach ($entry in $candidates.Values) {
        if ($entry.Claims.Count -lt 2) { continue }   # a date is read only where the count could matter
        $active = @()
        $unreadable = $null
        foreach ($claim in $entry.Claims) {
            $sha = $claimShas[$claim]
            $ct = "$(git -C $Root log -1 --format=%ct $sha 2>$null)".Trim()
            if ($LASTEXITCODE -ne 0 -or $ct -notmatch '^\d+$') {
                git -C $Root fetch --quiet origin $claim 2>$null | Out-Null
                $ct = "$(git -C $Root log -1 --format=%ct $sha 2>$null)".Trim()
            }
            if ($LASTEXITCODE -ne 0 -or $ct -notmatch '^\d+$') { $unreadable = $claim; break }
            if (($now - [int64]$ct) -le $staleAfter) { $active += $claim }
        }
        if ($unreadable) {
            Write-Host "roadmap-claims: not graded — the claim count for '$($entry.Name)' was not made: the tip date of '$unreadable' could not be read (git log failed on the tip commit, and a fetch did not supply it)"
            $ungraded += "the claim count for '$($entry.Name)' was not made"
        } elseif ($active.Count -gt 2) {
            $failures += "roadmap-claims: '$($entry.Name)' holds $($active.Count) active claims ($($active -join ', ')) — more than two is over the WIP limit in docs/sdlc/team-workflow.md; finish or release one before claiming another"
        } elseif ($active.Count -eq 2) {
            Write-Host "roadmap-claims: note — '$($entry.Name)' holds two active claims ($($active -join ', ')); two are lawful only under the pipelining conditions in docs/sdlc/team-workflow.md, which a human confirms"
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host $_ }
    # The visibility roll-up keeps the words it always had; a finding of the roster readings changes it.
    $summary = if ($failures.Count -eq $visibilityFailures) { "$($failures.Count) of $checked claim(s) invisible or stale on this tree's roadmap" }
               else { "$($failures.Count) finding(s) on $checked claim(s) — the lines above say what and why" }
    Write-Host "roadmap-claims: FAIL ($summary)"
    exit 1
}
$ownText = if ($ownNumber) { ", own claim $ownNumber exempt" }
$gradedText = if ($graded -and $ownerColumnSeen -and -not $skippedNoOwner) { ', Owners and claim counts graded against the declared roster' }
if ($ungraded.Count -gt 0) {
    Write-Host "roadmap-claims: UNGRADED ($checked claim(s) visible with non-idea rows; $($ungraded -join '; ') — the reason is on the line(s) above)"
    exit 0
}
Write-Host "roadmap-claims: OK ($checked claim(s) visible with non-idea rows$gradedText$ownText)"
exit 0
