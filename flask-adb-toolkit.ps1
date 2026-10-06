#Requires -Version 5.1
<#
.SYNOPSIS
    Flask-ADB-toolkit - Windows launcher.

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

# Google lists a SHA-1 for every SDK package in its repository manifest.
# Returns the current stable Windows platform-tools zip URL and its SHA-1.
# Throws if the manifest cannot be read or does not look as expected.
function Get-PlatformToolsInfo {
    $base = 'https://dl.google.com/android/repository/'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $resp = Invoke-WebRequest -Uri ($base + 'repository2-3.xml') -UseBasicParsing -TimeoutSec 60
    $text = $resp.Content
    if ($text -is [byte[]]) { $text = [Text.Encoding]::UTF8.GetString($text) }
    $text = $text.TrimStart([char]0xFEFF)

    $xml = New-Object System.Xml.XmlDocument
    $xml.XmlResolver = $null
    $xml.LoadXml($text)

    $pkgs = @($xml.SelectNodes("//*[local-name()='remotePackage'][@path='platform-tools']"))
    if ($pkgs.Count -eq 0) { throw 'platform-tools is not listed in the manifest.' }
    $stable = @($pkgs | Where-Object { $_.SelectSingleNode("*[local-name()='channelRef']/@ref").Value -eq 'channel-0' })
    if ($stable.Count -eq 1) { $pkg = $stable[0] }
    elseif ($stable.Count -eq 0 -and $pkgs.Count -eq 1) { $pkg = $pkgs[0] }
    else { throw 'Could not tell which platform-tools entry is the stable release.' }

    $arch = $pkg.SelectSingleNode(".//*[local-name()='archive'][*[local-name()='host-os']='windows']")
    if (-not $arch) { throw 'No Windows archive is listed for platform-tools.' }
    $done = $arch.SelectSingleNode("*[local-name()='complete']")
    if (-not $done) { throw 'The Windows archive entry has no download details.' }
    $urlNode = $done.SelectSingleNode("*[local-name()='url']")
    $sumNode = $done.SelectSingleNode("*[local-name()='checksum']")
    if (-not $urlNode -or -not $sumNode) { throw 'The archive entry is missing its URL or checksum.' }
    if ($sumNode.GetAttribute('type') -ne 'sha1') { throw 'The checksum is not SHA-1 as expected.' }

    $rel  = $urlNode.InnerText.Trim()
    $sha1 = $sumNode.InnerText.Trim()
    if ($sha1 -notmatch '^[0-9a-fA-F]{40}$') { throw 'The checksum is not in the expected format.' }
    if ($rel -notmatch '^https?://') { $rel = $base + $rel }
    if ($rel -notmatch '^https://dl\.google\.com/') { throw 'The download is not hosted on dl.google.com.' }
    return [pscustomobject]@{ Url = $rel; Sha1 = $sha1.ToLower() }
}

Write-Host ""
Write-Host "  Flask-ADB-toolkit - Windows launcher" -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Locate Git Bash ---
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
    Write-Cyan "    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements"
    Write-Host ""
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $ans = Read-Host "  Install Git for Windows now? [y/N]"
        if ($ans -match '^[Yy]') {
            Write-Host ""
            & winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
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

# --- 2. Locate adb / fastboot ---
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
        $zip  = "$env:TEMP\platform-tools-windows.zip"
        $url  = $null
        $info = $null

        Write-Host "  Looking up Google's checksum for the current release..." -ForegroundColor Cyan
        try {
            $info = Get-PlatformToolsInfo
            $url  = $info.Url
        } catch {
            Write-Warn "Could not read Google's checksum list: $($_.Exception.Message)"
            Write-Warn "Without it, the download cannot be verified."
            $go = Read-Host "  Download the latest platform-tools without verification? [y/N]"
            if ($go -match '^[Yy]') {
                $url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
            }
        }

        if ($url) {
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

            if ($info) {
                $actual = (Get-FileHash -Path $zip -Algorithm SHA1).Hash.ToLower()
                if ($actual -ne $info.Sha1) {
                    Remove-Item $zip -Force -ErrorAction SilentlyContinue
                    Write-Err "Checksum mismatch. The download was discarded and nothing was installed."
                    Write-Host "  Expected: $($info.Sha1)"
                    Write-Host "  Got:      $actual"
                    Read-Host "  Press Enter to exit"
                    exit 1
                }
                Write-Ok "Checksum OK (matches the SHA-1 Google lists)."
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
            Write-Host "  Skipped the download."
            Write-Host "  You can still continue - the toolkit will tell you what is missing."
            Write-Host ""
        }
    } else {
        Write-Host ""
        Write-Host "  You can still continue - the toolkit will tell you what is missing."
        Write-Host ""
    }
}

# --- 3. Locate the .sh next to this launcher ---
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

# --- 4. Launch inside Git Bash ---
$bashScript = $shPath.Replace('\', '/')

Write-Host ""
Write-Host "  Starting Flask-ADB-toolkit..." -ForegroundColor Cyan
Write-Host ""

$bashArgs = @($bashScript) + $ExtraArgs
& $bash @bashArgs
exit $LASTEXITCODE
