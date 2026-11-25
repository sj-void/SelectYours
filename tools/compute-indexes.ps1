<#
  SelectYours: computes the Prestige Index and the Difficulty Index.
  Method: docs/methodology-prestige-difficulty.md (version 1, 23 Nov 2026).

  Inputs:
    docs/us-full-need-schools-international.csv   the 62 qualifying schools and their need policy
    docs/universities/_data/<slug>.json           per-school admissions and aid data
    docs/universities/_data/_rankings_national.json
    docs/universities/_data/_rankings_global.json
    docs/universities/_data/_endowments.json

  Outputs:
    docs/university-metrics.csv
    docs/prestige-and-difficulty-ranking.md
    the AUTO blocks in docs/universities/<slug>.md

  Run it again whenever the data changes:
    powershell -ExecutionPolicy Bypass -File tools\compute-indexes.ps1
#>
param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$NoProfiles
)
$ErrorActionPreference = 'Stop'
$docs    = Join-Path $Root 'docs'
$uniDir  = Join-Path $docs 'universities'
$dataDir = Join-Path $uniDir '_data'
$utf8    = New-Object System.Text.UTF8Encoding($false)
$inv     = [Globalization.CultureInfo]::InvariantCulture
$today   = (Get-Date).ToString('yyyy-MM-dd')

# ---------- helpers ----------
function Read-Json([string]$p) {
  if (Test-Path -LiteralPath $p) { return ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) | ConvertFrom-Json) }
  return $null
}
function Get-Slug([string]$n) { (($n.ToLower() -replace '&', 'and' -replace '\.', '') -replace '[^a-z0-9]+', '-').Trim('-') }
function Get-Prop($o, [string]$name) {
  if ($null -eq $o) { return $null }
  $p = $o.PSObject.Properties[$name]
  if ($p) { return $p.Value } else { return $null }
}
function Get-Num($x) {
  if ($null -eq $x) { return $null }
  if ($x -is [string]) {
    $m = [regex]::Match(($x -replace ',', ''), '-?\d+(\.\d+)?')
    if ($m.Success) { return [double]::Parse($m.Value, $inv) } else { return $null }
  }
  if ($x -is [bool]) { return $null }
  return [double]$x
}
function Get-MVal($metrics, [string]$name) { Get-Num (Get-Prop (Get-Prop $metrics $name) 'value') }
function Get-MSrc($metrics, [string]$name) { Get-Prop (Get-Prop $metrics $name) 'source' }
function Get-MAsOf($metrics, [string]$name) { Get-Prop (Get-Prop $metrics $name) 'as_of' }
function Limit([double]$v) { [math]::Max(0.0, [math]::Min(100.0, $v)) }

function Get-NatPts($rank) {
  if ($null -eq $rank) { return $null }
  return Limit (100 * (1 - [math]::Sqrt(([math]::Max(1, $rank) - 1) / 249)))
}
function Get-Global($v) {
  if ($null -eq $v -or [string]$v -eq '') { return @{ known = $false } }
  $s = [string]$v
  if ($s -match '(?i)not\s*ranked|unranked|reporter|^\s*nr\s*$') { return @{ known = $true; nr = $true; label = 'not ranked' } }
  if ($s -match '(\d+)\s*[-–]\s*(\d+)') { return @{ known = $true; nr = $false; rank = ([double]$matches[1] + [double]$matches[2]) / 2; label = $s.Trim() } }
  if ($s -match '(\d+)') { return @{ known = $true; nr = $false; rank = [double]$matches[1]; label = $s.Trim() } }
  return @{ known = $false }
}
function Get-GlobPts($g) {
  if (-not $g.known) { return $null }
  if ($g.nr) { return 0.0 }
  return Limit (100 * (1 - [math]::Sqrt(([math]::Max(1, $g.rank) - 1) / 399)))
}
function Get-WealthPts($perStudent) {
  if ($null -eq $perStudent -or $perStudent -le 0) { return $null }
  return Limit (100 * [math]::Log($perStudent / 100000) / [math]::Log(30))
}
function Get-AdmitPts($ratePct) {
  if ($null -eq $ratePct -or $ratePct -le 0) { return $null }
  return Limit (100 * [math]::Log(60 / $ratePct) / [math]::Log(20))
}
function Get-SatPts($mid) {
  if ($null -eq $mid) { return $null }
  return Limit (($mid - 1300) / 260 * 100)
}
function Get-SeatPts($seats) {
  if ($null -eq $seats) { return $null }
  if ($seats -le 5) { return 100.0 }
  return Limit (100 * [math]::Log(150 / $seats) / [math]::Log(30))
}
function Get-Weighted($pairs) {
  # $pairs: list of @(points, weight); skips null points and renormalizes over the rest
  $sw = 0.0; $s = 0.0
  foreach ($p in $pairs) { if ($null -ne $p[0]) { $s += $p[0] * $p[1]; $sw += $p[1] } }
  if ($sw -eq 0) { return $null }
  return $s / $sw
}
function F1($v) { if ($null -eq $v) { return '—' }; return ([math]::Round([double]$v, 1)).ToString('0.0', $inv) }
function F0($v) { if ($null -eq $v) { return '—' }; return ([math]::Round([double]$v)).ToString('0', $inv) }
function Get-Money($v) {
  if ($null -eq $v) { return '—' }
  if ($v -ge 1e9) { return '$' + ($v / 1e9).ToString('0.0', $inv) + 'B' }
  if ($v -ge 1e6) { return '$' + ($v / 1e6).ToString('0.0', $inv) + 'M' }
  return '$' + ($v / 1e3).ToString('0', $inv) + 'k'
}
function Get-PrestigeTier($v) {
  if ($null -eq $v) { return '—' }
  if ($v -ge 70) { return 'Tier 1, world-renowned' }
  if ($v -ge 55) { return 'Tier 2, elite' }
  if ($v -ge 40) { return 'Tier 3, highly regarded' }
  return 'Tier 4, respected'
}
function Get-DifficultyTier($v) {
  if ($null -eq $v) { return '—' }
  if ($v -ge 70) { return 'Extreme' }
  if ($v -ge 55) { return 'Very high' }
  if ($v -ge 40) { return 'High' }
  return 'Competitive'
}
function Get-RankLabel($r, $tie) { if ($null -eq $r) { return 'not ranked / not found' }; $t = ''; if ($tie -eq $true) { $t = ' (tie)' }; return '#' + (F0 $r) + $t }

