@echo off
setlocal EnableDelayedExpansion
title Flask-ADB-toolkit (Windows)

:: ══════════════════════════════════════════════════════════════
::  Flask-ADB-toolkit — Windows batch version
::  Same commands as flask-adb-toolkit.sh, plainer menu.
::  Needs adb and fastboot on PATH (platform-tools).
::  https://github.com/dedsec-1337/Flask-ADB-toolkit
:: ══════════════════════════════════════════════════════════════

set "BASE=%USERPROFILE%\Desktop\cmf"
set "STOCK_NEW=%BASE%\Galaga_B4.1-260812-1729"
set "STOCK_OLD=%BASE%\Galaga_V3.2-250507-1139_3.2"

:MENU
cls
echo ================================================
echo    Flask-ADB-toolkit
echo ================================================
call :CHECKSTATE
echo Device:     %DEV% (%MODE%)
echo Bootloader: %LOCK%
echo Slot:       %SLOT%
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
echo 12) Restore stock - newest (B4.1)
echo 13) Restore stock - older (V3.2)
echo 14) Performance pass
echo 15) Deep clean (orphaned app data)
echo 16) Battery and storage
echo 17) Take screenshot
echo 18) Install an APK
echo 19) Pull a file from phone
echo 20) Push a file to phone
echo 21) Device info
echo 22) Verify a file's checksum
echo  0) Exit
echo.
set /p CHOICE=^> 
echo.

if "%CHOICE%"=="1" call :CHECKSTATE & echo Device: %DEV% (%MODE%)  Lock: %LOCK%  Slot: %SLOT%
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
if "%CHOICE%"=="12" call :RESTORESTOCK "%STOCK_NEW%"
if "%CHOICE%"=="13" call :RESTORESTOCK "%STOCK_OLD%"
if "%CHOICE%"=="14" call :PERFPASS
if "%CHOICE%"=="15" call :DEEPCLEAN
if "%CHOICE%"=="16" call :BATTERYSTORAGE
if "%CHOICE%"=="17" call :SCREENSHOT
if "%CHOICE%"=="18" call :INSTALLAPK
if "%CHOICE%"=="19" call :PULLFILE
if "%CHOICE%"=="20" call :PUSHFILE
if "%CHOICE%"=="21" call :DEVICEINFO
if "%CHOICE%"=="22" call :VERIFYCHECKSUM
if "%CHOICE%"=="0" exit /b

echo.
pause
goto MENU

