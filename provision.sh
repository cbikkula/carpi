#!/usr/bin/env bash
# =============================================================================
#  carpi — provision a Raspberry Pi into an OpenDash wired Android Auto head unit
# -----------------------------------------------------------------------------
#  Run this ONCE on the Pi, after its first boot (when it's online).
#
#    Quick (recommended):
#      curl -fsSL https://raw.githubusercontent.com/cbikkula/carpi/main/provision.sh | bash
#
#    Or from a clone:
#      bash provision.sh
#
#  Optional environment knobs (set before running):
#      CARPI_SCREEN=hdmi|dsi     default hdmi   (dsi = official Raspberry Pi touchscreen)
#      CARPI_ROTATE=none|90|180|270   default none   (screen + touch rotation, clockwise)
#      CARPI_HDMI_MODE="1024 600 60 6"   forced HDMI CVT mode "W H Hz aspect" (headless boot)
#      CARPI_CONNECTOR=HDMI-1    X11 output name for rotation (HDMI-1 = Pi4 HDMI0 port)
#      CARPI_AUTORUN=1           install a oneshot service so this resumes after a reboot
#
#  What it does (idempotent — safe to re-run):
#    1. grows swap to 2 GB  (OpenDash will OOM on a Pi 4 with the default 100 MB)
#    2. builds OpenDash (github.com/openDsh/dash) from source via its install.sh
#    3. installs the USB udev rule so Android Auto can claim the phone over libusb
#    4. sets up a dedicated X11 kiosk session that boots straight into the dashboard
#       (avoids Bookworm's Wayland/labwc, which OpenDash's own autostart fights)
#    5. pre-seeds Dash + OpenAuto config (dark theme, wired AA)
#    6. (optional) rotates screen + touch, forces an HDMI mode, enables clean shutdown
# =============================================================================
set -euo pipefail

# ---- must be the normal user (dash builds into $HOME and runs as you), not root
if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user (e.g. 'pi'); it will use sudo where needed. Not as root." >&2
  exit 1
fi

USER_NAME="$(id -un)"
USER_HOME="$HOME"
DASH_DIR="$USER_HOME/dash"
SCREEN="${CARPI_SCREEN:-hdmi}"
ROTATE="${CARPI_ROTATE:-none}"
CONNECTOR="${CARPI_CONNECTOR:-HDMI-1}"
HDMI_MODE="${CARPI_HDMI_MODE:-1024 600 60 6}"
BOOTCFG=/boot/firmware/config.txt
[ -f "$BOOTCFG" ] || BOOTCFG=/boot/config.txt     # pre-Bookworm fallback

log()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# 0. Pre-flight
# -----------------------------------------------------------------------------
log "carpi provision starting for user '$USER_NAME'  (screen=$SCREEN rotate=$ROTATE)"

if ! ping -c1 -W3 github.com >/dev/null 2>&1; then
  warn "No network to github.com. This script downloads ~hundreds of MB and clones repos."
  warn "Connect Wi-Fi/Ethernet first (Raspberry Pi Imager can pre-configure Wi-Fi), then re-run."
  exit 1
fi

# Optional: install a oneshot service that re-runs this script on boot until it
# completes — so a power loss mid-build (a real risk in a car) resumes cleanly.
if [ "${CARPI_AUTORUN:-0}" = "1" ] && [ ! -f "$USER_HOME/.carpi-done" ]; then
  log "Installing resume-on-boot service (carpi-firstboot.service)"
  SELF="$(readlink -f "$0" 2>/dev/null || true)"
  if [ -n "$SELF" ] && [ -f "$SELF" ]; then
    sudo install -m0755 "$SELF" /usr/local/sbin/carpi-provision.sh
    sudo tee /etc/systemd/system/carpi-firstboot.service >/dev/null <<EOF
[Unit]
Description=carpi first-boot OpenDash build (resumes until complete)
After=network-online.target
Wants=network-online.target
ConditionPathExists=!$USER_HOME/.carpi-done

[Service]
Type=oneshot
User=$USER_NAME
Environment=CARPI_SCREEN=$SCREEN CARPI_ROTATE=$ROTATE CARPI_CONNECTOR=$CONNECTOR
ExecStart=/usr/local/sbin/carpi-provision.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable carpi-firstboot.service
  else
    warn "Could not resolve own path; skipping autorun service (piped via curl?). Re-run with a local copy if you want resume-on-boot."
  fi
fi

