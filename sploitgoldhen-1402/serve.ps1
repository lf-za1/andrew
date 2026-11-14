# Static server for the mirrored host. Default port 8000.
param([int]$Port = 8000)

$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener

# Wildcard prefixes need an URL ACL. Try the LAN bind first, fall back to
# loopback so the script still runs un-elevated -- the console needs the LAN
# one, so a loopback fallback is a warning, not a success.
$listener.Prefixes.Add("http://+:$Port/")
try {
  $listener.Start()
  Write-Host "serving $root on http://0.0.0.0:$Port/ (ctrl-c to stop)"
} catch {
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add("http://localhost:$Port/")
  $listener.Start()
  Write-Host "LAN bind denied -- loopback only."
  Write-Host "run elevated, or: netsh http add urlacl url=http://+:$Port/ user=Everyone"
  Write-Host "serving $root on http://localhost:$Port/ (ctrl-c to stop)"
}

$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.png'  = 'image/png'
  '.bin'  = 'application/octet-stream'
  '.appcache' = 'text/cache-manifest'
  '.md'   = 'text/plain; charset=utf-8'
}

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
  } catch { break }

  $req = $ctx.Request
  $res = $ctx.Response
  $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)

  if ($path -eq '/' -or $path -eq '') { $path = '/index.html' }
  if ($path -eq '/jb') { $path = '/jb.html' }

  $full = Join-Path $root ($path.TrimStart('/') -replace '/', '\')

  if (Test-Path -LiteralPath $full -PathType Leaf) {
    $bytes = [System.IO.File]::ReadAllBytes($full)
    $ext = [System.IO.Path]::GetExtension($full)
    $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
    $res.Headers.Add('Cache-Control', 'no-store')
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
  } else {
    $res.StatusCode = 404
    $body = [Text.Encoding]::UTF8.GetBytes('404')
    $res.ContentLength64 = $body.Length
    $res.OutputStream.Write($body, 0, $body.Length)
  }

  $res.OutputStream.Close()
}
