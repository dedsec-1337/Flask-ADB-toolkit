@echo off
setlocal EnableDelayedExpansion
title Flask-ADB-toolkit (Windows)

:: ==============================================================
:: Flask-ADB-toolkit - Windows batch version (v1.3)
:: Same commands as flask-adb-toolkit.sh, plainer menu.
:: Finds adb/fastboot automatically:
::   1) same folder as this .bat
::   2) platform-tools folder next to this .bat
::   3) already on PATH
:: https://github.com/dedsec-1337/Flask-ADB-toolkit
::
:: v1.3 fixes:
::  - Pressing Enter on a prompt no longer re-uses the previous
::    answer (menu choice, YES confirmation, slot, checksum)
::  - Flash ROM stops at the first failed step
::  - Restore stock shows the connected device first
::  - Detects recovery / unauthorized / offline phones
::  - Locale-independent screenshot file names
:: ==============================================================

set "BASE=%USERPROFILE%\Desktop\flashing"
set "SCRIPTDIR=%~dp0"
set "SCRIPTDIR=%SCRIPTDIR:~0,-1%"

call :FINDTOOLS
if errorlevel 1 (
  echo.
  pause
  exit /b 1
)

:MENU
cls
echo ================================================
echo   Flask-ADB-toolkit
echo ================================================
call :CHECKSTATE
echo Device:     %DEV% (%MODE%)
echo Bootloader: %LOCK%
echo Slot:       %SLOT%
if defined HINT echo WARNING: %HINT%
echo ------------------------------------------------
echo  1) Check device
echo  2) Unlock bootloader
echo  3) Flash any partition (generic)
echo  4) Flash ROM folder (auto-detect)
echo  5) Switch active slot
echo  6) Erase a partition
echo  7) Show all fastboot variables
echo  8) Reboot to bootloader
echo  9) Reboot to recovery
echo 10) Reboot to system
echo 11) Sideload a package
echo 12) Restore stock firmware
echo 13) Performance pass
echo 14) Deep clean (orphaned app data)
echo 15) Battery and storage
echo 16) Take screenshot
echo 17) Install an APK
echo 18) Pull a file from phone
echo 19) Push a file to phone
echo 20) Device info
echo 21) Verify a file's checksum
echo  0) Exit
echo.
set "CHOICE="
set /p CHOICE=^>
echo.
if "%CHOICE%"=="" goto MENU
if "%CHOICE%"=="1" call :CHECKSTATE & echo Device: %DEV% ^(%MODE%^)  Lock: %LOCK%  Slot: %SLOT%
if "%CHOICE%"=="2" call :UNLOCK
if "%CHOICE%"=="3" call :FLASHGENERIC
if "%CHOICE%"=="4" call :FLASHROM
if "%CHOICE%"=="5" call :SWITCHSLOT
if "%CHOICE%"=="6" call :ERASEPART
if "%CHOICE%"=="7" call :SHOWVARS
if "%CHOICE%"=="8" call :REBOOTBOOTLOADER
if "%CHOICE%"=="9" call :REBOOTRECOVERY
if "%CHOICE%"=="10" call :REBOOTSYSTEM
if "%CHOICE%"=="11" call :SIDELOAD
if "%CHOICE%"=="12" call :RESTORESTOCK
if "%CHOICE%"=="13" call :PERFPASS
if "%CHOICE%"=="14" call :DEEPCLEAN
if "%CHOICE%"=="15" call :BATTERYSTORAGE
if "%CHOICE%"=="16" call :SCREENSHOT
if "%CHOICE%"=="17" call :INSTALLAPK
if "%CHOICE%"=="18" call :PULLFILE
if "%CHOICE%"=="19" call :PUSHFILE
if "%CHOICE%"=="20" call :DEVICEINFO
if "%CHOICE%"=="21" call :VERIFYCHECKSUM
if "%CHOICE%"=="0" exit /b
echo.
pause
goto MENU

