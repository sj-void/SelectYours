param([string]$Majors, [string]$ProfileDir, [string[]]$Skip)
# Adds a "most common fields" bullet (IPEDS completions via College Scorecard) to section 7 of each profile,
# removes "most popular majors ... not published" phrases, and appends a numbered source.
$enc = New-Object System.Text.UTF8Encoding($false)
$data = Get-Content $Majors -Raw | ConvertFrom-Json
$repl = @(
  @('Majors, most popular majors and class sizes:', 'Majors and class sizes:'),
  @('Majors, most popular majors, class sizes:', 'Majors and class sizes:'),
  @('Majors, most popular majors and study abroad:', 'Majors and study abroad:'),
  @('Majors, most popular majors, ', 'Majors, '),
  @('Most popular majors and class sizes:', 'Class sizes:'),
  @('Most popular majors and STEM-designated majors:', 'STEM-designated majors:'),
  @('Most popular majors and study abroad:', 'Study abroad:'),
  @('Majors and most popular majors:', 'Number of majors:'),
  @('Number of majors and minors, popular majors and curriculum style: the CDS J section extracts unreliably, and no other official list was found', 'Number of majors and minors and curriculum style: Not published on the pages checked'),
  @('Number of majors and minors, popular majors and curriculum style:', 'Number of majors and minors and curriculum style:'),
  @('Minors and the most popular majors:', 'Minors:'),
  @('The total number of majors and the most popular majors weren''t published on the pages checked.', 'The total number of majors wasn''t published on the pages checked.')
)
$regex = @(
  @(' ?Most popular majors and minors: Not published on the pages checked (\([^)]*\))\.', ' Minors: Not published on the pages checked $1.'),
  @(' ?Most popular majors: Not published on the pages checked \([^)]*\)\.', ''),
  @(' ?Most popular majors: the CDS J1 (table doesn''t read cleanly|percentages don''t extract) from the PDF text,? and no other official list was found \([^)]*\)\.', ''),
  @(' ?Most popular majors \(CDS J\): not reliably extracted\.', '')
)
foreach ($p in $data.PSObject.Properties) {
  $slug = $p.Name; if ($Skip -contains $slug) { continue }
  $path = Join-Path $ProfileDir "$slug.md"
  $lines = [System.Collections.Generic.List[string]]([IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8))
  if (($lines -join "`n") -match 'Most common fields \(share of bachelor') { "skip (already): $slug"; continue }
  # next source number
  $srcIdx = -1; $max = 0; $inSrc = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^## Sources') { $inSrc = $true; continue }
    if ($inSrc -and $lines[$i] -match 'AUTO:') { break }
    if ($inSrc -and $lines[$i] -match '^(\d+)\. ') { $n = [int]$Matches[1]; if ($n -ge $max) { $max = $n }; $srcIdx = $i }
  }
  $num = $max + 1
  $fields = ($p.Value.top | ForEach-Object { "$($_.field) $($_.pct)%" }) -join ', '
  $bullet = "- **Most common fields (share of bachelor's degrees, IPEDS via College Scorecard):** $fields [$num]."
  $h = -1; $e = $lines.Count
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## 7\.') { $h = $i } elseif ($h -ge 0 -and $lines[$i] -match '^## ') { $e = $i; break } }
  if ($h -lt 0) { "NO SECTION 7: $slug"; continue }
  $done = $false
  for ($i = $h + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^- \*\*Most popular majors:\*\* Not published') { $lines[$i] = $bullet; $done = $true; break } }
  if (-not $done) {
    $first = -1; for ($i = $h + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^- ') { $first = $i; break } }
    # insert after the first bullet and its sub-bullets
    $at = $first + 1; while ($at -lt $e -and $lines[$at] -match '^\s+- ') { $at++ }
    $lines.Insert($at, $bullet); $e++; $srcIdx++
  }
  for ($i = $h + 1; $i -lt $e; $i++) {
    foreach ($r in $repl) { $lines[$i] = $lines[$i].Replace($r[0], $r[1]) }
    foreach ($r in $regex) { $lines[$i] = [regex]::Replace($lines[$i], $r[0], $r[1]) }
  }
  $src = "$num. Academics: program percentages (share of bachelor's degrees awarded by 2-digit CIP field). College Scorecard API, UNITID $($p.Value.id). U.S. Department of Education (IPEDS completions). https://api.data.gov/ed/collegescorecard/v1/schools?id=$($p.Value.id)&fields=latest.academics.program_percentage. Data: latest year published. Retrieved 2026-11-23."
  $lines.Insert($srcIdx + 1, $src)
  [IO.File]::WriteAllText($path, (($lines -join "`n") + "`n"), $enc)
  "ok $slug [$num]" + $(if ($done) { ' (replaced line)' } else { '' })
}
