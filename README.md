# ⚗️⚡ Flask-ADB-toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Version](https://img.shields.io/badge/version-1.5-blue)](https://github.com/dedsec-1337/Flask-ADB-toolkit/releases/tag/v1.5)
> **One little flask 🧪 — every flashing tool you'll ever need.**

[![Bash](https://img.shields.io/badge/language-bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](https://github.com/dedsec-1337/Flask-ADB-toolkit) [![Platform](https://img.shields.io/badge/platform-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%20%28Git--Bash%20%2F%20WSL%29-0078D6?style=for-the-badge)](https://github.com/dedsec-1337/Flask-ADB-toolkit) [![Vibes](https://img.shields.io/badge/vibes-100%25%20fun-ff69b4?style=for-the-badge)](https://github.com/dedsec-1337/Flask-ADB-toolkit)

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
| ------ | ------------ |
| 🔓 Unlock bootloader | Guided unlock (with warnings!) — re-reads the lock state after the command so you know it actually worked |
| ⚡ Flash any partition | boot, init_boot, recovery, vendor_boot, dtbo, vbmeta, vbmeta_system, system, vendor, product, super, userdata… or type your own — **works on any device** |
| 🔄 Switch active slot | A/B slot switching (`--set-active`, with a `set_active` fallback) |
| 🧹 Erase a partition | cache, userdata, metadata… (with warnings) |
| 🛠️ Reboot to fastbootd | For logical-partition operations |
| 📋 Show all fastboot variables | Debug info dump |
| 📦 Flash ROM | **Auto-detects** images, unpacks `payload.bin` when present, verifies checksums via sidecar files, saves a snapshot first, and stops at the first failed step |
| ⏮ Restore stock firmware | Point it at **any** stock-firmware folder with a `flash_all` script — no presets |

### 📱 Booted-phone (ADB) mode

| Option | What it does |
| ------ | ------------ |
| ⚡ Performance pass | Trims caches + speed-compiles every app — **skips un-compilable system packages and auto-resumes if interrupted** |
| 🧹 Deep clean | Finds orphaned app data, empty folders, clears thumbnail cache |
| 🔋 Battery & storage | Health + free-space report |
| 📜 Live logcat | Watch logs in real time |
| 📷 Screenshot | Saved to your **Downloads** folder |
| 📥 Install APK | Pick & install |
| ⬇️⬆️ Pull / Push files | Move files both ways |
| 💾 Back up before wipe | Pulls `/sdcard` (or selected folders) + third-party app list to `~/flask-adb-backups/` |

### 🔄 Recovery / Sideload mode

| Option | What it does |
| ------ | ------------ |
| 📤 Sideload a package | ADB-sideload any zip — GApps, Magisk, anything that isn't a full ROM install |
| 🔁 Reboot to system | Bounce back out of recovery when you're done |

### 🩺 Safety & diagnostics (any mode)

| Option | What it does |
| ------ | ------------ |
| 🩺 Connection doctor | Names the real problem — *unauthorized*, *offline*, *no permissions*, *multiple devices* — and prints the fix |
| 🎓 Learn mode | Show every command before it runs, or run in `--dry-run` (show, execute nothing) |
| 🧾 Support report | Bundles version + device info + log tail into `~/Downloads/flask-adb-support-report.txt` for a GitHub issue |
| ↩️ Restore a saved snapshot | Undo a `boot` / `vbmeta` / `dtbo` flash from `~/flask-adb-snapshots/` |

Plus: live **device status bar** (connection mode 🔌, bootloader lock 🔒/🔓, active slot, battery warning below 30 %) and a menu that **adapts to whatever state your phone is in**.

### 💡 About the ROM flasher

Drop your ROM folder **anywhere** — `~/Desktop/flashing` is just the default suggestion where "Flash ROM" looks first, not a requirement.

The flasher:

1. Finds the ROM `.zip` and scans for `vbmeta`, `vbmeta_system`, `dtbo`, `boot`, `init_boot`, `vendor_boot`, `recovery`, `super_empty`.
2. **If the zip contains `payload.bin`** (LineageOS, crDroid, EvolutionX, most Nothing/CMF builds), offers to unpack it with `payload-dumper-go` and uses the extracted `.img` files as the source.
3. **If a `<zip>.sha256`, `SHA256SUMS` or `checksums.txt` sits next to the zip**, verifies automatically. Otherwise asks if you want to paste a hash manually.
4. Saves a **snapshot** of every partition it's about to overwrite, via `fastboot fetch`.
5. Flashes each image in a safe order (`vbmeta` with `--disable-verity --disable-verification`), stops at the first failure, then reboots to recovery and sideloads the zip.

`system.img` is deliberately **never auto-flashed** — it's normally installed by the ROM zip itself. Use *Flash any partition* if a guide specifically requires it.

`payload-dumper-go` install:
- **Linux / macOS (Go):** `go install github.com/ssut/payload-dumper-go@latest`
- **macOS (Homebrew):** `brew install payload-dumper-go`
- **Arch (AUR):** `yay -S payload-dumper-go-bin`
- **Prebuilt binaries:** [github.com/ssut/payload-dumper-go/releases](https://github.com/ssut/payload-dumper-go/releases)

## 📋 Requirements

- A computer with Linux, macOS, or Windows
- `adb` & `fastboot` (see the install steps for your OS)
- A USB cable
- A phone with **USB debugging enabled** (see below — don't skip this, it bites everyone)
- A phone with an **unlocked bootloader** (for flashing)
- **macOS only:** bash 4 or newer (`brew install bash`). macOS ships bash 3.2, which the script can't run on.
- ~30 seconds of courage

## 🔌 Don't forget: USB debugging & the allow prompt

This is the #1 "why isn't my phone showing up?" moment:

> **Enable USB debugging, and tap "Allow" on the USB debugging prompt.** Otherwise your phone and your computer are basically a bad first date: both showed up, nobody said hello, and they spend the whole evening pretending they can't see each other. 💔  
>
> USB debugging is your phone's way of saying *"new phone, who dis?"* — and tapping **Allow** is how it saves your PC's number. Skip either one and the toolkit will sit there saying "not connected" while your phone is literally plugged in. Awkward. 🔌🙃

How to actually do it:

1. On the phone: **Settings → About phone → tap "Build number" 7 times** → you are now a developer. 🎓
2. **Settings → System → Developer options → USB debugging** → turn it on.
3. Plug the phone into the computer.
4. When the phone pops up **"Allow USB debugging?"** — check **"Always allow from this computer"** and tap **OK**.

Unlocking the bootloader also wipes the phone, which resets those remembered permissions — so **re-allow the prompt after every unlock/wipe**. 👻

## 🚀 Quick start (Linux / macOS)

Install `adb` & `fastboot`:

- **Ubuntu / Debian:** `sudo apt update && sudo apt install android-tools-adb android-tools-fastboot`
- **Arch / CachyOS:** `sudo pacman -S android-tools`
- **Fedora:** `sudo dnf install android-tools`
- **macOS:** `brew install android-platform-tools bash`

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

Windows does not ship `adb` or `fastboot`. The new **PowerShell launcher** self-heals that — it finds Git Bash, downloads Google's platform-tools for you, and puts them on your PATH in one click.

### What you need

- `flask-adb-toolkit.ps1`
- `flask-adb-toolkit.bat`
- `flask-adb-toolkit.sh`
- A USB cable and the phone's USB driver (Windows Update usually handles Nothing / CMF phones; if not, install the OEM driver)

Put all three files **in the same folder**. That's it.

### Step-by-step

1. Download the three files above and put them in a folder like `Desktop\flask-adb`.

   ```text
   flask-adb\
     flask-adb-toolkit.bat      ← double-click this
     flask-adb-toolkit.ps1
     flask-adb-toolkit.sh
   ```

2. Double-click **`flask-adb-toolkit.bat`**.

3. First run, the launcher will:
   - Check for Git Bash. If missing, offer to install it with `winget install Git.Git`.
   - Check for `adb` and `fastboot`. If missing, offer to download Google's platform-tools into `%LOCALAPPDATA%\Android\platform-tools` and add them to your user PATH.
   - Hand off to `flask-adb-toolkit.sh` inside Git Bash → you get the **full-colour, mode-aware menu**.

4. Enable **USB debugging** on the phone, plug it in, tap **Allow** on the prompt, then use the numbered menu.

### What if PowerShell opens in a blue window and closes instantly?

That means the launcher hit an error before it could print to the screen. Open **PowerShell** manually (Start → *Windows PowerShell*), `cd` to the folder, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\flask-adb-toolkit.ps1
```

The error will stay on screen. Paste it into a GitHub issue with the support report.

### Windows notes

- Screenshots are saved to `%USERPROFILE%\Downloads`
- The PowerShell launcher does not need anything on PATH permanently — it can clean up after itself
- Restore stock looks for `flash_all.bat` first; a `.sh` restore uses Git Bash or WSL
- If Windows says "Windows protected your PC", click **More info** → **Run anyway** (the file is a local script you downloaded, not a signed installer)

## 🗑️ Uninstalling

**Remove the toolkit:**

- Linux / macOS / WSL:
  ```bash
  rm -f ~/flask-adb-toolkit.sh
  find ~ -maxdepth 1 -name '.flask-adb-compile-progress*' -delete
  ```
- Windows: delete the `flask-adb` folder (all three files)

Screenshots taken through the toolkit are saved in your **Downloads** folder.

**Optional – remove adb/fastboot:**

- Ubuntu/Debian: `sudo apt remove android-tools-adb android-tools-fastboot && sudo apt autoremove`
- Arch: `sudo pacman -Rns android-tools`
- Fedora: `sudo dnf remove android-tools`
- macOS: `brew uninstall android-platform-tools`
- Windows: delete `%LOCALAPPDATA%\Android\platform-tools` and remove that folder from your user PATH

## ⚠️ Disclaimer

Flashing can erase data and brick your device if misused.  
This tool asks you to type `YES` before anything dangerous — but **you** are still the one pressing the buttons.

- Not responsible for lost data, bricked phones, or voided warranties
- Always back up first
- Always verify checksums before flashing — the toolkit now auto-detects `<zip>.sha256` / `SHA256SUMS` for you
- Always enable USB debugging and allow the connection
- Provided as-is, made for fun & learning

## 🗺️ Roadmap

- [ ] macOS one-liner installer
- [ ] Config file at `~/.flask-adb-toolkit.conf`
- [ ] More device-specific profiles (open an issue with your device!)
- [ ] Even more colors 🌈

## 🤝 Contributing

Found a bug? Got a device profile to add?  
PRs and issues are welcome. Keep it friendly — this is a fun project. 🍪

## 📜 License

[MIT](https://github.com/dedsec-1337/Flask-ADB-toolkit/blob/main/LICENSE) — do whatever you want, just don't blame the flask if it spills. 🧪

---

*Made with 💚, one frustrated evening, and an unhealthy love of terminal colors.*