:: -- Find adb.exe / fastboot.exe without requiring a global PATH --
:FINDTOOLS
set "TOOLDIR="
if exist "%SCRIPTDIR%\adb.exe" set "TOOLDIR=%SCRIPTDIR%"
if not defined TOOLDIR if exist "%SCRIPTDIR%\platform-tools\adb.exe" set "TOOLDIR=%SCRIPTDIR%\platform-tools"
if not defined TOOLDIR (
  where adb >nul 2>&1
  if not errorlevel 1 goto :TOOLS_OK
)
if defined TOOLDIR (
  set "PATH=%TOOLDIR%;%PATH%"
  goto :TOOLS_OK
)
echo ================================================================
echo  adb.exe / fastboot.exe not found.
echo.
echo  Windows does NOT include them. Do this once:
echo.
echo  1. Download platform-tools:
echo       https://developer.android.com/tools/releases/platform-tools
echo  2. Unzip the folder (it is named platform-tools).
echo  3. EITHER:
echo       - Put flask-adb-toolkit.bat INSIDE that platform-tools folder
echo         and double-click it
echo     OR
echo       - Put the platform-tools folder next to this .bat
echo         (same directory as flask-adb-toolkit.bat\platform-tools\adb.exe)
echo.
echo  You do not need to type CMD inside the folder anymore.
echo ================================================================
exit /b 1

:TOOLS_OK
where adb >nul 2>&1
if errorlevel 1 (
  echo adb still not usable. Check the platform-tools folder.
  exit /b 1
)
echo Using adb from:
where adb
echo.
exit /b 0

:: -- State check - approximate; parses adb/fastboot output --
:CHECKSTATE
set "MODE=none"
set "DEV=none"
set "LOCK=unknown"
set "LOCKRAW="
set "SLOT=unknown"
set "HINT="
for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
  if not "%%A"=="" if not "%%A"=="*" (
    set "DEV=%%A"
    if "%%B"=="sideload" set "MODE=sideload"
    if "%%B"=="recovery" set "MODE=recovery"
    if "%%B"=="unauthorized" set "HINT=Phone is connected but NOT authorized. Unlock the screen and tap Allow on the USB debugging prompt."
    if "%%B"=="offline" set "HINT=Phone shows as offline. Unplug, replug, or toggle USB debugging off and on."
    if "%%B"=="device" (
      set "MODE=adb"
      for /f "usebackq delims=" %%S in (`adb shell getprop ro.boot.slot_suffix 2^>nul`) do set "SLOT=%%S"
      for /f "usebackq delims=" %%L in (`adb shell getprop ro.boot.vbmeta.device_state 2^>nul`) do set "LOCKRAW=%%L"
    )
  )
)
if "%MODE%"=="none" if not defined HINT (
  for /f "tokens=1,2" %%A in ('fastboot devices 2^>nul') do (
    if not "%%A"=="" (
      set "DEV=%%A"
      set "MODE=fastboot"
      for /f "tokens=2" %%U in ('fastboot getvar unlocked 2^>^&1 ^| findstr /i unlocked') do set "LOCKRAW=%%U"
      for /f "tokens=2" %%S in ('fastboot getvar current-slot 2^>^&1 ^| findstr /i current-slot') do set "SLOT=%%S"
    )
  )
)
if /i "%LOCKRAW%"=="unlocked" set "LOCK=unlocked"
if /i "%LOCKRAW%"=="orange" set "LOCK=unlocked"
if /i "%LOCKRAW%"=="yes" set "LOCK=unlocked"
if /i "%LOCKRAW%"=="locked" set "LOCK=locked"
if /i "%LOCKRAW%"=="green" set "LOCK=locked"
if /i "%LOCKRAW%"=="no" set "LOCK=locked"
goto :EOF

:NEEDMODE
call :CHECKSTATE
if not "%MODE%"=="%~1" (
  echo This needs the phone in %~1 mode. It's currently: %MODE%.
  exit /b 1
)
exit /b 0

:: Clear A first: "set /p" keeps the OLD value when you just press Enter,
:: which would silently auto-confirm every prompt after the first YES.
:CONFIRM
echo %~1
set "A="
set /p A=Type YES to continue: 
if /i not "%A%"=="YES" exit /b 1
exit /b 0

:UNLOCK
call :NEEDMODE fastboot || exit /b
if "%LOCK%"=="unlocked" (
  echo Already unlocked. Nothing to do.
  exit /b
)
echo Step: fastboot flashing unlock, then confirm on the phone with volume + power.
call :CONFIRM "This wipes the phone completely." || exit /b
fastboot flashing unlock || fastboot oem unlock
exit /b

