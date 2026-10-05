# Changelog

## 1.5.1 — 2026-10-05

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

All notable changes to **Flask-ADB-toolkit** are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Config file at `~/.flask-adb-toolkit.conf` (remember default ROM folder, learn mode, etc.).

## [1.5] — 2026-10-03

### Added
- **`payload.bin` support in the ROM flasher.** Modern ROMs (LineageOS, crDroid, Evolution X, most Nothing/CMF builds) ship a single `payload.bin` container instead of separate `.img` files. The flasher now detects it inside the ROM zip and offers to unpack it with `payload-dumper-go`, then feeds the extracted images straight into the existing flash sequence. If the dumper is missing, it prints the one-line install for your OS.
- **PowerShell launcher for Windows (`flask-adb-toolkit.ps1` + `.bat` wrapper).**
- **Auto-detect checksum sidecars next to ROM zips.**

### Fixed
- **`run()` never reported failure.** PIPESTATUS capture restored.
- Checksum sidecars no longer fail-open when no matching entry.
- Dry-run honesty, per-device resume, serial redaction in support report.
