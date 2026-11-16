@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ==========================================
echo  Invoice Dashboard - local server
echo ==========================================
echo.

where python >nul 2>nul
if errorlevel 1 goto :nopython

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
python -m http.server 8765
goto :eof

:nopython
echo [ERROR] Python not found on this PC.
echo.
echo Option 1: install Python, then run this file again.
echo Option 2: just double-click index.html. The dashboard will
echo           remember the files you picked last time, so you do
echo           not need to select them again (unless the Excel
echo           files are very large).
echo.
pause
