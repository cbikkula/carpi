# Wiring, Power & Specs

Everything physical: what to buy, how it connects, how to power it from the car
without corrupting the SD card. Read this once before you cut any wires.

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

### Optional
- **Ignition-sense parts** — voltage divider + clamp diode, or an opto-isolator/relay, to feed the switched-12 V "key-on" signal **safely down to 3.3 V** into GPIO3 for auto power-on/off.
- **Cooling** — a heatsink/fan; a sealed box in a hot car can thermal-throttle independent of power.

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
- (Optional) ignition-sense level-shift bits, heatsink/fan
- Official Pi 15 W (Pi 4) / 27 W (Pi 5) USB-C PSU — handy on the bench to confirm the
  build is healthy before it goes in the car
