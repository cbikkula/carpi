# Wiring, Power & Specs

Everything physical for a full car infotainment build: what to buy, how it connects,
and how to power it from the car without corrupting the SD card. The core parts get you
navigation/music/calls/voice; the optional parts (USB camera, OBD-II adapter) unlock the
backup-camera and live-vehicle-data features. Read this once before you cut any wires.

> ⚠️ **Working on a car's 12 V system can blow fuses, drain the battery, or start a
> fire if done wrong.** Fuse everything close to the source, never feed raw 12 V
> into the Pi, and if you're unsure about tapping the fuse box, have an installer
> do the 12 V side. The Pi/USB side below is safe to do yourself.

---

## 1. Parts list (specs)

### Core
| Part | Spec / why |
|---|---|
| **Raspberry Pi 4 Model B** | 4 GB recommended (2 GB works but compiles slower & tighter on swap). Pi 5 also fine — see power notes. |
| **microSD card** | 32 GB+, **A1/A2 "high-endurance"** (e.g. SanDisk High Endurance / Max Endurance). Car heat + power cycles kill cheap cards. A USB-SSD boot is even more robust. |
| **Touchscreen** | Either a **generic 7" HDMI 1024×600 touchscreen**, or the **official Raspberry Pi 7" DSI touchscreen** (best-supported: touch rotation + brightness "just work"). |
| **USB-C → USB-A data cable** | Phone (USB-C) → **Pi USB-A port**. Must be a **data** cable, not charge-only. Short & good quality — long/flaky cables cause AA "connecting" loops. |

### Power (the part that matters most)
| Part | Spec / why |
|---|---|
| **12 V→5 V buck converter** | Wide input (**8–32 V**), automotive-grade, delivering a **genuine continuous 5 V / 3 A (15 W)** for a Pi 4 — or **5 V / 5 A (25 W)** / USB-PD for a Pi 5. Cheap "5 V 3 A" cig-lighter adapters often sag under load → brownouts. |
| **Inline fuse / add-a-fuse tap** | **5 A** automotive blade fuse at the **fuse box / source**, protecting the wire. |
| **Primary wire** | **18 AWG** (or thicker 16 AWG) for the 12 V run; keep the 5 V run short. |
| **Clean-shutdown device** | A **supercapacitor UPS HAT** (best for a car — survives thousands of power cycles, tolerates heat) **or** a latching car-power board (Mausberry, OnOff SHIM). Holds 5 V up for the ~10–30 s the Pi needs to halt after key-off. |

### Optional — unlock the extra head-unit features
- **Backup / dash camera** — OpenDash's camera page is a *viewer*, so it needs a real
  video source. Three ways to feed it:
  - **Car already has a reversing camera?** Reuse it — most factory cameras are analog
    composite, so add a cheap **composite→USB capture dongle** (~$10). It shows up as a
    `/dev/video` device. No new camera needed.
  - **Car has none?** Add a cheap one: any **USB/UVC webcam** (~$10–25, plug-and-play),
    or an **aftermarket reversing camera** (~$15–30, weatherproof, license-plate/rear
    mount) + the same composite→USB dongle. Better suited to the rear of a car than a webcam.
  - **IP camera:** OpenDash also accepts a network **RTSP** stream (`rtsp://…`).
  Note: there's **no automatic reverse-gear trigger** — the camera is a manual screen
  (auto-popping it on reverse would need extra CAN/GPIO wiring). You pick the source in
  the OpenDash camera page; to pre-set it, the keys live in `~/.config/openDsh/dash.conf`
  (`Pages/Camera/local_device` for a `/dev/video*` device, `Pages/Camera/stream_url` +
  `Pages/Camera/is_network=true` for RTSP).
- **OBD-II adapter** — for **live vehicle data & gauges** (RPM, coolant, boost, fault codes) via CAN bus. A USB or Bluetooth ELM327-style adapter plugged into the car's OBD-II port.
- **Ignition-sense parts** — voltage divider + clamp diode, or an opto-isolator/relay, to feed the switched-12 V "key-on" signal **safely down to 3.3 V** into GPIO3 for auto power-on/off.
- **Cooling** — a heatsink/fan; a sealed box in a hot car can thermal-throttle independent of power.

