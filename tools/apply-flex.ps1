param([string]$Findings, [string]$ProfileDir)
# Flexible applier: fills the category part of a "Not published on the pages checked" gap (bullet or inline),
# keeping any other items of a combined label marked as not published.
$enc = New-Object System.Text.UTF8Encoding($false)
$cat = @{
  mentor   = @{ match='(?i)mentor';                  remove='(?i)(,\s*)?\bmentor(ing|\s*program(me)?s)?\b(\s*(and|,))?';          name='Mentor programs' }
  alumni   = @{ match='(?i)alumn';                   remove='(?i)notable alumn(i|ae)';                                              name='Notable alumni' }
  abroad   = @{ match='(?i)study.abroad';            remove='(?i)study(-| )abroad( participation)?\s*(,|and)?\s*';                  name='Study abroad and research' }
  advising = @{ match='(?i)pre-health|advising';     remove='(?i)(pre-health(\s*and)?(,)?\s*)|(^advising details$)';               name='Pre-health advising' }
  airport  = @{ match='(?i)airport';                 remove='(?i)(;|,|\s+and)?\s*(the\s+)?nearest airport( and distance)?';         name='Nearest airport' }
}
function Tidy([string]$s) { $s = ($s -replace '\s+', ' ' -replace '\(\s*,\s*', '(' -replace ',\s*\)', ')' -replace '^\s*(and|,)\s*', '' -replace '\s*(,|and)\s*$', '' -replace ',\s*,', ',').Trim(' ', ',', ';'); if ($s -match ', ' -and $s -notmatch ' and ' ) { $i = $s.LastIndexOf(', '); $s = $s.Substring(0,$i) + ' and ' + $s.Substring($i+2) }; if ($s) { $s = $s.Substring(0,1).ToUpper() + $s.Substring(1) }; return $s }
$rows = Get-Content $Findings -Encoding UTF8 | Where-Object { $_ -match '^[a-z-]+ \| ' } | ForEach-Object { $p = $_ -split ' \| ', 4; [pscustomobject]@{ slug=$p[0].Trim(); cat=$p[1].Trim(); text=$p[2].Trim().TrimEnd('.'); src=$p[3].Trim() } } | Where-Object { $cat.ContainsKey($_.cat) }
foreach ($g in ($rows | Group-Object slug)) {
  $path = Join-Path $ProfileDir "$($g.Name).md"
  $L = [System.Collections.Generic.List[string]]([IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8))
  $max = 0; $si = -1; $in = $false
  for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i] -match '^## Sources') { $in = $true; continue }; if ($in -and $L[$i] -match 'AUTO:') { break }; if ($in -and $L[$i] -match '^(\d+)\. ') { $n=[int]$Matches[1]; if ($n -ge $max) { $max = $n }; $si = $i } }
  $new = @()
  foreach ($f in $g.Group) {
    $c = $cat[$f.cat]; $done = $false
    for ($i = 0; $i -lt $L.Count -and -not $done; $i++) {
      if ($L[$i] -notmatch 'Not published on the (official )?pages checked') { continue }
      $num = $max + 1 + $new.Count; $T = "$($f.text) [$num]."
      $mb = [regex]::Match($L[$i], '^(?<ind>\s*)- \*\*(?<lab>[^*]+?):\*\* Not published on the (?:official )?pages checked(?<d> \([^)]*\))?\.(?<rest>.*)$')
      if ($mb.Success -and $mb.Groups['lab'].Value -match $c.match) {
        $lab = $mb.Groups['lab'].Value; $rem = Tidy ([regex]::Replace($lab, $c.remove, ''))
        if (-not $rem -or $rem -match '^(Practicalities|Notable)$') { $L[$i] = "$($mb.Groups['ind'].Value)- **$lab`:** $T$($mb.Groups['rest'].Value)" }
        else { $L[$i] = "$($mb.Groups['ind'].Value)- **$($c.name):** $T"; $L.Insert($i + 1, "$($mb.Groups['ind'].Value)- **$rem`:** Not published on the pages checked$($mb.Groups['d'].Value).$($mb.Groups['rest'].Value)"); if ($si -gt $i) { $si++ } }
        $done = $true; break
      }
      foreach ($m in [regex]::Matches($L[$i], '(?<lab>[A-Z][^.:\[\]*]*?): Not published on the (?:official )?pages checked(?<d> \([^)]*\))?\.')) {
        $lab = $m.Groups['lab'].Value; if ($lab -notmatch $c.match) { continue }
        $rem = Tidy ([regex]::Replace($lab, $c.remove, ''))
        $rep = if (-not $rem -or $rem -match '^(Practicalities|Notable)$') { "$lab`: $T" } else { "$($c.name): $T $rem`: Not published on the pages checked$($m.Groups['d'].Value)." }
        $L[$i] = $L[$i].Substring(0, $m.Index) + $rep + $L[$i].Substring($m.Index + $m.Length); $done = $true; break
      }
    }
    if (-not $done) { "SKIP $($f.slug) $($f.cat)"; continue }
    $new += "$($max + 1 + $new.Count). $($f.src) (as given in a search summary). Checked 2026-11-23."
    "ok $($f.slug) $($f.cat)"
  }
  for ($k = 0; $k -lt $new.Count; $k++) { $L.Insert($si + 1 + $k, $new[$k]) }
  if ($new.Count) { [IO.File]::WriteAllText($path, (($L -join "`n") + "`n"), $enc) }
}
