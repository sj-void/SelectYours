<#
  Merges a patch file into docs/universities/<slug>.md.

  Patch format (UTF-8 markdown):
    ## <exact section heading as in the profile, e.g. "7. Academics" or "Quick facts">
    <new body: replaces the section's old body; AUTO blocks in the old body are kept>
    ...
    ## New sources
    S1. Title. Publisher. URL. Data: ... Checked YYYY-MM-DD.
    S2. ...

  In bodies, cite new sources as [S1], [S2]...; they are renumbered to follow the profile's last source.
  Existing citations like [3] are left untouched.

  Usage: .\tools\merge-profile-patch.ps1 -Slug williams-college -Patch <path>
#>
param([Parameter(Mandatory)][string]$Slug, [Parameter(Mandatory)][string]$Patch)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "docs\universities\$Slug.md"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) -replace "`r`n", "`n"
$patchText = [IO.File]::ReadAllText($Patch, [Text.Encoding]::UTF8) -replace "`r`n", "`n"

# --- existing max source number (lines like "12. " or "9b. " under ## Sources) ---
$srcIdx = $text.IndexOf("`n## Sources")
if ($srcIdx -lt 0) { throw "No ## Sources in $Slug" }
$srcPart = $text.Substring($srcIdx)
$nums = [regex]::Matches($srcPart, '(?m)^(\d+)[a-z]?\. ') | ForEach-Object { [int]$_.Groups[1].Value }
$max = ($nums | Measure-Object -Maximum).Maximum
if (-not $max) { $max = 0 }

# --- parse patch sections ---
$parts = [regex]::Split($patchText, '(?m)^## ')
$sections = [ordered]@{}
foreach ($p in $parts) {
  if (-not $p.Trim()) { continue }
  $nl = $p.IndexOf("`n"); if ($nl -lt 0) { $nl = $p.Length }
  $head = $p.Substring(0, $nl).Trim(); $body = if ($nl -lt $p.Length) { $p.Substring($nl + 1) } else { '' }
  $sections[$head] = $body.Trim("`n", "`r", " ") + "`n"
}
$map = @{}
$newSrc = @()
if ($sections.Contains('New sources')) {
  foreach ($line in ($sections['New sources'] -split "`n")) {
    if ($line -match '^S(\d+)\.\s+(.*)$') { $n = $max + [int]$matches[1]; $map["S$($matches[1])"] = $n; $newSrc += "$n. $($matches[2])" }
  }
  $sections.Remove('New sources')
}
function Fix-Cites([string]$s) { return [regex]::Replace($s, '\[S(\d+)\]', { param($m) '[' + $map["S$($m.Groups[1].Value)"] + ']' }) }

# --- optional "## Replace" section: blocks of  <<<\nold text\n===\nnew text\n>>>  (exact, first occurrence) ---
if ($sections.Contains('Replace')) {
  $blocks = [regex]::Matches($sections['Replace'], '(?s)<<<\n(.*?)\n===\n(.*?)\n>>>')
  foreach ($b in $blocks) {
    $old = $b.Groups[1].Value; $new = Fix-Cites $b.Groups[2].Value
    $i = $text.IndexOf($old)
    if ($i -lt 0) { Write-Warning "Replace target not found in ${Slug}: $($old.Substring(0, [Math]::Min(70, $old.Length)))"; continue }
    $text = $text.Substring(0, $i) + $new + $text.Substring($i + $old.Length)
  }
  $sections.Remove('Replace')
}

# --- replace each section body, preserving AUTO blocks ---
foreach ($head in $sections.Keys) {
  $hdr = "## $head`n"
  $start = $text.IndexOf("`n$hdr")
  if ($start -lt 0) { Write-Warning "Section not found in ${Slug}: $head"; continue }
  $bodyStart = $start + 1 + $hdr.Length
  $nextIdx = $text.IndexOf("`n## ", $bodyStart)
  if ($nextIdx -lt 0) { $nextIdx = $text.Length }
  $oldBody = $text.Substring($bodyStart, $nextIdx - $bodyStart)
  $autos = [regex]::Matches($oldBody, '(?s)<!-- AUTO:[A-Z-]+:START -->.*?<!-- AUTO:[A-Z-]+:END -->|<!--\s*AUTO:[A-Z-]+(?!:START|:END)[^>]*-->') | ForEach-Object { $_.Value }
  $newBody = "`n" + (Fix-Cites $sections[$head]).TrimEnd() + "`n"
  if ($autos) { $newBody += "`n" + ($autos -join "`n`n") + "`n" }
  $text = $text.Substring(0, $bodyStart) + $newBody + $text.Substring($nextIdx)
}

# --- append new sources after the last numbered source line ---
if ($newSrc.Count -gt 0) {
  $srcIdx = $text.IndexOf("`n## Sources")
  $last = [regex]::Matches($text.Substring($srcIdx), '(?m)^\d+[a-z]?\. .*$') | Select-Object -Last 1
  $insertAt = $srcIdx + $last.Index + $last.Length
  $text = $text.Substring(0, $insertAt) + "`n" + ($newSrc -join "`n") + $text.Substring($insertAt)
}
[IO.File]::WriteAllText($path, $text, $utf8)
"merged $($sections.Count) sections, $($newSrc.Count) new sources into $Slug (sources now end at $($max + $newSrc.Count))"
