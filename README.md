# carpi 🚗📱

Turn a **Raspberry Pi** into a **wired Android Auto head unit** for your car — boots
straight into the [OpenDash](https://github.com/openDsh/dash) dashboard, powered from
the cigarette-lighter / 12 V circuit, with your phone connected over USB.

Plug your phone in → Maps/Waze, media, calls, and voice on the dash screen. No
subscription, no proprietary head unit.

---

## What it is

- A **flash-and-go recipe**, not a custom map app. You flash Raspberry Pi OS, run
  one command, and the Pi becomes an Android Auto receiver running OpenDash.
- **Wired Android Auto** over USB (the reliable path). The Pi is the USB *host*; your
  phone projects Android Auto to the Pi's screen, exactly like a factory head unit.
- Designed to live in a car: dedicated kiosk session, 12 V power guidance, and a
  **clean-shutdown** path so ignition-off doesn't corrupt the SD card.

### What you get
✅ Google Maps / Waze with live traffic (from the phone) &nbsp; ✅ Voice commands
&nbsp; ✅ Media & calls &nbsp; ✅ Boots to the dashboard automatically

### What it is **not** (yet)
- Not a custom map UI — it shows **Android Auto's own interface**. (A custom overlay
  is a future layer to build *on top of* this working base.)
- Not wireless — wired USB is what this targets; wireless AA on a Pi 4 is flaky.

---

## Quick start

1. **Flash** Raspberry Pi OS Lite (64-bit) with Raspberry Pi Imager, baking in your
   Wi-Fi + SSH. → [FLASH.md](FLASH.md)
2. **SSH in once** and run:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cbikkula/carpi/main/provision.sh | bash
   sudo reboot
   ```
3. **Plug the phone** into a Pi **USB-A** port with a USB-C→USB-A **data** cable.
4. **Wire it into the car** → [WIRING.md](WIRING.md)

Full step-by-step (with options and troubleshooting) is in **[FLASH.md](FLASH.md)**.

---

## Hardware (short version)

- Raspberry Pi 4 (4 GB) + high-endurance microSD
- 7" HDMI touchscreen **or** official Pi DSI touchscreen
- USB-C→USB-A **data** cable (phone → Pi)
- Automotive **12 V→5 V / 3 A** USB-C buck converter + **5 A** fuse + a
  **supercap/UPS** for clean shutdown

Full specs, the wiring diagram, and a buy-list are in **[WIRING.md](WIRING.md)**.

---

## How it works (the non-obvious bits)

- **USB role:** a wired AA head unit makes the **Pi the host** and the **phone the
  accessory** (AOAv2). Phone goes in a **USB-A** port, *not* USB-C, and **no
  `dtoverlay=dwc2`** (that's USB device mode — the wrong role). A udev rule lets the
  non-root dashboard claim the phone after it switches into accessory mode.
- **Display:** under the modern KMS driver the old `display_rotate` keys are ignored;
  rotation (screen **and** touch) is done in the graphics session. `provision.sh`
  handles it via `xrandr` + `xinput`.
- **Boot-to-dashboard:** runs OpenDash in a **dedicated X11 kiosk session** on tty1.
  This deliberately avoids Bookworm's Wayland/labwc, which OpenDash's stock
  autostart fights (causing blank-screen issues).
- **Build, not download:** OpenDash compiles from source (~30–45 min on a Pi 4), so
  `provision.sh` bumps swap to 2 GB first to avoid out-of-memory during the build.

---

## Repository layout

| Path | What |
|---|---|
| [`provision.sh`](provision.sh) | The one script. Builds + configures everything on the Pi. Idempotent. |
| [`FLASH.md`](FLASH.md) | Flash from Windows, run setup, first AA connection, troubleshooting. |
| [`WIRING.md`](WIRING.md) | Parts/specs, power, clean-shutdown, full wiring diagram, buy-list. |
| [`config/51-android.rules`](config/51-android.rules) | USB udev rule for Android Auto. |
| [`config/config.txt.snippets`](config/config.txt.snippets) | HDMI/DSI/shutdown `config.txt` reference. |

---

## Credits & caveats

Built on **[OpenDash](https://github.com/openDsh/dash)** (which bundles OpenAuto +
AASDK). Android Auto is a trademark of Google; this is an unofficial
open-source receiver. Wired AA behavior can change with phone/Android Auto updates.
Do the 12 V wiring carefully — see the safety notes in WIRING.md.
