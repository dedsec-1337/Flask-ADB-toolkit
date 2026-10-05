#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# ⚗️⚡ Flask-ADB-toolkit
# A fun terminal toolkit that makes flashing ROMs, vendor
# images & partitions easy — even for total beginners.
# https://github.com/dedsec-1337/Flask-ADB-toolkit
#
# Version 1.5.2
#   • payload.bin support in the ROM flasher (payload-dumper-go)
#   • FIX: payload-dumper -p is comma-separated (was last-wins / extracted nothing)
#   • FIX: multi-zip ROM folders prompt instead of head -n1
#   • FIX: restore_stock accepts flash_all.bat
#   • FIX: confirm() and all prompts treat EOF/Ctrl+D as cancel (no more silent YES replay)
#   • FIX: payload-dumper -p only passed to payload-dumper-go (Python tool no longer broken)
#   • FIX: super_empty checked in both ROM dir and payload_extracted/
#   • FIX: performance_pass only clears resume file on full success
#   • FIX: dry-run skips 30s wait loops
#   • FIX: nested payload.bin extraction; stricter checksum sidecar matching
#   • PowerShell launcher for Windows (flask-adb-toolkit.ps1 + .bat)
#   • Auto-detect .sha256 / SHA256SUMS next to ROM zips
#   • Connection doctor: names the real problem (unauthorized,
#     offline, no permissions, several phones) and the fix
#   • Pre-flight check: stops flashing on a locked bootloader
#     and warns below 30 % battery
#   • Snapshot before flash (fastboot fetch) + restore option
#   • Command log (~/.flask-adb-toolkit.log) + support report
#   • Back up before wipe (files + app list)
#   • Learn mode: show every command, or dry-run
#   • ROM flasher no longer demands vendor_boot.img and stops
#     at the first failed step
# Fixes in this build:
#   • run() PIPESTATUS capture restored (stop-on-first-failure works again)
#   • Checksum sidecars no longer fail-open when the hash is missing
#   • Checksum runs before payload extraction
#   • payload-dumper prefers selective -p partitions + direct zip
#   • Dry-run no longer claims "✓ Flashed / Erased / Sideloaded"
#   • Performance-pass resume file is per-device
#   • Support report redacts long hex strings (possible serials)
# ══════════════════════════════════════════════════════════════

# ── Needs bash 4+ (macOS ships bash 3.2) ──
if (( BASH_VERSINFO[0] < 4 )); then
  echo "Flask-ADB-toolkit needs bash 4 or newer. You have $BASH_VERSION."
  echo "macOS ships an old bash. Fix: brew install bash, then run this script again."
  exit 1
fi

VERSION="1.5.2"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BRED='\033[1;31m'; BGREEN='\033[1;32m'; BYELLOW='\033[1;33m'
BCYAN='\033[1;36m'; BBLUE='\033[1;34m'; BMAGENTA='\033[1;35m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Default folder suggestion — not required, just where "Flash ROM" looks first ──
BASE=~/Desktop/flashing

# ── Files the toolkit writes ──
LOGFILE=~/.flask-adb-toolkit.log
SNAPDIR=~/flask-adb-snapshots
BACKUPDIR=~/flask-adb-backups
REPORT=~/Downloads/flask-adb-support-report.txt

# ── State ──
LEARN=0          # 0 = off, 1 = show every command, 2 = dry-run (show, run nothing)
RUN_OUT=""
MODE="none"; DEV="none"; LOCK="unknown"; LOCKRAW=""; SLOT="unknown"
PROBLEM=""; PROBLEM_DETAIL=""; ADB_STATE_RAW=""
# Partitions too big (or pointless) to snapshot
SNAP_SKIP=" userdata super system system_ext vendor product odm cache metadata "

set -uo pipefail
PS3="> "

line(){ echo -e "${DIM}────────────────────────────────────────${RESET}"; }

draw_header(){
  echo -e "${BCYAN}╔═══════════════════════════════════════════╗${RESET}"
  echo -e "${BCYAN}║${RESET} ${BOLD}⚗️ Flask-ADB-toolkit ⚡${RESET} ${BCYAN}║${RESET}"
  echo -e "${BMAGENTA}╚═══════════════════════════════════════════╝${RESET}"
}

# ══════════════════════════════════════════════════════════════
# Helpers: logging, command wrappers, prompts
# ══════════════════════════════════════════════════════════════

strip_ansi(){ sed $'s/\033\\[[0-9;]*m//g'; }

log(){ { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"; } 2>/dev/null || true; }

rotate_log(){
  if [[ -f "$LOGFILE" ]] && (( $(wc -c < "$LOGFILE") > 1048576 )); then
    mv -f "$LOGFILE" "$LOGFILE.old" 2>/dev/null || true
  fi
}

# Learn mode: print the real command before it runs
_show(){
  if (( LEARN >= 1 )); then printf '%b$ %s%b\n' "$DIM" "$*" "$RESET"; fi
  return 0
}

# run: show (learn mode), log, execute, tee output into the log
run(){
  _show "$*"; log "RUN: $*"
  if (( LEARN == 2 )); then log "(dry-run: not executed)"; return 0; fi
  local rc
  "$@" 2>&1 | tee -a "$LOGFILE"
  rc=${PIPESTATUS[0]}
  log "EXIT: $rc"
  return "$rc"
}

# run_tty: same, but keeps the real terminal (progress bars, live output)
run_tty(){
  _show "$*"; log "RUN: $*"
  if (( LEARN == 2 )); then log "(dry-run: not executed)"; return 0; fi
  "$@"
  local rc=$?
  log "EXIT: $rc"
  return "$rc"
}

# run_capture: output goes into $RUN_OUT (and the log), not the screen
run_capture(){
  _show "$*"; log "RUN: $*"
  RUN_OUT=""
  if (( LEARN == 2 )); then log "(dry-run: not executed)"; return 0; fi
  local rc
  RUN_OUT=$("$@" 2>&1)
  rc=$?
  log "$RUN_OUT"
  log "EXIT: $rc"
  return "$rc"
}

# run_to_file FILE cmd...: redirect stdout (binary-safe) into FILE
run_to_file(){
  local out="$1"; shift
  _show "$* > $out"; log "RUN: $* > $out"
  if (( LEARN == 2 )); then log "(dry-run: not executed)"; return 0; fi
  "$@" > "$out"
  local rc=$?
  log "EXIT: $rc"
  return "$rc"
}

confirm(){
  echo -e "${BYELLOW}$1${RESET}"
  local a=""
  read -rp "Type YES to continue: " a || a=""
  [[ "$a" == "YES" ]]
}

ask_yes(){ local a=""; read -rp "$1 [y/N] " a || a=""; [[ "${a,,}" == y* ]]; }
ask_no(){ local a=""; read -rp "$1 [Y/n] " a || a=""; [[ "${a,,}" != n* ]]; }

# Tidy a typed/pasted path: trim spaces, strip quotes, "\ " → " ", expand ~
clean_path(){
  local p="$1"
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"
  case "$p" in
    \'*\') p="${p:1:${#p}-2}" ;;
    \"*\") p="${p:1:${#p}-2}" ;;
  esac
  p="${p//\\ / }"
  # shellcheck disable=SC2088  # case patterns, not paths — $HOME substitution is intentional
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="$HOME/${p:2}" ;;
  esac
  printf '%s' "$p"
}

# sha256sum on Linux, shasum on macOS
sha256_of(){
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

learn_label(){
  case "$LEARN" in
    0) echo "off" ;;
    1) echo "show every command before it runs" ;;
    2) echo "dry-run (show commands, run nothing)" ;;
  esac
}

cycle_learn(){
  LEARN=$(( (LEARN + 1) % 3 ))
  log "learn mode -> $LEARN"
}

# ══════════════════════════════════════════════════════════════
# Device state
# ══════════════════════════════════════════════════════════════

problem_label(){
  case "$PROBLEM" in
    unauthorized) echo "unauthorized (tap Allow on the phone)" ;;
    offline)      echo "offline" ;;
    noperm)       echo "no permissions (Linux udev rules)" ;;
    wait)         echo "still connecting" ;;
    multi)        echo "$PROBLEM_DETAIL phones attached" ;;
    other)        echo "adb state: $PROBLEM_DETAIL" ;;
  esac
}

check_state(){
  MODE="none"; DEV="none"; LOCK="unknown"; LOCKRAW=""; SLOT="unknown"
  PROBLEM=""; PROBLEM_DETAIL=""; ADB_STATE_RAW=""
  local row n=0 first_serial="" first_state="" f="" fn=0 total
  while IFS= read -r row; do
    row="${row%$'\r'}"
    case "$row" in
      ""|"List of devices attached"*|"* daemon"*|"adb server"*) continue ;;
    esac
    n=$((n+1))
    if (( n == 1 )); then
      first_serial=$(awk '{print $1}' <<< "$row")
      first_state=$(awk '{$1=""; sub(/^[ \t]+/,""); print}' <<< "$row")
    fi
  done < <(adb devices 2>/dev/null)

  # Old adb builds can list a bootloader device; fastboot handles that one below.
  if (( n == 1 )) && [[ "$first_state" == bootloader* ]]; then
    n=0; first_serial=""; first_state=""
  fi
  ADB_STATE_RAW="$first_state"

  f=$(fastboot devices 2>/dev/null | sed '/^[[:space:]]*$/d')
  [[ -n "$f" ]] && fn=$(printf '%s\n' "$f" | wc -l | tr -d ' ')

  # More than one phone: refuse to guess. Flashing the wrong one is worse than a nag.
  total=$((n + fn))
  if (( total > 1 )); then
    PROBLEM="multi"; PROBLEM_DETAIL="$total"
    return
  fi

  if (( n == 1 )); then
    DEV="$first_serial"
    case "$first_state" in
      device)
        MODE="adb"
        SLOT=$(adb shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r_')
        LOCKRAW=$(adb shell getprop ro.boot.vbmeta.device_state 2>/dev/null | tr -d '\r')
        [[ -z "$LOCKRAW" ]] && LOCKRAW=$(adb shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r')
        case "$LOCKRAW" in
          unlocked|orange) LOCK="unlocked" ;;
          locked|green) LOCK="locked" ;;
        esac
        ;;
      sideload) MODE="sideload" ;;
      recovery) MODE="recovery" ;;
      unauthorized*) PROBLEM="unauthorized" ;;
      offline*) PROBLEM="offline" ;;
      "no permissions"*) PROBLEM="noperm" ;;
      authorizing*|connecting*) PROBLEM="wait" ;;
      *) PROBLEM="other"; PROBLEM_DETAIL="$first_state" ;;
    esac
    return
  fi

  if (( fn == 1 )); then
    MODE="fastboot"; DEV=$(awk '{print $1}' <<< "$f")
    SLOT=$(fastboot getvar current-slot 2>&1 | grep -o 'current-slot: .*' | cut -d' ' -f2)
    LOCKRAW=$(fastboot getvar unlocked 2>&1 | grep -o 'unlocked: .*' | cut -d' ' -f2)
    case "$LOCKRAW" in
      yes) LOCK="unlocked" ;;
      no) LOCK="locked" ;;
    esac
  fi
}

