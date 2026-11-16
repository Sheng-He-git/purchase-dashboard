@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Invoice Dashboard - local server

rem ============================================================
rem  Invoice Dashboard - single-file launcher + local server.
rem  No Python, no extra files needed except index.html.
rem
rem  Only ONE thing to change: the port number below.
rem  If it says "port already in use", try 8770 / 8800 / 8899.
rem ============================================================
set "PORT=8765"

echo ==========================================
echo  Invoice Dashboard - local server
echo ==========================================
echo  Folder : %cd%
echo  URL    : http://localhost:%PORT%/index.html
echo.
echo  Keep this window open while using the
echo  dashboard; close it to stop the server.
echo.

set "DP_PORT=%PORT%"
set "DP_ROOT=%~dp0"

start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 2; Start-Process 'http://localhost:%PORT%/index.html'"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0';$t=Get-Content -LiteralPath $p -Raw -Encoding UTF8; $m='#>>'+'>PS'; $i=$t.IndexOf($m); if($i -lt 0){ Write-Host '[ERROR] self-extract failed' -ForegroundColor Red; exit 1 }; Invoke-Expression $t.Substring($i)"

if errorlevel 1 goto :failed
goto :end

:failed
echo.
echo [WARN] The local server could not start.
echo        Reason is usually: port %PORT% is already used by another program.
echo        Fix: open this file, change  set "PORT=%PORT%"  to 8770 or 8800, save, run again.
echo        Alternative: just double-click index.html - the dashboard will
echo        reload the files you picked last time (no need to pick again).
echo.
pause
goto :end

:end
exit /b


#>>>PS
# ============================================================
#  Embedded static server (PowerShell, part of this .bat file).
#  Everything below this line is PowerShell code; cmd never runs
#  it because of the "exit /b" above.
# ============================================================
$ErrorActionPreference = "Stop"

$Port = 8765
if ($env:DP_PORT) {
  $tmpPort = 0
  if ([int]::TryParse($env:DP_PORT, [ref]$tmpPort) -and $tmpPort -gt 0) { $Port = $tmpPort }
}

$Root = ""
if ($env:DP_ROOT) { $Root = $env:DP_ROOT }
if (-not $Root -or $Root.Trim() -eq "") { $Root = (Get-Location).Path }
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
  Write-Host "        Close the other server window and run this file again." -ForegroundColor Red
  Write-Host "        To use another port, open this file and change  set `"PORT=$Port`"" -ForegroundColor Red
  Write-Host "        to a free number such as 8770, 8800 or 8899." -ForegroundColor Red
  Write-Host ""
  exit 1
}

Write-Host "------------------------------------------"
Write-Host " Serving : $Root"
Write-Host " URL     : http://localhost:$Port/index.html"
Write-Host "------------------------------------------"
Write-Host " Requests are logged below. Ctrl+C to stop."
Write-Host ""

while ($true) {
  $client = $listener.AcceptTcpClient()
  $stream = $null
  try {
    $client.ReceiveTimeout = 4000
    $stream = $client.GetStream()

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

        $query = ""
        $qi = $target.IndexOf("?")
        if ($qi -ge 0) {
          $query = $target.Substring($qi + 1)
          $target = $target.Substring(0, $qi)
        }
        $target = [System.Uri]::UnescapeDataString($target)

        $isList = ($target -eq "/__list")
        $full = $null
        $inside = $false

        if (-not $isList) {
          if ($target -eq "" -or $target -eq "/") { $target = "/index.html" }
          $rel = ($target.TrimStart('/') -replace '/', '\')
          $full = [System.IO.Path]::GetFullPath((Join-Path $Root $rel))
          if (Test-Path -LiteralPath $full -PathType Container) {
            $full = [System.IO.Path]::GetFullPath((Join-Path $full "index.html"))
          }
          $inside = $full.StartsWith($Root + "\", [System.StringComparison]::OrdinalIgnoreCase) -or ($full -eq $Root)
        }

        if ($isList) {
          # 目录清单：页面用它实现「文件夹里有几个 Excel 就读几个」
          $sub = ""
          if ($query -match 'dir=([^&]*)') { $sub = [System.Uri]::UnescapeDataString($matches[1]) }
          $listDir = $Root
          if ($sub.Trim() -ne "") {
            $listDir = [System.IO.Path]::GetFullPath((Join-Path $Root ($sub.Trim() -replace '/', '\')))
          }
          $names = @()
          $okDir = $listDir.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)
          if ($okDir -and (Test-Path -LiteralPath $listDir -PathType Container)) {
            Get-ChildItem -LiteralPath $listDir -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Extension -match '^\.(xlsx|xlsm|xls|csv)$' -and $_.Name -notlike '~$*' -and $_.Name -notlike '.*' } |
              Sort-Object Name |
              ForEach-Object {
                $safe = $_.Name.Replace('\', '\\').Replace('"', '\"')
                $names += '{"name":"' + $safe + '","size":' + $_.Length + '}'
              }
          }
          $json = '{"files":[' + ($names -join ',') + ']}'
          $body = [System.Text.Encoding]::UTF8.GetBytes($json)
          $head = "HTTP/1.1 200 OK`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
          Write-Host ("{0}  200  /__list  ({1} file(s))" -f (Get-Date -Format "HH:mm:ss"), @($names).Count)
        } elseif (-not $inside) {
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
    # empty / aborted connection (browser preconnect): ignore, keep serving
  } finally {
    if ($stream) { try { $stream.Dispose() } catch {} }
    try { $client.Close() } catch {}
  }
}
