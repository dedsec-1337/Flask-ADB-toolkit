@echo off
title Flask-ADB-toolkit
echo.
echo   ---------------------------------------------
echo    ⚗️⚡  Flask-ADB-toolkit  (Windows launcher)
echo   ---------------------------------------------
echo.

REM --- Try Git Bash first (recommended: adb/fastboot just work on Windows) ---
set "BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH%" set "BASH=C:\Program Files (x86)\Git\bin\bash.exe"

if exist "%BASH%" (
    echo  [OK] Git Bash found - launching the toolkit...
    echo.
    "%BASH%" --login -i -c "cd ~ && chmod +x ~/flask-adb-toolkit.sh && ~/flask-adb-toolkit.sh"
    goto :end
)

REM --- Fallback: WSL (Ubuntu on Windows) ---
where wsl >nul 2>nul
if %errorlevel%==0 (
    echo  [OK] WSL found - launching the toolkit in Ubuntu...
    echo.
    wsl -e bash -lc "chmod +x ~/flask-adb-toolkit.sh && ~/flask-adb-toolkit.sh"
    goto :end
)

echo  [X] Could not find Git Bash or WSL on this PC.
echo.
echo   To fix this, pick ONE:
echo.
echo   OPTION A - Easiest (recommended):
echo     1. Install Git for Windows:  https://git-scm.com/download/win
echo     2. Install platform-tools:   https://developer.android.com/tools/releases/platform-tools
echo        and add the folder containing adb.exe / fastboot.exe to your PATH
echo     3. Put flask-adb-toolkit.sh in your user folder (C:\Users\YOU\)
echo     4. Double-click this .bat again
echo.
echo   OPTION B - Ubuntu inside Windows (WSL):
echo     1. Open PowerShell as Administrator and run:  wsl --install
echo     2. Restart your PC, open "Ubuntu" from the Start menu, create a user
echo     3. Inside Ubuntu run:  sudo apt update ^&^& sudo apt install android-tools-adb android-tools-fastboot
echo     4. Copy the script to your Ubuntu home folder
echo     5. Double-click this .bat again

:end
echo.
pause
