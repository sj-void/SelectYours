# Builds the site's logo and favicon images from the brand sources.
#   Source art : site-src/brand/selectyours-logo-source.png (1254x1254, opaque background)
#   Cutout mask: site-src/brand/selectyours.ico (256x256, transparent background)
# The .ico's alpha channel is scaled up and applied to the high-res PNG, so the
# result is sharp and has the same cutout as the .ico.
# Output (site-src/assets): logo-512.png, logo-96.png, favicon-32.png,
# apple-touch-icon.png, favicon.ico. Run, then rebuild the site.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\make-logo.ps1
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
Add-Type -AssemblyName System.Drawing
$brand  = Join-Path $Root 'site-src\brand'
$assets = Join-Path $Root 'site-src\assets'
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $brand 'selectyours-logo-source.png'))
$ico = New-Object System.Drawing.Icon (Join-Path $brand 'selectyours.ico'), 256, 256
$W = $src.Width; $H = $src.Height

# Upscale the icon to source size to get a high-res alpha mask.
$mask = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($mask)
$g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
$g.DrawImage($ico.ToBitmap(), 0, 0, $W, $H); $g.Dispose()

$out = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$ds = $src.LockBits($rect, 'ReadOnly', $fmt); $dm = $mask.LockBits($rect, 'ReadOnly', $fmt); $do = $out.LockBits($rect, 'WriteOnly', $fmt)
$n = $W * $H * 4
$bs = New-Object byte[] $n; $bm = New-Object byte[] $n
[Runtime.InteropServices.Marshal]::Copy($ds.Scan0, $bs, 0, $n)
[Runtime.InteropServices.Marshal]::Copy($dm.Scan0, $bm, 0, $n)
$minX = $W; $minY = $H; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $H; $y++) {
  $row = $y * $W * 4
  for ($x = 0; $x -lt $W; $x++) {
    $i = $row + $x * 4
    $a = $bm[$i + 3]
    if ($a -lt 12) { $a = 0 }
    $bs[$i + 3] = [byte]$a
    if ($a -gt 40) { if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }; if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y } }
  }
}
[Runtime.InteropServices.Marshal]::Copy($bs, 0, $do.Scan0, $n)
$src.UnlockBits($ds); $mask.UnlockBits($dm); $out.UnlockBits($do)

# Crop to the visible logo, centred in a square with a small margin.
$side = [Math]::Max($maxX - $minX, $maxY - $minY) * 1.04
$cx = ($minX + $maxX) / 2; $cy = ($minY + $maxY) / 2
$crop = New-Object System.Drawing.RectangleF ($cx - $side / 2), ($cy - $side / 2), $side, $side

function Save-Size($size, $file, $bg) {
  $b = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gr = [System.Drawing.Graphics]::FromImage($b)
  $gr.InterpolationMode = 'HighQualityBicubic'; $gr.PixelOffsetMode = 'HighQuality'; $gr.SmoothingMode = 'HighQuality'
  if ($bg) { $gr.Clear($bg) } else { $gr.Clear([System.Drawing.Color]::Transparent) }
  $pad = if ($bg) { [int]($size * 0.08) } else { 0 }
  $dst = New-Object System.Drawing.RectangleF $pad, $pad, ($size - 2 * $pad), ($size - 2 * $pad)
  $gr.DrawImage($out, $dst, $crop, [System.Drawing.GraphicsUnit]::Pixel); $gr.Dispose()
  $b.Save((Join-Path $assets $file), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
Save-Size 512 'logo-512.png' $null
Save-Size 96 'logo-96.png' $null
Save-Size 32 'favicon-32.png' $null
Save-Size 180 'apple-touch-icon.png' ([System.Drawing.Color]::FromArgb(255, 247, 244, 237))
Copy-Item (Join-Path $brand 'selectyours.ico') (Join-Path $assets 'favicon.ico') -Force
"Logo bbox in source: $minX,$minY - $maxX,$maxY; wrote images to $assets"