# Small, silent waits used after reboots so the menu reflects reality.
wait_for_fastboot(){
  (( LEARN == 2 )) && return 0
  local i
  for i in {1..30}; do
    fastboot devices 2>/dev/null | grep -q . && return 0
    sleep 1
  done
  return 1
}

wait_for_adb(){
  (( LEARN == 2 )) && return 0
  local i
  for i in {1..30}; do
    adb devices 2>/dev/null | grep -qw device && return 0
    sleep 1
  done
  return 1
}

# Battery check we can only run while we still have adb. Called before reboots that lead to flashing.
battery_check_adb(){
  [[ "$MODE" == "adb" ]] || return 0
  local lvl
  lvl=$(adb shell dumpsys battery 2>/dev/null | awk -F': *' '/level:/{print $2; exit}' | tr -d '\r ')
  [[ -z "$lvl" ]] && return 0
  if (( lvl < 30 )); then
    echo -e "${BYELLOW}Battery is at ${lvl}%. Below 30% is risky for flashing.${RESET}"
    confirm "Continue anyway?" || return 1
  fi
  return 0
}

identify_device(){
  case "$MODE" in
    fastboot)
      local prod; prod=$(fastboot getvar product 2>&1 | grep -o 'product: .*' | cut -d' ' -f2)
      echo -e "${BOLD}Product:${RESET} ${prod:-unknown}"
      ;;
    adb)
      local model dev
      model=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
      dev=$(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')
      echo -e "${BOLD}Model:${RESET} ${model:-unknown} ${DIM}(${dev:-unknown})${RESET}"
      ;;
  esac
}

status_bar(){
  local dtxt ltxt stxt
  case "$MODE" in
    adb) dtxt="${BGREEN}✓ $DEV — booted${RESET}" ;;
    sideload) dtxt="${BCYAN}✓ $DEV — recovery (sideload)${RESET}" ;;
    recovery) dtxt="${BCYAN}✓ $DEV — recovery (not on the sideload screen)${RESET}" ;;
    fastboot) dtxt="${BMAGENTA}✓ $DEV — bootloader${RESET}" ;;
    *)
      if [[ -n "$PROBLEM" ]]; then
        dtxt="${BYELLOW}⚠ phone attached but unusable: $(problem_label)${RESET}"
      else
        dtxt="${BRED}✗ not connected${RESET}"
      fi
      ;;
  esac
  case "$LOCK" in
    unlocked) ltxt="${BGREEN}🔓 unlocked${RESET}" ;;
    locked) ltxt="${BRED}🔒 locked${RESET}" ;;
    *) ltxt="${BYELLOW}? unknown${RESET}${DIM}${LOCKRAW:+ (raw: $LOCKRAW)}${RESET}" ;;
  esac
  [[ "$SLOT" == "unknown" || -z "$SLOT" ]] && stxt="${BYELLOW}?${RESET}" || stxt="${BCYAN}$SLOT${RESET}"
  echo -e "${BOLD}Device:${RESET} $dtxt"
  echo -e "${BOLD}Bootloader:${RESET} $ltxt ${BOLD}Slot:${RESET} $stxt"
  identify_device
  if [[ -n "$PROBLEM" ]]; then echo -e "${DIM}→ Open the 🩺 Connection doctor for the fix.${RESET}"; fi
  if (( LEARN > 0 )); then echo -e "${BYELLOW}🎓 Learn mode: $(learn_label)${RESET}"; fi
  return 0
}

check_slot(){
  check_state
  case "$MODE" in
    fastboot|adb)
      echo -e "${BOLD}Active slot:${RESET} ${BCYAN}${SLOT}${RESET}"
      ;;
    none)
      echo -e "${BRED}No device found — connect the phone to check.${RESET}"
      ;;
    *)
      echo -e "${YELLOW}Slot can't be read in $MODE mode. Boot the phone or open the bootloader.${RESET}"
      ;;
  esac
}

device_info(){
  check_state
  case "$MODE" in
    fastboot)
      echo -e "${CYAN}Querying bootloader variables...${RESET}"
      fastboot getvar product 2>&1
      fastboot getvar current-slot 2>&1
      fastboot getvar unlocked 2>&1
      fastboot getvar serialno 2>&1
      ;;
    adb)
      echo -e "${BOLD}Model:${RESET} $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Codename:${RESET} $(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Android:${RESET} $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Build:${RESET} $(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Security patch:${RESET} $(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Kernel:${RESET} $(adb shell uname -r 2>/dev/null | tr -d '\r')"
      ;;
    sideload|recovery)
      echo -e "${YELLOW}Device info is only available when booted or in the bootloader.${RESET}"
      ;;
    *) echo -e "${BRED}No device found.${RESET}" ;;
  esac
}

need_mode(){
  if [[ "$MODE" != "$1" ]]; then
    if [[ -n "$PROBLEM" ]]; then
      echo -e "${BRED}A phone is attached but unusable: $(problem_label). Open the Connection doctor.${RESET}"
    else
      echo -e "${BRED}This needs the phone in $1 mode. It's currently: $MODE.${RESET}"
    fi
    return 1
  fi
  return 0
}

# ══════════════════════════════════════════════════════════════
# Connection doctor
# ══════════════════════════════════════════════════════════════

connection_doctor(){
  echo -e "${BOLD}${CYAN}🩺 Connection doctor${RESET}"
  line
  local t missing=0
  for t in adb fastboot; do
    if command -v "$t" >/dev/null 2>&1; then
      echo -e "${GREEN}✓${RESET} $t found: ${DIM}$(command -v "$t")${RESET}"
    else
      echo -e "${BRED}✗ $t not found.${RESET} Install it (README → Quick start / Windows guide), then run this again."
      missing=1
    fi
  done
  (( missing )) && return
  echo -e "${DIM}$(adb version 2>/dev/null | head -n1)${RESET}"
  line
  check_state
  echo -e "${BOLD}adb reports:${RESET} ${ADB_STATE_RAW:-nothing}"
  echo

  case "$PROBLEM" in
    unauthorized)
      echo -e "${BYELLOW}The phone sees this computer but has not trusted it yet (unauthorized).${RESET}"
      echo "  1. Unlock the phone screen."
      echo "  2. Look for \"Allow USB debugging?\". Tick \"Always allow from this computer\", tap Allow."
      echo "  3. No prompt? Unplug and replug, or switch USB debugging off and on."
      echo "  4. Still nothing? Developer options → \"Revoke USB debugging authorizations\""
      echo "     (not every ROM has it), then replug."
      ;;
    offline)
      echo -e "${BYELLOW}adb sees the phone but cannot talk to it (offline). Usually a stale connection.${RESET}"
      echo "  1. Unplug, wait a few seconds, replug."
      echo "  2. Switch USB debugging off and on."
      echo "  3. Restart the adb server (offered below)."
      ;;
    noperm)
      echo -e "${BYELLOW}Linux sees the phone, but your user is not allowed to use it (no permissions).${RESET}"
      echo "  adb needs udev rules for the phone and your user in the right group."
      echo "  A maintained rules set: github.com/M0Rf30/android-udev-rules"
      echo "  In short: install its rules file, add your user to the adbusers group,"
      echo "  reload udev, run adb kill-server, replug the phone."
      ;;
    wait)
      echo -e "${BYELLOW}The phone is still connecting or authorizing.${RESET}"
      echo "  Wait a few seconds and open the doctor again."
      ;;
    multi)
      echo -e "${BYELLOW}$PROBLEM_DETAIL phones/devices are attached.${RESET}"
      echo "  The toolkit refuses to act with more than one: it could flash the wrong phone."
      echo "  Unplug everything except the phone you want to work on."
      ;;
    other)
      echo -e "${BYELLOW}adb reports a state the toolkit doesn't know: $PROBLEM_DETAIL${RESET}"
      echo "  Replug the phone. If it stays, copy that state into a GitHub issue."
      ;;
    *)
      case "$MODE" in
        adb) echo -e "${BGREEN}✓ Phone connected and booted. Nothing to fix.${RESET}" ;;
        sideload) echo -e "${BGREEN}✓ Phone is in recovery on the sideload screen.${RESET}" ;;
        recovery)
          echo -e "${BYELLOW}Phone is in recovery, but not on the sideload screen.${RESET}"
          echo "  To sideload: Apply update → Apply from ADB (wording varies by recovery)."
          ;;
        fastboot) echo -e "${BGREEN}✓ Phone connected in the bootloader. Nothing to fix.${RESET}" ;;
        none)
          echo -e "${BYELLOW}Nothing found by adb or fastboot.${RESET} In order:"
          echo "  1. Cable: use a data cable. Charge-only cables look identical."
          echo "  2. Try another USB port. Skip hubs."
          echo "  3. Booted phone: screen unlocked, USB debugging on (Developer options)."
          echo "     Try File transfer mode in the phone's USB notification."
          echo "  4. Phone on the bootloader screen but not listed: that is the cable, a missing"
          echo "     driver (Windows) or missing udev rules (Linux)."
          echo "  5. Restart the adb server (offered below)."
          ;;
      esac
      ;;
  esac

  case "$PROBLEM:$MODE" in
    unauthorized:*|offline:*|wait:*|:none)
      echo
      if ask_yes "Restart the adb server now?"; then
        run adb kill-server
        run adb start-server
        echo -e "${GREEN}Done.${RESET} Replug the phone, then open the doctor again."
      fi
      ;;
  esac
}

