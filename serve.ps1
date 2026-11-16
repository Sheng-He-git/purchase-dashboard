# serve.ps1 - minimal static file server for the dashboard (no Python required)
# Started by start-dashboard.bat. Serves the current folder on http://localhost:8765
# so the page is allowed to read the Excel files next to index.html.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Port 8765

param(
  [int]$Port = 8765,
  [string]$Root = ""
)

$ErrorActionPreference = "Stop"

if (-not $Root -or $Root.Trim() -eq "") {
  $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".htm"  = "text/html; charset=utf-8"
  ".js"   = "application/javascript; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".csv"  = "text/csv; charset=utf-8"
  ".txt"  = "text/plain; charset=utf-8"
  ".xlsx" = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  ".xls"  = "application/vnd.ms-excel"
  ".xlsm" = "application/vnd.ms-excel.sheet.macroEnabled.12"
  ".pptx" = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  ".png"  = "image/png"
  ".jpg"  = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".gif"  = "image/gif"
  ".svg"  = "image/svg+xml"
  ".ico"  = "image/x-icon"
  ".woff" = "font/woff"
  ".woff2" = "font/woff2"
}

try {
  $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
  $listener.Start()
} catch {
  Write-Host ""
  Write-Host "[ERROR] Cannot listen on port $Port (probably already in use)." -ForegroundColor Red
  Write-Host "        Close the other server window and run start-dashboard.bat again." -ForegroundColor Red
  Write-Host "        To use another port, edit 8765 in start-dashboard.bat AND in this file." -ForegroundColor Red
  Write-Host ""
  exit 1
}

Write-Host "------------------------------------------"
Write-Host " Engine : PowerShell (built in, no Python)"
Write-Host " Folder : $Root"
Write-Host " URL    : http://localhost:$Port/index.html"
Write-Host "------------------------------------------"
Write-Host " Keep this window open. Close it to stop."
Write-Host ""

while ($true) {
  $client = $listener.AcceptTcpClient()
  $stream = $null
  try {
    $client.ReceiveTimeout = 4000
    $stream = $client.GetStream()

    # read request headers (until blank line)
    $buffer = New-Object byte[] 8192
    $sb = New-Object System.Text.StringBuilder
    while ($true) {
      $n = $stream.Read($buffer, 0, $buffer.Length)
      if ($n -le 0) { break }
      [void]$sb.Append([System.Text.Encoding]::ASCII.GetString($buffer, 0, $n))
      if ($sb.ToString().Contains("`r`n`r`n")) { break }
      if ($sb.Length -gt 65536) { break }
    }

    $req = $sb.ToString()
    if ($req.Length -gt 0) {
      $parts = ($req -split "`r`n")[0] -split ' '
      $method = $parts[0]
      $target = ""
      if ($parts.Length -gt 1) { $target = $parts[1] }

      if ($target -ne "") {
        if ($target -like "http*") { $target = ([System.Uri]$target).AbsolutePath }
        $target = ($target -split '\?')[0]
        $target = [System.Uri]::UnescapeDataString($target)
        if ($target -eq "" -or $target -eq "/") { $target = "/index.html" }

        $rel = ($target.TrimStart('/') -replace '/', '\')
        $full = [System.IO.Path]::GetFullPath((Join-Path $Root $rel))

        if (Test-Path -LiteralPath $full -PathType Container) {
          $full = [System.IO.Path]::GetFullPath((Join-Path $full "index.html"))
        }

        $inside = $full.StartsWith($Root + "\", [System.StringComparison]::OrdinalIgnoreCase) -or
                  ($full -eq $Root)

        if (-not $inside) {
          $body = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
          $head = "HTTP/1.1 403 Forbidden`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
        } elseif (Test-Path -LiteralPath $full -PathType Leaf) {
          $ext = [System.IO.Path]::GetExtension($full).ToLower()
          $ctype = $mime[$ext]
          if (-not $ctype) { $ctype = "application/octet-stream" }
          $body = [System.IO.File]::ReadAllBytes($full)
          $head = "HTTP/1.1 200 OK`r`nContent-Type: $ctype`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
          Write-Host ("{0}  200  {1}  ({2} bytes)" -f (Get-Date -Format "HH:mm:ss"), $target, $body.Length)
        } else {
          $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $target")
          $head = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
          Write-Host ("{0}  404  {1}" -f (Get-Date -Format "HH:mm:ss"), $target) -ForegroundColor Yellow
        }

        $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
        $stream.Write($hb, 0, $hb.Length)
        if ($method -ne "HEAD") { $stream.Write($body, 0, $body.Length) }
        $stream.Flush()
      }
    }
  } catch {
    # empty / aborted connection (browser preconnect): ignore and keep serving
  } finally {
    if ($stream) { try { $stream.Dispose() } catch {} }
    try { $client.Close() } catch {}
  }
}
