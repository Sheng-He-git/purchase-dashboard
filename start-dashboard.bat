@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Invoice Dashboard - local server

rem ============================================================
rem  Only ONE thing to change here: the port number below.
rem  If it says "port already in use", try 8770 / 8800 / 8899.
rem ============================================================
set PORT=8765

echo ==========================================
echo  Invoice Dashboard - local server
echo ==========================================
echo  Folder : %cd%
echo  URL    : http://localhost:%PORT%/index.html
echo.
echo  No Python needed. Keep this window open
echo  while using the dashboard; close it to stop.
echo.

start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 2; Start-Process 'http://localhost:%PORT%/index.html'"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port %PORT%

if errorlevel 1 goto :failed
goto :end

:failed
echo.
echo [WARN] The local server could not start.
echo        Reason is usually: port %PORT% is already used by another program.
echo        Fix: open this file, change  set PORT=%PORT%  to 8770 or 8800, save, run again.
echo        Alternative: just double-click index.html - the dashboard will
echo        reload the files you picked last time (no need to pick again).
echo.
pause

:end
