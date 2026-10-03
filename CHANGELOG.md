# Changelog

All notable changes to **Flask-ADB-toolkit** are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Config file at `~/.flask-adb-toolkit.conf` (remember default ROM folder, learn mode, etc.).

## [1.5] — 2026-10-03

### Added
- **`payload.bin` support in the ROM flasher.** Modern ROMs (LineageOS, crDroid, EvolutionX, most Nothing/CMF builds) ship a single `payload.bin` container instead of separate `.img` files. The flasher now detects it inside the ROM zip and offers to unpack it with `payload-dumper-go`, then feeds the extracted images straight into the existing flash sequence. If the dumper is missing, it prints the one-line install for your OS.
- **PowerShell launcher for Windows (`flask-adb-toolkit.ps1` + `.bat` wrapper).** Replaces the old cmd-only `.bat`. The launcher finds Git Bash (offers `winget install Git.Git` if missing), checks `adb` / `fastboot` on PATH (offers to download Google's platform-tools into `%LOCALAPPDATA%\Android\platform-tools` and add it to the user PATH), then hands off to the `.sh` inside Git Bash. Windows users now get the same full-colour, mode-aware menu as Linux and macOS.
- **Auto-detect checksum sidecars next to ROM zips.** Before flashing, the toolkit looks for `<zip>.sha256`, `<zip>.sha256sum`, `SHA256SUMS`, `SHA256SUMS.txt`, `checksums.txt` and similar files next to the zip. If one is found, the expected hash is read automatically and verified — no more copy-pasting hashes from a download page.

### Changed
- The ROM flasher now scans `.img` files inside an extracted `payload_extracted/` folder when one exists, falling back to the top-level ROM folder otherwise.

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

## [1.2] — 2026-09-XX

- Generic partition flasher for any Android device.
- Sideload helper and recovery reboot shortcuts.
- Checksum verifier (`sha256sum` / `shasum`).
- Performance pass with resume, deep clean, battery & storage report.

## [1.1] — 2026-09-XX

- Auto-detecting ROM flasher.
- Booted-phone tools: screenshot, APK install, pull/push, logcat.

## [1.0] — 2026-09-XX

- First release. Menu-driven adb & fastboot wrapper.