# -----------------------------------------------------------------------------
# 1. Swap → 2 GB  (compiling AASDK/OpenAuto OOMs on a 1–2 GB Pi with default swap)
# -----------------------------------------------------------------------------
log "Setting swap to 2 GB"
if [ -f /etc/dphys-swapfile ]; then
  sudo dphys-swapfile swapoff || true
  sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
  if grep -q '^#\?CONF_MAXSWAP=' /etc/dphys-swapfile; then
    sudo sed -i 's/^#\?CONF_MAXSWAP=.*/CONF_MAXSWAP=2048/' /etc/dphys-swapfile
  else
    echo 'CONF_MAXSWAP=2048' | sudo tee -a /etc/dphys-swapfile >/dev/null
  fi
  sudo dphys-swapfile setup
  sudo dphys-swapfile swapon
else
  warn "dphys-swapfile not present; skipping swap bump (watch for OOM during build)."
fi

# -----------------------------------------------------------------------------
# 2. Base packages + clone + build OpenDash
# -----------------------------------------------------------------------------
log "Installing git and updating apt"
sudo apt-get update
sudo apt-get install -y git

if [ ! -d "$DASH_DIR/.git" ]; then
  log "Cloning OpenDash → $DASH_DIR"
  git clone https://github.com/openDsh/dash "$DASH_DIR"
else
  log "OpenDash already cloned; pulling latest"
  git -C "$DASH_DIR" pull --ff-only || warn "git pull skipped (local changes?)"
fi

if [ ! -x "$DASH_DIR/bin/dash" ]; then
  log "Building OpenDash — this takes ~30–45 min on a Pi 4. Go get a coffee."
  # install.sh installs all apt deps and builds AASDK, h264bitstream, qt-gstreamer,
  # OpenAuto and Dash. It ends with 3 interactive prompts; feed 'n' to each so the
  # build completes non-interactively (we wire up autostart ourselves below).
  ( cd "$DASH_DIR" && printf 'n\nn\nn\n' | ./install.sh )
else
  log "OpenDash binary already present ($DASH_DIR/bin/dash); skipping build"
fi

[ -x "$DASH_DIR/bin/dash" ] || { warn "Build did not produce $DASH_DIR/bin/dash — check output above."; exit 1; }

# -----------------------------------------------------------------------------
# 3. USB udev rule so non-root OpenAuto can claim the phone (Android Auto)
#    Phone re-enumerates as Google VID 0x18d1 (PIDs 0x2d00–0x2d05) after the
#    AOAP accessory-mode switch; grant plugdev access to that device node.
# -----------------------------------------------------------------------------
log "Installing Android Auto USB udev rule + adding $USER_NAME to plugdev"
sudo tee /etc/udev/rules.d/51-android.rules >/dev/null <<'EOF'
# Android Auto over USB (AOAv2). The phone connects to a Pi USB-A *host* port.
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0664", GROUP="plugdev"
EOF
sudo usermod -aG plugdev "$USER_NAME"
sudo udevadm control --reload-rules && sudo udevadm trigger

# Sanity: a wired head unit must NOT be in USB gadget/peripheral mode.
if grep -qE '^\s*dtoverlay=dwc2' "$BOOTCFG" 2>/dev/null; then
  warn "Found dtoverlay=dwc2 in $BOOTCFG — that forces USB *device* mode and breaks"
  warn "phone detection for a head unit. Removing it."
  sudo sed -i '/^\s*dtoverlay=dwc2.*/d' "$BOOTCFG"
fi

# -----------------------------------------------------------------------------
# 4. Kiosk autostart: a dedicated X11 session that runs ONLY dash on tty1.
#    autostart.sh -axi installs xserver-xorg/xinit, writes run_dash.sh, and appends
#    `startx` on tty1 to .bashrc. We then own ~/.xinitrc to add DPMS-off + rotation.
# -----------------------------------------------------------------------------
log "Configuring X11 kiosk autostart (xinit path — avoids Wayland/labwc)"
( cd "$DASH_DIR" && ./autostart.sh -axi ) || warn "autostart.sh -axi returned non-zero; continuing"

# Console autologin on tty1 so the startx-on-login fires unattended at boot.
sudo raspi-config nonint do_boot_behaviour B2 || warn "could not set console autologin via raspi-config"

# Rotation commands for the X session (clockwise). xrandr rotates the output;
# the libinput/xinput matrix rotates touch to match.
ROT_CMDS=""
case "$ROTATE" in
  90)  ROT_CMDS="xrandr --output $CONNECTOR --rotate right;   TMATRIX='0 1 0 -1 0 1'" ;;
  180) ROT_CMDS="xrandr --output $CONNECTOR --rotate inverted; TMATRIX='-1 0 1 0 -1 1'" ;;
  270) ROT_CMDS="xrandr --output $CONNECTOR --rotate left;    TMATRIX='0 -1 1 1 0 0'" ;;
  none|*) ROT_CMDS="" ;;
