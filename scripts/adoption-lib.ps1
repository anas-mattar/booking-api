<#
.SYNOPSIS
    Shared readers for the adoption record's declarations: the developer roster
    (Get-DeveloperMode, feature 013), the critical surfaces (Get-CriticalSurfaces,
    feature 017) and the nested code repositories (Get-CodeRepos, feature 012, shared since
    feature 018).

.DESCRIPTION
    Dot-sourced by scripts/enforcement-pack.ps1 (which enforces) and scripts/verify-kit.ps1
    (which reports) for the developer and surface readers, and by scripts/scope-check-repos.ps1
    for Get-CodeRepos (and, from feature 018 phase 3, scripts/territory-check.ps1). Feature 012 established this pattern with scripts/scope-lib.ps1, for the
    same reason: two graders of one rule drift, and a comment claiming they agree is not a
    mechanism.

    That is not a hypothetical here. Feature 013 shipped the logic twice, and it went wrong
    in both of the ways duplication allows, inside one feature: the copies drifted (the
    root-object guard landed in the enforcing copy only), and the reporting copy used two
    comparers that disagreed with each other. The drift was found by a reviewer reading a
    comment asserting the two copies matched exactly.

    Get-DeveloperMode returns one object describing the record, and BOTH behaviours are read
    from it: the mode the check enforces, and the problems the doctor reports. Neither script
    interprets the record itself.
#>

