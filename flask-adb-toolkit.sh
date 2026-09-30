#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  ⚗️⚡ Flask-ADB-toolkit
#  A fun terminal toolkit that makes flashing ROMs, vendor
#  images & partitions easy — even for total beginners.
#  https://github.com/dedsec-1337/Flask-ADB-toolkit
#  Version 1.2 — ROM flashing now auto-detects boot, dtbo,
#  init_boot, vbmeta and vbmeta_system in the ROM folder and
#  flashes whichever are present. Added direct reboot-to-recovery,
#  a standalone sideload command, and a checksum verifier.
# ══════════════════════════════════════════════════════════════
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BRED='\033[1;31m'; BGREEN='\033[1;32m'; BYELLOW='\033[1;33m'
BCYAN='\033[1;36m'; BBLUE='\033[1;34m'; BMAGENTA='\033[1;35m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Device-specific config (CMF Phone 2 Pro / Galaga) ──
# Edit or delete this block for a different phone.
BASE=~/Desktop/cmf
STOCK_NEW="$BASE/Galaga_B4.1-260812-1729"
STOCK_OLD="$BASE/Galaga_V3.2-250507-1139_3.2"

set -uo pipefail
PS3="> "

line(){ echo -e "${DIM}────────────────────────────────────────${RESET}"; }

draw_header(){
  echo -e "${BCYAN}╔═══════════════════════════════════════════╗${RESET}"
  echo -e "${BCYAN}║${RESET}    ${BOLD}⚗️  Flask-ADB-toolkit  ⚡${RESET}    ${BCYAN}║${RESET}"
  echo -e "${BMAGENTA}╚═══════════════════════════════════════════╝${RESET}"
}

confirm(){
  echo -e "${BYELLOW}$1${RESET}"
  read -rp "Type YES to continue: " a
  [[ "$a" == "YES" ]]
}

check_state(){
  MODE="none"; DEV="none"; LOCK="unknown"; LOCKRAW=""; SLOT="unknown"
  local a f
  a=$(adb devices 2>/dev/null | sed -n '2p')
  if [[ -n "$a" ]]; then
    DEV=$(echo "$a" | awk '{print $1}')
    local st; st=$(echo "$a" | awk '{print $2}')
    if [[ "$st" == "sideload" ]]; then
      MODE="sideload"
    elif [[ "$st" == "device" ]]; then
      MODE="adb"
      SLOT=$(adb shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r_')
      LOCKRAW=$(adb shell getprop ro.boot.vbmeta.device_state 2>/dev/null | tr -d '\r')
      [[ -z "$LOCKRAW" ]] && LOCKRAW=$(adb shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r')
      case "$LOCKRAW" in
        unlocked|orange) LOCK="unlocked" ;;
        locked|green) LOCK="locked" ;;
      esac
    fi
    return
  fi
  f=$(fastboot devices 2>/dev/null)
  if [[ -n "$f" ]]; then
    MODE="fastboot"; DEV=$(echo "$f" | awk '{print $1}')
    SLOT=$(fastboot getvar current-slot 2>&1 | grep -o 'current-slot: .*' | cut -d' ' -f2)
    LOCKRAW=$(fastboot getvar unlocked 2>&1 | grep -o 'unlocked: .*' | cut -d' ' -f2)
    case "$LOCKRAW" in
      yes) LOCK="unlocked" ;;
      no) LOCK="locked" ;;
    esac
  fi
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
    fastboot) dtxt="${BMAGENTA}✓ $DEV — bootloader${RESET}" ;;
    *) dtxt="${BRED}✗ not connected${RESET}" ;;
  esac
  case "$LOCK" in
    unlocked) ltxt="${BGREEN}🔓 unlocked${RESET}" ;;
    locked) ltxt="${BRED}🔒 locked${RESET}" ;;
    *) ltxt="${BYELLOW}? unknown${RESET}${DIM}${LOCKRAW:+ (raw: $LOCKRAW)}${RESET}" ;;
  esac
  [[ "$SLOT" == "unknown" || -z "$SLOT" ]] && stxt="${BYELLOW}?${RESET}" || stxt="${BCYAN}$SLOT${RESET}"
  echo -e "${BOLD}Device:${RESET} $dtxt"
  echo -e "${BOLD}Bootloader:${RESET} $ltxt   ${BOLD}Slot:${RESET} $stxt"
  identify_device
}

