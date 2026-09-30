# ⚗️⚡ Flask-ADB-toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/dedsec-1337/Flask-ADB-toolkit)](https://github.com/dedsec-1337/Flask-ADB-toolkit/releases)

> **One little flask 🧪 — every flashing tool you'll ever need.**

![Bash](https://img.shields.io/badge/language-bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%20%28Git--Bash%20%2F%20WSL%29-0078D6?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-yellow?style=for-the-badge)
![Vibes](https://img.shields.io/badge/vibes-100%25%20fun-ff69b4?style=for-the-badge)

🌐 **Live site:** [dedsec-1337.github.io/Flask-ADB-toolkit](https://dedsec-1337.github.io/Flask-ADB-toolkit/) — features, quick start, and a one-click copy/download of the script.

---

## 🤔 What is this?

**Flask-ADB-toolkit** is a colorful, menu-driven terminal program that wraps all the scary
`fastboot` / `adb` commands into friendly numbered options.

No memorizing commands. No copy-pasting from random forum posts at 2 AM.
Just plug in your phone, launch the script, and pick what you want from a menu. 🎮

It was built for people who **know nothing about custom ROMs, vendor images, or flashing** —
but want to try anyway.

## 🌱 The story (why this exists)

> This started as a fun personal project because **I had an issue** — flashing my phone
> meant juggling long, cryptic fastboot commands, and one wrong move could brick the thing.
> So I thought: *why not put everything in one flask — like a lab flask 🧪 — and just… pour?*
>
> What began as a tiny menu for my own CMF Phone 2 Pro grew into a full toolkit:
> auto-detected ROM flashing, a generic partition flasher for *any* Android device,
> recovery/sideload helpers, a checksum verifier, deep-clean junk hunting,
> a resumable "performance pass," screenshots, APK installs and more.
>
> It's a little rough around the edges, made for fun — but it works, and it might save
> someone else from the same headache. 🍻

## 🎯 Who is this for?

- 😰 People who are **terrified** of fastboot commands but curious about custom ROMs
- 📱 CMF Phone 2 Pro (Galaga) owners who want one-tap ROM flashing & stock restore
- 🛠️ Anyone who wants a **generic** partition flasher that works on **any** Android device
- 🧹 Tinkerers who like keeping their phone clean and snappy

## ✨ Features

### 🔧 Bootloader / Fastboot mode

| Option | What it does |
|---|---|
| 🔓 Unlock bootloader | Guided unlock (with warnings!) |
| ⚡ Flash any partition | boot, init_boot, recovery, vendor_boot, dtbo, vbmeta, vbmeta_system, system, vendor, super, userdata… or type your own — **works on any device** |
| 🔄 Switch active slot | A/B slot switching |
| 🧹 Erase a partition | cache, userdata, metadata… (with warnings) |
| 🛠️ Reboot to fastbootd | For logical-partition operations |
| 📋 Show all fastboot variables | Debug info dump |
| 📦 Flash ROM | **Auto-detects** `boot`, `dtbo`, `init_boot`, `vbmeta`, `vbmeta_system`, `super_empty` in your ROM folder and flashes whichever exist, in a safe order — `vbmeta` flashed with `--disable-verity --disable-verification` (correctly placed before `flash`) |
| ⏮ Restore stock *(CMF Phone 2 Pro)* | Newest (B4.1) or older (V3.2) build, both slots |

### 📱 Booted-phone (ADB) mode

| Option | What it does |
|---|---|
| ⚡ Performance pass | Trims caches + speed-compiles every app — **skips un-compilable system packages and auto-resumes if interrupted** |
| 🧹 Deep clean | Finds orphaned app data, empty folders, clears thumbnail cache |
| 🔋 Battery & storage | Health + free-space report |
| 📜 Live logcat | Watch logs in real time |
| 📷 Screenshot | Saved straight to your desktop |
| 📥 Install APK | Pick & install |
| ⬇️⬆️ Pull / Push files | Move files both ways |

### 🔄 Recovery / Sideload mode

| Option | What it does |
|---|---|
| 📤 Sideload a package | ADB-sideload any zip — GApps, Magisk, anything that isn't a full ROM install |
| 🔁 Reboot to system | Bounce back out of recovery when you're done |

### 🌐 Works everywhere in the menu

| Option | What it does |
|---|---|
| 🎯 Reboot to recovery | Straight to recovery — from fastboot *or* booted mode, no digging through the ROM flow |
| 🔎 Verify a file's checksum | Paste a file, optionally the expected SHA256 — get a match / no-match verdict before you flash |

Plus: live **device status bar** (connection mode 🔌, bootloader lock 🔒/🔓, active slot)
and a menu that **adapts to whatever state your phone is in**.

### 💡 About the ROM flasher

Drop your ROM folder **anywhere** — `~/Desktop/cmf` is just the default suggestion, not a requirement.
If the auto-picker finds nothing there, you type the path directly.

The flasher looks for: `vbmeta`, `vbmeta_system`, `dtbo`, `boot`, `init_boot`, `vendor_boot`,
`super_empty`, and the ROM `.zip` — flashes whatever's present in a safe order, then
wipes super (if present), reboots to recovery, and sideloads the zip.

`system.img` is deliberately **never auto-flashed**: it's normally a logical partition
the ROM zip installs itself. It's listed when found, and reachable through
"Flash any partition" if a guide specifically tells you to flash it directly.

> **CMF Phone 2 Pro owners:** options 8–9 in the bootloader menu light up when your
> stock folders are in `~/Desktop/cmf`.

## 📋 Requirements

- A computer with Linux, macOS — or Windows (see below 👇)
- `adb` & `fastboot` installed — see the install command for your OS below
- A USB cable, and a phone with an **unlocked bootloader** (for flashing)
- ~30 seconds of courage

## 🚀 Quick start (Linux / macOS)

Install `adb` & `fastboot` — pick your OS:

- Ubuntu / Debian: `sudo apt update && sudo apt install android-tools-adb android-tools-fastboot`
- Arch / CachyOS: `sudo pacman -S android-tools`
- Fedora: `sudo dnf install android-tools`
- macOS: `brew install android-platform-tools`

Save the script:

    nano ~/flask-adb-toolkit.sh

Paste the script, then `Ctrl+O`, `Enter`, `Ctrl+X` to save and exit.

Make it executable and run it:

    chmod +x ~/flask-adb-toolkit.sh
    ~/flask-adb-toolkit.sh

Rather paste than type? The [live site](https://dedsec-1337.github.io/Flask-ADB-toolkit/) has a **Copy Full Script** and **Download .sh** button that pulls the current version straight off GitHub. Same script, fewer keystrokes.

Then just follow the colorful menus. 🎨

## 🪟 Windows?

Yes! Two ways — pick your comfort level:

- **🟢 Easiest:** [Git for Windows](https://git-scm.com/download/win) (gives you Git Bash) + Google's [platform-tools](https://developer.android.com/tools/releases/platform-tools) on your `PATH` → then double-click **`flask-adb-toolkit.bat`** 🎉
- **🟣 Classic:** Ubuntu inside Windows via **WSL** (`wsl --install`) — it's basically Linux, then follow the Linux steps above.

The `.bat` is functionally equivalent to the `.sh` — same real adb/fastboot commands, same
checks before anything dangerous, checksums verified via Windows-native `certutil -hashfile`.
No color, and a flat menu instead of the mode-aware one (batch can't do that cleanly),
but everything works. For the full visual experience, use Git Bash or WSL with the `.sh`.

## 🗑️ Uninstalling

Removing the toolkit is one file deletion. Removing the dependencies is optional.

### Remove the toolkit itself

- **Linux / macOS / WSL:** `rm -f ~/flask-adb-toolkit.sh ~/.flask-adb-compile-progress`
- **Windows (Git Bash):** delete `flask-adb-toolkit.bat` from wherever you saved it, or run `rm ~/flask-adb-toolkit.bat`

Screenshots taken through the toolkit live in `~/Desktop/cmf/screenshots/` (or `%USERPROFILE%\Desktop\cmf\screenshots\` on Windows) — remove that folder too if you don't want to keep them.

### Remove adb & fastboot (optional)

If you installed platform-tools just for this toolkit and want the disk space back:

- **Ubuntu / Debian:** `sudo apt remove android-tools-adb android-tools-fastboot` — add `sudo apt autoremove` afterwards to clear unused dependencies too.
- **Arch / CachyOS:** `sudo pacman -Rns android-tools`
- **Fedora:** `sudo dnf remove android-tools`
- **macOS:** `brew uninstall android-platform-tools` — if you don't use Homebrew for anything else, remove it with the official uninstall script from brew.sh.
- **Windows (Git Bash):** delete the `platform-tools` folder you extracted, and remove its path from **System Properties → Environment Variables → Path**. Uninstall Git for Windows via **Settings → Apps** if you don't use it.
- **Windows (WSL):** `sudo apt remove android-tools-adb android-tools-fastboot` inside your distro. To remove the distro entirely: `wsl --unregister Ubuntu` from PowerShell.

## ⚠️ Disclaimer

Flashing partitions **erases data** and can, if misused, brick your device.
This tool asks for confirmation (`type YES`) before anything dangerous —
but **you** are still the one pressing the buttons. 🔘

- Not responsible for lost data, bricked phones, or voided warranties
- Always back up first 📦
- Always **verify checksums** before flashing a download 🔎 (the toolkit has one built in)
- Everything here is provided **as-is**, made for fun & learning

## 🗺️ Roadmap

- [ ] More device-specific profiles (open an issue with your device!)
- [ ] macOS one-liner installer
- [ ] Undo-last-flash safety snapshot (if feasible)
- [ ] Even more colors 🌈

## 🤝 Contributing

Found a bug? Got a device profile to add? PRs and issues are welcome!
Keep it friendly — this is a fun project. 🍪

## 📜 License

[MIT](LICENSE) — do whatever you want, just don't blame the flask if it spills. 🧪

---

<p align="center">
  <i>Made with 💚, one frustrated evening, and an unhealthy love of terminal colors.</i>
</p>