# ---------- fixed markers (sources in the methodology) ----------
$ivy     = @('harvard-university','yale-university','princeton-university','columbia-university','university-of-pennsylvania','brown-university','dartmouth-college','cornell-university')
$ivyPlus = $ivy + @('university-of-chicago','duke-university','massachusetts-institute-of-technology','stanford-university')
# UK Home Office HPI Global Universities List 2026 (updated 4 Nov 2026), US entries that are among our 62
$hpi = @('brown-university','california-institute-of-technology','columbia-university','cornell-university','duke-university','harvard-university','johns-hopkins-university','massachusetts-institute-of-technology','new-york-university','northwestern-university','princeton-university','stanford-university','university-of-chicago','university-of-pennsylvania','vanderbilt-university','washington-university-in-st-louis','yale-university')
# Carnegie 2025 R1 and AAU membership (both verified 23 Nov 2026): the 23 research universities on our list
$r1aau = @('harvard-university','yale-university','princeton-university','massachusetts-institute-of-technology','california-institute-of-technology','stanford-university','columbia-university','cornell-university','university-of-pennsylvania','brown-university','dartmouth-college','duke-university','vanderbilt-university','rice-university','university-of-chicago','northwestern-university','university-of-notre-dame','johns-hopkins-university','washington-university-in-st-louis','university-of-rochester','new-york-university','tufts-university','brandeis-university')
# Swarthmore IR "Doctorates Awarded" (NSF SED 2015-2024 / IPEDS bachelor's 2006-2015), all-disciplines top-25 rank
$phd = @{ 'california-institute-of-technology'=1; 'swarthmore-college'=3; 'massachusetts-institute-of-technology'=4; 'reed-college'=5; 'carleton-college'=6; 'university-of-chicago'=7; 'haverford-college'=8; 'grinnell-college'=9; 'pomona-college'=10; 'princeton-university'=11; 'williams-college'=12; 'yale-university'=14; 'harvard-university'=15; 'bryn-mawr-college'=17; 'rice-university'=18; 'oberlin-college'=19; 'macalester-college'=20; 'amherst-college'=21; 'brown-university'=23; 'vassar-college'=24; 'wellesley-college'=25 }