# ══════════════════════════════════════════════════════════════
# Reboots
# ══════════════════════════════════════════════════════════════

reboot_bootloader(){
  case "$MODE" in
    adb|sideload|recovery)
      battery_check_adb || return
      run adb reboot bootloader
      echo -e "${DIM}Waiting for the bootloader...${RESET}"
      if wait_for_fastboot; then
        echo -e "${GREEN}✓ Bootloader is up.${RESET}"
      else
        echo -e "${YELLOW}Did not see the bootloader within 30 s. It may still be booting — check the screen.${RESET}"
      fi
      ;;
    fastboot) echo -e "${YELLOW}Already in bootloader.${RESET}" ;;
    *) echo -e "${RED}No device found.${RESET}" ;;
  esac
}

reboot_system(){
  case "$MODE" in
    fastboot) run fastboot reboot ;;
    sideload|recovery) run adb reboot ;;
    adb) echo -e "${YELLOW}Already booted.${RESET}" ;;
    *) echo -e "${RED}No device found.${RESET}" ;;
  esac
}

reboot_recovery(){
  case "$MODE" in
    adb) run adb reboot recovery ;;
    fastboot) run fastboot reboot recovery ;;
    sideload|recovery) echo -e "${YELLOW}Already in recovery.${RESET}" ;;
    *) echo -e "${RED}No device found.${RESET}" ;;
  esac
}

reboot_fastbootd(){
  need_mode fastboot || return
  echo -e "${CYAN}Some logical-partition operations (like wipe-super) need this mode instead of plain bootloader.${RESET}"
  run fastboot reboot fastboot
}

# ══════════════════════════════════════════════════════════════
# Safety: pre-flight, snapshots
# ══════════════════════════════════════════════════════════════

# Stop before flashing/erasing when the bootloader is locked (or can't be read).
preflight(){
  case "$LOCK" in
    unlocked) return 0 ;;
    locked)
      echo -e "${BRED}Stopped: the bootloader is locked. Flashing would be refused or fail.${RESET}"
      echo -e "${DIM}Unlock it first: Bootloader tools → Unlock bootloader (this wipes the phone).${RESET}"
      return 1
      ;;
    *)
      echo -e "${BYELLOW}Could not read the bootloader lock state.${RESET}"
      confirm "Continue anyway?"
      ;;
  esac
}

# snapshot_partition TARGET: try to save the current partition with `fastboot fetch`.
# Returns 0 saved, 1 failed or unsupported, 2 skipped (too big / not worth it).
snapshot_partition(){
  local target="$1" base out why
  base="${target%_[ab]}"
  if [[ "$SNAP_SKIP" == *" $base "* ]]; then
    echo -e "${DIM}• $target: data or too large, no snapshot.${RESET}"
    return 2
  fi
  mkdir -p "$SNAPDIR" || return 1
  out="$SNAPDIR/${target}__$(date +%Y%m%d_%H%M%S).img"
  if run_capture fastboot fetch "$target" "$out" && { (( LEARN == 2 )) || [[ -s "$out" ]]; }; then
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: would save)${RESET} $target → $out"
    else
      echo -e "${GREEN}✓ saved${RESET} $target → $out"
    fi
    return 0
  fi
  rm -f "$out"
  if (( LEARN == 2 )); then
    echo -e "${DIM}(dry-run: no real fetch happened)${RESET} $target"
    return 0
  fi
  why=$(tail -n1 <<< "$RUN_OUT")
  echo -e "${YELLOW}✗ $target not saved${RESET}${DIM}${why:+ — $why}${RESET}"
  return 1
}

# One partition: snapshot it, and if that fails ask before going on.
snapshot_gate(){
  local rc
  snapshot_partition "$1"; rc=$?
  if (( rc == 1 )); then
    echo -e "${DIM}Not every phone supports this, and some only allow it from fastbootd (Bootloader tools → Reboot to fastbootd).${RESET}"
    confirm "No snapshot saved for $1. Continue anyway?" || return 1
  fi
  return 0
}

