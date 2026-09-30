# ⚗️⚡ Flask-ADB-toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/dedsec-1337/Flask-ADB-toolkit)](https://github.com/dedsec-1337/Flask-ADB-toolkit/releases)

> **One little flask 🧪 — every flashing tool you'll ever need.**

![Bash](https://img.shields.io/badge/language-bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%20%28Git--Bash%20%2F%20WSL%29-0078D6?style=for-the-badge)
![Vibes](https://img.shields.io/badge/vibes-100%25%20fun-ff69b4?style=for-the-badge)

🌐 **Live site:** [dedsec-1337.github.io/Flask-ADB-toolkit](https://dedsec-1337.github.io/Flask-ADB-toolkit/) — features, quick start, and a one-click copy/download of the script.

---

## 🤔 What is this?

**Flask-ADB-toolkit** is a colorful, menu-driven terminal program that wraps all the scary `fastboot` / `adb` commands into friendly numbered options.

No memorizing commands.  
No copy-pasting from random forum posts at 2 AM.  
Just plug in your phone, launch the script, and pick what you want from a menu. 🎮

It was built for people who **know nothing about custom ROMs, vendor images, or flashing** — but want to try anyway.

## 🌱 The story (why this exists)

> This started as a fun personal project because **I had an issue** — flashing my phone meant juggling long, cryptic fastboot commands, and one wrong move could brick the thing.  
> So I thought: *why not put everything in one flask — like a lab flask 🧪 — and just… pour?*  
>
> What began as a tiny menu for my own CMF Phone 2 Pro grew into a full toolkit: auto-detected ROM flashing, a generic partition flasher for *any* Android device, recovery/sideload helpers, a checksum verifier, deep-clean junk hunting, a resumable "performance pass," screenshots, APK installs and more.  
>
> It's a little rough around the edges, made for fun — but it works, and it might save someone else from the same headache. 🍻

## 🎯 Who is this for?

- 😰 People who are **terrified** of fastboot commands but curious about custom ROMs
- 📱 CMF Phone 2 Pro (Galaga) owners who want one-tap ROM flashing & stock restore
- 🛠️ Anyone who wants a **generic** partition flasher that works on **any** Android device
- 🧹 Tinkerers who like keeping their phone clean and snappy

## ✨ Features

### 🔧 Bootloader / Fastboot mode

| Option | What it does |
| --- | --- |
| 🔓 Unlock bootloader | Guided unlock (with warnings!) |
| ⚡ Flash any partition | boot, init_boot, recovery, vendor_boot, dtbo, vbmeta, vbmeta_system, system, vendor, super, userdata… or type your own — **works on any device** |
| 🔄 Switch active slot | A/B slot switching |
| 🧹 Erase a partition | cache, userdata, metadata… (with warnings) |
| 🛠️ Reboot to fastbootd | For logical-partition operations |
| 📋 Show all fastboot variables | Debug info dump |
| 📦 Flash ROM | **Auto-detects** `boot`, `dtbo`, `init_boot`, `vbmeta`, `vbmeta_system`, `super_empty` in your ROM folder and flashes whichever exist, in a safe order — `vbmeta` flashed with `--disable-verity --disable-verification` |
| ⏮ Restore stock *(CMF Phone 2 Pro)* | Newest (B4.1) or older (V3.2) build, both slots |

### 📱 Booted-phone (ADB) mode

| Option | What it does |
| --- | --- |
| ⚡ Performance pass | Trims caches + speed-compiles every app — **skips un-compilable system packages and auto-resumes if interrupted** |
| 🧹 Deep clean | Finds orphaned app data, empty folders, clears thumbnail cache |
| 🔋 Battery & storage | Health + free-space report |
| 📜 Live logcat | Watch logs in real time |
| 📷 Screenshot | Saved straight to your Downloads folder |
| 📥 Install APK | Pick & install |
| ⬇️⬆️ Pull / Push files | Move files both ways |

### 🔄 Recovery / Sideload mode

| Option | What it does |
| --- | --- |
| 📤 Sideload a package | ADB-sideload any zip — GApps, Magisk, anything that isn't a full ROM install |
| 🔁 Reboot to system | Bounce back out of recovery when you're done |

### 🌐 Works everywhere in the menu

| Option | What it does |
| --- | --- |
| 🎯 Reboot to recovery | Straight to recovery — from fastboot *or* booted mode |
| 🔎 Verify a file's checksum | Paste a file + optional expected SHA256 — get a match / no-match verdict before you flash |

Plus: live **device status bar** (connection mode 🔌, bootloader lock 🔒/🔓, active slot) and a menu that **adapts to whatever state your phone is in**.

### 💡 About the ROM flasher

Drop your ROM folder **anywhere** — `~/Desktop/cmf` is just the default suggestion, not a requirement.  
If the auto-picker finds nothing there, you type the path directly.

The flasher looks for: `vbmeta`, `vbmeta_system`, `dtbo`, `boot`, `init_boot`, `vendor_boot`, `super_empty`, and the ROM `.zip` — flashes whatever's present in a safe order, then wipes super (if present), reboots to recovery, and sideloads the zip.

`system.img` is deliberately **never auto-flashed** (it's normally a logical partition the ROM zip installs itself). It's still listed when found and available through "Flash any partition" if a guide specifically requires it.

> **CMF Phone 2 Pro owners:** options 8–9 in the bootloader menu light up when your stock folders are in `~/Desktop/cmf`.

## 📋 Requirements

- A computer with Linux, macOS, or Windows
- `adb` & `fastboot` installed
- A USB cable
- A phone with an **unlocked bootloader** (for flashing)
- ~30 seconds of courage

## 🚀 Quick start (Linux / macOS)

Install `adb` & `fastboot`:

- **Ubuntu / Debian:**  
  `sudo apt update && sudo apt install android-tools-adb android-tools-fastboot`
- **Arch / CachyOS:**  
  `sudo pacman -S android-tools`
- **Fedora:**  
  `sudo dnf install android-tools`
- **macOS:**  
  `brew install android-platform-tools`

Then:

```bash
nano ~/flask-adb-toolkit.sh
```

Paste the script → `Ctrl+O` → `Enter` → `Ctrl+X`

```bash
chmod +x ~/flask-adb-toolkit.sh
~/flask-adb-toolkit.sh
```

Prefer not to paste? The [live site](https://dedsec-1337.github.io/Flask-ADB-toolkit/) has **Copy Full Script** and **Download .sh** buttons.

## 🪟 Windows

Two options:

- **Easiest:** Install [Git for Windows](https://git-scm.com/download/win) + [platform-tools](https://developer.android.com/tools/releases/platform-tools), then double-click `flask-adb-toolkit.bat`
- **Classic:** Use WSL (`wsl --install`) and follow the Linux steps

The `.bat` works the same as the `.sh` (same safety checks, same commands). For full colours and the adaptive menu, use Git Bash or WSL with the `.sh`.

## 🗑️ Uninstalling

**Remove the toolkit:**

- Linux / macOS / WSL:  
  `rm -f ~/flask-adb-toolkit.sh ~/.flask-adb-compile-progress`
- Windows: delete `flask-adb-toolkit.bat`

Screenshots taken through the toolkit are saved in your **Downloads** folder (`~/Downloads` or `%USERPROFILE%\Downloads` on Windows).

**Optional – remove adb/fastboot:**

- Ubuntu/Debian: `sudo apt remove android-tools-adb android-tools-fastboot && sudo apt autoremove`
- Arch: `sudo pacman -Rns android-tools`
- Fedora: `sudo dnf remove android-tools`
- macOS: `brew uninstall android-platform-tools`

## ⚠️ Disclaimer

Flashing can erase data and brick your device if misused.  
This tool asks you to type `YES` before anything dangerous — but **you** are still the one pressing the buttons.

- Not responsible for lost data, bricked phones, or voided warranties
- Always back up first
- Always verify checksums before flashing
- Provided as-is, made for fun & learning

## 🗺️ Roadmap

- [ ] More device-specific profiles (open an issue with your device!)
- [ ] macOS one-liner installer
- [ ] Undo-last-flash safety snapshot (if feasible)
- [ ] Even more colors 🌈

## 🤝 Contributing

Found a bug? Got a device profile to add?  
PRs and issues are welcome. Keep it friendly — this is a fun project. 🍪

## 📜 License

[MIT](LICENSE) — do whatever you want, just don’t blame the flask if it spills. 🧪

---

<p align="center">
  <i>Made with 💚, one frustrated evening, and an unhealthy love of terminal colors.</i>
</p>