# The evidence mode for the Critical lane (docs/sdlc/critical-delivery.md item 5), derived
# from the project's declared developers — never declared directly, so a project cannot
# assert team independence while naming one person.
#
# Every degenerate input resolves to 'solo', the stricter arm: no record, an unreadable or
# unparsable one, a root that is not a JSON object, no field, a non-array, an empty array, an
# array of blanks. Adoptions predating this feature declare nothing, and any other default
# would silently drop a requirement in projects that never asked.
#
# Returns:
#   Mode      'solo' | 'team'
#   Count     usable developers after trimming, dropping blank or non-string entries and objects
#             with no usable name, and collapsing duplicates case-insensitively across both forms
#   Why       one clause naming the reason, for the caller's message
#   Declared  whether the record declares the field at all, so no caller needs its own notion
#             of "is this declared" — a second such notion had grown in the doctor
#   Roster    the usable developers, deduplicated case-insensitively, in the order the record writes
#             them: @{ Name; Repos; CanApproveCritical; Form }. A string entry is a developer with no
#             repos who may approve Critical; an object entry is { name, repos?, canApproveCritical? }
#             (feature 021). Where one person is written twice and any copy denies Critical approval,
#             the person is denied: the stricter reading wins, as every degenerate input does here
#   HasObjectEntries  whether any usable entry was written as an object, so the doctor says what it read
#             for a roster that uses the new form and prints exactly what it always printed for strings
#   Problems  zero or more @{ Message; Fix } (and Severity = 'warn' for the one that is a warning)
#             the doctor reports. The check ignores them, and
#             the reason is narrower than it first looks: a problem never makes a record
#             produce a LAXER mode than it would without the malformation. It does NOT mean
#             every problem lands on solo — ["ada","grace"," "] is malformed and is team.
#             Getting that reason wrong is how a maintainer talks themselves out of the
#             doctor (013 phase 5 review, NEW-4)
function Get-DeveloperMode {
    param([Parameter(Mandatory)][string]$Root)

    $problems = [System.Collections.Generic.List[object]]::new()
    $recordPath = Join-Path $Root 'kit-adoption.json'
    if (-not (Test-Path -LiteralPath $recordPath)) {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'no kit-adoption.json'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }

    # Inside the try: 'unreadable' is one of the degenerate records FR-003 names, and a read
    # can fail on a path Test-Path accepts — a directory, a lock, a permission denial, a
    # dangling symlink. Phase 4 moved this read out of the try and, with
    # $ErrorActionPreference = 'Stop', an unreadable record became an unhandled error that
    # skipped every check ordered after this one (013 phase 4 re-review, N2).
    try {
        # -ErrorAction Stop so the catch fires regardless of the caller's preference. Both
        # shipped callers set 'Stop', but a library that only works under one caller's
        # settings is not self-contained (013 phase 5 review, NEW-E).
        $rawRecord = "$(Get-Content -LiteralPath $recordPath -Raw -ErrorAction Stop)"
    } catch {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'kit-adoption.json could not be read'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }

    # The root must be a JSON OBJECT, judged from the TEXT. Testing the parsed value is not
    # enough: ConvertFrom-Json emits array elements to the pipeline one at a time, so a
    # single-element root array collapses to one PSCustomObject indistinguishable from a real
    # record. The root of a JSON document is whatever the first non-whitespace character
    # opens, so this test cannot be fooled by a brace inside a string.
    if ($rawRecord.TrimStart([char]0xFEFF, ' ', "`t", "`r", "`n") -notmatch '^\{') {
        $problems.Add(@{ Message = 'kit-adoption.json is not a JSON object at its root'; Fix = 'the record is a single JSON object; a root array is ignored entirely and the project falls back to the solo evidence rule' })
        return @{ Mode = 'solo'; Count = 0; Declared = $true; Why = 'kit-adoption.json is not a JSON object at its root'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }
    try {
        $record = $rawRecord | ConvertFrom-Json
    } catch {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'kit-adoption.json does not parse'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }
    if ($record -isnot [PSCustomObject]) {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'kit-adoption.json is not a JSON object'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }

    if ($null -eq $record.developers) {
        # An explicit `"developers": null` is the same unfinished edit as `[]` and is reported
        # the same way — but only when the key is really present. An ABSENT key is the
        # supported default for every adoption predating this feature and must stay silent.
        if ($rawRecord -match '(?m)"developers"\s*:') {
            $problems.Add(@{ Message = 'kit-adoption.json developers is null'; Fix = 'name the project''s developers, or remove the key — an explicit null is treated as solo, the same as an empty array' })
            return @{ Mode = 'solo'; Count = 0; Declared = $true; Why = 'developers in kit-adoption.json is null'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
        }
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'no developers declared in kit-adoption.json'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }
    if ($record.developers -isnot [Array]) {
        $problems.Add(@{ Message = 'kit-adoption.json developers is not an array'; Fix = 'declare it as a JSON array of names, e.g. ["ada", "grace"] — a non-array is ignored and the project is treated as solo (adoption/updating.md)' })
        return @{ Mode = 'solo'; Count = 0; Declared = $true; Why = 'developers in kit-adoption.json is not an array'; Problems = $problems; Roster = @(); HasObjectEntries = $false }
    }

    $entries = @($record.developers)
    # Read each entry once, in order: a string is a developer as before; an object is a developer when it
    # has a usable name. Anything else (a blank string, a number, an array, null) is the generic
    # "blank or non-string entry" the doctor has always reported.
    $generic = 0
    $hasObject = $false
    $parsed = [System.Collections.Generic.List[object]]::new()
    $entryProblems = [System.Collections.Generic.List[object]]::new()
    $declaredRepos = $null
    for ($pos = 1; $pos -le $entries.Count; $pos++) {
        $e = $entries[$pos - 1]
        if ($e -is [string]) {
            if ([string]::IsNullOrWhiteSpace($e)) { $generic++ }
            else { $parsed.Add(@{ Name = $e.Trim(); Repos = @(); CanApproveCritical = $true; Form = 'string' }) }
            continue
        }
        if ($e -isnot [PSCustomObject]) { $generic++; continue }
        $props = @($e.PSObject.Properties.Name)
        # An assignment inside the if, not the if as an expression: an expression unrolls a one-element
        # array to its element, and "name": ["a"] would read as the name "a" (021 phase 1 review, F2).
        $name = $null
        if ($props -contains 'name') { $name = $e.name }
        if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) {
            $entryProblems.Add(@{ Message = "kit-adoption.json developers entry $pos is an object with no usable name"; Fix = 'give it a non-empty "name", or remove it — an entry with no name is dropped before the count is taken, which can silently move the project from team back to solo' })
            continue
        }
        $name = $name.Trim()
        $repos = @()
        if ($props -contains 'repos') {
            $r = $e.repos
            $bad = ($r -isnot [Array]) -or (@($r | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0)
            if ($bad) {
                $entryProblems.Add(@{ Message = "kit-adoption.json developers entry $pos ('$name') has a repos that is not an array of names"; Fix = 'write repos as an array of code repository names, for example ["api", "web"] — until then it is read as no repos' })
            } else {
                $repos = @($r | ForEach-Object { $_.Trim() })
                if ($null -eq $declaredRepos) { $declaredRepos = @((Get-CodeRepos -Root $Root).Repos) }
                foreach ($rn in $repos) {
                    if ($declaredRepos -notcontains $rn) {
                        $entryProblems.Add(@{ Severity = 'warn'; Message = "kit-adoption.json developers entry $pos ('$name') names repository '$rn' in repos, which codeRepos does not declare"; Fix = 'declare it in codeRepos or correct the name — repos is recorded and read by no check' })
                    }
                }
            }
        }
        $permitted = $true
        if ($props -contains 'canApproveCritical') {
            if ($e.canApproveCritical -is [bool]) { $permitted = $e.canApproveCritical }
            else {
                $permitted = $false
                $entryProblems.Add(@{ Message = "kit-adoption.json developers entry $pos ('$name') has a canApproveCritical that is not true or false"; Fix = 'write the JSON value true or false — until it is a boolean the developer is read as NOT permitted to approve Critical features' })
            }
        }
        $hasObject = $true
        $parsed.Add(@{ Name = $name; Repos = $repos; CanApproveCritical = $permitted; Form = 'object' })
    }
    $named = @($parsed | ForEach-Object { $_.Name })
    if ($entries.Count -eq 0) {
        $problems.Add(@{ Message = 'kit-adoption.json developers is empty'; Fix = 'name the project''s developers, or remove the field — an empty array is indistinguishable from an unfinished edit and is treated as solo' })
    } elseif ($generic -gt 0) {
        $problems.Add(@{ Message = 'kit-adoption.json developers contains a blank or non-string entry'; Fix = 'every entry is a non-empty name; blanks and non-strings are dropped before the count is taken, which can silently move the project from team back to solo' })
    }

    # ONE comparer for detecting duplicates and for naming them. Two comparers that disagree
    # would dereference an empty group (013 phase 4 re-review, N6).
    foreach ($ep in $entryProblems) { $problems.Add($ep) }
    # The kept entry is found through the SAME comparer, never a second one: `-ieq` and OrdinalIgnoreCase
    # disagree on a few characters, and a lookup that finds nothing dropped the denial (review F1).
    $seen = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    $unique = [System.Collections.Generic.List[string]]::new()
    $rosterOut = [System.Collections.Generic.List[object]]::new()
    $firstDupe = $null
    foreach ($d in $parsed) {
        $n = $d.Name
        if (-not $seen.ContainsKey($n)) { $seen[$n] = $d; $unique.Add($n); $rosterOut.Add($d) }
        else {
            if (-not $firstDupe) { $firstDupe = $n }
            # the same person written twice: a denial in any copy denies the person
            if (-not $d.CanApproveCritical) { $seen[$n].CanApproveCritical = $false }
        }
    }
    if ($firstDupe) {
        $problems.Add(@{ Message = "kit-adoption.json developers lists '$firstDupe' more than once (case-insensitively)"; Fix = 'one entry per person — duplicates are collapsed before the count is taken, so the extra entry changes nothing except how the record reads' })
    }

    $mode = if ($unique.Count -ge 2) { 'team' } else { 'solo' }
    $noun = if ($unique.Count -eq 1) { 'developer' } else { 'developers' }
    return @{
        Mode     = $mode
        Count    = $unique.Count
        Declared = $true
        Why      = "$($unique.Count) $noun declared in kit-adoption.json"
        Problems = $problems
        Roster   = @($rosterOut)
        HasObjectEntries = $hasObject
    }
}

# The project's critical surfaces (constitution X, Level declaration; feature 017): path globs
# naming where its critical code lives, from the optional `criticalSurfaces` key. A Standard or
# Micro feature whose Territory reaches one is graded by scripts/enforcement-pack.ps1, and the
# doctor (scripts/verify-kit.ps1) reports the declaration. Both read it HERE and nowhere else,
# the way Get-DeveloperMode is read: two interpreters of one record is what 013 shipped and
# paid for.
#
# The direction of every degenerate input is the OPPOSITE of Get-DeveloperMode's. There, the
# unusable record falls to the stricter arm (solo). Here the strict state is ARMED, and a list
# nobody can read in full must never arm a floor that has a hole in it, nor read as an armed
# floor that is clean: so any problem leaves Armed false, State 'malformed', and the check
# reports UNGRADED. A problem therefore never makes this result MORE armed than the same record
# without it, and an unusable entry is never silently dropped from an otherwise armed list.
#
# Returns:
#   State     'absent' | 'unreadable' | 'empty' | 'malformed' | 'valid'
#   Armed     true only for State 'valid'
#   Globs     the usable entries: trimmed, `\` read as `/`, duplicates collapsed
#             case-insensitively. Populated for 'malformed' too, for messages only — a caller
#             must not grade against it unless Armed
#   Declared  whether the key is present at all (an explicit null counts as present)
#   Why       one clause naming the state, for the caller's message
#   Problems  zero or more @{ Message; Fix } the doctor reports as findings
#
# An empty array is NOT a problem. 'criticalSurfaces': [] reads as an explicit statement that
# the project has none, which is lawful; it is simply not armed. A record that exists but cannot
# be read (unreadable, not parseable, root not an object) is State 'unreadable', distinct from
# 'absent' so the check can say so by name instead of grading it as unarmed; it carries no
# Problems, because Get-DeveloperMode and the doctor already report that defect and the doctor
# must not print it twice.
function Get-CriticalSurfaces {
    param([Parameter(Mandatory)][string]$Root)

    $problems = [System.Collections.Generic.List[object]]::new()
    $absent = { param($why) @{ State = 'absent'; Armed = $false; Globs = @(); Declared = $false; Why = $why; Problems = $problems } }
    # 'unreadable' is NOT 'absent' (017 phase 2 review F2, approved by the owner). Absent means
    # the project said nothing, which is lawful and merely not armed. Unreadable means the
    # record exists and this reader cannot tell what it says, so it cannot know whether the
    # project asked for a floor. A caller that folded the two together would grade a project
    # with broken JSON exactly like one that never asked, which is the quiet clean grade spec
    # FR-012 forbids. No Problems here: the defect is reported once, by the doctor itself and
    # by Get-DeveloperMode, and a second report would be noise.
    $unreadable = { param($why) @{ State = 'unreadable'; Armed = $false; Globs = @(); Declared = $false; Why = $why; Problems = $problems } }

    $recordPath = Join-Path $Root 'kit-adoption.json'
    if (-not (Test-Path -LiteralPath $recordPath)) { return (& $absent 'no kit-adoption.json') }
    try {
        $rawRecord = "$(Get-Content -LiteralPath $recordPath -Raw -ErrorAction Stop)"
    } catch {
        return (& $unreadable 'kit-adoption.json could not be read')
    }
    if ($rawRecord.TrimStart([char]0xFEFF, ' ', "`t", "`r", "`n") -notmatch '^\{') {
        return (& $unreadable 'kit-adoption.json is not a JSON object at its root')
    }
    try { $record = $rawRecord | ConvertFrom-Json } catch { return (& $unreadable 'kit-adoption.json does not parse') }
    if ($record -isnot [PSCustomObject]) { return (& $unreadable 'kit-adoption.json is not a JSON object') }

    $present = $record.PSObject.Properties.Name -contains 'criticalSurfaces'
    if (-not $present) { return (& $absent 'no criticalSurfaces declared in kit-adoption.json') }

    $malformed = {
        param($message, $fix, $globs)
        $problems.Add(@{ Message = $message; Fix = $fix })
        @{ State = 'malformed'; Armed = $false; Globs = @($globs); Declared = $true; Why = $message; Problems = $problems }
    }
    if ($null -eq $record.criticalSurfaces) {
        return (& $malformed 'kit-adoption.json criticalSurfaces is null' 'declare it as a JSON array of path globs, or remove the key — an explicit null leaves the surface floor unarmed (adoption/updating.md)' @())
    }
    if ($record.criticalSurfaces -isnot [Array]) {
        return (& $malformed 'kit-adoption.json criticalSurfaces is not an array' 'declare it as a JSON array of path globs, e.g. ["src/auth/", "api/Payments/**"] — a non-array leaves the surface floor unarmed (adoption/updating.md)' @())
    }

    $entries = @($record.criticalSurfaces)
    if ($entries.Count -eq 0) {
        return @{ State = 'empty'; Armed = $false; Globs = @(); Declared = $true; Why = 'criticalSurfaces is empty'; Problems = $problems }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $usable = [System.Collections.Generic.List[string]]::new()
    $sawBlank = $false
    $unsafe = [System.Collections.Generic.List[string]]::new()
    foreach ($e in $entries) {
        if ($e -isnot [string] -or [string]::IsNullOrWhiteSpace($e)) { $sawBlank = $true; continue }
        $glob = $e.Trim().Replace('\', '/')
        # The same shape Get-Territory refuses (scripts/scope-lib.ps1): a drive or leading slash
        # can never match a repo-relative Territory path, and a '..' segment addresses outside
        # the tree. Either would sit in the list looking like coverage and match nothing.
        if ($glob -match '^([A-Za-z]:|/)' -or $glob -match '(^|/)\.\.(/|$)') { $unsafe.Add($glob); continue }
        if ($seen.Add($glob)) { $usable.Add($glob) }
    }
    if ($sawBlank) {
        $problems.Add(@{ Message = 'kit-adoption.json criticalSurfaces contains a blank or non-string entry'; Fix = 'every entry is a non-empty path or glob; the floor is not armed until the whole list is usable, because a dropped entry would silently weaken it' })
    }
    foreach ($u in $unsafe) {
        $problems.Add(@{ Message = "kit-adoption.json criticalSurfaces entry '$u' is not a repo-relative path"; Fix = 'write surfaces governance-root-relative (repo-prefixed in a multi-repo project) with no drive letter, leading slash or .. segment — an entry that can never match leaves a hole in the floor' })
    }
    if ($problems.Count -gt 0) {
        return @{ State = 'malformed'; Armed = $false; Globs = @($usable); Declared = $true; Why = 'criticalSurfaces holds an entry that cannot be used'; Problems = $problems }
    }
    $noun = if ($usable.Count -eq 1) { 'critical surface' } else { 'critical surface(s)' }
    return @{ State = 'valid'; Armed = $true; Globs = @($usable); Declared = $true; Why = "$($usable.Count) $noun declared in kit-adoption.json"; Problems = $problems }
}

# The nested code repositories a project declares (feature 012; shared by feature 018). The reader
# the scripts that WALK those repositories share: scripts/scope-check-repos.ps1 grades their commits
# today, and scripts/territory-check.ps1 will compare their branches (feature 018, phase 3). It used
# to live inside the scope check, and a second script that needed it would have carried a second
# interpretation of the record, which is what 013 paid for. The scope check now calls this and
# prints exactly what it printed before.
#
# It is NOT the only place the key is read: scripts/verify-kit.ps1 validates codeRepos for the
# doctor with its own checks (feature 012 phase 2). The two are about different questions (what to
# walk, and what to report as a finding), and this function does not replace that one.
#
# The messages are RETURNED, not printed, because each caller speaks in its own voice: the scope
# check prefixes them with its own name, the territory check prints them as warnings. The text is
# byte-identical to what the scope check printed, so the REPOS-* rules are the guard.
#
# Returns:
#   Repos     the usable entries, in the record's order: single directory names, never a path
#   Warnings  zero or more message strings, each beginning 'WARN '
#   Unusable  true when the declaration was PRESENT and could not be read in full: unparseable JSON,
#             a non-array, or any rejected entry. An absent record, an absent key and an empty array
#             are lawful statements that there are none and are NOT unusable. A caller that needs to
#             tell "declared nothing" from "declared something I cannot use" reads this.
function Get-CodeRepos {
    param([Parameter(Mandatory)][string]$Root)
    $result = @{ Repos = @(); Warnings = @(); Unusable = $false }
    $recordPath = Join-Path $Root 'kit-adoption.json'
    if (-not (Test-Path $recordPath)) { return $result }
    try {
        $record = Get-Content -Raw -Path $recordPath | ConvertFrom-Json
    } catch {
        $result.Warnings += 'WARN kit-adoption.json is not valid JSON — no code repositories read (fix the record; scripts/verify-kit.ps1 explains the shape)'
        $result.Unusable = $true
        return $result
    }
    if ($null -ne $record.codeRepos -and $record.codeRepos -isnot [Array]) {
        $result.Warnings += 'WARN kit-adoption.json codeRepos is not an array — ignoring it (shape: adoption/updating.md)'
        $result.Unusable = $true
        return $result
    }
    # Entries are single directory names (012 D2). A path, a traversal or a drive prefix would address
    # a directory outside the governance root: read-only here, but it grades the wrong tree. The
    # doctor FAILs these too; the readers refuse them because a code repository's CI may never run
    # the doctor (012 phase 1 review, F7).
    $clean = @()
    foreach ($e in @($record.codeRepos | Where-Object { $_ })) {
        if ("$e" -notmatch '^(?!\.+$)[A-Za-z0-9._-]+$') {
            $result.Warnings += "WARN ignoring codeRepos entry '$e' — entries are plain directory names under this repository, not paths (scripts/verify-kit.ps1 explains the shape)"
            $result.Unusable = $true
            continue
        }
        $clean += "$e"
    }
    $result.Repos = @($clean)
    return $result
}

# --- Review claims (feature 037, GAP-024 b) ------------------------------------------------------------
# A Critical feature's reviewer takes the review: a remote ref refs/heads/review/<feature>/<slug>, one
# commit, pushed by scripts/claim-review.ps1. These two functions and Get-RosterBySlug are the one reader
# of that ledger, so the command that writes a claim and the check that grades it cannot disagree about
# what a claim is (the 013 lesson). The ref can never match the pattern the other ledger readers use
# (refs/heads/(\d{3,}-\S+)$), so no claim counter, number allocator or territory comparison sees it.

# A roster name as a ref name can hold it. A ref cannot contain a space, a leading dot, '..', a trailing
# '.' or '.lock', and a roster name may hold any of them. Trim, lower-case, every character outside
# [a-z0-9._-] becomes '-', runs of '-' and of '.' collapse, leading and trailing '-' and '.' are removed,
# and a trailing '.lock' becomes '-lock'. An empty result means the name has no usable slug.
function ConvertTo-ReviewSlug {
    param([string]$Name)
    $s = "$Name".Trim().ToLowerInvariant()
    $s = [regex]::Replace($s, '[^a-z0-9._-]', '-')
    $s = [regex]::Replace($s, '-{2,}', '-')
    $s = [regex]::Replace($s, '\.{2,}', '.')
    $s = $s.Trim('-', '.')
    if ($s.EndsWith('.lock')) { $s = $s.Substring(0, $s.Length - 5) + '-lock' }
    return $s
}

# The roster entries by slug: slug -> @(entries). A slug held by two entries is ambiguous, and neither
# of them can claim (the check and the command name both, and pick neither). Entries are the objects
# Get-DeveloperMode returns in .Roster.
function Get-RosterBySlug {
    param([object[]]$Roster = @())
    $map = [ordered]@{}
    foreach ($entry in @($Roster)) {
        $slug = ConvertTo-ReviewSlug $entry.Name
        if (-not $slug) { continue }
        if (-not $map.Contains($slug)) { $map[$slug] = @() }
        $map[$slug] += $entry
    }
    return $map
}

# The review claims on origin for one feature. A read that fails is NOT an empty list: Failed is set with
# a Cause, and a caller that reads Claims without looking at Failed would read "nobody pulled the review"
# where the truth is "could not tell" (the GAP-036 recipe, one species with GAP-027/034/035). With
# -WithAuthors each claim's commit author is read too, fetching the ref once if the commit is not in the
# clone; a claim whose author cannot be read fails the whole reading, because a claim whose author is
# unknown cannot be told from the Owner's.
#
# Returns: Failed, Cause, Claims = @( @{ Slug; Sha; AuthorName; AuthorEmail } )
function Get-ReviewClaims {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Feature, [switch]$WithAuthors)
    $result = @{ Failed = $false; Cause = ''; Claims = @() }
    git -C $Root remote get-url origin 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $result.Failed = $true; $result.Cause = 'there is no origin remote, so the review claims cannot be read'
        return $result
    }
    $lines = @(git -C $Root ls-remote --heads origin "refs/heads/review/$Feature/*" 2>$null)
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        $result.Failed = $true; $result.Cause = "git ls-remote --heads origin failed (git exited $exit), so the review claims cannot be read"
        return $result
    }
    $pattern = '^([0-9a-fA-F]+)\s+refs/heads/review/' + [regex]::Escape($Feature) + '/([^/\s]+)$'
    foreach ($line in $lines) {
        if ("$line" -notmatch $pattern) { continue }
        $claim = @{ Slug = $matches[2]; Sha = $matches[1]; AuthorName = ''; AuthorEmail = '' }
        if ($WithAuthors) {
            $meta = @(git -C $Root log -1 --format='%an%x1f%ae' $claim.Sha 2>$null)
            if ($LASTEXITCODE -ne 0) {
                git -C $Root fetch --quiet origin "refs/heads/review/$Feature/$($claim.Slug)" 2>$null | Out-Null
                $meta = @(git -C $Root log -1 --format='%an%x1f%ae' $claim.Sha 2>$null)
            }
            if ($LASTEXITCODE -ne 0 -or "$($meta[0])" -notmatch "\x1f") {
                $result.Failed = $true; $result.Cause = "the author of the review claim '$($claim.Slug)' could not be read (git log failed on its commit, and a fetch did not supply it)"
                $result.Claims = @()
                return $result
            }
            $parts = "$($meta[0])" -split "\x1f", 2
            $claim.AuthorName = $parts[0]; $claim.AuthorEmail = $parts[1]
        }
        $result.Claims += $claim
    }
    return $result
}

# --- Pull-time fit (feature 037, GAP-024 c) -------------------------------------------------------------
# The first and only reader of a roster entry's `repos` (recorded since feature 021, read by nothing until now).
# A claim can be told which roadmap row it is for (scripts/claim-feature.ps1 -Row); this compares the repositories
# the row declares, in an optional `Repos` column of the roadmap table, with the claimant's. It is ADVISORY: it
# returns what to say and nothing in it can stop, delay or change a claim, and it never ranks, proposes or assigns
# anyone. A reading it cannot make is a named kind, never a clean silence.

# One pipe-table line as trimmed cells; an escaped \| is cell content, not a boundary (the GAP-015 lesson).
function Get-RoadmapCells {
    param([string]$Line)
    $shield = [string][char]1
    $cells = $Line.Trim().Trim('|').Replace('\|', $shield) -split '\|'
    return @($cells | ForEach-Object { $_.Replace($shield, '\|').Trim() })
}

# The rows of every roadmap table (a table whose header has a Status column) with the first cell and, where the
# table has a Repos column, the repository names its cell lists (empty or an em dash lists none).
# Returns: Ok, Cause, Rows = @( @{ Name; HasReposColumn; Repos } )
function Get-RoadmapRows {
    param([Parameter(Mandatory)][string]$Root)
    $result = @{ Ok = $true; Cause = ''; Rows = @() }
    $path = Join-Path $Root 'docs/roadmap.md'
    if (-not (Test-Path -LiteralPath $path)) { $result.Ok = $false; $result.Cause = 'docs/roadmap.md was not found in this tree'; return $result }
    try { $lines = @(Get-Content -LiteralPath $path -ErrorAction Stop) } catch { $result.Ok = $false; $result.Cause = 'docs/roadmap.md could not be read'; return $result }
    $statusIdx = -1; $reposIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = "$($lines[$i])"
        if ($line -notmatch '^\s*\|') { $statusIdx = -1; $reposIdx = -1; continue }
        if ($line -match '^\s*\|[\s:|-]+\|?\s*$') { continue }
        $cells = Get-RoadmapCells $line
        $next = if ($i + 1 -lt $lines.Count) { "$($lines[$i + 1])" } else { '' }
        if ($next -match '^\s*\|[\s:|-]+\|?\s*$') {
            $statusIdx = [array]::IndexOf(@($cells | ForEach-Object { "$_" }), 'Status')
            $reposIdx = [array]::IndexOf(@($cells | ForEach-Object { "$_" }), 'Repos')
            continue
        }
        if ($statusIdx -lt 0) { continue }
        $repos = @()
        if ($reposIdx -ge 0 -and $reposIdx -lt $cells.Count) {
            # An empty cell, an em dash and an ASCII hyphen declare nothing; a name written twice is one name (phase 3 review F3).
            $repos = @()
            foreach ($name in (($cells[$reposIdx] -split ',') | ForEach-Object { $_.Trim() })) {
                if (-not $name -or $name -eq [string][char]0x2014 -or $name -eq '-') { continue }
                if ($repos -notcontains $name) { $repos += $name }
            }
        }
        $result.Rows += @{ Name = $cells[0]; HasReposColumn = ($reposIdx -ge 0); Repos = $repos }
    }
    return $result
}

