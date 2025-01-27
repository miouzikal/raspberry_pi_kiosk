#!/bin/bash

# Quiet boot
sudo sed -i 's/$/ quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0 fbcon=rotate:3/' "/boot/firmware/cmdline.txt"
sudo sed -i "s/tty1/tty3/" "/boot/firmware/cmdline.txt"
sudo tee -a "/boot/firmware/config.txt" <<<"disable_splash=1" > /dev/null

# Update
sudo apt update && sudo apt full-upgrade -y

CURRENT_USER="$(whoami)"
HOME_ASSISTANT_URL="https://home.ccilo.ca/raspberry-dashboard/home#sous_sol"

# Install kiosk dependencies
sudo apt install --no-install-recommends -y greetd labwc seatd wlr-randr chromium-browser vim libinput-tools

# Configure touchscreen rotation for Waveshare 10.1" (90-degree clockwise)
sudo tee /etc/udev/rules.d/99-waveshare-touch.rules > /dev/null <<EOL
SUBSYSTEM=="input", ATTRS{name}=="Waveshare  Waveshare", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 -1 1 1 0 0 0 0 1"
EOL

# Apply udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Enable greetd
sudo systemctl enable greetd
sudo systemctl set-default graphical.target

# Create greetd configuration
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null <<EOL
[terminal]
vt = 7

[default_session]
command = "/usr/bin/labwc"
user = "$CURRENT_USER"
EOL

# Create labwc autostart
LABWC_DIR="/home/$CURRENT_USER/.config/labwc"
mkdir -p "$LABWC_DIR"

sudo tee "$LABWC_DIR/autostart" > /dev/null <<EOL
#!/usr/bin/env bash

# Rotate screen
wlr-randr --output HDMI-A-1 --transform 90

# Launch Chromium in kiosk mode
chromium-browser \\
--app="$HOME_ASSISTANT_URL" \\
--disable-component-update \\
--disable-composited-antialiasing \\
--disable-features=TranslateUI \\
--disable-infobars \\
--disable-low-res-tiling \\
--disable-restore-session-state \\
--disable-session-crashed-bubble \\
--disable-smooth-scrolling \\
--enable-accelerated-video-decode \\
--enable-features=OverlayScrollbar \\
--enable-gpu-rasterization \\
--enable-low-end-device-mode \\
--enable-oop-rasterization \\
--fast \\
--fast-start \\
--force-dark-mode \\
--ignore-gpu-blocklist \\
--kiosk \\
--no-first-run \\
--noerrdialogs \\
--overscroll-history-navigation=0 \\
--ozone-platform=wayland \\
--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \\
--start-maximized
EOL

# Set proper permissions
sudo chmod +x "$LABWC_DIR/autostart"
