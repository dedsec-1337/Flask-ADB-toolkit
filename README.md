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
| ⚡ Flash any partition | boot, init_boot, recovery, vendor_boot, dtbo, vbmeta, vbmeta_system, system, vendor, product, super, userdata… or type your own — **works on any device** |
| 🔄 Switch active slot | A/B slot switching |
| 🧹 Erase a partition | cache, userdata, metadata… (with warnings) |
| 🛠️ Reboot to fastbootd | For logical-partition operations |
| 📋 Show all fastboot variables | Debug info dump |
| 📦 Flash ROM | **Auto-detects** `boot`, `dtbo`, `init_boot`, `vbmeta`, `vbmeta_system`, `super_empty` in your ROM folder and flashes whichever exist, in a safe order — `vbmeta` flashed with `--disable-verity --disable-verification` |
| ⏮ Restore stock firmware | Point it at **any** stock-firmware folder that contains a `flash_all` script — no presets, no hardcoded versions. Type or paste the path once and it does the rest (wipes data, restores both slots on multi-slot devices) |

### 📱 Booted-phone (ADB) mode

| Option | What it does |
| --- | --- |
| ⚡ Performance pass | Trims caches + speed-compiles every app — **skips un-compilable system packages and auto-resumes if interrupted** (full resume on Linux/macOS; single pass on the Windows `.bat`) |
| 🧹 Deep clean | Finds orphaned app data, empty folders, clears thumbnail cache |
| 🔋 Battery & storage | Health + free-space report |
| 📜 Live logcat | Watch logs in real time |
| 📷 Screenshot | Saved to your **Downloads** folder |
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
| ℹ️ Device info | Model, codename, Android/build/security-patch — booted or in bootloader |
| 🔎 Verify a file's checksum | Paste a file + optional expected SHA256 — get a match / no-match verdict before you flash |

Plus: live **device status bar** (connection mode 🔌, bootloader lock 🔒/🔓, active slot) and a menu that **adapts to whatever state your phone is in**.

### 💡 About the ROM flasher

Drop your ROM folder **anywhere** — `~/Desktop/flashing` (`%USERPROFILE%\Desktop\flashing` on Windows) is just the default suggestion where "Flash ROM" looks first, not a requirement.

If the auto-picker finds nothing there, you type or paste the path directly.

The flasher looks for: `vbmeta`, `vbmeta_system`, `dtbo`, `boot`, `init_boot`, `vendor_boot`, `super_empty`, and the ROM `.zip` — flashes whatever's present in a safe order, then wipes super (if present), reboots to recovery, and sideloads the zip.

