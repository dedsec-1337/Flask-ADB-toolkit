@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flask-adb-toolkit.ps1" %*
pause
endlocal