:FLASHGENERIC
call :NEEDMODE fastboot || exit /b
echo Partitions: boot init_boot recovery vendor_boot dtbo vbmeta vbmeta_system system vendor product super userdata
set "PART="
set /p PART=Partition name: 
if "%PART%"=="" (
  echo No partition name entered.
  exit /b
)
echo Slot: leave blank for none, or type a / b
set "SUF="
set "TARGET="
set /p SUF=Slot suffix (a/b/blank): 
if /i "%SUF%"=="a" set "TARGET=%PART%_a"
if /i "%SUF%"=="b" set "TARGET=%PART%_b"
if not defined TARGET set "TARGET=%PART%"
set "IMAGE="
set /p IMAGE=Full path to image file (drag and drop works): 
set "IMAGE=%IMAGE:"=%"
if not exist "%IMAGE%" (
  echo File not found: %IMAGE%
  exit /b
)
set "FLAGS="
if /i "%PART%"=="vbmeta" (
  call :CONFIRM "Also set --disable-verity --disable-verification on this vbmeta flash?" && set "FLAGS=--disable-verity --disable-verification "
)
if /i "%PART%"=="vbmeta_system" (
  call :CONFIRM "Also set --disable-verity --disable-verification on this vbmeta flash?" && set "FLAGS=--disable-verity --disable-verification "
)
if /i "%PART%"=="userdata" echo Warning: flashing userdata erases all user data.
if /i "%PART%"=="super" echo Warning: flashing super directly replaces the whole dynamic-partition layout.
echo Command: fastboot %FLAGS%flash %TARGET% "%IMAGE%"
call :CONFIRM "Flash this image to %TARGET%?" || exit /b
fastboot %FLAGS%flash %TARGET% "%IMAGE%"
exit /b

:ERASEPART
call :NEEDMODE fastboot || exit /b
echo Common: cache userdata metadata dtbo vbmeta boot recovery
set "PART="
set /p PART=Partition name: 
if "%PART%"=="" (
  echo No partition name entered.
  exit /b
)
set "SUF="
set "TARGET="
set /p SUF=Slot suffix (a/b/blank): 
if /i "%SUF%"=="a" set "TARGET=%PART%_a"
if /i "%SUF%"=="b" set "TARGET=%PART%_b"
if not defined TARGET set "TARGET=%PART%"
if /i "%PART%"=="userdata" echo Warning: erases all user data.
if /i "%PART%"=="metadata" echo Warning: can affect encryption state.
call :CONFIRM "Erase %TARGET%?" || exit /b
fastboot erase %TARGET%
exit /b

:SHOWVARS
call :NEEDMODE fastboot || exit /b
fastboot getvar all 2>&1
exit /b

:SWITCHSLOT
call :NEEDMODE fastboot || exit /b
set "S="
set /p S=Slot to switch to (a/b): 
if /i not "%S%"=="a" if /i not "%S%"=="b" (
  echo Enter a or b.
  exit /b
)
fastboot --set-active=%S%
echo Active slot set to %S%.
exit /b

:REBOOTBOOTLOADER
call :CHECKSTATE
if "%MODE%"=="adb" adb reboot bootloader
if "%MODE%"=="sideload" adb reboot bootloader
if "%MODE%"=="recovery" adb reboot bootloader
if "%MODE%"=="fastboot" echo Already in bootloader.
if "%MODE%"=="none" echo No device found.
exit /b

:REBOOTSYSTEM
call :CHECKSTATE
if "%MODE%"=="fastboot" fastboot reboot
if "%MODE%"=="sideload" adb reboot
if "%MODE%"=="recovery" adb reboot
if "%MODE%"=="adb" echo Already booted.
if "%MODE%"=="none" echo No device found.
exit /b

:REBOOTRECOVERY
call :CHECKSTATE
if "%MODE%"=="adb" adb reboot recovery
if "%MODE%"=="fastboot" fastboot reboot recovery
if "%MODE%"=="sideload" echo Already in recovery.
if "%MODE%"=="recovery" echo Already in recovery.
if "%MODE%"=="none" echo No device found.
exit /b

:SIDELOAD
call :CHECKSTATE
if not "%MODE%"=="sideload" (
  echo Phone needs to be in recovery, at the "Apply from ADB" screen.
  echo Reboot to recovery first, then choose Apply update, then Apply from ADB.
  exit /b
)
set "ZIP="
set /p ZIP=Full path to the zip (drag and drop works): 
set "ZIP=%ZIP:"=%"
if not exist "%ZIP%" (
  echo File not found: %ZIP%
  exit /b
)
adb sideload "%ZIP%"
exit /b

