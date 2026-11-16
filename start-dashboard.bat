@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Invoice Dashboard - local server

echo ==========================================
echo  Invoice Dashboard - local server
echo ==========================================
echo.
echo Serving folder:
echo   %cd%
echo URL:
echo   http://localhost:8765/index.html
echo.
echo The browser will open in 2 seconds.
echo Keep this window open while using the dashboard.
echo Close this window to stop the server.
echo.

start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 2; Start-Process 'http://localhost:8765/index.html'"

rem --- engine 1: Python (if really usable) ---
where python >nul 2>nul
if errorlevel 1 goto :use_ps
python -c "import sys" >nul 2>nul
if errorlevel 1 goto :use_ps

echo Engine: Python
python -m http.server 8765
goto :end

rem --- engine 2: PowerShell (always present on Windows 10/11) ---
:use_ps
echo Engine: PowerShell (built in, Python not needed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 8765
if errorlevel 1 goto :failed
goto :end

:failed
echo.
echo [WARN] The local server could not start.
echo        You can still just double-click index.html - the dashboard
echo        will reload the files you picked last time (no need to pick again).
echo.
pause

:end