$fixedRefs = [ordered]@{
  'HPI'      = 'UK Home Office, High Potential Individual visa: global universities list 2026 (updated 4 Nov 2026). https://www.gov.uk/government/publications/high-potential-individual-visa-global-universities-list/high-potential-individual-visa-global-universities-list-2026'
  'Carnegie' = 'ACE/Carnegie Classifications, 2025 Research Activity Designations, R1 list. https://carnegieclassifications.acenet.edu/institutions/?inst=&research2025%5B%5D=1'
  'AAU'      = 'Association of American Universities, member universities by year of entry. https://www.aau.edu/resource-library/aau-member-universities-by-year-of-entry'
  'IvyPlus'  = 'Chetty, Deming and Friedman (2023), "Diversifying Society''s Leaders?", NBER w31492 (Ivy-Plus definition). https://www.nber.org/papers/w31492'
  'PhD'      = 'Swarthmore College Institutional Research, "Doctorates Awarded" (NSF Survey of Earned Doctorates, 2015-2024). https://www.swarthmore.edu/institutional-research/doctorates-awarded'
  'Method'   = 'SelectYours methodology, version 1 (23 Nov 2026): ../methodology-prestige-difficulty.md'
}

# ---------- load ----------
$csv      = Import-Csv -LiteralPath (Join-Path $docs 'us-full-need-schools-international.csv') -Encoding UTF8
$schools  = $csv | Where-Object { $_.category -in @('A_need_blind_full_need', 'B_need_aware_full_need') -or $_.school -eq 'Berea College' }
$nat      = Read-Json (Join-Path $dataDir '_rankings_national.json')
$glob     = Read-Json (Join-Path $dataDir '_rankings_global.json')
$endow    = Read-Json (Join-Path $dataDir '_endowments.json')