check_slot(){
  check_state
  case "$MODE" in
    fastboot|adb)
      echo -e "${BOLD}Active slot:${RESET} ${BCYAN}${SLOT}${RESET}"
      ;;
    *)
      echo -e "${BRED}No device found — connect the phone to check.${RESET}"
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
      echo -e "${BOLD}Model:${RESET}          $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Codename:${RESET}       $(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Android:${RESET}        $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Build:${RESET}          $(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Security patch:${RESET} $(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')"
      echo -e "${BOLD}Kernel:${RESET}         $(adb shell uname -r 2>/dev/null | tr -d '\r')"
      ;;
    *) echo -e "${BRED}No device found.${RESET}" ;;
  esac
}

need_mode(){
  if [[ "$MODE" != "$1" ]]; then
    echo -e "${BRED}This needs the phone in $1 mode. It's currently: $MODE.${RESET}"
    return 1
  fi
  return 0
}

reboot_bootloader(){
  case "$MODE" in
    adb|sideload) adb reboot bootloader ;;
    fastboot) echo -e "${YELLOW}Already in bootloader.${RESET}" ;;
    *) echo -e "${RED}No device found.${RESET}" ;;
  esac
}
reboot_system(){
  case "$MODE" in
    fastboot) fastboot reboot ;;
    sideload) adb reboot ;;
    adb) echo -e "${YELLOW}Already booted.${RESET}" ;;
    *) echo -e "${RED}No device found.${RESET}" ;;
  esac
}
reboot_recovery(){
  case "$MODE" in
    adb) adb reboot recovery ;;
    fastboot) fastboot reboot recovery ;;
    sideload) echo -e "${YELLOW}Already in recovery.${RESET}" ;;
    *) echo -e "${RED}No device found.${RESET}" ;;
  esac
}
reboot_fastbootd(){
  need_mode fastboot || return
  echo -e "${CYAN}Some logical-partition operations (like wipe-super) need this mode instead of plain bootloader.${RESET}"
  fastboot reboot fastboot
}

# ── Generic partition tools — work on any device in fastboot ──
pick_slot_suffix(){
  local opts=("No slot suffix" "A" "B") so
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
  echo -e "${BOLD}${CYAN}⚡ Generic partition flash${RESET}"
  line

  echo -e "${BOLD}Step 1 — partition:${RESET}"
  local partitions=(boot init_boot recovery vendor_boot dtbo vbmeta vbmeta_system system vendor product super userdata "custom (type it)")
  select p in "${partitions[@]}"; do [[ -n "$p" ]] && break; echo "Pick a number."; done
  local partition="$p"
  [[ "$partition" == "custom (type it)" ]] && read -rp "Partition name: " partition

  echo
  local suffix; suffix=$(pick_slot_suffix)
  local target="${partition}${suffix}"

  echo
  echo -e "${BOLD}Step 2 — image file:${RESET}"
  local imgs=() f
  while IFS= read -r f; do imgs+=("$f"); done < <(find ~/Desktop -maxdepth 4 -iname '*.img' 2>/dev/null)
  imgs+=("Type a custom path")
  select f in "${imgs[@]}"; do [[ -n "$f" ]] && break; echo "Pick a number."; done
  local image="$f"
  [[ "$image" == "Type a custom path" ]] && read -rp "Full path to image: " image
  [[ -f "$image" ]] || { echo -e "${RED}File not found: $image${RESET}"; return; }

  echo
  local extra_flags=""
  case "$partition" in
    userdata) echo -e "${BRED}Warning: flashing userdata erases all user data.${RESET}" ;;
    super) echo -e "${BRED}Warning: flashing super directly replaces the whole dynamic-partition layout.${RESET}" ;;
    system|vendor|product) echo -e "${BYELLOW}Note: this is usually a logical partition inside super. A plain flash may need extra steps on some devices.${RESET}" ;;
    vbmeta|vbmeta_system)
      if confirm "Also set --disable-verity --disable-verification on this vbmeta flash? (needed for most custom ROMs/kernels)"; then
        extra_flags="--disable-verity --disable-verification "
      fi
      ;;
  esac

  echo -e "${BOLD}Command:${RESET} fastboot ${extra_flags}flash $target \"$(basename "$image")\""
  confirm "Flash $(basename "$image") to $target?" || return
  # shellcheck disable=SC2086
  fastboot ${extra_flags}flash "$target" "$image"
}