esac

cat > "$USER_HOME/.xinitrc" <<EOF
#!/bin/sh
# carpi kiosk session — blank-screen/DPMS off, optional rotation, then dash forever.
xset -dpms; xset s off; xset s noblank
EOF
if [ -n "$ROT_CMDS" ]; then
  cat >> "$USER_HOME/.xinitrc" <<EOF
$ROT_CMDS
# rotate the first touch device to match the display
TDEV="\$(xinput list --name-only 2>/dev/null | grep -i -m1 touch || true)"
[ -n "\$TDEV" ] && [ -n "\${TMATRIX:-}" ] && xinput set-prop "\$TDEV" 'Coordinate Transformation Matrix' \$TMATRIX
EOF
fi
cat >> "$USER_HOME/.xinitrc" <<EOF
while true; do
  "$DASH_DIR/bin/dash" >> "$DASH_DIR/bin/dash.log" 2>&1
  sleep 2
done
EOF
chmod +x "$USER_HOME/.xinitrc"

# Official 7" DSI panel: udev rule so brightness control works for a non-root user.
if [ "$SCREEN" = "dsi" ] && [ -x "$DASH_DIR/rpi.sh" ]; then
  ( cd "$DASH_DIR" && ./rpi.sh -arb ) || warn "rpi.sh -arb (brightness udev) returned non-zero"
fi

# -----------------------------------------------------------------------------
# 5. Pre-seed config: dark theme + wired Android Auto
# -----------------------------------------------------------------------------
log "Pre-seeding Dash + OpenAuto config"
mkdir -p "$USER_HOME/.config/openDsh"
cat > "$USER_HOME/.config/openDsh/dash.conf" <<'EOF'
[Theme]
mode=1
[Theme%20Color]
EOF
# OpenAuto reads openauto.ini from its working dir (= $HOME/dash). Reasonable wired defaults.
cat > "$DASH_DIR/openauto.ini" <<'EOF'
[Video]
Resolution=1
ScreenDPI=140
[Input]
EnableTouchscreen=true
EOF

# -----------------------------------------------------------------------------
# 6. Display + power housekeeping in config.txt
# -----------------------------------------------------------------------------
log "Updating $BOOTCFG (KMS, HDMI force-mode, clean shutdown)"
ensure_cfg() { grep -qxF "$1" "$BOOTCFG" 2>/dev/null || echo "$1" | sudo tee -a "$BOOTCFG" >/dev/null; }

ensure_cfg "dtoverlay=vc4-kms-v3d"
ensure_cfg "max_framebuffers=2"

if [ "$SCREEN" = "hdmi" ]; then
  # Force output + mode so the car screen works even with no/garbled EDID and no
  # monitor attached at flash time. (Rotation is handled in X, not here, under KMS.)
  ensure_cfg "hdmi_force_hotplug=1"
  ensure_cfg "hdmi_group=2"
  ensure_cfg "hdmi_mode=87"
  ensure_cfg "hdmi_cvt=$HDMI_MODE 0 0 0"
elif [ "$SCREEN" = "dsi" ]; then
  ensure_cfg "display_auto_detect=1"
fi

# Clean shutdown: pulling GPIO3 (physical pin 5) LOW triggers a proper halt.
# Wire your ignition-sense (level-shifted to 3.3V!) here, and hold 5V through the
# shutdown with a supercap/UPS or a latching car-power board. See WIRING.md.
ensure_cfg "dtoverlay=gpio-shutdown,gpio_pin=3,active_low=1,gpio_pull=up"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
touch "$USER_HOME/.carpi-done"
if [ "${CARPI_AUTORUN:-0}" = "1" ]; then
  sudo systemctl disable carpi-firstboot.service >/dev/null 2>&1 || true
fi

log "carpi provision complete."
cat <<EOF

  Next:
    • Reboot:            sudo reboot
    • On reboot the Pi boots straight into the OpenDash dashboard.
    • Plug your phone into a Pi USB-A port with a USB-C→USB-A *data* cable.
      Accept the Android Auto prompt on the phone. First time, enable
      "Add new cars to Android Auto" in the phone's Android Auto settings.

  If the screen is blank or rotated wrong, see TROUBLESHOOTING in FLASH.md.
  Build log:   $DASH_DIR/bin/dash.log
EOF
