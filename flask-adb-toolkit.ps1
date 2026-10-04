#Requires -Version 5.1
<#
.SYNOPSIS
    Flask-ADB-toolkit — Windows launcher.

.DESCRIPTION
    Finds Git Bash, checks adb / fastboot, then hands off to
    flask-adb-toolkit.sh inside Git Bash. Double-click
    flask-adb-toolkit.bat to run this without opening a terminal.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

function Write-Ok   { param($m) Write-Host "  $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "  $m" -ForegroundColor Red }
function Write-Cyan { param($m) Write-Host "  $m" -ForegroundColor Cyan }

Write-Host ""
Write-Host "  Flask-ADB-toolkit — Windows launcher" -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Locate Git Bash ──
$bashCandidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
) | Where-Object { $_ -and (Test-Path $_) }

$bash = $bashCandidates | Select-Object -First 1

if (-not $bash) {
    $onPath = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($onPath) {
        $src = $onPath.Source
        # Skip WSL launcher (System32\bash.exe) and WindowsApps stubs
        if ($src -notmatch '(?i)\\System32\\bash\.exe$' -and $src -notmatch '(?i)\\WindowsApps\\') {
            $bash = $src
        }
    }
}

if (-not $bash) {
    Write-Warn "Git Bash was not found on this computer."
    Write-Host ""
    Write-Host "  Git Bash comes with Git for Windows and is what runs the .sh script."
    Write-Host "  Install it with:"
    Write-Cyan "    winget install --id Git.Git -e --source winget"
    Write-Host ""
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $ans = Read-Host "  Install Git for Windows now? [y/N]"
        if ($ans -match '^[Yy]') {
            Write-Host ""
            & winget install --id Git.Git -e --source winget
            Write-Host ""
            # Refresh candidate list for this session
            $bashCandidates = @(
                "$env:ProgramFiles\Git\bin\bash.exe",
                "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
                "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
            ) | Where-Object { $_ -and (Test-Path $_) }
            $bash = $bashCandidates | Select-Object -First 1
            if ($bash) {
                Write-Ok "Git Bash now available: $bash - continuing."
            } else {
                Write-Ok "Installed. Close this window and double-click the .bat again."
                exit 0
            }
        } else {
            Read-Host "  Press Enter to exit"
            exit 1
        }
    } else {
        Write-Host "  Download Git manually: https://git-scm.com/download/win"
        Read-Host "  Press Enter to exit"
        exit 1
    }
}

if (-not $bash) {
    Write-Err "Git Bash still not found after install attempt."
    Read-Host "  Press Enter to exit"
    exit 1
}

Write-Ok "Git Bash: $bash"

# ── 2. Locate adb / fastboot ──
$missing = @()
foreach ($tool in 'adb','fastboot') {
    $cmd = Get-Command "$tool.exe" -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command $tool -ErrorAction SilentlyContinue }
    if ($cmd) {
        Write-Ok "$tool : $($cmd.Source)"
    } else {
        Write-Warn "$tool not found on PATH"
        $missing += $tool
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Warn "Missing: $($missing -join ', ')"
    Write-Host ""
    Write-Host "  adb and fastboot live in Google's platform-tools. This launcher"
    Write-Host "  can download them to:"
    Write-Cyan "    $env:LOCALAPPDATA\Android\platform-tools"
    Write-Host "  and add that folder to your user PATH."
    Write-Host ""
    $ans = Read-Host "  Download platform-tools now? [y/N]"
    if ($ans -match '^[Yy]') {
        $dest = "$env:LOCALAPPDATA\Android"
        $zip  = "$env:TEMP\platform-tools-latest-windows.zip"
        $url  = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Write-Host "  Downloading platform-tools..." -ForegroundColor Cyan
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        } catch {
            Write-Err "Download failed: $($_.Exception.Message)"
            Read-Host "  Press Enter to exit"
            exit 1
        }

        Write-Host "  Unzipping..." -ForegroundColor Cyan
        Expand-Archive -Path $zip -DestinationPath $dest -Force
        Remove-Item $zip -Force -ErrorAction SilentlyContinue

        $pt = Join-Path $dest 'platform-tools'
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($userPath -notlike "*$pt*") {
            $newPath = if ([string]::IsNullOrEmpty($userPath)) { $pt } else { "$userPath;$pt" }
            [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
            $env:Path = "$pt;$env:Path"
            Write-Ok "Added $pt to user PATH (and this session)."
            Write-Host ""
        } else {
            Write-Ok "platform-tools already on PATH."
        }
    } else {
        Write-Host ""
        Write-Host "  You can still continue - the toolkit will tell you what's missing."
        Write-Host ""
    }
}

# ── 3. Locate the .sh next to this launcher ──
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shPath    = Join-Path $scriptDir 'flask-adb-toolkit.sh'

if (-not (Test-Path $shPath)) {
    Write-Err "flask-adb-toolkit.sh was not found next to this launcher."
    Write-Host "  Expected at: $shPath"
    Write-Host ""
    Write-Host "  Download it from:"
    Write-Cyan "    https://raw.githubusercontent.com/dedsec-1337/Flask-ADB-toolkit/main/flask-adb-toolkit.sh"
    Read-Host "  Press Enter to exit"
    exit 1
}

# ── 4. Launch inside Git Bash ──
$bashScript = $shPath -replace '\\', '/'

Write-Host ""
Write-Host "  Starting Flask-ADB-toolkit..." -ForegroundColor Cyan
Write-Host ""

$bashArgs = @($bashScript) + $ExtraArgs
& $bash @bashArgs
exit $LASTEXITCODE