erase_partition(){
  need_mode fastboot || return
  echo -e "${BOLD}${CYAN}🧹 Erase a partition${RESET}"
  line
  local partitions=(cache userdata metadata dtbo vbmeta boot recovery "custom (type it)")
  select p in "${partitions[@]}"; do [[ -n "$p" ]] && break; echo "Pick a number."; done
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
  fastboot erase "$target"
}

show_fastboot_vars(){
  need_mode fastboot || return
  echo -e "${CYAN}Querying every fastboot variable...${RESET}"
  fastboot getvar all 2>&1
}

unlock_bootloader(){
  need_mode fastboot || return
  if [[ "$LOCK" == "unlocked" ]]; then
    echo -e "${GREEN}Already unlocked. Nothing to do.${RESET}"; return
  fi
  echo -e "${CYAN}Step: fastboot flashing unlock, then confirm on the phone with volume + power.${RESET}"
  confirm "This wipes the phone completely." || return
  fastboot flashing unlock || fastboot oem unlock
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
  fastboot --set-active="$s"
  echo -e "${GREEN}Active slot set to $s.${RESET}"
}

# ── Sideload / recovery tools — work on any device ──
pick_zip(){
  local zips=() f
  while IFS= read -r f; do zips+=("$f"); done < <(find ~/Desktop ~/Downloads -maxdepth 4 -iname '*.zip' 2>/dev/null)
  zips+=("Type a custom path")
  echo -e "${BOLD}Which package?${RESET}" >&2
  select f in "${zips[@]}"; do [[ -n "$f" ]] && break; echo "Pick a number." >&2; done
  local zip="$f"
  [[ "$zip" == "Type a custom path" ]] && read -rp "Full path to zip: " zip
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
  adb sideload "$zip"
}

verify_checksum(){
  echo -e "${BOLD}${CYAN}🔎 Verify a file's checksum${RESET}"
  line
  read -rp "Path to file: " f
  [[ -f "$f" ]] || { echo -e "${RED}File not found: $f${RESET}"; return; }
  read -rp "Expected SHA256 (leave blank to just show it): " expected
  echo -e "${DIM}Hashing (may take a moment for large files)...${RESET}"
  local actual; actual=$(sha256sum "$f" | awk '{print $1}')
  echo -e "${BOLD}SHA256:${RESET} $actual"
  if [[ -n "$expected" ]]; then
    expected="${expected,,}"
    if [[ "$actual" == "$expected" ]]; then
      echo -e "${GREEN}✓ Matches. Safe to flash.${RESET}"
    else
      echo -e "${BRED}✗ Does NOT match. Do not flash this file — re-download it.${RESET}"
    fi
  fi
}