$rows = New-Object System.Collections.Generic.List[object]
foreach ($s in $schools) {
  $slug = Get-Slug $s.school
  $sj   = Read-Json (Join-Path $dataDir ($slug + '.json'))
  $m    = Get-Prop $sj 'metrics'
  $rn   = Get-Prop (Get-Prop $nat 'schools') $slug
  $rg   = Get-Prop (Get-Prop $glob 'schools') $slug
  $en   = Get-Prop (Get-Prop $endow 'schools') $slug
  $flags = New-Object System.Collections.Generic.List[string]
  if ($null -eq $sj) { $flags.Add('no school data file') }

  # --- Prestige pillar A: US standing ---
  $usnR = Get-Num (Get-Prop $rn 'usnews_rank'); $forR = Get-Num (Get-Prop $rn 'forbes_rank'); $wsjR = Get-Num (Get-Prop $rn 'wsj_rank')
  $usnP = Get-NatPts $usnR; $forP = Get-NatPts $forR; $wsjP = Get-NatPts $wsjR
  # v1.1: WSJ is display-only (only its top 100 is public), so US standing = 60% U.S. News + 40% Forbes
  $pA = Get-Weighted @(@($usnP, 0.6), @($forP, 0.4))
  if ($null -eq $usnP -or $null -eq $forP) { $flags.Add('US standing uses ' + @(@($usnP, $forP) | Where-Object { $null -ne $_ }).Count + ' of 2 ranks') }

  # --- Prestige pillar B: global recognition ---
  $qs = Get-Global (Get-Prop $rg 'qs'); $th = Get-Global (Get-Prop $rg 'the'); $ar = Get-Global (Get-Prop $rg 'arwu')
  $gp = @((Get-GlobPts $qs), (Get-GlobPts $th), (Get-GlobPts $ar)) | Where-Object { $null -ne $_ }
  $pB = $null; if (@($gp).Count -gt 0) { $pB = (@($gp) | Measure-Object -Average).Average }
  if (@($gp).Count -lt 3) { $flags.Add('global recognition uses ' + @($gp).Count + ' of 3 rankings') }

  # --- Prestige pillar C: wealth per student ---
  $endUsd = Get-Num (Get-Prop $en 'endowment_usd')
  $enroll = Get-MVal $m 'total_enrollment'
  $perSt = $null; if ($endUsd -and $enroll) { $perSt = $endUsd / $enroll }
  $pC = Get-WealthPts $perSt
  if ($null -eq $pC) { $flags.Add('no wealth figure') }

  $prestige = Get-Weighted @(@($pA, 0.55), @($pB, 0.30), @($pC, 0.15))
  if ($null -eq $pA) { $prestige = $null }   # no index without US standing

  # --- Difficulty ---
  $rate = Get-MVal $m 'admit_rate_class_of_2030'; $rateKey = 'admit_rate_class_of_2030'
  if ($null -eq $rate) { $rate = Get-MVal $m 'admit_rate'; $rateKey = 'admit_rate' }
  if ($null -eq $rate) {
    $ap = Get-MVal $m 'applicants'; $ad = Get-MVal $m 'admits'
    if ($ap -and $ad) { $rate = 100 * $ad / $ap; $rateKey = 'admits/applicants' }
  }
  if ($null -ne $rate -and $rate -lt 1) { $rate = $rate * 100 }   # stored as a fraction
  $rateSrc = if ($rateKey -eq 'admits/applicants') { Get-MSrc $m 'admits' } else { Get-MSrc $m $rateKey }
  $rateAsOf = if ($rateKey -eq 'admits/applicants') { Get-MAsOf $m 'admits' } else { Get-MAsOf $m $rateKey }
  $dAdmit = Get-AdmitPts $rate

  $s25 = Get-MVal $m 'sat_25'; $s75 = Get-MVal $m 'sat_75'
  $satMid = $null; $satFromAct = $false
  if ($s25 -and $s75) { $satMid = ($s25 + $s75) / 2 }
  else {
    # Official 2018 ACT/SAT concordance, Table A2 (ACT composite -> SAT total), act.org
    $conc = @{ 36=1590; 35=1540; 34=1500; 33=1460; 32=1430; 31=1400; 30=1370; 29=1340; 28=1310; 27=1280; 26=1240; 25=1210; 24=1180 }
    $a25 = Get-MVal $m 'act_25'; $a75 = Get-MVal $m 'act_75'
    if ($a25 -and $a75 -and $conc.ContainsKey([int]$a25) -and $conc.ContainsKey([int]$a75)) {
      $satMid = ($conc[[int]$a25] + $conc[[int]$a75]) / 2; $satFromAct = $true
      $flags.Add('SAT midpoint converted from ACT ' + $a25 + '-' + $a75 + ' (2018 concordance)')
    }
  }
  $dSat = Get-SatPts $satMid

  $blind = ($s.category -eq 'A_need_blind_full_need')
  $dNeed = if ($blind) { 0.0 } else { 100.0 }

  $aided = Get-MVal $m 'intl_aided_count'
  $seats = $null; if ($null -ne $aided) { $seats = $aided / 4 }
  $dSeat = Get-SeatPts $seats

  $difficulty = Get-Weighted @(@($dAdmit, 0.6), @($dSat, 0.2), @($dNeed, 0.1), @($dSeat, 0.1))
  if ($null -eq $dAdmit) { $flags.Add('no admit rate'); $difficulty = $null }   # no index without the main component
  if ($null -eq $dSat) { $flags.Add('no SAT range') }
  if ($null -eq $dSeat) { $flags.Add('no CDS H6 count') }

  $rows.Add([pscustomobject]@{
    school = $s.school; slug = $slug; type = $s.institution_type; state = $s.state
    need_policy_intl = $s.admission_policy_intl; need_blind = $blind; need_source = $s.official_source
    usnews_category = (Get-Prop $rn 'usnews_category'); usnews_rank = $usnR; usnews_tie = (Get-Prop $rn 'usnews_tie'); usnews_pts = $usnP; usnews_source = (Get-Prop $rn 'usnews_source')
    forbes_rank = $forR; forbes_pts = $forP; forbes_source = (Get-Prop $rn 'forbes_source')
    wsj_rank = $wsjR; wsj_pts = $wsjP; wsj_source = (Get-Prop $rn 'wsj_source')
    qs = $qs; qs_pts = (Get-GlobPts $qs); qs_source = (Get-Prop $rg 'qs_source')
    the = $th; the_pts = (Get-GlobPts $th); the_source = (Get-Prop $rg 'the_source')
    arwu = $ar; arwu_pts = (Get-GlobPts $ar); arwu_source = (Get-Prop $rg 'arwu_source')
    endowment = $endUsd; endowment_asof = (Get-Prop $en 'as_of'); endowment_source = (Get-Prop $en 'source')
    total_enrollment = $enroll; enrollment_source = (Get-MSrc $m 'total_enrollment'); per_student = $perSt
    pillar_us = $pA; pillar_global = $pB; pillar_wealth = $pC; prestige = $prestige
    admit_rate = $rate; admit_rate_asof = $rateAsOf; admit_rate_source = $rateSrc; admit_pts = $dAdmit
    sat_mid = $satMid; sat_from_act = $satFromAct
    sat_source = $(if ($satFromAct) { (Get-MSrc $m 'act_25') + ' ; concordance: https://www.act.org/content/act/en/products-and-services/the-act/scores/act-sat-concordance.html' } else { Get-MSrc $m 'sat_25' })
    sat_asof = $(if ($satFromAct) { 'ACT ' + (Get-MAsOf $m 'act_25') + ', converted' } else { Get-MAsOf $m 'sat_25' }); sat_pts = $dSat
    need_pts = $dNeed
    intl_aided = $aided; seats = $seats; seats_source = (Get-MSrc $m 'intl_aided_count'); seats_asof = (Get-MAsOf $m 'intl_aided_count'); seat_pts = $dSeat
    intl_admit_rate = (Get-MVal $m 'intl_admit_rate'); intl_admit_source = (Get-MSrc $m 'intl_admit_rate')
    difficulty = $difficulty
    ivy = ($ivy -contains $slug); ivy_plus = ($ivyPlus -contains $slug); r1_aau = ($r1aau -contains $slug); hpi = ($hpi -contains $slug)
    phd_rank = $(if ($phd.ContainsKey($slug)) { $phd[$slug] } else { $null })
    flags = ($flags -join '; ')
    prestige_rank = $null; difficulty_rank = $null
  })
}

