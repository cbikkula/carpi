# carpi 🚗📱

**A full car infotainment system — built on a Raspberry Pi for a fraction of the cost
of a factory or aftermarket head unit.**

Navigation, music, hands-free calls, voice control, backup camera, live vehicle data —
everything a modern car's touchscreen does. You flash a Pi, run one command, and it
boots straight into the [OpenDash](https://github.com/openDsh/dash) dashboard with
Android Auto. Plug your phone in and drive.

No subscription. No proprietary head unit. No installer markup.

---

## Everything your car's screen does — for ~$120 instead of $500–$1,500

| Capability | How |
|---|---|
| 🗺️ **Navigation + live traffic** | Google Maps / Waze via Android Auto |
| 🎵 **Music & media** | Phone apps, Bluetooth audio, local files |
| 📞 **Hands-free calls & texts** | Android Auto |
| 🎙️ **Voice control** | "Hey Google" through Android Auto |
| 🚀 **Boots to the dashboard** | Dedicated kiosk — on with the car, no menus |

**Add a little hardware and it does the rest a head unit does** (all supported by OpenDash):

| Capability | Add-on |
|---|---|
| 🎥 **Backup / dash camera** | Reuse your car's **existing reversing camera** (~$10 composite→USB dongle), or add a cheap **USB / aftermarket reversing camera** if it has none — or an **RTSP IP camera**. ~$10–40 either way. |
| 📊 **Live vehicle data & gauges** (RPM, coolant, boost, fault codes) | A cheap **OBD-II** adapter (CAN bus) |
| 🎛️ **Steering-wheel button control** | GPIO wiring |
| 🌗 **Custom themes, day/night, dark mode** | Built in — just configure |

### What it costs vs. the alternatives
| Option | Typical cost |
|---|---|
| Factory infotainment upgrade (dealer) | $1,000–$2,500+ |
| Aftermarket CarPlay/Android Auto unit **+ professional install** | $300–$1,500 |
| **carpi** (Pi 4 + 7" touchscreen + power + cabling) | **~$100–$150** |

Same core experience — the screen, the maps, the music, the voice — at parts cost.

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
- *(Optional)* a camera (USB, or your car's existing reversing camera via a capture
  dongle), OBD-II adapter — to unlock the extra features above

Full specs, the wiring diagram, and a buy-list are in **[WIRING.md](WIRING.md)**.

---

## Good to know

- **It runs Android Auto's interface**, not a bespoke skin — which is *why* it does
  everything your phone's nav/media/voice can, with zero app development. A custom UI
  or extra dashboard widgets are an optional layer to build *on top of* this working
  base later (OpenDash is fully themeable and extensible).
- **Wired** is the target (rock-solid). Wireless Android Auto on a Pi 4 is possible but
  flaky, so this setup uses a USB cable.
- **The backup camera is a manual screen** — OpenDash shows the camera when you open its
  page, but it does **not** auto-pop when you shift into reverse (a factory unit does).
  Adding a real reverse-gear trigger needs extra CAN-bus/GPIO wiring — a future add-on.
- A few things still belong to the car itself (AM/FM tuner, OEM amplifier integration);
  carpi covers the touchscreen-infotainment half — the part that actually costs money
  to replace.

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
AASDK) — a full open-source car infotainment platform. Android Auto is a trademark of
Google; this is an unofficial open-source receiver. Wired AA behavior can change with
phone/Android Auto updates. Do the 12 V wiring carefully — see the safety notes in
WIRING.md.
