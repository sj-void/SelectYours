param([string]$Findings, [string]$ProfileDir, [switch]$DryRun)
# Applies "slug | category | text | source" findings to the matching "Not published on the pages checked" gap line.
$enc = New-Object System.Text.UTF8Encoding($false)
$NP = 'Not published on the (?:official )?pages checked'
function Cap([string]$s) { if (-not $s) { return $s }; $s = $s.Trim(' ', ',', ';'); return $s.Substring(0,1).ToUpper() + $s.Substring(1) }
function TidyLabel([string]$l) { $l = $l.Trim(' ', ',', ';'); if ($l -match ', ' -and $l -notmatch ' and ') { $i = $l.LastIndexOf(', '); $l = $l.Substring(0,$i) + ' and ' + $l.Substring($i+2) }; return (Cap $l) }
$rows = Get-Content $Findings -Encoding UTF8 | Where-Object { $_ -match '^[a-z-]+ \| ' } | ForEach-Object { $p = $_ -split ' \| ', 4; [pscustomobject]@{ slug=$p[0].Trim(); cat=$p[1].Trim(); text=$p[2].Trim().TrimEnd('.'); src=$p[3].Trim() } }
foreach ($g in ($rows | Group-Object slug)) {
  $path = Join-Path $ProfileDir "$($g.Name).md"
  $lines = [System.Collections.Generic.List[string]]([IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8))
  # source numbering
  $max = 0; $srcIdx = -1; $inSrc = $false
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## Sources') { $inSrc = $true; continue }; if ($inSrc -and $lines[$i] -match 'AUTO:') { break }; if ($inSrc -and $lines[$i] -match '^(\d+)\. ') { $n=[int]$Matches[1]; if ($n -ge $max) { $max = $n }; $srcIdx = $i } }
  $newSrc = @()
  foreach ($f in $g.Group) {
    $catRe = switch ($f.cat) { 'airport' { '(?i)airport|Transport:|Nearest city:' } 'health' { '(?i)counsel|disab' } 'housing' { '(?i)housing|practicalit|break' } 'alumni' { '(?i)alumn' } }
    $idx = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $NP -and $lines[$i] -match $catRe) { $idx = $i; break } }
    if ($idx -lt 0) { "SKIP no gap line: $($f.slug) $($f.cat)"; continue }
    $num = $max + 1 + $newSrc.Count; $T = "$($f.text) [$num]."
    $line = $lines[$idx]; $insert = $null; $done = $false
    $mB = [regex]::Match($line, "^(?<ind>\s*)- \*\*(?<lab>[^*]+?):\*\* $NP (?<d>\([^)]*\))\.(?<rest>.*)$")
    if ($mB.Success) {
      $ind=$mB.Groups['ind'].Value; $lab=$mB.Groups['lab'].Value; $d=$mB.Groups['d'].Value; $rest=$mB.Groups['rest'].Value
      switch ($f.cat) {
        'alumni' { $line = "$ind- **$lab`:** $T$rest"; $done = $true }
        'airport' {
          if ($lab -imatch '^(nearest airport|airport distance|transport)$') { $line = "$ind- **$lab`:** $T$rest" }
          else { $nl = TidyLabel ($lab -ireplace '(,|;| and)\s*(the )?nearest airport( and distance)?\s*$', ''); $line = "$ind- **$nl`:** Not published on the pages checked $d.$rest"; $insert = "$ind- **Nearest airport:** $T" }
          $done = $true }
        'health' {
          if ($lab -imatch '^Insurance, counseling') { $line = "$ind- **Insurance:** Not published on the pages checked $d.$rest"; $insert = "$ind- **Counseling and disability services:** $T" }
          else { $line = "$ind- **$lab`:** $T$rest" }
          $done = $true }
        'housing' {
          $hasG = $f.text -match '(?i)guarantee|must live|required to live|live on campus|consecutive'
          if ($lab -imatch 'Annual Security Report') {
            $nl = if ($hasG) { 'Annual Security Report' } else { ($lab -ireplace ',\s*break housing', '') }
            $line = "$ind- **$nl`:** Not published on the pages checked $d.$rest"; $insert = "$ind- **Housing:** $T"
          } elseif ($lab -imatch 'break housing') {
            $nl = $lab -ireplace '\(break housing,\s*', '(' -ireplace '(,| and)\s*break housing', '' -ireplace 'break housing(,| and)\s*', ''
            $line = "$ind- **$(TidyLabel $nl)`:** Not published on the pages checked $d.$rest"; $insert = "$ind- **Break housing:** $T"
          } else { $insert = "$ind- **Break housing:** $T" }
          $done = $true }
      }
    }
    if (-not $done) {
      # inline clause "Label: Not published on the pages checked (d)."
      $mI = [regex]::Match($line, "(?<lab>[A-Z][^.:\[\]*]*?): $NP(?<d> \([^)]*\))?\.")
      $found = $false
      foreach ($m in [regex]::Matches($line, "(?<lab>[A-Z][^.:\[\]*]*?): $NP(?<d> \([^)]*\))?\.")) { if ($m.Groups['lab'].Value -match $catRe) { $mI = $m; $found = $true; break } }
      if (-not $found) { "SKIP no clause: $($f.slug) $($f.cat) :: $($line.Substring(0,[Math]::Min(120,$line.Length)))"; continue }
      $lab = $mI.Groups['lab'].Value; $d = $mI.Groups['d'].Value; $rep = $null
      switch ($f.cat) {
        'alumni' { $rep = "$lab`: $T" }
        'health' { $rep = "$lab`: $T" }
        'airport' {
          if ($lab -imatch '^(nearest airport( and (distance|transport))?|airport distance|distance to the nearest airport|transport|nearest city)$') { $rep = "$lab`: $T" }
          else { $nl = TidyLabel ($lab -ireplace '(,|;| and)\s*(the )?nearest airport( and distance)?\s*$', ''); $rep = "$nl`: Not published on the pages checked$d. Nearest airport: $T" } }
        'housing' {
          if ($lab -imatch 'break housing') {
            $nl = ($lab -ireplace 'break housing(,| and)\s*', '' -ireplace '(,| and)\s*break housing', '').Trim()
            if ($nl -and $nl -ine 'break housing') { $rep = "Break housing: $T $(TidyLabel $nl): Not published on the pages checked$d." } else { $rep = "Break housing: $T" }
          } else { $rep = "$lab`: Not published on the pages checked$d. Break housing: $T" } }
      }
      $line = $line.Substring(0, $mI.Index) + $rep + $line.Substring($mI.Index + $mI.Length)
    }
    $lines[$idx] = $line
    if ($insert) { $lines.Insert($idx + 1, $insert); if ($srcIdx -gt $idx) { $srcIdx++ } }
    $newSrc += "$num. $($f.src) (as given in a search summary). Checked 2026-11-23."
    "ok $($f.slug) $($f.cat) [$num]"
  }
  if ($newSrc.Count -gt 0) {
    for ($k = 0; $k -lt $newSrc.Count; $k++) { $lines.Insert($srcIdx + 1 + $k, $newSrc[$k]) }
    if (-not $DryRun) { [IO.File]::WriteAllText($path, (($lines -join "`n") + "`n"), $enc) }
  }
}