# ---------- rank ----------
$i = 0; foreach ($r in ($rows | Where-Object { $null -ne $_.prestige } | Sort-Object -Property prestige -Descending)) { $i++; $r.prestige_rank = $i }
$i = 0; foreach ($r in ($rows | Where-Object { $null -ne $_.difficulty } | Sort-Object -Property difficulty -Descending)) { $i++; $r.difficulty_rank = $i }
$n = $rows.Count

# ---------- CSV ----------
$rows | Sort-Object { if ($null -eq $_.prestige_rank) { 999 } else { $_.prestige_rank } } | ForEach-Object {
  [pscustomobject][ordered]@{
    prestige_rank = $_.prestige_rank; school = $_.school; slug = $_.slug; type = $_.type; state = $_.state
    prestige_index = F1 $_.prestige; prestige_tier = Get-PrestigeTier $_.prestige
    us_standing = F1 $_.pillar_us; global_recognition = F1 $_.pillar_global; wealth_per_student = F1 $_.pillar_wealth
    usnews_category = $_.usnews_category; usnews_2027_rank = $_.usnews_rank; forbes_2027_rank = $_.forbes_rank; wsj_2026_rank = $_.wsj_rank
    qs_2027 = $_.qs.label; the_2027 = $_.the.label; arwu_2026 = $_.arwu.label
    endowment_fy2025_usd = $_.endowment; total_enrollment = $_.total_enrollment; endowment_per_student_usd = $(if ($_.per_student) { [math]::Round($_.per_student) } else { $null })
    difficulty_rank = $_.difficulty_rank; difficulty_index = F1 $_.difficulty; difficulty_tier = Get-DifficultyTier $_.difficulty
    admit_rate_pct = $(if ($null -ne $_.admit_rate) { [math]::Round($_.admit_rate, 2) } else { $null }); admit_rate_as_of = $_.admit_rate_asof
    sat_midpoint = $_.sat_mid; need_policy_intl = $_.need_policy_intl
    intl_aided_students = $_.intl_aided; aided_seats_per_class = $(if ($null -ne $_.seats) { [math]::Round($_.seats, 1) } else { $null })
    intl_admit_rate_pct = $_.intl_admit_rate
    ivy_league = $_.ivy; ivy_plus = $_.ivy_plus; carnegie_r1_and_aau = $_.r1_aau; uk_hpi_2026 = $_.hpi; nsf_phd_top25_rank = $_.phd_rank
    data_flags = $_.flags; computed_on = $today
  }
} | Export-Csv -LiteralPath (Join-Path $docs 'university-metrics.csv') -NoTypeInformation -Encoding UTF8

