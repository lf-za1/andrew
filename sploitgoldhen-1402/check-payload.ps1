# Preflight for the payload the host will load.
# Mirrors the checks afterglow.js makes at runtime, so a mismatch shows up
# here instead of on the console, mid-chain, with a spent boot.
param(
  [string]$Root = $PSScriptRoot,
  [string]$File = "goldhen.bin",
  [string]$Mode = "goldhen",
  [string]$Firmware = "14.02"
)

$fail = 0
function Ok($m)   { Write-Host "  OK   $m" }
function Bad($m)  { Write-Host "  FAIL $m"; $script:fail++ }
function Warn($m) { Write-Host "  WARN $m" }

$path = Join-Path $Root $File
Write-Host "payload: $path"
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Bad "file missing"; exit 1 }

$bytes = [System.IO.File]::ReadAllBytes($path)
$len = $bytes.Length
$GH_COMPOSITE = 0x50000 + 636760          # afterglow.js GH.nlOff + GH.nlLen
Write-Host "size: $len bytes  (composite = $GH_COMPOSITE)"

if ($len -eq 0) { Bad "empty file -- loadPayload refuses" }
elseif ($len -eq $GH_COMPOSITE) {
  Ok "composite GoldHEN image -- patch chain path (loadGoldhen)"
  if ($Mode -ne "goldhen") { Warn "mode=$Mode will NOT take the composite path; use mode=goldhen" }
}
elseif ($bytes[0] -eq 0xE9) {
  Ok "leading 0xE9 (jmp) -- raw payload path (loadPayload)"
  $rel = [int]($bytes[1] -bor ($bytes[2] -shl 8) -bor ($bytes[3] -shl 16) -bor ($bytes[4] -shl 24))
  $target = 5 + $rel
  if ($target -lt 0 -or $target -ge $len) { Bad "jmp target 0x$($target.ToString('x')) outside the file" }
  else { Ok "jmp +0x$($rel.ToString('x')) -> 0x$($target.ToString('x')) (in range)" }
}
else {
  Bad ("first byte 0x{0:x2} is neither 0xE9 nor a {1}-byte composite -- loadEnabler refuses" -f $bytes[0], $GH_COMPOSITE)
}

if ($Mode -eq "golden") { Warn "mode 'golden' is not 'goldhen' -- you get the raw path with no patchset" }

# The patch set runs before the payload on the enabler path.
$ps = "patchset-" + $Firmware.Replace(".", "") + ".bin"
$ppath = Join-Path $Root $ps
Write-Host "patchset: $ppath"
if ($Mode -eq "goldhen") {
  if (-not (Test-Path -LiteralPath $ppath)) { Bad "missing $ps -- GoldHEN will not start without it" }
  else {
    $plen = (Get-Item -LiteralPath $ppath).Length
    if ($plen -gt (0x400 - 0xc0)) { Bad "$ps is $plen bytes, body area holds at most $((0x400 - 0xc0))" }
    else { Ok "$ps, $plen bytes, fits the body area" }
  }
} else {
  Warn "mode=$Mode skips the patch set entirely (correct only for payloads that patch themselves)"
}

# Offline cache: a stale entry serves the OLD bytes and the console looks broken.
$mpath = Join-Path $Root "cache.appcache"
if (Test-Path -LiteralPath $mpath) {
  $want = $null
  foreach ($line in (Get-Content -LiteralPath $mpath -Encoding UTF8)) {
    if ($line -match ("^" + [regex]::Escape($File) + "\s+#([0-9a-f]{32})")) { $want = $Matches[1]; break }
  }
  if (-not $want) { Warn "$File is not in cache.appcache -- first load hits the network, later loads still work" }
  else {
    $got = (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash.ToLower()
    if ($want -eq $got) { Ok "cache.appcache hash matches ($got)" }
    else { Bad "cache.appcache hash $want != file $got -- bump the manifest or the console keeps the old payload" }
  }
}

Write-Host ""
Write-Host ("sha256 " + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)
Write-Host ("sha1   " + (Get-FileHash -LiteralPath $path -Algorithm SHA1).Hash)
Write-Host ("url    " + "http://<ip-du-pc>:8000/jb.html?log=1&afterglow=run&mode=" + $Mode + "&payload=" + $File)
Write-Host ""
if ($fail -gt 0) { Write-Host "$fail check(s) failed -- fix before serving"; exit 1 }
Write-Host "all checks passed"