restore_snapshot(){
  need_mode fastboot || return
  preflight || return
  local snaps=() f="" name target
  while IFS= read -r f; do snaps+=("$f"); done < <(ls -1t "$SNAPDIR"/*.img 2>/dev/null)
  if (( ${#snaps[@]} == 0 )); then
    echo -e "${YELLOW}No snapshots saved yet (they live in $SNAPDIR).${RESET}"
    return
  fi
  echo -e "${BOLD}Which snapshot?${RESET} ${DIM}(newest first)${RESET}"
  f=""
  select f in "${snaps[@]}" "Cancel"; do [[ -n "${f:-}" ]] && break; echo "Pick a number."; done
  [[ -z "${f:-}" || "$f" == "Cancel" ]] && return
  name=$(basename "$f")
  # Snapshot files are named <partition>__YYYYmmdd_HHMMSS.img
  if [[ "$name" == *"__"* ]]; then
    target="${name%%__*}"
  else
    target=""
  fi
  if [[ -z "$target" ]]; then
    read -rp "Partition to flash it to: " target
  fi
  confirm "Flash $name back to $target?\nThis restores that partition only. It does not bring back wiped data." || return
  if run fastboot flash "$target" "$f"; then
    echo -e "${GREEN}✓ Restored $target.${RESET}"
  else
    echo -e "${BRED}✗ Restore failed. Details: $LOGFILE${RESET}"
  fi
}

# ══════════════════════════════════════════════════════════════
# Generic partition tools — work on any device in fastboot
# ══════════════════════════════════════════════════════════════

pick_slot_suffix(){
  local opts=("No slot suffix" "A" "B") so=""
  echo -e "${BOLD}Slot:${RESET}" >&2
  select so in "${opts[@]}"; do
    case "$so" in
      "No slot suffix") echo ""; return 0 ;;
      "A") echo "_a"; return 0 ;;
      "B") echo "_b"; return 0 ;;
      *) echo "Pick a number." >&2 ;;
    esac
  done
}

flash_generic(){
  need_mode fastboot || return
  preflight || return
  echo -e "${BOLD}${CYAN}⚡ Generic partition flash${RESET}"
  line
  echo -e "${BOLD}Step 1 — partition:${RESET}"
  local partitions=(boot init_boot recovery vendor_boot dtbo vbmeta vbmeta_system system vendor product super userdata "custom (type it)") p=""
  select p in "${partitions[@]}"; do [[ -n "${p:-}" ]] && break; echo "Pick a number."; done
  [[ -z "${p:-}" ]] && return
  local partition="$p"
  [[ "$partition" == "custom (type it)" ]] && read -rp "Partition name: " partition
  echo
  local suffix; suffix=$(pick_slot_suffix)
  local target="${partition}${suffix}"
  echo
  echo -e "${BOLD}Step 2 — image file:${RESET}"
  local imgs=() f=""
  while IFS= read -r f; do imgs+=("$f"); done < <(find ~/Desktop ~/Downloads -maxdepth 4 -iname '*.img' 2>/dev/null)
  imgs+=("Type a custom path")
  select f in "${imgs[@]}"; do [[ -n "${f:-}" ]] && break; echo "Pick a number."; done
  [[ -z "${f:-}" ]] && return
  local image="$f"
  if [[ "$image" == "Type a custom path" ]]; then read -rp "Full path to image: " image; fi
  image=$(clean_path "$image")
  [[ -f "$image" ]] || { echo -e "${RED}File not found: $image${RESET}"; return; }
  echo
  local extra_flags="" flags=()
  case "$partition" in
    userdata) echo -e "${BRED}Warning: flashing userdata erases all user data.${RESET}" ;;
    super) echo -e "${BRED}Warning: flashing super directly replaces the whole dynamic-partition layout.${RESET}" ;;
    system|vendor|product) echo -e "${BYELLOW}Note: this is usually a logical partition inside super. A plain flash may need extra steps on some devices.${RESET}" ;;
    vbmeta|vbmeta_system)
      if confirm "Also set --disable-verity --disable-verification on this vbmeta flash? (needed for most custom ROMs/kernels)"; then
        extra_flags="--disable-verity --disable-verification "
        flags=(--disable-verity --disable-verification)
      fi
      ;;
  esac
  echo -e "${BOLD}Command:${RESET} fastboot ${extra_flags}flash $target \"$(basename "$image")\""
  confirm "Flash $(basename "$image") to $target?" || return
  snapshot_gate "$target" || return
  if run fastboot ${flags[@]+"${flags[@]}"} flash "$target" "$image"; then
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: would flash)${RESET} $target"
    else
      echo -e "${GREEN}✓ Flashed $target.${RESET}"
    fi
  else
    echo -e "${BRED}✗ Flash failed. Details: $LOGFILE${RESET}"
  fi
}

erase_partition(){
  need_mode fastboot || return
  preflight || return
  echo -e "${BOLD}${CYAN}🧹 Erase a partition${RESET}"
  line
  local partitions=(cache userdata metadata dtbo vbmeta boot recovery "custom (type it)") p
  local p=""
  select p in "${partitions[@]}"; do [[ -n "${p:-}" ]] && break; echo "Pick a number."; done
  [[ -z "${p:-}" ]] && return
  local partition="$p"
  [[ "$partition" == "custom (type it)" ]] && read -rp "Partition name: " partition
  echo
  local suffix; suffix=$(pick_slot_suffix)
  local target="${partition}${suffix}"
  case "$partition" in
    userdata) echo -e "${BRED}Warning: erases all user data.${RESET}" ;;
    metadata) echo -e "${BRED}Warning: can affect encryption state.${RESET}" ;;
  esac
  confirm "Erase $target?" || return
  snapshot_gate "$target" || return
  if run fastboot erase "$target"; then
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: would erase)${RESET} $target"
    else
      echo -e "${GREEN}✓ Erased $target.${RESET}"
    fi
  else
    echo -e "${BRED}✗ Erase failed. Details: $LOGFILE${RESET}"
  fi
}

show_fastboot_vars(){
  need_mode fastboot || return
  echo -e "${CYAN}Querying every fastboot variable...${RESET}"
  run fastboot getvar all
}

unlock_bootloader(){
  need_mode fastboot || return
  if [[ "$LOCK" == "unlocked" ]]; then
    echo -e "${GREEN}Already unlocked. Nothing to do.${RESET}"; return
  fi
  echo -e "${CYAN}Step: fastboot flashing unlock, then confirm on the phone with volume + power.${RESET}"
  confirm "This wipes the phone completely.\nBack up first: boot the phone → Booted-phone tools → Back up before wipe. Nothing can be backed up from this mode." || return
  run fastboot flashing unlock || run fastboot oem unlock
  echo -e "${DIM}Re-reading lock state...${RESET}"
  sleep 1
  check_state
  case "$LOCK" in
    unlocked) echo -e "${BGREEN}✓ Bootloader is now unlocked.${RESET}" ;;
    locked)   echo -e "${BYELLOW}Still shows locked. The prompt may be waiting on the phone — confirm it there, then re-open this menu.${RESET}" ;;
    *)        echo -e "${DIM}Could not read lock state. Check the phone screen.${RESET}" ;;
  esac
}

switch_slot(){
  need_mode fastboot || return
  local s
  while true; do
    read -rp "Slot to switch to (a/b): " s
    s="${s,,}"
    [[ "$s" == "a" || "$s" == "b" ]] && break
    echo -e "${RED}Enter a or b.${RESET}"
  done
  if run fastboot --set-active="$s" || run fastboot set_active "$s"; then
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: would set active slot to)${RESET} $s"
    else
      echo -e "${GREEN}Active slot set to $s.${RESET}"
    fi
  else
    echo -e "${BRED}✗ Could not set the slot. Details: $LOGFILE${RESET}"
  fi
}

# ══════════════════════════════════════════════════════════════
# Sideload / recovery tools — work on any device
# ══════════════════════════════════════════════════════════════

pick_zip(){
  local zips=() f
  while IFS= read -r f; do zips+=("$f"); done < <(find ~/Desktop ~/Downloads -maxdepth 4 -iname '*.zip' 2>/dev/null)
  zips+=("Type a custom path")
  echo -e "${BOLD}Which package?${RESET}" >&2
  local f=""
  select f in "${zips[@]}"; do [[ -n "${f:-}" ]] && break; echo "Pick a number." >&2; done
  [[ -z "${f:-}" ]] && return 1
  local zip="$f"
  if [[ "$zip" == "Type a custom path" ]]; then read -rp "Full path to zip: " zip; fi
  zip=$(clean_path "$zip")
  [[ -f "$zip" ]] || { echo -e "${RED}File not found: $zip${RESET}" >&2; return 1; }
  echo "$zip"
}

sideload_package(){
  if [[ "$MODE" != "sideload" ]]; then
    echo -e "${BRED}Phone needs to be in recovery, at the \"Apply from ADB\" screen.${RESET}"
    echo -e "${DIM}Reboot to recovery first, then in the recovery menu choose Apply update → Apply from ADB.${RESET}"
    return
  fi
  local zip; zip=$(pick_zip) || return
  echo -e "${CYAN}Sideloading $(basename "$zip")...${RESET}"
  run_tty adb sideload "$zip"
}

# verify_checksum [FILE]: returns 0 on match or when only showing the hash, 1 on mismatch/error
verify_checksum(){
  local f="${1:-}" expected="" actual
  echo -e "${BOLD}${CYAN}🔎 Verify a file's checksum${RESET}"
  line
  if [[ -z "$f" ]]; then read -rp "Path to file: " f || f=""; fi
  f=$(clean_path "$f")
  [[ -f "$f" ]] || { echo -e "${RED}File not found: $f${RESET}"; return 1; }
  read -rp "Expected SHA256 (leave blank to just show it): " expected || expected=""
  echo -e "${DIM}Hashing (may take a moment for large files)...${RESET}"
  actual=$(sha256_of "$f") || { echo -e "${RED}Neither sha256sum nor shasum found on this computer.${RESET}"; return 1; }
  echo -e "${BOLD}SHA256:${RESET} $actual"
  if [[ -n "$expected" ]]; then
    expected="${expected//[[:space:]]/}"
    expected="${expected,,}"
    if [[ "$actual" == "$expected" ]]; then
      echo -e "${GREEN}✓ Matches. Safe to flash.${RESET}"
    else
      echo -e "${BRED}✗ Does NOT match. Do not flash this file — re-download it.${RESET}"
      return 1
    fi
  fi
  return 0
}

# ══════════════════════════════════════════════════════════════
# payload.bin support — modern ROMs ship one container, not images
# ══════════════════════════════════════════════════════════════

# Does the zip contain a payload.bin at its root?
rom_zip_has_payload(){
  local zip="$1"
  # Prefer unzip listing; if missing, still return true so extract_payload can try
  # (payload-dumper-go reads zips natively — no need to block the offer).
  if command -v unzip >/dev/null 2>&1; then
    unzip -Z1 "$zip" 2>/dev/null | grep -qE '(^|/)payload\.bin$'
  else
    return 0
  fi
}

# Locate a payload-dumper binary on PATH.
find_payload_dumper(){
  local cmd
  for cmd in payload-dumper-go payload_dumper payload-dumper; do
    if command -v "$cmd" >/dev/null 2>&1; then echo "$cmd"; return 0; fi
  done
  return 1
}

payload_dumper_install_hint(){
  echo -e "${BYELLOW}payload-dumper-go is not installed. Get it here:${RESET}"
  echo -e "  ${DIM}Linux / macOS (Go):${RESET} go install github.com/ssut/payload-dumper-go@latest"
  echo -e "  ${DIM}macOS (Homebrew):${RESET}  brew install payload-dumper-go"
  echo -e "  ${DIM}Arch (AUR):${RESET}        yay -S payload-dumper-go-bin"
  echo -e "  ${DIM}Windows / any:${RESET}    prebuilt binaries → https://github.com/ssut/payload-dumper-go/releases"
  echo -e "  ${DIM}(put the binary on PATH or next to this script)${RESET}"
}

# Extract needed partitions from a ROM zip that contains payload.bin.
# Prefer feeding the zip directly to payload-dumper-go (it understands payload.bin
# inside a zip). Fall back to unzip + dump if that fails.
# Only extracts the partitions the flasher actually uses.
# Returns 0 on success, 1 on any failure (already cleaned up).
extract_payload(){
  local zip="$1" outdir="$2" dumper
  # super_empty is never inside payload.bin (standalone fastboot-style file). Drop it.
  # payload-dumper-go -p takes a single comma-separated list (repeated -p is last-wins).
  local needed=(vbmeta vbmeta_system dtbo boot init_boot vendor_boot recovery)
  local plist
  plist=$(IFS=,; printf '%s' "${needed[*]}")
  dumper=$(find_payload_dumper) || { payload_dumper_install_hint; return 1; }
  mkdir -p "$outdir" || return 1
  echo -e "${CYAN}Unpacking selected partitions with $dumper... (this can take a minute)${RESET}"

  # -p is payload-dumper-go only. Python payload_dumper / payload-dumper reject it.
  local use_p=0
  [[ "$dumper" == *payload-dumper-go* ]] && use_p=1

  # Try feeding the zip directly (payload-dumper-go accepts zip containing payload.bin)
  if (( use_p )); then
    if run_tty "$dumper" -o "$outdir" -p "$plist" "$zip"; then
      rm -f "$outdir/payload.bin" 2>/dev/null
      return 0
    fi
  else
    if run_tty "$dumper" -o "$outdir" "$zip"; then
      rm -f "$outdir/payload.bin" 2>/dev/null
      return 0
    fi
  fi

  # Fallback: unzip root-level payload.bin then dump
  echo -e "${DIM}Direct zip dump failed — falling back to unzip + dump.${RESET}"
  local tmp="$outdir/.payload_tmp"
  rm -rf "$tmp"; mkdir -p "$tmp"
  # Prefer the root-level path if present; otherwise extract the first payload.bin found
  local payload_member
  payload_member=$(unzip -Z1 "$zip" 2>/dev/null | grep -E '(^|/)payload\.bin$' | head -n1)
  if [[ -z "$payload_member" ]]; then
    echo -e "${BRED}No payload.bin inside the zip.${RESET}"
    rm -rf "$tmp"; return 1
  fi
  if ! run unzip -o "$zip" "$payload_member" -d "$tmp"; then
    echo -e "${BRED}Could not pull payload.bin out of the zip.${RESET}"
    rm -rf "$tmp"; return 1
  fi
  local payload_file="$tmp/$payload_member"
  if [[ ! -f "$payload_file" ]]; then
    # unzip may flatten; try basename
    payload_file="$tmp/$(basename "$payload_member")"
  fi
  if [[ ! -f "$payload_file" ]]; then
    echo -e "${BRED}payload.bin was not produced by unzip.${RESET}"
    rm -rf "$tmp"; return 1
  fi
  if (( use_p )); then
    if ! run_tty "$dumper" -o "$outdir" -p "$plist" "$payload_file"; then
      echo -e "${BRED}payload-dumper failed. Details: $LOGFILE${RESET}"
      rm -rf "$tmp"; return 1
    fi
  else
    if ! run_tty "$dumper" -o "$outdir" "$payload_file"; then
      echo -e "${BRED}payload-dumper failed. Details: $LOGFILE${RESET}"
      rm -rf "$tmp"; return 1
    fi
  fi
  rm -rf "$tmp"
  rm -f "$outdir/payload.bin" 2>/dev/null
  return 0
}

# ══════════════════════════════════════════════════════════════
# Checksum sidecar auto-detection — look for .sha256 / SHA256SUMS
# ══════════════════════════════════════════════════════════════

# Find a checksum file that likely belongs to ZIP. Echoes its path.
find_checksum_file(){
  local zip="$1" dir base c
  dir=$(dirname "$zip"); base=$(basename "$zip")
  local candidates=(
    "${zip}.sha256" "${zip}.sha256sum" "${zip}.sha256.txt"
    "${dir}/${base}.sha256" "${dir}/${base}.sha256sum"
    "${dir}/SHA256SUMS" "${dir}/SHA256SUMS.txt"
    "${dir}/sha256sums.txt" "${dir}/CHECKSUMS.sha256"
    "${dir}/checksums.txt" "${dir}/checksum.txt"
  )
  for c in "${candidates[@]}"; do
    [[ -f "$c" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# Extract the expected hash for TARGET (or a lone hash) from CHECKFILE.
expected_hash_for(){
  local checkfile="$1" target="$2"
  local base line hash file
  base=$(basename "$target")
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == "#"* ]] && continue
    hash="${line%%[[:space:]]*}"
    [[ "$hash" =~ ^[0-9a-fA-F]{64}$ ]] || continue
    file="${line#"$hash"}"
    file="${file#"${file%%[![:space:]]*}"}"   # trim leading whitespace
    file="${file#\*}"                          # binary marker
    file="${file##*/}"                         # basename
    # Filename present → must match basename. Bare hash line handled below.
    if [[ -n "$file" && "$file" == "$base" ]]; then
      printf '%s' "${hash,,}"; return 0
    fi
  done < "$checkfile"
  # Single-line / bare-hash file (no filename on the line at all)
  local bare=1
  while IFS= read -r line; do
    line="${line%$'
'}"
    [[ -z "$line" || "$line" == "#"* ]] && continue
    if [[ ! "$line" =~ ^[0-9a-fA-F]{64}$ ]]; then bare=0; break; fi
  done < "$checkfile"
  if (( bare )); then
    hash=$(head -n1 "$checkfile" | tr -d '[:space:]')
    if [[ "$hash" =~ ^[0-9a-fA-F]{64}$ ]]; then
      printf '%s' "${hash,,}"; return 0
    fi
  fi
  return 1
}