# ── CMF Phone 2 Pro (Galaga) specific — but the auto-detect below works for any ROM folder laid out the same way ──
pick_rom(){
  local dirs=() d
  if [[ -d "$BASE" ]]; then
    for d in "$BASE"/*/; do
      d="${d%/}"
      [[ -n "$(find "$d" -maxdepth 1 -name '*.zip' ! -name '*.json' 2>/dev/null)" || -f "$d/vendor_boot.img" ]] && dirs+=("$d")
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
      read -rp "Full path to the ROM folder: " d
    fi
    [[ -d "$d" ]] || { echo -e "${RED}Folder not found: $d${RESET}" >&2; return 1; }
    [[ -f "$d/vendor_boot.img" ]] || { echo -e "${RED}No vendor_boot.img in that folder.${RESET}" >&2; return 1; }
    echo "$d"; return 0
  done
}

flash_rom(){
  need_mode fastboot || return
  local dir zip
  dir=$(pick_rom) || return
  zip=$(find "$dir" -maxdepth 1 -name "*.zip" ! -name "*.json" | head -n1)

  echo -e "${BOLD}${CYAN}Detected in $(basename "$dir"):${RESET}"
  declare -A found
  local name
  for name in vbmeta vbmeta_system dtbo boot init_boot vendor_boot; do
    if [[ -f "$dir/$name.img" ]]; then
      found[$name]=1
      echo -e "  ${GREEN}✓${RESET} $name.img"
    fi
  done
  [[ -f "$dir/super_empty.img" ]] && { found[super_empty]=1; echo -e "  ${GREEN}✓${RESET} super_empty.img"; }
  [[ -f "$dir/system.img" ]] && echo -e "  ${DIM}• system.img (present, not auto-flashed — see note below)${RESET}"
  [[ -n "$zip" ]] && echo -e "  ${GREEN}✓${RESET} $(basename "$zip")"
  echo

  if [[ -z "${found[vendor_boot]:-}" ]]; then
    echo -e "${BRED}vendor_boot.img not found in this folder — it carries the recovery and is required.${RESET}"
    return
  fi
  if [[ -z "$zip" ]]; then
    echo -e "${BYELLOW}No ROM zip found here either. You can still flash the images, then sideload manually with option elsewhere in this menu.${RESET}"
  fi

  echo -e "${CYAN}Plan: flash the detected images in order, wipe super if present, then reboot to recovery"
  [[ -n "$zip" ]] && echo -e "and sideload $(basename "$zip")."
  [[ -f "$dir/system.img" ]] && echo -e "${BYELLOW}Note: system.img won't be touched automatically. It's normally installed by the ROM zip itself — use \"Flash any partition\" if a guide specifically tells you to flash it directly.${RESET}"
  confirm "Proceed? This wipes data and system." || return

  [[ -n "${found[vbmeta]:-}" ]] && fastboot --disable-verity --disable-verification flash vbmeta "$dir/vbmeta.img"
  [[ -n "${found[vbmeta_system]:-}" ]] && fastboot --disable-verity --disable-verification flash vbmeta_system "$dir/vbmeta_system.img"
  [[ -n "${found[dtbo]:-}" ]] && fastboot flash dtbo "$dir/dtbo.img"
  [[ -n "${found[boot]:-}" ]] && fastboot flash boot "$dir/boot.img"
  [[ -n "${found[init_boot]:-}" ]] && fastboot flash init_boot "$dir/init_boot.img"
  [[ -n "${found[super_empty]:-}" ]] && fastboot wipe-super "$dir/super_empty.img"
  fastboot flash vendor_boot "$dir/vendor_boot.img"

  fastboot reboot recovery
  echo -e "${YELLOW}On the phone: Factory reset → Format data, then Apply update → Apply from ADB.${RESET}"
  read -rp "Once the phone is waiting for the package, press Enter..."

  if [[ -n "$zip" ]]; then
    adb sideload "$zip"
  else
    echo -e "${DIM}No zip to sideload — use the \"Sideload a package\" option once you're ready.${RESET}"
  fi
}

restore_stock(){
  need_mode fastboot || return
  local dir="$1"
  echo -e "${CYAN}Steps: run flash_all.sh, wipe data, flash both slots, boot to stock.${RESET}"
  confirm "Restores stock from $(basename "$dir"). Wipes the phone." || return
  [[ -f "$dir/flash_all.sh" ]] || { echo -e "${RED}flash_all.sh missing — get it from spike0en/nothing_flasher (galaga-tetris branch)${RESET}"; return; }
  (cd "$dir" && bash flash_all.sh)
}

# ── Booted-phone maintenance ──
performance_pass(){
  need_mode adb || return
  local progress=~/.flask-adb-compile-progress
  local pkgs=() p failed=() i=0 total

  mapfile -t pkgs < <(adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort)
  total=${#pkgs[@]}

  echo -e "${CYAN}Trims app cache, then force-compiles every app for speed.${RESET}"
  adb shell pm trim-caches 999G

  if [[ -f "$progress" ]]; then
    echo -e "${BCYAN}Resuming from last run — finished apps are skipped.${RESET}"
  fi
  echo -e "${CYAN}Compiling $total packages... (Ctrl+C = pause, just run again to resume)${RESET}"

  for p in "${pkgs[@]}"; do
    ((i++))
    if [[ -f "$progress" ]] && grep -qx "$p" "$progress"; then
      continue
    fi
    printf "\r${DIM}[%d/%d] %s${RESET}    " "$i" "$total" "$p"
    if adb shell cmd package compile -m speed -f "$p" >/dev/null 2>&1; then
      echo "$p" >> "$progress"
    else
      failed+=("$p")
    fi
  done
  echo

  if ((${#failed[@]})); then
    echo -e "${BYELLOW}⚠️  ${#failed[@]} package(s) could not be compiled — usually harmless system overlays:${RESET}"
    printf '  • %s\n' "${failed[@]}"
    echo -e "${DIM}Everything else compiled fine. The pass finished on its own — nothing is stuck.${RESET}"
    echo -e "${DIM}Run the Performance pass again anytime to retry the failed ones.${RESET}"
  else
    echo -e "${BGREEN}⚡ Done — every app compiled for speed.${RESET}"
  fi
  rm -f "$progress"
}

deep_clean(){
  need_mode adb || return
  echo -e "${CYAN}Scans for leftover app data, empty folders, and thumbnail cache.${RESET}"
  local installed; installed=$(adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort)
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
    adb shell rm -rf /sdcard/DCIM/.thumbnails /sdcard/Pictures/.thumbnails
    echo -e "${GREEN}Thumbnail cache cleared.${RESET}"
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
  echo -e "${CYAN}Live log. Ctrl+C to stop.${RESET}"
  adb logcat
}

take_screenshot(){
  need_mode adb || return
  local dir=~/Desktop/cmf/screenshots
  mkdir -p "$dir"
  local f="$dir/screenshot_$(date +%Y%m%d_%H%M%S).png"
  adb exec-out screencap -p > "$f"
  echo -e "${GREEN}Saved: $f${RESET}"
}

install_apk(){
  need_mode adb || return
  local apks=() f
  while IFS= read -r f; do apks+=("$f"); done < <(find ~/Desktop ~/Downloads -maxdepth 3 -iname '*.apk' 2>/dev/null)
  apks+=("Type a custom path")
  echo -e "${BOLD}Which APK?${RESET}"
  select f in "${apks[@]}"; do [[ -n "$f" ]] && break; echo "Pick a number."; done
  local apk="$f"
  [[ "$apk" == "Type a custom path" ]] && read -rp "Full path to APK: " apk
  [[ -f "$apk" ]] || { echo -e "${RED}File not found: $apk${RESET}"; return; }
  adb install "$apk"
}

pull_file(){
  need_mode adb || return
  read -rp "Path on phone to pull: " src
  read -rp "Save to (local path, blank = current folder): " dst
  [[ -z "$dst" ]] && dst="."
  adb pull "$src" "$dst"
}

push_file(){
  need_mode adb || return
  read -rp "Local file to push: " src
  [[ -f "$src" ]] || { echo -e "${RED}File not found: $src${RESET}"; return; }
  read -rp "Destination path on phone: " dst
  adb push "$src" "$dst"
}

bootloader_menu(){
  while true; do
    clear; draw_header; line; check_state; status_bar; line
    echo -e "${BOLD}${MAGENTA}🔧 Bootloader tools${RESET}"
    echo
    echo -e "1) 🔓 Unlock bootloader"
    echo -e "2) ⚡ Flash any partition ${DIM}(generic — any device)${RESET}"
    echo -e "3) 🔄 Switch active slot"
    echo -e "4) 🧹 Erase a partition ${DIM}(generic)${RESET}"
    echo -e "5) 🛠️  Reboot to fastbootd ${DIM}(needed for some logical-partition ops)${RESET}"
    echo -e "6) 📋 Show all fastboot variables"
    line
    echo -e "${DIM}ROM folders under $BASE:${RESET}"
    echo -e "7) 📦 Flash ROM ${DIM}(auto-detects boot/dtbo/init_boot/vbmeta/vendor_boot)${RESET}"
    echo -e "8) ⏮  Restore stock — newest (B4.1)"
    echo -e "9) ⏮  Restore stock — older (V3.2)"
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
      8) restore_stock "$STOCK_NEW" ;;
      9) restore_stock "$STOCK_OLD" ;;
      0) return ;;
      *) echo -e "${RED}Unknown option${RESET}" ;;
    esac
    read -rp $'\nPress Enter to continue...'
  done
}

booted_menu(){
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
    echo -e "7) ⬇  Pull a file from phone"
    echo -e "8) ⬆  Push a file to phone"
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
      0) return ;;
      *) echo -e "${RED}Unknown option${RESET}" ;;
    esac
    read -rp $'\nPress Enter to continue...'
  done
}

while true; do
  clear; draw_header; line
  check_state; status_bar
  line
  echo
  n=1
  if [[ "$MODE" == "fastboot" ]]; then
    echo -e "${BOLD}$n)${RESET} 🔧 Bootloader tools"; opt_bl=$n; ((n++))
    echo -e "${BOLD}$n)${RESET} Reboot to system"; opt_rs=$n; ((n++))
    echo -e "${BOLD}$n)${RESET} Reboot to recovery"; opt_rec=$n; ((n++))
  fi
  if [[ "$MODE" == "adb" ]]; then
    echo -e "${BOLD}$n)${RESET} 📱 Booted-phone tools"; opt_bt=$n; ((n++))
    echo -e "${BOLD}$n)${RESET} Reboot to recovery"; opt_rec=$n; ((n++))
  fi
  if [[ "$MODE" == "adb" || "$MODE" == "sideload" ]]; then
    echo -e "${BOLD}$n)${RESET} Reboot to bootloader"; opt_rb=$n; ((n++))
  fi
  if [[ "$MODE" == "sideload" ]]; then
    echo -e "${BOLD}$n)${RESET} 📤 Sideload a package"; opt_sideload=$n; ((n++))
    echo -e "${BOLD}$n)${RESET} Reboot to system"; opt_rs=$n; ((n++))
  fi
  if [[ "$MODE" != "none" ]]; then
    echo -e "${BOLD}$n)${RESET} ℹ️  Device info"; opt_info=$n; ((n++))
  fi
  echo -e "${BOLD}$n)${RESET} Check active slot"; opt_slot=$n; ((n++))
  echo -e "${BOLD}$n)${RESET} 🔎 Verify a file's checksum"; opt_check=$n; ((n++))
  echo -e "${BOLD}0)${RESET} Exit"
  echo
  case "$MODE" in
    none) echo -e "${DIM}No phone detected.${RESET}" ;;
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
  elif [[ "$c" == "0" ]]; then exit 0
  else echo -e "${RED}Unknown option${RESET}"; read -rp $'\nPress Enter...'
  fi
  unset opt_bl opt_rs opt_rec opt_bt opt_rb opt_sideload opt_info opt_slot opt_check
done
