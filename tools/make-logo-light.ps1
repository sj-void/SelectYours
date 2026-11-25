# Builds the light-theme logo variants from site-src/assets/logo-512.png.
# The orbit ring in the logo art is white, which vanishes on the light (cream) theme.
# This recolours only the ring pixels to a mid blue, keeping the building, the globe
# and its white rim untouched. Ring regions are hand-measured in 512px logo space.
# Output (site-src/assets): logo-512-light.png, logo-96-light.png. Run after make-logo.ps1.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\make-logo-light.ps1
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
Add-Type -AssemblyName System.Drawing
$assets = Join-Path $Root 'site-src\assets'
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $assets 'logo-512.png'))
$W = $src.Width; $H = $src.Height; $k = $W / 512.0

$ring = @(54, 108, 190)          # recolour target (R, G, B)
$gcx = 256 * $k; $gcy = 249 * $k # globe centre
$rimIn = 168 * $k; $rimOut = 186 * $k   # globe rim band (kept white)

function In-Ring([double]$x, [double]$y) {
  $x = $x / $k; $y = $y / $k
  # Left tail: the stroke that sweeps in front of the first column.
  # Above the top step (y < 396) and above its lower diagonal edge; ends at column 2.
  if ($x -ge 95 -and $x -le 209) {
    $top = 397 - ($x - 95) * (29.0 / 121)
    $bot = if ($x -lt 140) { 414 } else { [Math]::Min(395.5, 402 - ($x - 140) * (30.0 / 70) + 1) }
    if ($y -ge $top - 1 -and $y -le $bot) { return $true }
  }
  # Right segment crossing the globe from the entablature to the rim.
  if ($x -ge 366 -and $x -le 458 -and $y -ge 200 -and $y -le 312) {
    $mid = 289 - ($x - 380) * 0.75
    if ([Math]::Abs($y - $mid) -le 14) { return $true }
  }
  # Building block (steps, columns, entablature) is never ring.
  if ($x -ge 106 -and $x -le 408 -and $y -ge 390 -and $y -le 450) { return $false }
  if ($x -ge 140 -and $x -le 378 -and $y -ge 212 -and $y -le 392) { return $false }
  $d = [Math]::Sqrt([Math]::Pow($x - 256, 2) + [Math]::Pow($y - 249, 2))
  return ($d -gt 186)
}

$rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$bmp = $src.Clone($rect, $fmt); $src.Dispose()
$bd = $bmp.LockBits($rect, 'ReadWrite', $fmt)
$n = $W * $H * 4; $b = New-Object byte[] $n
[Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $b, 0, $n)
for ($y = 0; $y -lt $H; $y++) {
  for ($x = 0; $x -lt $W; $x++) {
    $i = ($y * $W + $x) * 4
    if ($b[$i + 3] -eq 0) { continue }
    if (-not (In-Ring $x $y)) { continue }
    $bl = $b[$i]; $gr = $b[$i + 1]; $rd = $b[$i + 2]
    $mn = [Math]::Min($rd, [Math]::Min($gr, $bl))
    $t = [Math]::Max(0.0, [Math]::Min(1.0, ($mn - 60) / 195.0))
    $b[$i + 2] = [byte]($rd * (1 - $t) + $ring[0] * $t)
    $b[$i + 1] = [byte]($gr * (1 - $t) + $ring[1] * $t)
    $b[$i]     = [byte]($bl * (1 - $t) + $ring[2] * $t)
  }
}
[Runtime.InteropServices.Marshal]::Copy($b, 0, $bd.Scan0, $n)
$bmp.UnlockBits($bd)
$bmp.Save((Join-Path $assets 'logo-512-light.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$s = New-Object System.Drawing.Bitmap 96, 96, $fmt
$g = [System.Drawing.Graphics]::FromImage($s)
$g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.SmoothingMode = 'HighQuality'
$g.Clear([System.Drawing.Color]::Transparent); $g.DrawImage($bmp, 0, 0, 96, 96); $g.Dispose()
$s.Save((Join-Path $assets 'logo-96-light.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$s.Dispose(); $bmp.Dispose()
"Wrote logo-512-light.png and logo-96-light.png to $assets"