:FLASHROM
call :NEEDMODE fastboot || exit /b
set "DIR="
set /p DIR=Full path to the ROM folder (drag and drop works): 
set "DIR=%DIR:"=%"
if not exist "%DIR%\vendor_boot.img" (
  echo vendor_boot.img not found in that folder - it carries the recovery and is required.
  exit /b
)
echo Detected in this folder:
if exist "%DIR%\vbmeta.img" echo  - vbmeta.img
if exist "%DIR%\vbmeta_system.img" echo  - vbmeta_system.img
if exist "%DIR%\dtbo.img" echo  - dtbo.img
if exist "%DIR%\boot.img" echo  - boot.img
if exist "%DIR%\init_boot.img" echo  - init_boot.img
if exist "%DIR%\vendor_boot.img" echo  - vendor_boot.img
if exist "%DIR%\super_empty.img" echo  - super_empty.img
if exist "%DIR%\system.img" echo  - system.img (present, NOT auto-flashed - see note below)
set "ZIP="
for %%Z in ("%DIR%\*.zip") do if not "%%~nZ"=="" set "ZIP=%%Z"
if defined ZIP echo  - %ZIP%
echo.
if exist "%DIR%\system.img" echo Note: system.img is not touched automatically. It's normally installed by the ROM zip itself.
echo If any step fails, the whole process stops right there.
call :CONFIRM "Proceed? This wipes data and system." || exit /b

if exist "%DIR%\vbmeta.img" (
  fastboot --disable-verity --disable-verification flash vbmeta "%DIR%\vbmeta.img"
  if errorlevel 1 goto :ROMFAIL
)
if exist "%DIR%\vbmeta_system.img" (
  fastboot --disable-verity --disable-verification flash vbmeta_system "%DIR%\vbmeta_system.img"
  if errorlevel 1 goto :ROMFAIL
)
if exist "%DIR%\dtbo.img" (
  fastboot flash dtbo "%DIR%\dtbo.img"
  if errorlevel 1 goto :ROMFAIL
)
if exist "%DIR%\boot.img" (
  fastboot flash boot "%DIR%\boot.img"
  if errorlevel 1 goto :ROMFAIL
)
if exist "%DIR%\init_boot.img" (
  fastboot flash init_boot "%DIR%\init_boot.img"
  if errorlevel 1 goto :ROMFAIL
)
if exist "%DIR%\super_empty.img" (
  fastboot wipe-super "%DIR%\super_empty.img"
  if errorlevel 1 goto :ROMFAIL
)
fastboot flash vendor_boot "%DIR%\vendor_boot.img"
if errorlevel 1 goto :ROMFAIL
fastboot reboot recovery
if errorlevel 1 goto :ROMFAIL

echo On the phone: Factory reset, then Format data, then Apply update, then Apply from ADB.
pause
if defined ZIP (
  adb sideload "%ZIP%"
) else (
  echo No zip found in that folder - use "Sideload a package" once you're ready.
)
exit /b

:ROMFAIL
echo.
echo STOPPED. A flash step failed (see the error above). Nothing after it was run.
echo Fix the problem and try again.
exit /b 1

:RESTORESTOCK
call :NEEDMODE fastboot || exit /b
set "DIR="
set /p DIR=Full path to the stock firmware folder (drag and drop works): 
set "DIR=%DIR:"=%"
if not exist "%DIR%" (
  echo Folder not found: %DIR%
  exit /b
)
if not exist "%DIR%\flash_all.bat" if not exist "%DIR%\flash_all.sh" (
  echo No flash_all script in that folder. This expects the layout your device's stock-firmware archive uses ^(for Nothing/CMF phones: spike0en/nothing_flasher, galaga-tetris branch^).
  exit /b
)
set "PROD=unknown"
for /f "tokens=2" %%P in ('fastboot getvar product 2^>^&1 ^| findstr /i "product:"') do set "PROD=%%P"
echo Connected device product: %PROD%
echo Make sure this firmware is built for THAT device. Wrong firmware can brick the phone.
echo Restores stock from %DIR%. Wipes the phone.
call :CONFIRM "Continue?" || exit /b
pushd "%DIR%"
if exist flash_all.bat (call flash_all.bat) else (bash flash_all.sh)
popd
exit /b

:PERFPASS
call :NEEDMODE adb || exit /b
echo Trims app cache, then force-compiles every app for speed.
echo This is a plain single pass on Windows - no resume tracking like the .sh version.
echo Lines saying "Failure: ... android.auto_generated_rro_..." are harmless system overlays. Ignore them.
adb shell pm trim-caches 999G
adb shell cmd package compile -m speed -f -a
echo Finished. Check the messages above for anything other than rro overlays.
exit /b

