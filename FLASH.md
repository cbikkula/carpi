# Flash & Setup (from a Windows PC)

Goal: a microSD that boots a Raspberry Pi straight into a full car infotainment
dashboard (OpenDash) with Android Auto — navigation, music, calls, voice, and room to
add a backup camera and live vehicle data later. Plug in the phone, drive.

You do this in two stages because **OpenDash is built from source on the Pi** (there's
no prebuilt image), and the very first boot can't reach the network early enough to
download it. So: **(1)** flash a clean OS with your Wi-Fi baked in, then **(2)** run one
command that builds and configures everything (~30–45 min, unattended).

---

## Stage 1 — Flash Raspberry Pi OS with Raspberry Pi Imager

1. Install **Raspberry Pi Imager** on Windows: https://www.raspberrypi.com/software/
2. Insert the microSD.
3. In Imager:
   - **Device:** Raspberry Pi 4 (or 5)
   - **OS:** *Raspberry Pi OS (other)* → **Raspberry Pi OS Lite (64-bit)**
     *(Lite is intentional — we run a dedicated kiosk session, no heavy desktop.)*
   - **Storage:** your microSD
4. Click **Next → Edit Settings** (the OS customization dialog) and set:
   - ✅ **Set hostname:** `carpi`
   - ✅ **Set username and password** — remember these (you'll SSH in once)
   - ✅ **Configure wireless LAN** — your Wi-Fi SSID + password + country
     *(this is what gets the Pi online for the build)*
   - ✅ **Set locale** (timezone / keyboard)
   - **Services tab:** ✅ **Enable SSH** → *Use password authentication*
5. **Save → Write.** Wait for it to flash and verify.

> Why these settings: Imager writes them to the boot partition and the Pi applies
> them on first boot. The Wi-Fi config is the key bit — it brings the Pi online so
> Stage 2 can download OpenDash.

---

## Stage 2 — Build the head unit (one command)

1. Put the microSD in the Pi, connect the **screen**, and power it (a normal USB-C
   supply is fine for setup — the car wiring comes later, see **WIRING.md**).
2. Give it ~1 minute to boot and join Wi-Fi.
3. From your Windows PC, open **PowerShell** or **Windows Terminal** and SSH in:
   ```powershell
   ssh <your-username>@carpi.local
   ```
   *(If `carpi.local` doesn't resolve, find the Pi's IP in your router and use that.)*
4. Run the provisioner:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cbikkula/carpi/main/provision.sh | bash
   ```
   That's it. It bumps swap, builds OpenDash, installs the USB rule for Android Auto,
   sets up the boot-to-dashboard kiosk, and pre-seeds a dark theme. **~30–45 min.**
5. When it finishes:
   ```bash
   sudo reboot
   ```
   The Pi reboots **straight into the dashboard**.

### Options (set before the curl command)
```bash
# Official Pi DSI touchscreen instead of generic HDMI:
CARPI_SCREEN=dsi  curl -fsSL https://raw.githubusercontent.com/cbikkula/carpi/main/provision.sh | bash

# Rotate screen + touch 270° (e.g. portrait mount). Values: 90 | 180 | 270
CARPI_ROTATE=270  curl -fsSL .../provision.sh | bash

# Resume-on-boot (auto-retries the build if power drops mid-install — good for a car).
# Needs a local copy, not the curl pipe:
git clone https://github.com/cbikkula/carpi && CARPI_AUTORUN=1 bash carpi/provision.sh
```

---

## Stage 3 — First Android Auto connection

1. On the **phone**, open the Android Auto settings once and enable
   **"Add new cars to Android Auto"** (and make sure Android Auto is set up at all).
2. Plug the phone into a **Pi USB-A port** with a **USB-C→USB-A data cable**
   (see WIRING.md for why USB-A, not USB-C).
3. Accept the **"Allow Android Auto?"** prompt on the phone.
4. The dashboard shows Android Auto — Maps/Waze, media, calls, voice. Done.

---

## Stage 4 — Install in the car

Follow **WIRING.md** for the 12 V→5 V converter, fusing, the clean-shutdown
UPS/ignition wiring, and the full diagram. Bench-test everything on a desk supply
*first* — confirm it boots to the dashboard and the phone connects — before it goes
behind the dash.

---

## Optional — Add a backup / dash camera

OpenDash's camera page is a *viewer*, so you just give it a video source. Pick one:

### A) A USB camera (simplest)
1. Plug the **USB camera into any Pi USB-A port** (the phone uses one too — the Pi 4 has
   four, so both fit).
2. Confirm the Pi sees it (SSH in):
   ```bash
   ls /dev/video*            # expect /dev/video0 (or similar)
   v4l2-ctl --list-devices   # shows the camera's name + device path
   ```
3. On the dashboard, open the **Camera** page → choose **Local**, select the device →
   **Connect**. You should see the live view.

### B) Reuse the car's existing reversing camera
Same as above, but the camera's analog (composite) wire goes into a **composite→USB
capture dongle**, and the **dongle** plugs into the Pi's USB-A port. To the Pi it looks
just like a USB camera (`/dev/video0`) — follow steps 2–3 above.

### C) A network (IP) camera
On the **Camera** page choose **Network** and enter an **RTSP** URL
(`rtsp://user:pass@192.168.1.50:554/stream`). No USB cable needed.

**Pre-set it without the UI (optional):** the source is stored in
`~/.config/openDsh/dash.conf` — `Pages/Camera/local_device=/dev/video0`, or
`Pages/Camera/stream_url=rtsp://…` with `Pages/Camera/is_network=true`.

**Mounting:** for an actual *reversing* camera, use a weatherproof one at the rear and
run its cable forward to the Pi — a bare USB webcam is only fine for a forward/dash view.

> ⚠️ The camera is a **manual screen** — open the Camera page to see it. OpenDash does
> **not** auto-switch to it when you shift into reverse; that needs extra CAN-bus/GPIO
> wiring (a future add-on).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| **Blank screen after reboot** | Check `~/dash/bin/dash.log`. Confirm console autologin on tty1 is on (`sudo raspi-config` → System → Boot/Auto Login → *Console Autologin*). The kiosk starts X from the tty1 login. |
| **Screen rotated wrong / touch off** | Re-run with `CARPI_ROTATE=90/180/270`. For a **generic HDMI** panel, touch needs the xinput matrix (provision.sh sets it); find the device name with `xinput list` if it didn't auto-match. The **DSI** panel rotates touch automatically. |
| **Wrong resolution / no image on the car screen** | Set the panel's real mode: `CARPI_HDMI_MODE="1024 600 60 6"` (W H Hz aspect) and re-run, or edit `hdmi_cvt` in `/boot/firmware/config.txt` per `config/config.txt.snippets`. |
| **Phone not detected / "connecting" loop** | Use a **data** cable (not charge-only), in a **USB-A** port (not USB-C). Confirm there's **no** `dtoverlay=dwc2` in config.txt. `lsusb` should list the phone. |
| **`LIBUSB_ERROR_ACCESS` in dash.log** | udev rule/plugdev missing. Re-run provision.sh, then **reboot** (group change needs it). |
| **Lightning-bolt icon / random reboots** | Under-voltage — your power supply is too weak. See WIRING.md §2. `vcgencmd get_throttled` (0x0 = healthy). |
| **Build failed / out of memory** | Confirm swap is 2 GB (`free -h`), then re-run provision.sh — it's idempotent and skips finished steps. |
| **Android Auto wired support changed** | Newer phones/AA versions can be finicky over USB; make sure the phone's AA app is up to date and "Add new cars" was enabled before first plug-in. |
| **Camera not listed / no `/dev/video0`** | Re-seat the USB camera/capture dongle; `ls /dev/video*` and `dmesg | tail` after plugging in. Use a USB 2.0 (black) port if a cheap dongle won't enumerate on USB 3.0. For RTSP, test the URL with `ffplay rtsp://…` first. |

---

## What you can tweak later

- **Theme/scale/colors:** `~/.config/openDsh/dash.conf`
- **Android Auto video/input:** `~/dash/openauto.ini`
- **Wireless AA** is possible but flaky on a Pi 4 (needs a 5 GHz-hotspot-capable
  adapter); wired is the reliable path and what this setup targets.
