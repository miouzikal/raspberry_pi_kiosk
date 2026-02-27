
# Raspberry Pi Kiosk Mode Setup

A setup script that configures a Raspberry Pi 4B as a dedicated kiosk for displaying a Home Assistant UI on a touchscreen. Uses a lightweight Wayland stack for fast, low-memory operation with a seamless boot splash.

## Stack

| Layer | Component | Purpose |
|-------|-----------|---------|
| Boot splash | **Plymouth** (DRM backend) | Seamless splash image from early boot |
| Compositor | **Cage** (Wayland kiosk) | Single-app fullscreen compositor, ~64KB |
| Browser | **Cog** (WPE WebKit) | Embedded kiosk browser, ~100MB RAM |
| OS | **RPi OS Lite Bookworm 64-bit** | Minimal base with apt/SSH access |

## Hardware

- Raspberry Pi 4B 4GB
- [64GB Raddor SD Card](https://www.amazon.ca/-/fr/dp/B0CD2SR4XM?ref=ppx_yo2ov_dt_b_product_details&th=1)
- [WaveShare 10.1DP-CAPLCD screen](https://www.amazon.ca/-/fr/dp/B0BPM9VTY6?ref=ppx_yo2ov_dt_b_product_details&th=1) — 1280x800, HDMI + USB touch
- [Copper Heatsink](https://www.amazon.ca/-/fr/Dissipateur-thermique-acrylique-Raspberry-d%C3%A9paisseur/dp/B0CP5SLMLM/ref=sr_1_14?__mk_fr_CA=%C3%85M%C3%85%C5%BD%C3%95%C3%91&crid=1QVUH3VEBV6A3&keywords=copper+raspberry+pi+heatsink&qid=1706462908&s=electronics&sprefix=copper+raspberry+pi+heatsink%2Celectronics%2C84&sr=1-14)
- [TP-Link Archer T3U](https://www.amazon.ca/dp/B07P6N2TZH?psc=1&ref=ppx_yo2ov_dt_b_product_details) — USB WiFi (copper heatsink blocks onboard WiFi)
- [USB Microphone](https://www.amazon.ca/-/fr/gp/product/B01KLRBHGM/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&psc=1) — for wake-on-sound

## Prerequisites

- Raspberry Pi 4B with Raspberry Pi OS Lite Bookworm 64-bit
- SD card (64GB+ recommended)
- A computer with an SD card reader
- Monitor, keyboard, and mouse for initial setup
- Stable internet connection
- Home Assistant instance accessible on the network

## Flashing Raspberry Pi OS Lite

### 1. Download and Install Raspberry Pi Imager
- Download from the [Raspberry Pi website](https://www.raspberrypi.org/downloads/)
- Install and open the Imager

### 2. Flash with WiFi and User Configuration
- Select **Raspberry Pi OS Lite (Bookworm 64-bit)**
- Select your SD card
- Click the gear icon for advanced options:
  - Set up WiFi credentials
  - Optionally change the hostname
  - Set a username and password
  - Enable SSH
- Flash the SD card

## Setting Up Kiosk Mode

### 1. Boot and Log In
- Insert the SD card, connect to monitor/keyboard/power
- Log in with your configured credentials

### 2. Install Git and Clone Repository
```bash
sudo apt-get update
sudo apt-get install git -y
git clone https://github.com/miouzikal/raspberry_pi_kiosk ~/raspberry_pi_kiosk
```

### 3. Run the Setup Script
```bash
cd ~/raspberry_pi_kiosk/src
chmod +x kiosk-setup.sh
./kiosk-setup.sh
```

> **Note:** Do not run as root. The script uses `sudo` internally for privileged operations.

### 4. Follow the Prompts
The script walks through these steps, confirming before each one:

1. **System Update & Upgrade** — updates package lists, optionally upgrades
2. **Install Dependencies** — installs Cage, Cog, Plymouth, and supporting packages
3. **Configure Quiet Boot** — suppresses boot text, configures firmware for Plymouth and KMS
4. **Configure Screen** — sets screen orientation, enables I2C for brightness control
5. **Configure Plymouth** — installs custom boot splash theme, rebuilds initramfs
6. **Configure Kiosk Service** — prompts for your Home Assistant URL, installs the Cage+Cog systemd service

### 5. Reboot
After all steps complete, reboot to apply changes.

## Boot Chain

The boot sequence minimizes visual gaps:

1. **VideoCore firmware** — rainbow splash suppressed (`disable_splash=1`)
2. **Kernel** — quiet boot, no logos or cursor
3. **Plymouth** — DRM-mode splash image appears (vc4/v3d loaded in initramfs for early DRM)
4. **Cage + Cog** — Plymouth hands off display, Cage claims DRM, Cog loads Home Assistant

## Post-Setup

After rebooting, the Pi will:
- Show the Plymouth splash during boot
- Launch directly into the Cog browser displaying your Home Assistant URL
- Touch input works through the WaveShare screen's USB HID interface
- The kiosk service auto-restarts if the browser crashes

## Troubleshooting

### Black screen after boot
- Check service status: `sudo systemctl status kiosk.service`
- Check logs: `sudo journalctl -u kiosk.service -b`
- Verify the user is in video/input groups: `groups $(whoami)`

### Plymouth splash not showing
- Verify initramfs contains Plymouth: `lsinitramfs /boot/initrd.img-$(uname -r) | grep plymouth`
- Check `auto_initramfs=1` is in `/boot/firmware/config.txt`
- Rebuild: `sudo plymouth-set-default-theme -R kiosk-splash`

### Touch not working
- Check libinput: `sudo libinput list-devices`
- Verify the USB touch cable is connected

### Wrong screen orientation
- Re-run the screen configuration step or edit `/etc/kiosk-cage-rotation` and the `fbcon=rotate:` parameter in `/boot/firmware/cmdline.txt`

### Network issues (HA not loading)
- The kiosk starts without waiting for network — Cog will show an error page until the network connects
- Check WiFi: `nmcli device status` or `wpa_cli status`