# Verify TARGET against a sidecar next to it. Silent if no sidecar.
# Returns 0 (match or no sidecar), 1 (mismatch / hash tool missing).
verify_sidecar_if_present(){
  local target="$1" checkfile expected actual
  checkfile=$(find_checksum_file "$target") || return 0
  expected=$(expected_hash_for "$checkfile" "$target")
  if [[ -z "$expected" ]]; then
    echo -e "${BYELLOW}Checksum file found ($(basename "$checkfile")) but no entry for $(basename "$target").${RESET}"
    echo -e "${DIM}Falling through to manual verification prompt.${RESET}"
    return 2
  fi
  echo -e "${BCYAN}Found $(basename "$checkfile"). Verifying $(basename "$target")...${RESET}"
  actual=$(sha256_of "$target") || {
    echo -e "${YELLOW}No sha256 tool found; skipping verification.${RESET}"
    return 0
  }
  if [[ "$actual" == "$expected" ]]; then
    echo -e "${BGREEN}✓ Checksum matches.${RESET}"
    return 0
  fi
  echo -e "${BRED}✗ Checksum does NOT match!${RESET}"
  echo -e "${DIM}Expected: $expected${RESET}"
  echo -e "${DIM}Actual:   $actual${RESET}"
  return 1
}

# ══════════════════════════════════════════════════════════════
# ROM folder flashing — CMF Phone 2 Pro (Galaga) was the first target,
# but the auto-detect works for any ROM folder laid out the same way.
# ══════════════════════════════════════════════════════════════

FLASHABLE_IMGS=(vbmeta vbmeta_system dtbo boot init_boot vendor_boot recovery super_empty)

# A folder is worth offering if it holds a ROM zip or at least one known image.
rom_dir_ok(){
  local d="$1" n
  [[ -n "$(find "$d" -maxdepth 1 -iname '*.zip' 2>/dev/null | head -n1)" ]] && return 0
  for n in "${FLASHABLE_IMGS[@]}"; do [[ -f "$d/$n.img" ]] && return 0; done
  return 1
}