# ---------- ranking markdown ----------
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# Prestige and admission difficulty: the 62 full-need schools')
[void]$sb.AppendLine()
[void]$sb.AppendLine('**Computed:** ' + $today + ' by `tools/compute-indexes.ps1`. **Method:** [methodology-prestige-difficulty.md](methodology-prestige-difficulty.md) (version 1). **All numbers:** [university-metrics.csv](university-metrics.csv). Every input value has its own source URL in `universities/_data/`, and each school profile cites it.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('How to read this:')
[void]$sb.AppendLine('- **Prestige Index (0–100)** = 55% US standing (U.S. News 2027 60%, Forbes 2027 40%) + 30% global recognition (QS 2027, THE 2027, ARWU 2026) + 15% endowment per student (FY2025). The WSJ 2026 rank is shown for the top 100 but not scored.')
[void]$sb.AppendLine('- **Difficulty Index (0–100)** is for an international student who needs aid: 60% overall admit rate, 20% SAT midpoint, 10% need-aware penalty, 10% scarcity of aided international seats (CDS H6).')
[void]$sb.AppendLine('- The two are separate on purpose. Compare the columns to find schools that are prestigious but less hard to get into.')
[void]$sb.AppendLine('- The global sub-score is 0 for most liberal arts colleges, because they are not eligible for QS or THE. Use the **US standing** column for a US-only view.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Ranked by prestige')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| # | School | Type | Prestige | Tier | US standing | Global | Wealth | Difficulty | Difficulty tier | Admit rate |')
[void]$sb.AppendLine('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
foreach ($r in ($rows | Sort-Object { if ($null -eq $_.prestige_rank) { 999 } else { $_.prestige_rank } })) {
  $ar = if ($null -ne $r.admit_rate) { ($r.admit_rate).ToString('0.0', $inv) + '%' } else { '—' }
  $link = '[' + $r.school + '](universities/' + $r.slug + '.md)'
  [void]$sb.AppendLine('| ' + $(if ($r.prestige_rank) { $r.prestige_rank } else { '—' }) + ' | ' + $link + ' | ' + $r.type + ' | ' + (F1 $r.prestige) + ' | ' + (Get-PrestigeTier $r.prestige) + ' | ' + (F1 $r.pillar_us) + ' | ' + (F1 $r.pillar_global) + ' | ' + (F1 $r.pillar_wealth) + ' | ' + (F1 $r.difficulty) + ' | ' + (Get-DifficultyTier $r.difficulty) + ' | ' + $ar + ' |')
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Ranked by difficulty (hardest first)')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| # | School | Difficulty | Tier | Admit rate (cycle) | SAT midpoint | Need policy for internationals | Aided international seats per class | Prestige rank |')
[void]$sb.AppendLine('| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
foreach ($r in ($rows | Sort-Object { if ($null -eq $_.difficulty_rank) { 999 } else { $_.difficulty_rank } })) {
  $ar = if ($null -ne $r.admit_rate) { ($r.admit_rate).ToString('0.0', $inv) + '% (' + $r.admit_rate_asof + ')' } else { '—' }
  $link = '[' + $r.school + '](universities/' + $r.slug + '.md)'
  $np = if ($r.need_blind) { 'Need-blind' } else { $r.need_policy_intl }
  [void]$sb.AppendLine('| ' + $(if ($r.difficulty_rank) { $r.difficulty_rank } else { '—' }) + ' | ' + $link + ' | ' + (F1 $r.difficulty) + ' | ' + (Get-DifficultyTier $r.difficulty) + ' | ' + $ar + ' | ' + (F0 $r.sat_mid) + ' | ' + $np + ' | ' + $(if ($null -ne $r.seats) { '~' + (F0 $r.seats) + ' (' + (F0 $r.intl_aided) + ' aided ÷ 4)' } else { '—' }) + ' | ' + $(if ($r.prestige_rank) { $r.prestige_rank } else { '—' }) + ' |')
}
[void]$sb.AppendLine()
$flagged = $rows | Where-Object { $_.flags }
if ($flagged) {
  [void]$sb.AppendLine('## Partial data')
  [void]$sb.AppendLine()
  [void]$sb.AppendLine('For these schools, a missing component''s weight was spread over the other components (methodology, section 1).')
  [void]$sb.AppendLine()
  foreach ($r in $flagged) { [void]$sb.AppendLine('- **' + $r.school + ':** ' + $r.flags) }
  [void]$sb.AppendLine()
}
[void]$sb.AppendLine('## Sources')
[void]$sb.AppendLine()
[void]$sb.AppendLine('- The per-school source URL for every rank, endowment, admit rate, SAT range and CDS H6 figure is in [university-metrics.csv](university-metrics.csv), the files in `universities/_data/`, and the "Index sources" section of each profile.')
[void]$sb.AppendLine('- Ranking editions: U.S. News Best Colleges 2027 (Sept 2026), Forbes America''s Top Colleges 2027 (10 Sept 2026), WSJ/College Pulse 2026 (Sept 2025), QS WUR 2027 (June 2026), THE WUR 2027 (Sept 2026), ARWU 2026 (15 Aug 2026). The methodology lists the publisher methodology pages.')
foreach ($k in $fixedRefs.Keys) { if ($k -ne 'Method') { [void]$sb.AppendLine('- ' + $fixedRefs[$k]) } }
[IO.File]::WriteAllText((Join-Path $docs 'prestige-and-difficulty-ranking.md'), $sb.ToString(), $utf8)

# ---------- profile AUTO blocks ----------
function Set-AutoBlock([string]$text, [string]$name, [string]$block) {
  $start = '<!-- AUTO:' + $name + ':START -->'; $end = '<!-- AUTO:' + $name + ':END -->'
  $full = $start + "`n" + $block.TrimEnd() + "`n" + $end
  $rxBlock = [regex]::new([regex]::Escape($start) + '.*?' + [regex]::Escape($end), 'Singleline')
  if ($rxBlock.IsMatch($text)) { return $rxBlock.Replace($text, [System.Text.RegularExpressions.MatchEvaluator] { param($x) $full }, 1) }
  $rxOne = [regex]::new('<!--\s*AUTO:' + $name + '(?!:START|:END)[^>]*-->')
  if ($rxOne.IsMatch($text)) { return $rxOne.Replace($text, [System.Text.RegularExpressions.MatchEvaluator] { param($x) $full }, 1) }
  return $text + "`n`n" + $full + "`n"
}

if (-not $NoProfiles) {
  foreach ($r in $rows) {
    $path = Join-Path $uniDir ($r.slug + '.md')
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)

    $p = New-Object System.Text.StringBuilder
    [void]$p.AppendLine('**Prestige Index: ' + (F1 $r.prestige) + ' / 100, ' + (Get-PrestigeTier $r.prestige) + '. #' + $r.prestige_rank + ' of ' + $n + ' full-need schools** [R-M].')
    [void]$p.AppendLine()
    [void]$p.AppendLine('| Measure | Result | Points |')
    [void]$p.AppendLine('| --- | --- | --- |')
    [void]$p.AppendLine('| U.S. News Best Colleges 2027 | ' + (Get-RankLabel $r.usnews_rank $r.usnews_tie) + $(if ($r.usnews_category) { ', ' + $r.usnews_category } else { '' }) + ' [R1] | ' + (F0 $r.usnews_pts) + ' |')
    [void]$p.AppendLine('| Forbes America''s Top Colleges 2027 | ' + (Get-RankLabel $r.forbes_rank $null) + ' [R2] | ' + (F0 $r.forbes_pts) + ' |')
    [void]$p.AppendLine('| WSJ/College Pulse Best Colleges 2026 (shown, not scored) | ' + $(if ($null -ne $r.wsj_rank) { '#' + (F0 $r.wsj_rank) } else { 'outside the published top 100' }) + ' [R3] | — |')
    [void]$p.AppendLine('| QS World University Rankings 2027 | ' + $(if ($r.qs.known) { $r.qs.label } else { 'not found' }) + ' [R4] | ' + (F0 $r.qs_pts) + ' |')
    [void]$p.AppendLine('| THE World University Rankings 2027 | ' + $(if ($r.the.known) { $r.the.label } else { 'not found' }) + ' [R5] | ' + (F0 $r.the_pts) + ' |')
    [void]$p.AppendLine('| ARWU 2026 | ' + $(if ($r.arwu.known) { $r.arwu.label } else { 'not found' }) + ' [R6] | ' + (F0 $r.arwu_pts) + ' |')
    [void]$p.AppendLine('| Endowment FY2025 per student | ' + (Get-Money $r.endowment) + ' ÷ ' + $(if ($r.total_enrollment) { ([double]$r.total_enrollment).ToString('#,0', $inv) } else { '—' }) + ' students = ' + (Get-Money $r.per_student) + ' [R7][R8] | ' + (F0 $r.pillar_wealth) + ' |')
    [void]$p.AppendLine()
    [void]$p.AppendLine('Sub-scores: **US standing ' + (F1 $r.pillar_us) + '** (55%), **global recognition ' + (F1 $r.pillar_global) + '** (30%), **wealth ' + (F1 $r.pillar_wealth) + '** (15%).')
    $marks = New-Object System.Collections.Generic.List[string]
    if ($r.ivy) { $marks.Add('Ivy League') }
    if ($r.ivy_plus) { $marks.Add('Ivy-Plus [R-IvyPlus]') }
    if ($r.r1_aau) { $marks.Add('Carnegie R1 research university (2025) [R-Carnegie] and AAU member [R-AAU]') }
    if ($r.hpi) { $marks.Add('on the UK HPI 2026 Global Universities List [R-HPI]') }
    if ($r.phd_rank) { $marks.Add('#' + $r.phd_rank + ' nationally for PhDs earned per graduate [R-PhD]') }
    if ($marks.Count -gt 0) { [void]$p.AppendLine(); [void]$p.AppendLine('Markers: ' + ($marks -join '; ') + '.') }
    if ($r.flags) { [void]$p.AppendLine(); [void]$p.AppendLine('_Partial data: ' + $r.flags + '._') }
    $text = Set-AutoBlock $text 'PRESTIGE' $p.ToString()

    $d = New-Object System.Text.StringBuilder
    [void]$d.AppendLine('**Difficulty Index for an international aid applicant: ' + (F1 $r.difficulty) + ' / 100, ' + (Get-DifficultyTier $r.difficulty) + '. #' + $r.difficulty_rank + ' hardest of ' + $n + '** [R-M].')
    [void]$d.AppendLine()
    [void]$d.AppendLine('| Component (weight) | Value | Points |')
    [void]$d.AppendLine('| --- | --- | --- |')
    [void]$d.AppendLine('| Admit rate (60%) | ' + $(if ($null -ne $r.admit_rate) { ($r.admit_rate).ToString('0.0', $inv) + '%, ' + $r.admit_rate_asof } else { 'not found' }) + ' [D1] | ' + (F0 $r.admit_pts) + ' |')
    [void]$d.AppendLine('| SAT midpoint (20%) | ' + (F0 $r.sat_mid) + $(if ($r.sat_asof) { ', ' + $r.sat_asof } else { '' }) + ' [D2] | ' + (F0 $r.sat_pts) + ' |')
    [void]$d.AppendLine('| Need policy for internationals (10%) | ' + $(if ($r.need_blind) { 'Need-blind' } else { $r.need_policy_intl }) + ' [D3] | ' + (F0 $r.need_pts) + ' |')
    [void]$d.AppendLine('| Aided international seats per class (10%) | ' + $(if ($null -ne $r.seats) { '~' + (F0 $r.seats) + ' (' + (F0 $r.intl_aided) + ' aided international undergraduates ÷ 4' + $(if ($r.seats_asof) { ', ' + $r.seats_asof } else { '' }) + ')' } else { 'not found' }) + ' [D4] | ' + (F0 $r.seat_pts) + ' |')
    $text = Set-AutoBlock $text 'DIFFICULTY' $d.ToString()

    $src = New-Object System.Text.StringBuilder
    [void]$src.AppendLine('### Index sources')
    [void]$src.AppendLine()
    [void]$src.AppendLine('- [R-M] ' + $fixedRefs['Method'] + ' Computed ' + $today + '.')
    [void]$src.AppendLine('- [R1] U.S. News Best Colleges 2027: ' + $(if ($r.usnews_source) { $r.usnews_source } else { 'not found' }))
    [void]$src.AppendLine('- [R2] Forbes America''s Top Colleges 2027: ' + $(if ($r.forbes_source) { $r.forbes_source } else { 'not found' }))
    [void]$src.AppendLine('- [R3] WSJ/College Pulse Best Colleges 2026: ' + $(if ($r.wsj_source) { $r.wsj_source } else { 'not found' }))
    [void]$src.AppendLine('- [R4] QS World University Rankings 2027: ' + $(if ($r.qs_source) { $r.qs_source } else { 'not found' }))
    [void]$src.AppendLine('- [R5] THE World University Rankings 2027: ' + $(if ($r.the_source) { $r.the_source } else { 'not found' }))
    [void]$src.AppendLine('- [R6] ShanghaiRanking ARWU 2026: ' + $(if ($r.arwu_source) { $r.arwu_source } else { 'not found' }))
    [void]$src.AppendLine('- [R7] Endowment, ' + $(if ($r.endowment_asof) { $r.endowment_asof } else { 'FY2025' }) + ': ' + $(if ($r.endowment_source) { $r.endowment_source } else { 'not found' }))
    [void]$src.AppendLine('- [R8] Total enrollment (CDS B1): ' + $(if ($r.enrollment_source) { $r.enrollment_source } else { 'not found' }))
    foreach ($k in @('IvyPlus', 'Carnegie', 'AAU', 'HPI', 'PhD')) { [void]$src.AppendLine('- [R-' + $k + '] ' + $fixedRefs[$k]) }
    [void]$src.AppendLine('- [D1] Admit rate: ' + $(if ($r.admit_rate_source) { $r.admit_rate_source } else { 'not found' }))
    [void]$src.AppendLine('- [D2] SAT range (CDS C9): ' + $(if ($r.sat_source) { $r.sat_source } else { 'not found' }))
    [void]$src.AppendLine('- [D3] Need policy for internationals: ' + $r.need_source + ' (verified 22 Nov 2026, ../us-full-need-schools-international.csv)')
    [void]$src.AppendLine('- [D4] International aid recipients (CDS H6): ' + $(if ($r.seats_source) { $r.seats_source } else { 'not found' }))
    $text = Set-AutoBlock $text 'RANKING-SOURCES' $src.ToString()

    [IO.File]::WriteAllText($path, $text, $utf8)
  }
}

Write-Output ('Schools: ' + $n + '; prestige computed: ' + @($rows | Where-Object { $null -ne $_.prestige }).Count + '; difficulty computed: ' + @($rows | Where-Object { $null -ne $_.difficulty }).Count + '; flagged: ' + @($flagged).Count)
