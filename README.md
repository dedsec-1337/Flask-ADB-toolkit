# ⚗️⚡ Flask-ADB-toolkit

> **One little flask 🧪 — every flashing tool you'll ever need.**



![Bash](https://img.shields.io/badge/language-bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)




![Platform](https://img.shields.io/badge/platform-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%20(WSL%2FGit--Bash)

-0078D6?style=for-the-badge)


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
> flash ROMs, restore stock, flash *any* partition on *any* device, deep-clean junk,
> run a "performance pass," take screenshots, install APKs and more.
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
| ⚡ Flash any partition | boot, init_boot, recovery, vendor_boot, dtbo, vbmeta, system, vendor, super, userdata… or type your own — **works on any device** |
| 🔄 Switch active slot | A/B slot switching |
| 🧹 Erase a partition | cache, userdata, metadata… (with warnings) |
| 🛠️ Reboot to fastbootd | For logical-partition operations |
| 📋 Show all fastboot variables | Debug info dump |
| 📦 Flash ROM *(CMF Phone 2 Pro)* | vendor_boot → wipe-super → recovery → sideload, automated |
| ⏮ Restore stock | Newest (B4.1) or older (V3.2) build, both slots |

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

Plus: live **device status bar** (connection mode 🔌, bootloader lock 🔒/🔓, active slot)
and a menu that **adapts to whatever state your phone is in**.

## 📋 Requirements

- A computer with Linux, macOS — or Windows (see below 👇)
- `adb` & `fastboot` installed — see the install command for your OS below
- A USB cable, and a phone with an **unlocked bootloader** (for flashing)
- ~30 seconds of courage

## 🚀 Quick start (Linux / macOS)

```bash
# 1. Install adb & fastboot — pick your OS
sudo apt update && sudo apt install android-tools-adb android-tools-fastboot   # Ubuntu / Debian
sudo pacman -S android-tools                                                   # Arch / CachyOS
sudo dnf install android-tools                                                 # Fedora
brew install android-platform-tools                                           # macOS

# 2. Save the script
nano ~/flask-adb-toolkit.sh      # paste the script, Ctrl+O, Enter, Ctrl+X

# 3. Make it executable & run
chmod +x ~/flask-adb-toolkit.sh
~/flask-adb-toolkit.sh
```

Rather paste than type? The [live site](https://dedsec-1337.github.io/Flask-ADB-toolkit/) has a **Copy Full Script** and **Download .sh** button that pulls the current version straight off GitHub. Same script, fewer keystrokes.

Then just follow the colorful menus. 🎨

> **CMF Phone 2 Pro owners:** drop your ROM/stock folders into `~/Desktop/cmf`
> (each folder needs its `.zip` / `.img` files), and options 7–9 in the bootloader menu light up.

## 🪟 Windows?

Yes! Two ways — pick your comfort level:

- **🟢 Easiest:** [Git for Windows](https://git-scm.com/download/win) (gives you Git Bash) + Google's [platform-tools](https://developer.android.com/tools/releases/platform-tools) on your `PATH` → then double-click **`flask-adb-toolkit.bat`** 🎉
- **🟣 Classic:** Ubuntu inside Windows via **WSL** (`wsl --install`) — it's basically Linux, then follow the Linux steps above.

## ⚠️ Disclaimer

Flashing partitions **erases data** and can, if misused, brick your device.
This tool asks for confirmation (`type YES`) before anything dangerous —
but **you** are still the one pressing the buttons. 🔘

- Not responsible for lost data, bricked phones, or voided warranties
- Always back up first 📦
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