---

## 1b. A verified example build (real parts)

A worked example, with the gotchas called out. Use it as a template — exact models go
in and out of stock, so match the **specs**, not the link.

| Part | Pick | Verdict | Notes |
|---|---|---|---|
| **Screen** | 7" HDMI **touchscreen**, 1024×600 IPS (HMTECH / Waveshare etc.) | ✅ **must be touch** | ⚠️ A *non-touch* 7" panel will boot but you **can't operate Android Auto** — touch is the only way in. "HDMI for video, USB for touch." If it's 800×480, set `CARPI_HDMI_MODE="800 480 60 6"`. |
| **Power** | Anker PowerDrive III Duo (40 W USB-C PD) | ✅ usually OK | USB-C port gives 5 V/3 A as its base contract, enough for a Pi 4. Watch for the lightning-bolt icon. Gives **no clean-shutdown** on its own — see §3. |
| **Camera** | NexiGo N60 USB webcam (1080p, 110°, built-in mic) | ✅ dash cam / 🎙️ mic | Real UVC webcam → `/dev/video0`, plug-and-play. **Not weatherproof** — fine forward-facing, *not* for an exposed rear mount. Bonus: its mic doubles as the **Android Auto microphone** (voice + calls). |
| **USB extension** | 20 ft USB-A male→female, data | ✅ for the camera | Extends the webcam's reach. 20 ft passive is long — if the cam glitches, suspect the cable length first. |
| **Phone cable** | USB-A → USB-C **data** cable | ✅ essential | The A-to-A extension does **not** connect the phone. USB-A into the Pi, USB-C into the phone. |
| **Power cable** | USB-C → USB-C cable | ✅ needed | From the Anker USB-C port to the Pi's USB-C power port. |
| **GPS** | Onyehn VK-162 USB GPS | ⚪ not needed now | Android Auto uses the **phone's** GPS. Only useful later for an on-Pi custom map. Skip for the AA build. |
| **Mount** | (the 4.3"/5" monitor bracket won't fit) | ❌ wrong size | Get a mount sized for the **7" screen** (vent / CD-slot / dash). The small backup-monitor bracket is for 4.3–5" displays, not a 7" panel, and isn't a camera mount either. |

### How you interact with it
- **Touch the dash screen** — primary input for both OpenDash and Android Auto (this is
  why the screen *must* be touch).
- **Voice** — "Hey Google" via Android Auto, using any USB mic (the NexiGo webcam's mic works).
- **Your phone stays in your pocket** — when AA is active the phone screen locks; the
  phone is the brain (GPS, data, music), not the remote. You drive everything from the dash.
- **Optional later:** steering-wheel buttons via GPIO.

---

## 2. Why not "just a USB car charger"?

A Pi 4 wants a clean **5.1 V at up to 3 A**. In a car you get:
- **Crank sag** — voltage dips when the engine starts.
- **Load-dump spikes** — nasty transients on the 12 V rail.
- **Cheap adapters** that advertise 3 A but collapse under sustained load.

Any of these shows up as the **lightning-bolt under-voltage icon**, CPU throttling,
and eventually **SD-card corruption**. A proper wide-input automotive buck
converter regulates through all of it. This is the single most important choice in
the build — don't cheap out here.

Check health on the Pi any time:
```bash
vcgencmd get_throttled     # 0x0 = healthy. bit0 set = under-voltage NOW.
                           # 0x50000 = under-voltage + throttling has occurred.
dmesg | grep -i voltage    # kernel "Under-voltage detected!" warnings
```

---

## 3. The clean-shutdown problem (don't skip this)

When you turn the car off, **don't cut power instantly** — the OS needs ~10–30 s to
flush writes and halt. Pull the plug mid-write and you corrupt the card. Two pieces
solve it:

1. **Tell the Pi to shut down on key-off.** The `gpio-shutdown` overlay (provision.sh
   adds it) issues a proper halt when **GPIO3 (pin 5) goes LOW**. Wire your
   ignition-sense signal there — *level-shifted to 3.3 V*.
2. **Hold 5 V through the halt.** A **supercap/UPS HAT** bridges the gap, or a
   **latching board** (Mausberry/OnOff SHIM) keeps 5 V on until the Pi signals it's
   done, then cuts power itself.

Also: tap a **switched (ignition) 12 V** circuit, **not** a constant-hot one, or the
Pi will slowly drain your battery while parked.

---

## 4. Wiring diagram

```
   CAR 12V FUSE BOX
   (switched/ignition slot)
        │
   [ 5A fuse / add-a-fuse tap ]         ← fuse AT the source, protects the wire
        │ 18 AWG
        ▼
   ┌─────────────────────────┐
   │  12V→5V BUCK CONVERTER   │  wide input 8–32V, real 5V/3A (Pi4) or 5A (Pi5)
   │  (automotive, regulated) │
   └─────────────────────────┘
        │ 5V USB-C (short, thick)
        ▼
   ┌─────────────────────────┐        ┌──────────────────────────────┐
   │  SUPERCAP / UPS HAT      │───5V──▶│        RASPBERRY PI 4        │
   │  (holds 5V through halt) │        │                              │
   └─────────────────────────┘        │  USB-C power IN ◀── 5V       │
        ▲                              │                              │
        │ key-on 12V                   │  USB-A  ◀──── data cable ────┼──▶ PHONE (USB-C)
   [ ignition-sense ]                  │   (host)     USB-C→USB-A          (Android Auto)
   [ level-shift → 3.3V ]──────GPIO3──▶│  GPIO3 (pin5): clean-shutdown │
        (divider+clamp / opto)         │                              │
                                       │  HDMI ───▶ 7" touchscreen     │
                                       │  USB    ◀── touch (USB HID)   │  (HDMI panel)
                                       │   OR  DSI ribbon ◀──────────▶ │  (official panel)
                                       └──────────────────────────────┘
```

### The three connections that make it "plug and play"
1. **Power:** car 12 V (fused, switched) → buck converter → (UPS HAT) → Pi 5 V in.
2. **Phone:** phone **USB-C** → **USB-A** on the Pi (the Pi is the **host**). Data cable.
3. **Screen:** HDMI + USB-touch, **or** the DSI ribbon for the official panel.

---

## 5. USB: why the phone goes in a USB-A port (not USB-C)

A wired Android Auto head unit makes the **Pi the USB host** and the **phone the
accessory** (Android Open Accessory / AOAv2). So:

- ✅ Phone **USB-C → Pi USB-A** with a **data** cable.
- ❌ **Don't** plug the phone into the Pi's **USB-C** port — that's power-in / device mode.
- ❌ **Don't** use a USB-C→USB-C cable into the Pi, and **never** a charge-only cable
  (it powers the phone but never enumerates it — looks like "nothing happens").
- ❌ **Don't** add `dtoverlay=dwc2` to config.txt — that forces the Pi into USB
  *device* mode (the opposite role) and breaks detection. (That overlay is only for
  the *other* kind of project, where the Pi pretends to be a phone toward the car.)

The udev rule in `config/51-android.rules` (installed by provision.sh) is what lets
the non-root dashboard claim the phone after it switches into accessory mode.

---

## 6. Quick buy-list

- Raspberry Pi 4 (4 GB) + high-endurance microSD (32 GB+)
- 7" HDMI touchscreen **or** official Pi DSI touchscreen
- Short USB-C→USB-A **data** cable
- Wide-input (8–32 V) automotive **12 V→5 V / 3 A USB-C** buck converter
- **Supercap UPS HAT** (or Mausberry / OnOff SHIM latching board)
- Add-a-fuse tap + **5 A** blade fuse, 18 AWG wire, crimp connectors
- (Optional) backup camera — reuse the car's existing one via a composite→USB capture
  dongle, or add a USB/aftermarket reversing camera if not equipped; OBD-II adapter
  (vehicle data); ignition-sense level-shift bits; heatsink/fan
- Official Pi 15 W (Pi 4) / 27 W (Pi 5) USB-C PSU — handy on the bench to confirm the
  build is healthy before it goes in the car
