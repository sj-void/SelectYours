<#
  Builds docs/universities/_data/<slug>.json from the College Scorecard baseline (_scorecard.json),
  then applies school-specific overrides.

  -Overrides takes a hashtable: @{ metric = @(value, 'as_of', 'source', 'note') }
  Example:
    .\tools\new-school-json.ps1 -Slug williams-college -Name 'Williams College' -Id 168342 -Overrides @{
      sat_25 = @(1490,'Fall 2025 (CDS 2025-26 C9, search index)','https://...') }
#>
param(
  [Parameter(Mandatory)] [string]$Slug,
  [Parameter(Mandatory)] [string]$Name,
  [Parameter(Mandatory)] [int]$Id,
  [hashtable]$Overrides = @{},
  [string[]]$Notes = @()
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $root 'docs\universities\_data'
$sc = [IO.File]::ReadAllText((Join-Path $dataDir '_scorecard.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$r = $sc.schools."$Id"
if (-not $r) { throw "UnitID $Id not in _scorecard.json" }
$src = "https://api.data.gov/ed/collegescorecard/v1/schools?id=$Id (College Scorecard; saved in _data/_scorecard.json)"
$asof = 'Fall 2024 (IPEDS 2024-25, via College Scorecard)'
function M($v, $a, $s, $n) { $o = [ordered]@{ value = $v; as_of = $a; source = $s }; if ($n) { $o.note = $n }; return [pscustomobject]$o }
function V($k) { $p = $r.PSObject.Properties[$k]; if ($p) { return $p.Value } else { return $null } }

$m = [ordered]@{}
$ar = V 'latest.admissions.admission_rate.overall'
$m.admit_rate = M $(if ($null -ne $ar) { [math]::Round($ar * 100, 2) } else { $null }) $asof $src 'percent'
$e25 = V 'latest.admissions.sat_scores.25th_percentile.critical_reading'; $e75 = V 'latest.admissions.sat_scores.75th_percentile.critical_reading'
$m25 = V 'latest.admissions.sat_scores.25th_percentile.math'; $m75 = V 'latest.admissions.sat_scores.75th_percentile.math'
if ($e25 -and $m25 -and $e75 -and $m75) {
  $m.sat_25 = M ($e25 + $m25) $asof $src "sum of section 25th percentiles (ERW $e25 + Math $m25); approximates the composite"
  $m.sat_75 = M ($e75 + $m75) $asof $src "sum of section 75th percentiles (ERW $e75 + Math $m75); approximates the composite"
} else { $m.sat_25 = M $null $asof $src 'not reported'; $m.sat_75 = M $null $asof $src 'not reported' }
$m.act_25 = M (V 'latest.admissions.act_scores.25th_percentile.cumulative') $asof $src $null
$m.act_75 = M (V 'latest.admissions.act_scores.75th_percentile.cumulative') $asof $src $null
$size = V 'latest.student.size'; $nra = V 'latest.student.demographics.race_ethnicity.non_resident_alien'
$m.total_undergrad = M $size 'Fall 2024 (IPEDS, degree-seeking undergraduates)' $src $null
if ($size -and $null -ne $nra) { $m.intl_undergrad_count = M ([math]::Round($size * $nra)) 'Fall 2024 (IPEDS)' $src ("our calculation: " + [math]::Round($nra * 100, 1) + "% U.S. Nonresident x undergraduates") }
$gs = V 'latest.student.grad_students'
if ($size) { $m.total_enrollment = M ($size + $(if ($gs) { $gs } else { 0 })) 'Fall 2024 (IPEDS: degree-seeking undergraduates + graduate students)' $src $null }
$ret = V 'latest.student.retention_rate.four_year.full_time'
$m.retention_rate = M $(if ($null -ne $ret) { [math]::Round($ret * 100, 1) } else { $null }) 'IPEDS, via College Scorecard' $src 'percent'
$g6 = V 'latest.completion.completion_rate_4yr_150nt'
$m.grad_rate_6yr = M $(if ($null -ne $g6) { [math]::Round($g6 * 100, 1) } else { $null }) 'IPEDS, via College Scorecard' $src 'percent'
$m.coa_scorecard = M (V 'latest.cost.attendance.academic_year') 'IPEDS, via College Scorecard (an earlier year than 2026-27)' $src $null

foreach ($k in $Overrides.Keys) {
  $a = $Overrides[$k]
  $m[$k] = M $a[0] $a[1] $a[2] $(if ($a.Count -gt 3) { $a[3] } else { $null })
}
$out = [ordered]@{ school = $Name; slug = $Slug; unitid = $Id; checked_on = (Get-Date).ToString('yyyy-MM-dd'); metrics = $m; notes = $Notes }
[IO.File]::WriteAllText((Join-Path $dataDir "$Slug.json"), ($out | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
"wrote $Slug.json"
