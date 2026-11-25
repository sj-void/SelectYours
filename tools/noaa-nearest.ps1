# For each school in core-locations.json, find the nearest NOAA 1991-2020 normals station that has
# both mean temperature and precipitation normals, then fetch its annual/seasonal values.
param([string]$In, [string]$Out)
$schools = Get-Content $In -Raw | ConvertFrom-Json
$need = 'ANN-TAVG-NORMAL','ANN-PRCP-NORMAL'
$rows = @()
foreach ($s in $schools) {
  $best = $null
  foreach ($d in 0.3, 0.6, 1.0) {
    $bbox = '{0},{1},{2},{3}' -f ($s.lat + $d), ($s.lon - $d), ($s.lat - $d), ($s.lon + $d)
    $url = "https://www.ncei.noaa.gov/access/services/search/v1/data?dataset=normals-annualseasonal-1991-2020&bbox=$bbox&limit=50"
    try { $r = Invoke-RestMethod -Uri $url -TimeoutSec 60 } catch { continue }
    foreach ($x in $r.results) {
      $types = @($x.dataTypes | ForEach-Object { $_.id })
      if (($need | Where-Object { $types -notcontains $_ }).Count -gt 0) { continue }
      $lon = $x.location.coordinates[0]; $lat = $x.location.coordinates[1]
      $km = 111.2 * [math]::Sqrt([math]::Pow($lat - $s.lat, 2) + [math]::Pow(($lon - $s.lon) * [math]::Cos($s.lat * [math]::PI / 180), 2))
      if (-not $best -or $km -lt $best.km) { $best = [pscustomobject]@{ id = $x.stations[0].id; name = $x.stations[0].name; km = [math]::Round($km, 1) } }
    }
    if ($best) { break }
  }
  if (-not $best) { $rows += [pscustomobject]@{ slug = $s.slug; id = $null }; continue }
  $durl = "https://www.ncei.noaa.gov/access/services/data/v1?dataset=normals-annualseasonal-1991-2020&stations=$($best.id)&format=json&dataTypes=ANN-TAVG-NORMAL,ANN-PRCP-NORMAL,ANN-SNOW-NORMAL,DJF-TMIN-NORMAL,JJA-TMAX-NORMAL"
  $v = (Invoke-RestMethod -Uri $durl -TimeoutSec 60)[0]
  $rows += [pscustomobject]@{ slug = $s.slug; id = $best.id; name = $best.name; km = $best.km
    tavg = $v.'ANN-TAVG-NORMAL'; prcp = $v.'ANN-PRCP-NORMAL'; snow = $v.'ANN-SNOW-NORMAL'; wlow = $v.'DJF-TMIN-NORMAL'; shigh = $v.'JJA-TMAX-NORMAL' }
}
$rows | ConvertTo-Json | Set-Content $Out -Encoding utf8
$rows | ForEach-Object { '{0} | {1} | {2} | {3} km | avg {4} | winter low {5} | summer high {6} | prcp {7} | snow {8}' -f $_.slug, $_.id, $_.name, $_.km, $_.tavg, $_.wlow, $_.shigh, $_.prcp, $_.snow }