pick_rom(){
  local dirs=() d
  if [[ -d "$BASE" ]]; then
    for d in "$BASE"/*/; do
      d="${d%/}"
      [[ -d "$d" ]] && rom_dir_ok "$d" && dirs+=("$d")
    done
  fi
  dirs+=("Type a custom folder path")
  if [[ ${#dirs[@]} -eq 1 ]]; then
    echo -e "${DIM}No ROM folders found under $BASE — type the path directly.${RESET}" >&2
  else
    echo -e "${BOLD}Which ROM?${RESET}" >&2
  fi
  select d in "${dirs[@]}"; do
    [[ -z "$d" ]] && { echo "Pick a number." >&2; continue; }
    if [[ "$d" == "Type a custom folder path" ]]; then
      read -rp "Full path to the ROM folder: " d || d=""
      d=$(clean_path "$d")
    fi
    [[ -d "$d" ]] || { echo -e "${RED}Folder not found: $d${RESET}" >&2; return 1; }
    rom_dir_ok "$d" || { echo -e "${RED}Nothing flashable in that folder (no ROM zip, no known .img files).${RESET}" >&2; return 1; }
    echo "$d"; return 0
  done
}

# One flash step. On failure, stop the whole flow instead of flashing on top of it.
flash_step(){
  if run "$@"; then return 0; fi
  echo -e "${BRED}✗ Step failed: $*${RESET}"
  case "$*" in
    *wipe-super*) echo -e "${DIM}wipe-super often needs fastbootd: Bootloader tools → Reboot to fastbootd, then try again.${RESET}" ;;
  esac
  echo -e "${DIM}Stopped here so nothing is flashed on top of a failed step. Log: $LOGFILE${RESET}"
  return 1
}

flash_rom(){
  need_mode fastboot || return
  preflight || return

  local dir zip
  dir=$(pick_rom) || return
  # Prefer an interactive pick when multiple zips sit in the folder (GApps/Magisk common)
  local -a zips_in_dir=()
  local z
  while IFS= read -r z; do [[ -n "$z" ]] && zips_in_dir+=("$z"); done < <(find "$dir" -maxdepth 1 -iname '*.zip' 2>/dev/null | sort)
  if (( ${#zips_in_dir[@]} == 0 )); then
    zip=""
  elif (( ${#zips_in_dir[@]} == 1 )); then
    zip="${zips_in_dir[0]}"
  else
    echo -e "${BOLD}Multiple zips in that folder — pick the ROM zip:${RESET}"
    local f=""
    select f in "${zips_in_dir[@]}" "Cancel"; do
      [[ -n "${f:-}" ]] && break
      echo "Pick a number."
    done
    [[ -z "${f:-}" || "$f" == "Cancel" ]] && return
    zip="$f"
  fi

  # Checksum verification: prefer a sidecar next to the zip when present
  # (runs before any payload extraction so a bad download is caught early)
  if [[ -n "$zip" ]]; then
    local checkfile cs_rc
    if checkfile=$(find_checksum_file "$zip"); then
      echo -e "${BCYAN}Found $(basename "$checkfile") next to the zip.${RESET}"
      verify_sidecar_if_present "$zip"
      cs_rc=$?
      if (( cs_rc == 1 )); then
        echo -e "${BRED}Stopped. Sort out the checksum first.${RESET}"
        return
      elif (( cs_rc == 2 )); then
        # Sidecar present but no matching entry — fall through to manual prompt
        if ask_no "Verify the ROM zip's SHA256 before flashing? (recommended)"; then
          verify_checksum "$zip" || { echo -e "${BRED}Stopped. Sort out the checksum first.${RESET}"; return; }
        fi
      fi
    elif ask_no "Verify the ROM zip's SHA256 before flashing? (recommended)"; then
      verify_checksum "$zip" || { echo -e "${BRED}Stopped. Sort out the checksum first.${RESET}"; return; }
    fi
  fi



  # ── payload.bin handling ──
  local payload_dir=""
  if [[ -n "$zip" ]] && rom_zip_has_payload "$zip"; then
    echo -e "${BCYAN}This ROM ships a payload.bin (modern format).${RESET}"
    echo -e "${DIM}The toolkit can extract its partitions so the flasher can use them.${RESET}"
    if command -v unzip >/dev/null 2>&1; then
      if ask_yes "Extract payload.bin into $(basename "$dir")/payload_extracted now?"; then
        payload_dir="$dir/payload_extracted"
        if ! extract_payload "$zip" "$payload_dir"; then
          payload_dir=""
          echo -e "${BYELLOW}Continuing without extracted payload images.${RESET}"
        fi
      fi
    else
      echo -e "${BYELLOW}unzip is not installed — cannot unpack payload.bin.${RESET}"
      echo -e "${DIM}Install unzip, then run Flash ROM again.${RESET}"
    fi
  fi

  # Where to look for .img files: prefer the extracted payload folder if present
  local img_src="$dir"
  [[ -n "$payload_dir" && -d "$payload_dir" ]] && img_src="$payload_dir"

  echo -e "${BOLD}${CYAN}Detected in $(basename "$img_src"):${RESET}"
  declare -A found
  local name
  for name in vbmeta vbmeta_system dtbo boot init_boot vendor_boot recovery; do
    if [[ -f "$img_src/$name.img" ]]; then
      found[$name]=1
      echo -e " ${GREEN}✓${RESET} $name.img"
    fi
  done
  if [[ -f "$img_src/super_empty.img" ]]; then
    found[super_empty]=1; echo -e " ${GREEN}✓${RESET} super_empty.img"
  elif [[ -f "$dir/super_empty.img" ]]; then
    found[super_empty]=1; echo -e " ${GREEN}✓${RESET} super_empty.img ${DIM}(from ROM folder)${RESET}"
  fi
  [[ -f "$img_src/system.img" ]] && echo -e " ${DIM}• system.img (present, not auto-flashed — see note below)${RESET}"
  [[ -n "$zip" ]] && echo -e " ${GREEN}✓${RESET} $(basename "$zip")"
  echo

  if [[ -z "${found[vendor_boot]:-}" && -z "${found[recovery]:-}" ]]; then
    echo -e "${BYELLOW}No vendor_boot.img or recovery.img detected.${RESET}"
    echo -e "${DIM}The phone must already have a recovery that can sideload the ROM zip.${RESET}"
    confirm "Continue without flashing a recovery?" || return
  fi
  if [[ -z "$zip" ]]; then
    echo -e "${BYELLOW}No ROM zip found here. You can still flash the images, then sideload manually with the \"Sideload a package\" option.${RESET}"
  fi

  echo -e "${CYAN}Plan: save a snapshot of what's there, flash the detected images in order, wipe super if present, then reboot to recovery"
  [[ -n "$zip" ]] && echo -e "and sideload $(basename "$zip")."
  [[ -f "$img_src/system.img" ]] && echo -e "${BYELLOW}Note: system.img won't be touched automatically. It's normally installed by the ROM zip itself — use \"Flash any partition\" if a guide specifically tells you to flash it directly.${RESET}"

  confirm "Proceed? This wipes data and system.\nBack up first: boot the phone → Booted-phone tools → Back up before wipe." || return

  # Snapshot what is about to be overwritten
  echo -e "${CYAN}Trying to save the current images first...${RESET}"
  local saved=0 failed=0 part rc
  for part in vbmeta vbmeta_system dtbo boot init_boot vendor_boot recovery; do
    [[ -n "${found[$part]:-}" ]] || continue
    snapshot_partition "$part"; rc=$?
    case "$rc" in 0) saved=$((saved+1)) ;; 1) failed=$((failed+1)) ;; esac
  done
  if (( failed > 0 && saved == 0 )); then
    echo -e "${BYELLOW}No snapshots were possible on this phone in this mode.${RESET}"
    echo -e "${DIM}Some phones only allow it from fastbootd. Snapshots never bring back wiped data.${RESET}"
    confirm "Flash without a safety snapshot?" || return
  elif (( failed > 0 )); then
    echo -e "${DIM}$saved saved, $failed could not be saved. Only the saved ones can be restored later.${RESET}"
  fi

  [[ -n "${found[vbmeta]:-}" ]] && { flash_step fastboot --disable-verity --disable-verification flash vbmeta "$img_src/vbmeta.img" || return; }
  [[ -n "${found[vbmeta_system]:-}" ]] && { flash_step fastboot --disable-verity --disable-verification flash vbmeta_system "$img_src/vbmeta_system.img" || return; }
  [[ -n "${found[dtbo]:-}" ]] && { flash_step fastboot flash dtbo "$img_src/dtbo.img" || return; }
  [[ -n "${found[boot]:-}" ]] && { flash_step fastboot flash boot "$img_src/boot.img" || return; }
  [[ -n "${found[init_boot]:-}" ]] && { flash_step fastboot flash init_boot "$img_src/init_boot.img" || return; }
  if [[ -n "${found[super_empty]:-}" ]]; then
    local se="$img_src/super_empty.img"
    [[ -f "$se" ]] || se="$dir/super_empty.img"
    flash_step fastboot wipe-super "$se" || return
  fi
  [[ -n "${found[vendor_boot]:-}" ]] && { flash_step fastboot flash vendor_boot "$img_src/vendor_boot.img" || return; }
  [[ -n "${found[recovery]:-}" ]] && { flash_step fastboot flash recovery "$img_src/recovery.img" || return; }
  flash_step fastboot reboot recovery || return

  echo -e "${YELLOW}On the phone: Factory reset → Format data, then Apply update → Apply from ADB.${RESET}"
  read -rp "Once the phone is waiting for the package, press Enter..."
  if [[ -n "$zip" ]]; then
    if run_tty adb sideload "$zip"; then
      if (( LEARN == 2 )); then
        echo -e "${DIM}(dry-run: would sideload)${RESET} $(basename "$zip")"
      else
        echo -e "${GREEN}✓ Sideload finished.${RESET}"
      fi
    else
      echo -e "${BRED}✗ Sideload failed. Details: $LOGFILE${RESET}"
    fi
  else
    echo -e "${DIM}No zip to sideload — use the \"Sideload a package\" option once you're ready.${RESET}"
  fi
}

restore_stock(){
  need_mode fastboot || return
  preflight || return
  local dir="" script
  read -rp "Full path to the stock firmware folder: " dir || dir=""
  dir=$(clean_path "$dir")
  [[ -d "$dir" ]] || { echo -e "${RED}Folder not found: $dir${RESET}"; return; }
  echo -e "${CYAN}Steps: run flash_all script, wipe data, flash both slots, boot to stock.${RESET}"
  confirm "Restores stock from $(basename "$dir"). Wipes the phone.\nBack up first: boot the phone → Booted-phone tools → Back up before wipe." || return

  # Prefer .bat on Windows/Git Bash when present (README promises this); else .sh
  if [[ -f "$dir/flash_all.bat" ]]; then
    script="flash_all.bat"
  elif [[ -f "$dir/flash_all.sh" ]]; then
    script="flash_all.sh"
  else
    echo -e "${RED}No flash_all.sh or flash_all.bat in that folder. This expects the layout your device's stock-firmware archive uses (for Nothing/CMF phones: spike0en/nothing_flasher, galaga-tetris branch).${RESET}"
    return
  fi

  if [[ "$script" == *.bat ]]; then
    if ( cd "$dir" && run_tty cmd.exe /c "$script" ); then
      if (( LEARN == 2 )); then
        echo -e "${DIM}(dry-run: would run $script)${RESET}"
      else
        echo -e "${GREEN}✓ $script finished.${RESET}"
      fi
    else
      # Git Bash without cmd.exe? Try bash-compatible fallback if a .sh exists
      if [[ -f "$dir/flash_all.sh" ]]; then
        echo -e "${YELLOW}cmd.exe unavailable or failed — trying flash_all.sh instead.${RESET}"
        if ( cd "$dir" && run_tty bash flash_all.sh ); then
          echo -e "${GREEN}✓ flash_all.sh finished.${RESET}"
        else
          echo -e "${BRED}✗ flash_all reported a failure. Details: $LOGFILE${RESET}"
        fi
      else
        echo -e "${BRED}✗ $script reported a failure. Details: $LOGFILE${RESET}"
      fi
    fi
  else
    if ( cd "$dir" && run_tty bash flash_all.sh ); then
      if (( LEARN == 2 )); then
        echo -e "${DIM}(dry-run: would run flash_all.sh)${RESET}"
      else
        echo -e "${GREEN}✓ flash_all.sh finished.${RESET}"
      fi
    else
      echo -e "${BRED}✗ flash_all.sh reported a failure. Details: $LOGFILE${RESET}"
    fi
  fi
}

# ══════════════════════════════════════════════════════════════
# Booted-phone maintenance
# ══════════════════════════════════════════════════════════════

performance_pass(){
  need_mode adb || return
  # Resume file is per-device so two phones never skip each other's apps.
  local progress=~/".flask-adb-compile-progress-${DEV//[^A-Za-z0-9._-]/_}"
  local pkgs=() p failed=() i=0 total
  mapfile -t pkgs < <(adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort)
  total=${#pkgs[@]}
  echo -e "${CYAN}Trims app cache, then force-compiles every app for speed.${RESET}"
  run adb shell pm trim-caches 999G
  _show "adb shell cmd package compile -m speed -f <each package>"
  if (( LEARN == 2 )); then return; fi
  if [[ -f "$progress" ]]; then
    echo -e "${BCYAN}Resuming from last run — finished apps are skipped.${RESET}"
  fi
  log "performance pass: $total packages"
  echo -e "${CYAN}Compiling $total packages... (Ctrl+C = pause, just run again to resume)${RESET}"
  for p in "${pkgs[@]}"; do
    ((i++))
    if [[ -f "$progress" ]] && grep -qx "$p" "$progress"; then
      continue
    fi
    printf "\r${DIM}[%d/%d] %s${RESET} " "$i" "$total" "$p"
    if adb shell cmd package compile -m speed -f "$p" >/dev/null 2>&1; then
      echo "$p" >> "$progress"
    else
      failed+=("$p")
    fi
  done
  echo
  log "performance pass finished: ${#failed[@]} package(s) not compiled"
  if ((${#failed[@]})); then
    echo -e "${BYELLOW}⚠️ ${#failed[@]} package(s) could not be compiled — usually harmless system overlays:${RESET}"
    printf ' • %s\n' "${failed[@]}"
    echo -e "${DIM}Everything else compiled fine. The pass finished on its own — nothing is stuck.${RESET}"
    echo -e "${DIM}Run the Performance pass again anytime to retry the failed ones.${RESET}"
  else
    echo -e "${BGREEN}⚡ Done — every app compiled for speed.${RESET}"
    rm -f "$progress"
  fi
}

deep_clean(){
  need_mode adb || return
  echo -e "${CYAN}Scans for leftover app data, empty folders, and thumbnail cache.${RESET}"
  local installed b d e; installed=$(adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort)
  for b in /sdcard/Android/data /sdcard/Android/obb; do
    echo -e "${BLUE}-- $b --${RESET}"
    for d in $(adb shell "ls $b 2>/dev/null" | tr -d '\r'); do
      grep -qx "$d" <<< "$installed" || echo -e "${YELLOW}orphaned:${RESET} $b/$d"
    done
  done
  echo -e "${BLUE}-- empty directories --${RESET}"
  adb shell "find /sdcard/Android/data /sdcard/Android/obb -type d -empty" 2>/dev/null | tr -d '\r' | while read -r e; do
    [[ -n "$e" ]] && echo -e "${YELLOW}empty:${RESET} $e"
  done
  echo
  if confirm "Clear thumbnail cache too? (regenerates on its own, always safe)"; then
    run adb shell rm -rf /sdcard/DCIM/.thumbnails /sdcard/Pictures/.thumbnails
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: would clear thumbnail cache)${RESET}"
    else
      echo -e "${GREEN}Thumbnail cache cleared.${RESET}"
    fi
  fi
  echo -e "${DIM}To remove an orphaned folder: adb shell rm -rf '/sdcard/Android/data/<name>'${RESET}"
}

battery_storage(){
  need_mode adb || return
  echo -e "${BBLUE}-- Battery --${RESET}"
  adb shell dumpsys battery 2>/dev/null | grep -E "level|status|health|temperature"
  echo -e "${BBLUE}-- Storage --${RESET}"
  adb shell df -h /data /sdcard 2>/dev/null
}

view_logcat(){
  need_mode adb || return
  echo -e "${CYAN}Live log. Ctrl+C to stop and return to the menu.${RESET}"
  trap ':' INT
  run_tty adb logcat
  trap - INT
}

take_screenshot(){
  need_mode adb || return
  local dir=~/Downloads
  mkdir -p "$dir"
  local f
  f="$dir/screenshot_$(date +%Y%m%d_%H%M%S).png"
  if run_to_file "$f" adb exec-out screencap -p && { (( LEARN == 2 )) || [[ -s "$f" ]]; }; then
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: would save)${RESET} $f"
    else
      echo -e "${GREEN}Saved: $f${RESET}"
    fi
  else
    rm -f "$f"
    if (( LEARN == 2 )); then
      echo -e "${DIM}(dry-run: no real screenshot happened)${RESET}"
    else
      echo -e "${BRED}✗ Screenshot failed.${RESET}"
    fi
  fi
}

install_apk(){
  need_mode adb || return
  local apks=() f
  while IFS= read -r f; do apks+=("$f"); done < <(find ~/Desktop ~/Downloads -maxdepth 3 -iname '*.apk' 2>/dev/null)
  apks+=("Type a custom path")
  echo -e "${BOLD}Which APK?${RESET}"
  local f=""
  select f in "${apks[@]}"; do [[ -n "${f:-}" ]] && break; echo "Pick a number."; done
  [[ -z "${f:-}" ]] && return
  local apk="$f"
  if [[ "$apk" == "Type a custom path" ]]; then read -rp "Full path to APK: " apk; fi
  apk=$(clean_path "$apk")
  [[ -f "$apk" ]] || { echo -e "${RED}File not found: $apk${RESET}"; return; }
  run_tty adb install "$apk"
}

pull_file(){
  need_mode adb || return
  local src dst
  read -rp "Path on phone to pull: " src || src=""
  read -rp "Save to (local path, blank = current folder): " dst || dst=""
  dst=$(clean_path "$dst")
  [[ -z "$dst" ]] && dst="."
  run_tty adb pull "$src" "$dst"
}

push_file(){
  need_mode adb || return
  local src dst
  read -rp "Local file to push: " src || src=""
  src=$(clean_path "$src")
  [[ -f "$src" ]] || { echo -e "${RED}File not found: $src${RESET}"; return; }
  read -rp "Destination path on phone: " dst || dst=""
  run_tty adb push "$src" "$dst"
}

# Copy files + an app list to this computer before anything that wipes the phone.
backup_phone(){
  need_mode adb || return
  echo -e "${BOLD}${CYAN}💾 Back up before wipe${RESET}"
  line
  echo -e "${BYELLOW}This copies your files and a list of your apps to this computer.${RESET}"
  echo -e "${BYELLOW}It does NOT save app data, contacts, messages or settings.${RESET}"
  echo -e "${BYELLOW}Use the phone's own backup (Google / the maker's cloud) for those.${RESET}"
  echo
  echo -e "${DIM}Storage on the phone:${RESET}"
  adb shell df -h /sdcard 2>/dev/null
  echo
  local opts=("Photos & files (DCIM, Pictures, Download, Documents)" "Everything in /sdcard (can be many GB)" "App list only" "Cancel") o=""
  select o in "${opts[@]}"; do [[ -n "${o:-}" ]] && break; echo "Pick a number."; done
  [[ -z "${o:-}" ]] && return
  [[ "$o" == "Cancel" ]] && return
  local dest d
  dest="$BACKUPDIR/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$dest" || { echo -e "${RED}Could not create $dest${RESET}"; return; }

  _show "adb shell pm list packages -3 > $dest/third-party-apps.txt"
  log "RUN: adb shell pm list packages -3 > $dest/third-party-apps.txt"
  if (( LEARN != 2 )); then
    adb shell pm list packages -3 2>/dev/null | tr -d '\r' | sed 's/^package://' | sort > "$dest/third-party-apps.txt"
    echo -e "${GREEN}✓ App list:${RESET} $(wc -l < "$dest/third-party-apps.txt" | tr -d ' ') apps → $dest/third-party-apps.txt"
  fi

  if [[ "$o" == Photos* ]]; then
    for d in DCIM Pictures Download Documents; do
      echo -e "${CYAN}Copying /sdcard/$d/ ...${RESET}"
      run_tty adb pull "/sdcard/$d/" "$dest/" || echo -e "${YELLOW}• /sdcard/$d/ skipped or incomplete (missing folder?).${RESET}"
    done
  elif [[ "$o" == Everything* ]]; then
    echo -e "${CYAN}Copying all of /sdcard/ ...${RESET}"
    run_tty adb pull "/sdcard/" "$dest/" || echo -e "${YELLOW}• Some files could not be copied.${RESET}"
  fi
  echo
  echo -e "${BGREEN}Backup folder:${RESET} $dest"
  (( LEARN == 2 )) || echo -e "${DIM}Size: $(du -sh "$dest" 2>/dev/null | awk '{print $1}')${RESET}"
}

# ══════════════════════════════════════════════════════════════
# Support report + toolkit menu
# ══════════════════════════════════════════════════════════════

support_report(){
  check_state
  mkdir -p "$(dirname "$REPORT")" 2>/dev/null
  local mf="" prod=""
  if [[ "$MODE" == "fastboot" ]]; then
    mf=$(fastboot getvar max-fetch-size 2>&1 | grep -o 'max-fetch-size: .*' | cut -d' ' -f2)
    prod=$(fastboot getvar product 2>&1 | grep -o 'product: .*' | cut -d' ' -f2)
  fi
  {
    echo "Flask-ADB-toolkit support report"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Toolkit:   $VERSION"
    echo "Host:      $(uname -srm)"
    echo "Bash:      $BASH_VERSION"
    echo "adb:       $(adb version 2>/dev/null | head -n1)"
    echo "fastboot:  $(fastboot --version 2>/dev/null | head -n1)"
    echo
    echo "== Phone =="
    echo "Mode:      $MODE"
    echo "adb state: ${ADB_STATE_RAW:-none}"
    [[ -n "$PROBLEM" ]] && echo "Problem:   $PROBLEM $PROBLEM_DETAIL"
    case "$MODE" in
      adb)
        echo "Model:     $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
        echo "Codename:  $(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
        echo "Android:   $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
        echo "Build:     $(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
        echo "Patch:     $(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')"
        echo "Kernel:    $(adb shell uname -r 2>/dev/null | tr -d '\r')"
        echo "Slot:      ${SLOT:-?}   Lock: $LOCK"
        ;;
      fastboot)
        echo "Product:   ${prod:-unknown}"
        echo "Slot:      ${SLOT:-?}   Lock: $LOCK"
        echo "max-fetch-size: ${mf:-not reported}   (snapshots need this)"
        ;;
    esac
    echo
    echo "== Recent log (last 60 lines) =="
    if [[ -s "$LOGFILE" ]]; then
      tail -n 60 "$LOGFILE" | sed "s|$HOME|~|g" | sed -E "s/[0-9A-Fa-f]{8,}/[serial-redacted]/g" | strip_ansi
    else
      echo "(empty)"
    fi
  } > "$REPORT"
  echo -e "${GREEN}✓ Saved:${RESET} $REPORT"
  echo -e "${DIM}Home folder shows as ~ and long hex strings (possible serials) are redacted. Read it once before sharing.${RESET}"
  echo -e "Paste it into a new issue: ${BOLD}https://github.com/dedsec-1337/Flask-ADB-toolkit/issues/new${RESET}"
}

show_log(){
  if [[ -s "$LOGFILE" ]]; then
    echo -e "${DIM}$LOGFILE — last 40 lines${RESET}"
    tail -n 40 "$LOGFILE"
  else
    echo -e "${DIM}The log is empty. Anything you flash or run through the menus lands in $LOGFILE.${RESET}"
  fi
}

toolkit_menu(){
  local c=""
  while true; do
    clear; draw_header; line
    echo -e "${BOLD}${BLUE}🧰 Toolkit${RESET}"
    echo
    echo -e "1) 🎓 Learn mode — now: ${BOLD}$(learn_label)${RESET}"
    echo -e "   ${DIM}Press 1 to cycle: off → show commands → dry-run${RESET}"
    echo -e "2) 🧾 Make a support report ${DIM}(to attach to a GitHub issue)${RESET}"
    echo -e "3) 📜 Show the recent log"
    line
    echo -e "0) Back"
    echo
    read -rp "> " c; echo
    case "$c" in
      1) cycle_learn; continue ;;
      2) support_report ;;
      3) show_log ;;
      0) return ;;
      *) echo -e "${RED}Unknown option${RESET}" ;;
    esac
    read -rp $'\nPress Enter to continue...'
  done
}

# ══════════════════════════════════════════════════════════════
# Menus
# ══════════════════════════════════════════════════════════════

bootloader_menu(){
  local c=""
  while true; do
    clear; draw_header; line; check_state; status_bar; line
    echo -e "${BOLD}${MAGENTA}🔧 Bootloader tools${RESET}"
    echo
    echo -e "1) 🔓 Unlock bootloader"
    echo -e "2) ⚡ Flash any partition ${DIM}(generic — any device)${RESET}"
    echo -e "3) 🔄 Switch active slot"
    echo -e "4) 🧹 Erase a partition ${DIM}(generic)${RESET}"
    echo -e "5) 🛠️ Reboot to fastbootd ${DIM}(needed for some logical-partition ops)${RESET}"
    echo -e "6) 📋 Show all fastboot variables"
    line
    echo -e "${DIM}ROM folders under $BASE:${RESET}"
    echo -e "7) 📦 Flash ROM ${DIM}(auto-detects boot/dtbo/init_boot/vbmeta/vendor_boot/recovery, unpacks payload.bin)${RESET}"
    echo -e "8) ⏮ Restore stock firmware ${DIM}(pick any folder with a flash_all.sh)${RESET}"
    line
    echo -e "${DIM}Safety net:${RESET}"
    echo -e "9) ↩️ Restore a saved snapshot ${DIM}(from $SNAPDIR)${RESET}"
    line
    echo -e "0) Back"
    echo
    read -rp "> " c; echo
    case "$c" in
      1) unlock_bootloader ;;
      2) flash_generic ;;
      3) switch_slot ;;
      4) erase_partition ;;
      5) reboot_fastbootd ;;
      6) show_fastboot_vars ;;
      7) flash_rom ;;
      8) restore_stock ;;
      9) restore_snapshot ;;
      0) return ;;
      *) echo -e "${RED}Unknown option${RESET}" ;;
    esac
    read -rp $'\nPress Enter to continue...'
  done
}

booted_menu(){
  local c=""
  while true; do
    clear; draw_header; line; check_state; status_bar; line
    echo -e "${BOLD}${GREEN}📱 Booted-phone tools${RESET}"
    echo
    echo -e "${DIM}Maintenance:${RESET}"
    echo -e "1) ⚡ Performance pass"
    echo -e "2) 🧹 Deep clean"
    line
    echo -e "${DIM}Diagnostics:${RESET}"
    echo -e "3) 🔋 Battery & storage"
    echo -e "4) 📜 Live logcat"
    line
    echo -e "${DIM}Files:${RESET}"
    echo -e "5) 📷 Take screenshot"
    echo -e "6) 📥 Install an APK"
    echo -e "7) ⬇ Pull a file from phone"
    echo -e "8) ⬆ Push a file to phone"
    echo -e "9) 💾 Back up before wipe ${DIM}(files + app list)${RESET}"
    line
    echo -e "0) Back"
    echo
    read -rp "> " c; echo
    case "$c" in
      1) performance_pass ;;
      2) deep_clean ;;
      3) battery_storage ;;
      4) view_logcat ;;
      5) take_screenshot ;;
      6) install_apk ;;
      7) pull_file ;;
      8) push_file ;;
      9) backup_phone ;;
      0) return ;;
      *) echo -e "${RED}Unknown option${RESET}" ;;
    esac
    read -rp $'\nPress Enter to continue...'
  done
}

usage(){
  cat <<EOF
Flask-ADB-toolkit $VERSION
Usage: $(basename "$0") [option]
  --show-commands   print every adb/fastboot command before it runs
  --dry-run         print the commands, run none of them
  --version         print the version
  --help            this text
EOF
}

parse_args(){
  local arg
  for arg in "$@"; do
    case "$arg" in
      --show-commands|--learn) LEARN=1 ;;
      --dry-run) LEARN=2 ;;
      --version|-v) echo "Flask-ADB-toolkit $VERSION"; exit 0 ;;
      --help|-h) usage; exit 0 ;;
      *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
    esac
  done
}

main(){
  local n c=""
  log "toolkit start v$VERSION"
  while true; do
    clear; draw_header; line
    check_state; status_bar
    line
    echo
    n=1
    if [[ "$MODE" == "none" ]]; then
      echo -e "${BOLD}$n)${RESET} 🩺 Connection doctor"; opt_doc=$n; ((n++))
    fi
    if [[ "$MODE" == "fastboot" ]]; then
      echo -e "${BOLD}$n)${RESET} 🔧 Bootloader tools"; opt_bl=$n; ((n++))
      echo -e "${BOLD}$n)${RESET} Reboot to system"; opt_rs=$n; ((n++))
      echo -e "${BOLD}$n)${RESET} Reboot to recovery"; opt_rec=$n; ((n++))
    fi
    if [[ "$MODE" == "adb" ]]; then
      echo -e "${BOLD}$n)${RESET} 📱 Booted-phone tools"; opt_bt=$n; ((n++))
      echo -e "${BOLD}$n)${RESET} Reboot to recovery"; opt_rec=$n; ((n++))
    fi
    if [[ "$MODE" == "adb" || "$MODE" == "sideload" || "$MODE" == "recovery" ]]; then
      echo -e "${BOLD}$n)${RESET} Reboot to bootloader"; opt_rb=$n; ((n++))
    fi
    if [[ "$MODE" == "sideload" ]]; then
      echo -e "${BOLD}$n)${RESET} 📤 Sideload a package"; opt_sideload=$n; ((n++))
    fi
    if [[ "$MODE" == "sideload" || "$MODE" == "recovery" ]]; then
      echo -e "${BOLD}$n)${RESET} Reboot to system"; opt_rs=$n; ((n++))
    fi
    if [[ "$MODE" != "none" ]]; then
      echo -e "${BOLD}$n)${RESET} ℹ️ Device info"; opt_info=$n; ((n++))
    fi
    echo -e "${BOLD}$n)${RESET} Check active slot"; opt_slot=$n; ((n++))
    echo -e "${BOLD}$n)${RESET} 🔎 Verify a file's checksum"; opt_check=$n; ((n++))
    if [[ "$MODE" != "none" ]]; then
      echo -e "${BOLD}$n)${RESET} 🩺 Connection doctor"; opt_doc=$n; ((n++))
    fi
    echo -e "${BOLD}$n)${RESET} 🧰 Toolkit ${DIM}(learn mode, support report, log)${RESET}"; opt_tools=$n; ((n++))
    echo -e "${BOLD}0)${RESET} Exit"
    echo
    case "$MODE" in
      none)
        if [[ -n "$PROBLEM" ]]; then
          echo -e "${DIM}A phone is attached but unusable. Start with the Connection doctor.${RESET}"
        else
          echo -e "${DIM}No phone detected. Start with the Connection doctor.${RESET}"
        fi
        ;;
      recovery) echo -e "${DIM}Phone is in recovery. To sideload: Apply update → Apply from ADB.${RESET}" ;;
    esac
    echo
    read -rp "> " c; echo
    if [[ -n "${opt_bl:-}" && "$c" == "$opt_bl" ]]; then bootloader_menu
    elif [[ -n "${opt_rs:-}" && "$c" == "$opt_rs" ]]; then reboot_system; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_rec:-}" && "$c" == "$opt_rec" ]]; then reboot_recovery; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_bt:-}" && "$c" == "$opt_bt" ]]; then booted_menu
    elif [[ -n "${opt_rb:-}" && "$c" == "$opt_rb" ]]; then reboot_bootloader; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_sideload:-}" && "$c" == "$opt_sideload" ]]; then sideload_package; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_info:-}" && "$c" == "$opt_info" ]]; then device_info; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_slot:-}" && "$c" == "$opt_slot" ]]; then check_slot; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_check:-}" && "$c" == "$opt_check" ]]; then verify_checksum; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_doc:-}" && "$c" == "$opt_doc" ]]; then connection_doctor; read -rp $'\nPress Enter...'
    elif [[ -n "${opt_tools:-}" && "$c" == "$opt_tools" ]]; then toolkit_menu
    elif [[ "$c" == "0" ]]; then log "toolkit exit"; exit 0
    else echo -e "${RED}Unknown option${RESET}"; read -rp $'\nPress Enter...'
    fi
    unset opt_bl opt_rs opt_rec opt_bt opt_rb opt_sideload opt_info opt_slot opt_check opt_doc opt_tools
  done
}

# Run only when executed, not when sourced (lets the functions be tested).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  parse_args "$@"
  rotate_log
  main
fi