`system.img` is deliberately **never auto-flashed** (it's normally a logical partition the ROM zip installs itself). It's still listed when found and available through "Flash any partition" if a guide specifically requires it.

### 💡 About stock restore

Restore stock firmware works the same way the ROM flasher does: it asks for a folder path instead of relying on hardcoded presets. If your phone's stock archive extracts to a folder with a `flash_all` script inside, the toolkit can run it.

- **Windows `.bat`**: looks for `flash_all.bat` first, falls back to `flash_all.sh` (needs Git Bash or WSL for the `.sh`)
- **`.sh`**: runs `flash_all.sh` directly

For Nothing / CMF phones, that layout matches the stock firmware from projects like `spike0en/nothing_flasher` (galaga-tetris branch). Your own restore folders keep working exactly as before — you just type or paste the path once instead of pressing a preset button.

## 📋 Requirements

- A computer with Linux, macOS, or Windows
- `adb` & `fastboot` (see the install steps for your OS)
- A USB cable
- A phone with **USB debugging enabled** (see below — don't skip this, it bites everyone)
- A phone with an **unlocked bootloader** (for flashing)
- ~30 seconds of courage

Windows does **not** include `adb` / `fastboot`. You must download Google's platform-tools once. The `.bat` will find them for you after that.

## 🔌 Don't forget: USB debugging & the allow prompt

This is the #1 "why isn't my phone showing up?" moment, so let's get it out of the way — with a pun, as is tradition:

> **Enable USB debugging, and tap "Allow" on the USB debugging prompt.**
> Otherwise your phone and your computer are basically a bad first date: both showed up, nobody said hello, and they spend the whole evening pretending they can't see each other. 💔
>
> USB debugging is your phone's way of saying *"new phone, who dis?"* — and tapping **Allow** is how it saves your PC's number. Skip either one and the toolkit will sit there saying "not connected" while your phone is literally plugged in. Awkward. Very "it's not you, it's USB." 🔌🙃

How to actually do it:

1. On the phone: **Settings → About phone → tap "Build number" 7 times** → you are now a developer. Congrats. 🎓
2. **Settings → System → Developer options → USB debugging** → turn it on.
3. Plug the phone into the computer.
4. When the phone pops up **"Allow USB debugging?"** — check **"Always allow from this computer"** and tap **OK**.
   - No popup? Unplug, replug, or toggle USB debugging off/on. The prompt is shy; it re-asks when the RSA key changes (new OS, new user, wiped data).

Unlocking the bootloader also wipes the phone, which resets those remembered permissions — so **re-allow the prompt after every unlock/wipe**. Don't let your phone ghost your PC after it just got a fresh start. 👻

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

## 🪟 Windows — full guide

Windows does not ship `adb` or `fastboot`. You download them once, then double-click the toolkit. You do **not** need to open the platform-tools folder and type `CMD` every time.

### What you need

- `flask-adb-toolkit.bat` from this repo
- Google's [platform-tools](https://developer.android.com/tools/releases/platform-tools) zip (contains `adb.exe` and `fastboot.exe`)
- A USB cable and the phone's USB driver (Windows Update usually handles Nothing / CMF phones; if not, install the OEM driver)

### Step-by-step

1. Download **platform-tools** from Google and unzip it.
   You should have a folder named `platform-tools` with `adb.exe` and `fastboot.exe` inside.

2. Download `flask-adb-toolkit.bat` from this repo.

3. Put them together using **one** of these layouts (pick whichever is easier):

   **Option A — bat inside platform-tools (simplest)**

   ```
   platform-tools\
     adb.exe
     fastboot.exe
     flask-adb-toolkit.bat
   ```

   **Option B — platform-tools next to the bat**

   ```
   SomeFolder\
     flask-adb-toolkit.bat
     platform-tools\
       adb.exe
       fastboot.exe
   ```

4. Double-click `flask-adb-toolkit.bat`.
   It searches those locations (and PATH) automatically. If tools are found, the menu opens. If not, it prints exactly what is missing.

5. Enable **USB debugging** on the phone, plug it in, tap **Allow** on the prompt, then use the numbered menu.

You do **not** need to:

- Open the platform-tools folder
- Type `CMD` in the address bar
- Add anything to System PATH (optional, not required)

### Optional: Git Bash / WSL (full colour menu)

The `.bat` is the easy Windows version: same real `adb` / `fastboot` commands, same `YES` confirmations, checksums via `certutil`.

Instead of the mode-aware colour menu it shows one **flat list of all 21 options** — after the change that merged "Restore stock" into a single path-picking option, the count went from 22 down to 21.

For the full visual `.sh` experience on Windows:

- **Git Bash:** install [Git for Windows](https://git-scm.com/download/win), put platform-tools on PATH, run `flask-adb-toolkit.sh`
- **WSL:** `wsl --install`, then follow the Linux steps inside Ubuntu

### Windows notes

- Screenshots are saved to `%USERPROFILE%\Downloads`
- Performance pass on the `.bat` is a single compile pass (no resume file like the `.sh`)
- Restore stock looks for `flash_all.bat` first; a `.sh` restore needs Git Bash or WSL
- If Windows says "Windows protected your PC", click **More info** → **Run anyway** (the file is a local script you downloaded, not a signed installer)

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
- Windows: delete the `platform-tools` folder you unzipped

## ⚠️ Disclaimer

Flashing can erase data and brick your device if misused.
This tool asks you to type `YES` before anything dangerous — but **you** are still the one pressing the buttons.

- Not responsible for lost data, bricked phones, or voided warranties
- Always back up first
- Always verify checksums before flashing
- Always enable USB debugging and allow the connection — a phone that won't talk to your PC can't be flashed, un-bricked, or reasoned with
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

[MIT](LICENSE) — do whatever you want, just don't blame the flask if it spills. 🧪

---

<p align="center">
  <i>Made with 💚, one frustrated evening, and an unhealthy love of terminal colors.</i>
</p>