:: ── State check — approximate; parses adb/fastboot output ──
:CHECKSTATE
set "MODE=none"
set "DEV=none"
set "LOCK=unknown"
set "LOCKRAW="
set "SLOT=unknown"
for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
    if not "%%A"=="" (
        set "DEV=%%A"
        if "%%B"=="sideload" set "MODE=sideload"
        if "%%B"=="device" (
            set "MODE=adb"
            for /f "usebackq delims=" %%S in (`adb shell getprop ro.boot.slot_suffix 2^>nul`) do set "SLOT=%%S"
            for /f "usebackq delims=" %%L in (`adb shell getprop ro.boot.vbmeta.device_state 2^>nul`) do set "LOCKRAW=%%L"
        )
    )
)
if "%MODE%"=="none" (
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

:CONFIRM
echo %~1
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
set /p PART=Partition name: 
echo Slot: leave blank for none, or type a / b
set /p SUF=Slot suffix (a/b/blank): 
if /i "%SUF%"=="a" set "TARGET=%PART%_a"
if /i "%SUF%"=="b" set "TARGET=%PART%_b"
if "%SUF%"=="" set "TARGET=%PART%"
set /p IMAGE=Full path to image file: 
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
set /p PART=Partition name: 
set /p SUF=Slot suffix (a/b/blank): 
if /i "%SUF%"=="a" set "TARGET=%PART%_a"
if /i "%SUF%"=="b" set "TARGET=%PART%_b"
if "%SUF%"=="" set "TARGET=%PART%"
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
set /p S=Slot to switch to (a/b): 
fastboot --set-active=%S%
echo Active slot set to %S%.
exit /b

:REBOOTBOOTLOADER
call :CHECKSTATE
if "%MODE%"=="adb" adb reboot bootloader
if "%MODE%"=="sideload" adb reboot bootloader
if "%MODE%"=="fastboot" echo Already in bootloader.
if "%MODE%"=="none" echo No device found.
exit /b

:REBOOTSYSTEM
call :CHECKSTATE
if "%MODE%"=="fastboot" fastboot reboot
if "%MODE%"=="sideload" adb reboot
if "%MODE%"=="adb" echo Already booted.
if "%MODE%"=="none" echo No device found.
exit /b

:REBOOTRECOVERY
call :CHECKSTATE
if "%MODE%"=="adb" adb reboot recovery
if "%MODE%"=="fastboot" fastboot reboot recovery
if "%MODE%"=="sideload" echo Already in recovery.
if "%MODE%"=="none" echo No device found.
exit /b

:SIDELOAD
call :CHECKSTATE
if not "%MODE%"=="sideload" (
    echo Phone needs to be in recovery, at the "Apply from ADB" screen.
    echo Reboot to recovery first, then choose Apply update, then Apply from ADB.
    exit /b
)
set /p ZIP=Full path to the zip: 
if not exist "%ZIP%" (
    echo File not found: %ZIP%
    exit /b
)
adb sideload "%ZIP%"
exit /b

:FLASHROM
call :NEEDMODE fastboot || exit /b
set /p DIR=Full path to the ROM folder: 
if not exist "%DIR%\vendor_boot.img" (
    echo vendor_boot.img not found in that folder — it carries the recovery and is required.
    exit /b
)
echo Detected in this folder:
if exist "%DIR%\vbmeta.img" echo   - vbmeta.img
if exist "%DIR%\vbmeta_system.img" echo   - vbmeta_system.img
if exist "%DIR%\dtbo.img" echo   - dtbo.img
if exist "%DIR%\boot.img" echo   - boot.img
if exist "%DIR%\init_boot.img" echo   - init_boot.img
if exist "%DIR%\vendor_boot.img" echo   - vendor_boot.img
if exist "%DIR%\super_empty.img" echo   - super_empty.img
if exist "%DIR%\system.img" echo   - system.img (present, NOT auto-flashed — see note below)
set "ZIP="
for %%Z in ("%DIR%\*.zip") do if not "%%~nZ"=="" set "ZIP=%%Z"
if defined ZIP echo   - %ZIP%
echo.
if exist "%DIR%\system.img" echo Note: system.img is not touched automatically. It's normally installed by the ROM zip itself.
call :CONFIRM "Proceed? This wipes data and system." || exit /b

if exist "%DIR%\vbmeta.img" fastboot --disable-verity --disable-verification flash vbmeta "%DIR%\vbmeta.img"
if exist "%DIR%\vbmeta_system.img" fastboot --disable-verity --disable-verification flash vbmeta_system "%DIR%\vbmeta_system.img"
if exist "%DIR%\dtbo.img" fastboot flash dtbo "%DIR%\dtbo.img"
if exist "%DIR%\boot.img" fastboot flash boot "%DIR%\boot.img"
if exist "%DIR%\init_boot.img" fastboot flash init_boot "%DIR%\init_boot.img"
if exist "%DIR%\super_empty.img" fastboot wipe-super "%DIR%\super_empty.img"
fastboot flash vendor_boot "%DIR%\vendor_boot.img"
fastboot reboot recovery
echo On the phone: Factory reset, then Format data, then Apply update, then Apply from ADB.
pause
if defined ZIP (
    adb sideload "%ZIP%"
) else (
    echo No zip found in that folder — use "Sideload a package" once you're ready.
)
exit /b

:RESTORESTOCK
call :NEEDMODE fastboot || exit /b
set "DIR=%~1"
echo Restores stock from %DIR%. Wipes the phone.
call :CONFIRM "Continue?" || exit /b
if not exist "%DIR%\flash_all.bat" if not exist "%DIR%\flash_all.sh" (
    echo flash_all script missing in that folder — get it from spike0en/nothing_flasher, galaga-tetris branch.
    exit /b
)
pushd "%DIR%"
if exist flash_all.bat (call flash_all.bat) else (bash flash_all.sh)
popd
exit /b

:PERFPASS
call :NEEDMODE adb || exit /b
echo Trims app cache, then force-compiles every app for speed.
echo This is a plain single pass on Windows — no resume tracking like the .sh version.
adb shell pm trim-caches 999G
adb shell cmd package compile -m speed -f -a
echo Done.
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
set "TS=%date:~-4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=%TS: =0%"
adb exec-out screencap -p > "%SHOTDIR%\screenshot_%TS%.png"
echo Saved: %SHOTDIR%\screenshot_%TS%.png
exit /b

:INSTALLAPK
call :NEEDMODE adb || exit /b
set /p APK=Full path to the APK: 
if not exist "%APK%" (
    echo File not found: %APK%
    exit /b
)
adb install "%APK%"
exit /b

:PULLFILE
call :NEEDMODE adb || exit /b
set /p SRC=Path on phone to pull: 
set /p DST=Save to (local path, blank = current folder): 
if "%DST%"=="" set "DST=."
adb pull "%SRC%" "%DST%"
exit /b

:PUSHFILE
call :NEEDMODE adb || exit /b
set /p SRC=Local file to push: 
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
if "%MODE%"=="none" echo No device found.
exit /b

:VERIFYCHECKSUM
set /p F=Path to file: 
if not exist "%F%" (
    echo File not found: %F%
    exit /b
)
set /p EXPECTED=Expected SHA256 (leave blank to just show it): 
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
        echo Does NOT match. Do not flash this file — re-download it.
    )
)
exit /b
