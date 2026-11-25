# Builds a merge patch per school that adds a NOAA climate bullet to section 10 and removes "climate: not found" phrases.
param([string[]]$ClimateFiles, [string]$PatchDir, [string]$ProfileDir, [string[]]$Skip)
$enc = New-Object System.Text.UTF8Encoding($true)
function Title([string]$n) { $n = ($n -replace ',\s*([A-Z]{2})\s+US$', ', $1').Trim(); $parts = $n -split ', '; $ti = (Get-Culture).TextInfo; ($ti.ToTitleCase($parts[0].ToLower()) -replace '\bAp\b','Airport' -replace '\bIntl\b','International' -replace '\bRgnl\b','Regional' -replace '\bMuni\b','Municipal') + ', ' + $parts[1] }
function Num([string]$v) { if ($null -eq $v) { return $null }; $t = $v.Trim(); if ($t -eq '') { return $null }; return $t }
$clean = @(
  @('Climate and nearest airport: Not found\.', 'Nearest airport: Not found.'),
  @('Climate and the nearest airport: Not found\.', 'Nearest airport: Not found.'),
  @('Climate and airport: Not found\.', 'Nearest airport: Not found.'),
  @('Climate \(NOAA normals\) and nearest airport: Not found\.', 'Nearest airport: Not found.'),
  @('Climate \(NOAA normals\) and airport distance: Not found\.', 'Airport distance: Not found.'),
  @('Climate normals and transport: Not', 'Transport: Not'),
  @('Climate and transport: Not', 'Transport: Not'),
  @('Climate and nearest city: Not found\.', 'Nearest city: Not found.'),
  @('\s*Climate normals: Not (found|retrieved)\.', ''),
  @('\s*Climate: Not retrieved\.', ''),
  @('^- \*\*Location and climate:\*\*', '- **Location:**')
)
foreach ($cf in $ClimateFiles) {
  foreach ($c in (Get-Content $cf -Raw | ConvertFrom-Json)) {
    if ($Skip -contains $c.slug -or -not $c.id) { continue }
    $path = Join-Path $ProfileDir "$($c.slug).md"
    $lines = [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)
    $h = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match '^## 10\.' })
    $e = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match '^## 11\.' })
    $loc = $null
    for ($i = $h + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^- \*\*(Location|Setting)') { $loc = $lines[$i]; break } }
    $snow = Num $c.snow
    $bullet = "- **Climate:** NOAA 1991–2020 normals at $(Title $c.name), $($c.km) km from campus: average temperature $(Num $c.tavg)°F over the year; winter (Dec–Feb) average low $(Num $c.wlow)°F; summer (Jun–Aug) average high $(Num $c.shigh)°F; $(Num $c.prcp) inches of precipitation a year" + $(if ($snow) { ", including $snow inches of snowfall" } else { ' (this station has no snowfall normal)' }) + ' [S1].'
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine('## Replace')
    if ($loc) {
      $new = $loc; foreach ($p in $clean) { $new = [regex]::Replace($new, $p[0], $p[1]) }
      [void]$sb.AppendLine('<<<'); [void]$sb.AppendLine($loc); [void]$sb.AppendLine('==='); [void]$sb.AppendLine($new); [void]$sb.AppendLine($bullet); [void]$sb.AppendLine('>>>')
    } else {
      $anchor = $null; for ($i = $h + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^- ') { $anchor = $lines[$i]; break } }
      [void]$sb.AppendLine('<<<'); [void]$sb.AppendLine($anchor); [void]$sb.AppendLine('==='); [void]$sb.AppendLine($anchor); [void]$sb.AppendLine($bullet); [void]$sb.AppendLine('>>>')
    }
    for ($i = $h + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^- \*\*Annual Security Report and climate:\*\*') { [void]$sb.AppendLine('<<<'); [void]$sb.AppendLine('- **Annual Security Report and climate:**'); [void]$sb.AppendLine('==='); [void]$sb.AppendLine('- **Annual Security Report:**'); [void]$sb.AppendLine('>>>') } }
    [void]$sb.AppendLine(''); [void]$sb.AppendLine('## New sources')
    [void]$sb.AppendLine("S1. U.S. Climate Normals 1991–2020, station $($c.id) ($($c.name)). NOAA National Centers for Environmental Information. https://www.ncei.noaa.gov/access/services/data/v1?dataset=normals-annualseasonal-1991-2020&stations=$($c.id)&format=json. Data: 1991–2020 normals; the station is the nearest one with temperature and precipitation normals to the campus coordinates in College Scorecard. Checked 2026-11-23.")
    [IO.File]::WriteAllText((Join-Path $PatchDir "$($c.slug)-climate.md"), $sb.ToString(), $enc)
    "$($c.slug): " + $(if ($loc) { 'after location line' } else { 'after section header' })
  }
}