# What a claim of one roadmap row, by one claimant, has to say about fit. Returns @{ Kind; ... }:
#   None        nothing to say: no roster, the row declares none, the claimant lists none, or every repository is covered
#   Partial     RowName, Declared, Claimant, Uncovered, ListedBy
#   Unplaced    Claimant (as given), Roster (names joined): the claimant is not a roster name (the 021 comparison)
#   RowCount    Count: the fragment names no row, or several
#   NoColumn    RowName: the row's table has no Repos column
#   Unreadable  Cause: the roadmap could not be read
function Get-ClaimFit {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Row, [string]$Claimant)
    $roster = @((Get-DeveloperMode -Root $Root).Roster)
    if ($roster.Count -eq 0) { return @{ Kind = 'None' } }
    $read = Get-RoadmapRows -Root $Root
    if (-not $read.Ok) { return @{ Kind = 'Unreadable'; Cause = $read.Cause } }
    $matched = @($read.Rows | Where-Object { $_.Name.IndexOf($Row, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if ($matched.Count -ne 1) { return @{ Kind = 'RowCount'; Count = $matched.Count } }
    $hit = $matched[0]
    if (-not $hit.HasReposColumn) { return @{ Kind = 'NoColumn'; RowName = $hit.Name } }
    if ($hit.Repos.Count -eq 0) { return @{ Kind = 'None' } }
    $entry = $null
    foreach ($d in $roster) { if ([string]::Equals($d.Name, "$Claimant".Trim(), [StringComparison]::OrdinalIgnoreCase)) { $entry = $d; break } }
    if (-not $entry) { return @{ Kind = 'Unplaced'; Claimant = "$Claimant".Trim(); Roster = (($roster | ForEach-Object { $_.Name }) -join ', ') } }
    $mine = @($entry.Repos | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($mine.Count -eq 0) { return @{ Kind = 'None' } }
    $uncovered = @($hit.Repos | Where-Object { $mine -notcontains $_ })
    if ($uncovered.Count -eq 0) { return @{ Kind = 'None' } }
    $segments = @()
    foreach ($repo in $uncovered) {
        $names = @($roster | Where-Object { $_ -ne $entry -and (@($_.Repos | ForEach-Object { "$_".Trim() }) -contains $repo) } | ForEach-Object { $_.Name })
        $segments += @{ Repo = $repo; Names = ($names -join ', ') }
    }
    $listed = if ($segments.Count -eq 1) {
        if ($segments[0].Names) { $segments[0].Names } else { 'no one declared it' }
    } else {
        (@($segments | ForEach-Object { "$($_.Repo) - $(if ($_.Names) { $_.Names } else { 'no one declared it' })" })) -join '; '
    }
    return @{ Kind = 'Partial'; RowName = $hit.Name; Declared = $hit.Repos; Claimant = $entry.Name; Uncovered = $uncovered; ListedBy = $listed }
}
