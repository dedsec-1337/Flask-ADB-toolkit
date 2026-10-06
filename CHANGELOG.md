# Changelog

All notable changes to **Flask-ADB-toolkit** are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `flask-adb-toolkit.ps1`: the filter meant to skip the WSL launcher never matched (regex had `bash\\.exe`), so `System32\bash.exe` could be picked instead of Git Bash. Now `bash\.exe`.
- `flask-adb-toolkit.ps1`: the platform-tools download now uses the exact versioned URL from Google's repository manifest and is checked against the listed SHA-1 before unzipping. A mismatch discards the file and stops. If the manifest cannot be read, the launcher asks before downloading unverified.
- Switch active slot now asks for `YES`, shows the current slot, and does nothing if the chosen slot is already active.
- Flash ROM: if a step fails after earlier images were flashed, the toolkit offers to restore the snapshots it saved for them (newest step first) and lists any partition without a snapshot.
- Flash any partition / Erase a partition: an empty custom partition name is rejected instead of building a target from the slot suffix alone.

### Planned
- Config file at `~/.flask-adb-toolkit.conf` (remember default ROM folder, learn mode, etc.).

## [1.5.3] — 2026-10-06

### Fixed
- README version badge aligned to the actual release (was stuck on 1.5.1 / 1.5.2).
- `docs/llms.txt`: Windows `.bat` correctly described as launcher for the PowerShell script, not a parallel batch rewrite. Also removed the claim of built-in CMF restore presets (there are none), and updated the ROM-flash, requirements and uninstall entries to match the current script.
- `mkdocs.yml` removed. It was unused (Pages deploys `./docs` directly) and its nav pointed at a file that is not in `docs/`.
- CHANGELOG structure: bracketed headings, `[Unreleased]` at top, 1.0–1.2 dates filled in from git history.
- `.github/workflows/shellcheck.yml`: now runs real ShellCheck in addition to `bash -n`.
- Site CSS: removed unused `--accent-red` variable (the active `--red` remains white for selection/focus/CTAs).
- Uninstall notes (README, site, llms.txt) now list the log, support report, snapshot and backup locations.
- Added the missing `docs/og-image.png` (1200×630) referenced by the site's social-preview tags.


## [1.5.2] — 2026-10-05

### Fixed
- **Safety:** `confirm()` no longer replays the previous answer on Ctrl+D / EOF. EOF is treated as cancel.
- All prompt helpers (`ask_yes`, `ask_no`, menu loops, selects, path reads) initialise variables and treat EOF as cancel — no more `set -u` crashes or silent re-runs of the last action.
- **payload-dumper:** `-p` is only passed to `payload-dumper-go`. Python `payload_dumper` / `payload-dumper` extract without that flag (they used to always fail).
- `rom_zip_has_payload` no longer requires `unzip` when a dumper is present — the Go tool can read zips natively.
- `super_empty.img` is detected in both the ROM folder and `payload_extracted/`.
- Performance pass only deletes the resume file when every package compiled successfully (failed packages can still be retried).

## [1.5.1] — 2026-10-05

### Fixed
- **Critical:** `payload-dumper-go -p` now uses a single comma-separated list. Repeated `-p` flags were last-wins, so extraction silently produced zero images (often only trying `super_empty`, which is never in `payload.bin`).
- Multi-zip ROM folders: prompt to pick the ROM zip instead of `head -n1`.
- `restore_stock` accepts `flash_all.bat` (Windows) as promised in the README; falls back to `flash_all.sh`.
- Dry-run (`LEARN=2`) no longer burns 30 s in `wait_for_fastboot` / `wait_for_adb`.
- Ctrl+D / EOF at `select` prompts no longer trips `set -u` unbound-variable exits.
- Nested `payload.bin` members are extracted by path; root-level still preferred.
- Checksum sidecars: when a filename is present on the hash line, require a basename match (no more cross-file false verify). Bare single-hash files still work.
- PowerShell launcher: `winget` installs pass `--accept-source-agreements --accept-package-agreements`.
- `.bat` always pauses so the window does not vanish on success.

## [1.5] — 2026-10-03