:DEEPCLEAN
call :NEEDMODE adb || exit /b
echo Scanning /sdcard/Android/data and /sdcard/Android/obb for orphaned app folders...
adb shell pm list packages > "%TEMP%\flaskadb_installed.txt"
for %%B in (data obb) do (
  echo -- /sdcard/Android/%%B --
  for /f "usebackq delims=" %%D in (`adb shell ls /sdcard/Android/%%B 2^>nul`) do (
    findstr /c:"package:%%D" "%TEMP%\flaskadb_installed.txt" >nul || echo orphaned: /sdcard/Android/%%B/%%D
  )
)
del "%TEMP%\flaskadb_installed.txt" >nul 2>&1
echo.
call :CONFIRM "Clear thumbnail cache too? (regenerates on its own, always safe)"
if not errorlevel 1 (
  adb shell rm -rf /sdcard/DCIM/.thumbnails /sdcard/Pictures/.thumbnails
  echo Thumbnail cache cleared.
)
echo To remove an orphaned folder: adb shell rm -rf '/sdcard/Android/data/NAME'
exit /b

:BATTERYSTORAGE
call :NEEDMODE adb || exit /b
echo -- Battery --
adb shell dumpsys battery | findstr /i "level status health temperature"
echo -- Storage --
adb shell df -h /data /sdcard
exit /b

:SCREENSHOT
call :NEEDMODE adb || exit /b
set "SHOTDIR=%USERPROFILE%\Downloads"
if not exist "%SHOTDIR%" mkdir "%SHOTDIR%"
set "TS="
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul') do set "TS=%%T"
if not defined TS set "TS=%RANDOM%%RANDOM%"
adb exec-out screencap -p > "%SHOTDIR%\screenshot_%TS%.png"
if errorlevel 1 (
  del "%SHOTDIR%\screenshot_%TS%.png" >nul 2>&1
  echo Screenshot failed - nothing was saved.
  exit /b
)
echo Saved: %SHOTDIR%\screenshot_%TS%.png
exit /b

:INSTALLAPK
call :NEEDMODE adb || exit /b
set "APK="
set /p APK=Full path to the APK (drag and drop works): 
set "APK=%APK:"=%"
if not exist "%APK%" (
  echo File not found: %APK%
  exit /b
)
adb install "%APK%"
exit /b

:PULLFILE
call :NEEDMODE adb || exit /b
set "SRC="
set "DST="
set /p SRC=Path on phone to pull: 
set /p DST=Save to (local path, blank = current folder): 
set "DST=%DST:"=%"
if "%DST%"=="" set "DST=."
adb pull "%SRC%" "%DST%"
exit /b

:PUSHFILE
call :NEEDMODE adb || exit /b
set "SRC="
set "DST="
set /p SRC=Local file to push (drag and drop works): 
set "SRC=%SRC:"=%"
if not exist "%SRC%" (
  echo File not found: %SRC%
  exit /b
)
set /p DST=Destination path on phone: 
adb push "%SRC%" "%DST%"
exit /b

:DEVICEINFO
call :CHECKSTATE
if "%MODE%"=="fastboot" (
  fastboot getvar product
  fastboot getvar current-slot
  fastboot getvar unlocked
  fastboot getvar serialno
)
if "%MODE%"=="adb" (
  echo Model:
  adb shell getprop ro.product.model
  echo Codename:
  adb shell getprop ro.product.device
  echo Android:
  adb shell getprop ro.build.version.release
  echo Build:
  adb shell getprop ro.build.display.id
  echo Security patch:
  adb shell getprop ro.build.version.security_patch
)
if "%MODE%"=="sideload" echo Phone is in recovery. Reboot to system or bootloader to read device info.
if "%MODE%"=="recovery" echo Phone is in recovery. Reboot to system or bootloader to read device info.
if "%MODE%"=="none" echo No device found.
exit /b

:VERIFYCHECKSUM
set "F="
set "EXPECTED="
set "ACTUAL="
set /p F=Path to file (drag and drop works): 
set "F=%F:"=%"
if not exist "%F%" (
  echo File not found: %F%
  exit /b
)
set /p EXPECTED=Expected SHA256 (leave blank to just show it): 
set "EXPECTED=%EXPECTED: =%"
echo Hashing...
for /f "skip=1 tokens=* delims=" %%H in ('certutil -hashfile "%F%" SHA256') do (
  if not defined ACTUAL set "ACTUAL=%%H"
)
set "ACTUAL=%ACTUAL: =%"
echo SHA256: %ACTUAL%
if not "%EXPECTED%"=="" (
  if /i "%ACTUAL%"=="%EXPECTED%" (
    echo Matches. Safe to flash.
  ) else (
    echo Does NOT match. Do not flash this file - re-download it.
  )
)
exit /b
