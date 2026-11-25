param([string]$Findings, [string]$ProfileDir)
# Generic applier for categories insurance, founding, guarantee, work, majors.
$enc = New-Object System.Text.UTF8Encoding($false)
$re = @{ insurance='(?i)insurance'; founding='(?i)found|campus size'; guarantee='(?i)housing guarantee'; work='(?i)\bOPT\b|\bCPT\b|work rules'; majors='(?i)majors' }
$rows = Get-Content $Findings -Encoding UTF8 | Where-Object { $_ -match '^[a-z-]+ \| ' } | ForEach-Object { $p = $_ -split ' \| ', 4; [pscustomobject]@{ slug=$p[0].Trim(); cat=$p[1].Trim(); text=$p[2].Trim().TrimEnd('.'); src=$p[3].Trim() } } | Where-Object { $re.ContainsKey($_.cat) }
foreach ($g in ($rows | Group-Object slug)) {
  $path = Join-Path $ProfileDir "$($g.Name).md"
  $L = [System.Collections.Generic.List[string]]([IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8))
  $max = 0; $si = -1; $in = $false
  for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i] -match '^## Sources') { $in = $true; continue }; if ($in -and $L[$i] -match 'AUTO:') { break }; if ($in -and $L[$i] -match '^(\d+)\. ') { $n=[int]$Matches[1]; if ($n -ge $max) { $max = $n }; $si = $i } }
  $new = @()
  foreach ($f in $g.Group) {
    $idx = -1; $m = $null
    for ($i = 0; $i -lt $L.Count; $i++) {
      $mm = [regex]::Match($L[$i], '^(?<ind>\s*)- \*\*(?<lab>[^*]+?):\*\* Not published on the pages checked (?<d>\([^)]*\))\.(?<rest>.*)$')
      if ($mm.Success -and $mm.Groups['lab'].Value -match $re[$f.cat]) { $idx = $i; $m = $mm; break }
    }
    if ($idx -lt 0) { "SKIP $($f.slug) $($f.cat)"; continue }
    $num = $max + 1 + $new.Count; $ind = $m.Groups['ind'].Value; $lab = $m.Groups['lab'].Value; $d = $m.Groups['d'].Value; $rest = $m.Groups['rest'].Value
    $extra = $null
    switch ($f.cat) {
      'insurance' { $lab = 'Insurance' }
      'majors' {
        if ($lab -imatch 'class sizes') { $extra = "$ind- **Class sizes:** Not published on the pages checked $d." }
        if ($lab -imatch 'study abroad') { $extra = "$ind- **Study abroad:** Not published on the pages checked $d." }
        if ($lab -imatch 'curriculum') { $extra = "$ind- **Curriculum style and class sizes:** Not published on the pages checked $d." }
        $lab = 'Majors' }
      'guarantee' { if ($lab -imatch 'Annual Security Report') { $extra = "$ind- **Annual Security Report:** Not published on the pages checked $d." }; $lab = 'Housing guarantee' }
    }
    $L[$idx] = "$ind- **$lab`:** $($f.text) [$num].$rest"
    if ($extra) { $L.Insert($idx + 1, $extra); if ($si -gt $idx) { $si++ } }
    $new += "$num. $($f.src) (as given in a search summary). Checked 2026-11-23."
    "ok $($f.slug) $($f.cat) [$num]"
  }
  for ($k = 0; $k -lt $new.Count; $k++) { $L.Insert($si + 1 + $k, $new[$k]) }
  if ($new.Count) { [IO.File]::WriteAllText($path, (($L -join "`n") + "`n"), $enc) }
}