### Added
- **`payload.bin` support in the ROM flasher.** Modern ROMs (LineageOS, crDroid, EvolutionX, most Nothing/CMF builds) ship a single `payload.bin` container instead of separate `.img` files. The flasher now detects it inside the ROM zip and offers to unpack it with `payload-dumper-go`, then feeds the extracted images straight into the existing flash sequence. If the dumper is missing, it prints the one-line install for your OS.
- **PowerShell launcher for Windows (`flask-adb-toolkit.ps1` + `.bat` wrapper).** Replaces the old cmd-only `.bat`. The launcher finds Git Bash (offers `winget install Git.Git` if missing), checks `adb` / `fastboot` on PATH (offers to download Google's platform-tools into `%LOCALAPPDATA%\Android\platform-tools` and add it to the user PATH), then hands off to the `.sh` inside Git Bash. Windows users now get the same full-colour, mode-aware menu as Linux and macOS.
- **Auto-detect checksum sidecars next to ROM zips.** Before flashing, the toolkit looks for `<zip>.sha256`, `<zip>.sha256sum`, `SHA256SUMS`, `SHA256SUMS.txt`, `checksums.txt` and similar files next to the zip. If one is found, the expected hash is read automatically and verified — no more copy-pasting hashes from a download page.

### Changed
- The ROM flasher now scans `.img` files inside an extracted `payload_extracted/` folder when one exists, falling back to the top-level ROM folder otherwise.
- `payload-dumper-go` is preferred with selective `-p` partitions and can take the zip directly (unzip fallback retained).
- Checksum verification now runs *before* any payload extraction.

### Fixed
- **`run()` never reported failure.** `local rc` after the pipeline reset `PIPESTATUS`; stop-on-first-failure, unlock/set_active fallbacks and "✓ Flashed" after real errors are restored.
- Checksum sidecars no longer fail-open when the file exists but has no matching entry for the zip (warn + fall through to manual prompt).
- Dry-run no longer prints "✓ Flashed / Erased / Sideloaded / flash_all finished".
- Performance-pass resume file is per-device again.
- Support report redacts long hex strings (possible serials) in addition to `$HOME`.
- PowerShell launcher skips `System32\bash.exe` / WindowsApps stubs, and continues in-session after installing Git or platform-tools.
- `.bat` pauses on non-zero exit so errors stay visible.

## [1.4] — 2026-10-03

### Added
- **Battery pre-flight check.** Before rebooting to the bootloader to flash, the toolkit reads the phone's battery level over adb. Below 30 %, it stops and asks you to confirm.
- **`fastboot set_active` fallback.** Some bootloaders only accept the newer `set_active` spelling. Both forms are now tried.
- **Wait-for-device after reboot.** After `adb reboot bootloader`, the toolkit waits up to 30 s for the bootloader to appear so the next menu shows the real state instead of a stale one.
- **Unlock verification.** After `fastboot flashing unlock` / `oem unlock`, the toolkit re-reads the lock state and tells you whether it actually changed, instead of assuming success.
- **Dry-run honesty for snapshots and screenshots.** `--dry-run` now says *"would save"* instead of *"✓ saved"* for files that were never written.

### Changed
- **`flash_generic` also scans `~/Downloads`.** Image picker no longer only looks at `~/Desktop`, matching the other pickers.
- **Snapshot filenames use a readable separator.** New format: `<partition>__YYYYmmdd_HHMMSS.img`. `restore_snapshot` parses on `__`, no more fixed-width timestamp guessing.

### Fixed
- **`run()` `PIPESTATUS` read split onto its own line.** Same behaviour, but portable across bash versions instead of relying on `local x=…` assignment quirks.

## [1.3] — 2026-10-02

### Added
- **Connection doctor.** Names the real adb problem — `unauthorized`, `offline`, `no permissions`, `multi`, `wait` — and prints the fix step-by-step.
- **Pre-flight gate.** Flashing and erasing refuse to start when the bootloader is locked.
- **Snapshot before flash.** Uses `fastboot fetch` to save the current partition image into `~/flask-adb-snapshots/` before overwriting it. Restore via *Bootloader tools → Restore a saved snapshot*.
- **Command log.** Every adb/fastboot call and its output lands in `~/.flask-adb-toolkit.log` (rotates at 1 MB).
- **Support report.** *Toolkit → Make a support report* bundles version, host, device info and the log tail into `~/Downloads/flask-adb-support-report.txt` for GitHub issues.
- **Back up before wipe.** Booted-phone menu pulls `/sdcard` (or selected folders) plus a third-party app list into `~/flask-adb-backups/<timestamp>/`.
- **Learn mode.** Three states — *off*, *show commands*, *dry-run*. Cycles from *Toolkit → 1*.
- **ROM flasher no longer requires `vendor_boot.img`.** Warns once, offers to continue, and stops at the first failed step instead of flashing on top of it.
- **Flexible ROM folder picker.** Auto-detects `vbmeta`, `vbmeta_system`, `dtbo`, `boot`, `init_boot`, `vendor_boot`, `recovery`, `super_empty` and the ROM zip. Any layout, any device.

### Fixed
- `check_state` now recognises `unauthorized`, `offline`, `recovery`, `no permissions` and multi-device — not just `device` and `sideload`.
- The flasher stops at the first failed step instead of continuing.

## [1.2] — 2026-09-30

- Generic partition flasher for any Android device.
- Sideload helper and recovery reboot shortcuts.
- Checksum verifier (`sha256sum` / `shasum`).
- Performance pass with resume, deep clean, battery & storage report.

## [1.1] — 2026-09-30

- Auto-detecting ROM flasher.
- Booted-phone tools: screenshot, APK install, pull/push, logcat.

## [1.0] — 2026-09-29

- First release. Menu-driven adb & fastboot wrapper.
