#!/usr/bin/env bash
#
# configure_splash.sh
# Configures framebuffer splash screen displayed from early boot until the
# kiosk browser takes over.
#
# Strategy: vc4 and v3d GPU drivers are blacklisted from auto-loading so the
# firmware's simple-framebuffer persists for the entire boot. An initramfs
# script writes the splash image to /dev/fb0 at ~0.6s. The kiosk service
# explicitly loads vc4/v3d right before starting the browser, keeping the
# splash visible until the last possible moment.
#
# Standalone usage:
#   ./configure_splash.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Splash Screen"
show_progress

SPLASH_SOURCE="$SCRIPT_DIR/../resources/splash.png"
SPLASH_DIR="/usr/share/kiosk-splash"
INITRAMFS_MODULES="/etc/initramfs-tools/modules"

# Verify splash image exists
if [[ ! -f "$SPLASH_SOURCE" ]]; then
    echo -e "${COLOR_RED}Splash image not found: $SPLASH_SOURCE${COLOR_RESET}"
    exit 1
fi

echo -e "${BOLD}Framebuffer splash will be configured.${COLOR_RESET}"
echo "  Source image: $SPLASH_SOURCE"
echo "  Install dir:  $SPLASH_DIR"
echo
echo "This sets up:"
echo "  - Raw framebuffer image (32bpp BGRA for simple-framebuffer)"
echo "  - initramfs hook to embed splash in initrd"
echo "  - initramfs script to write splash at earliest boot (~0.6s)"
echo "  - Blacklists vc4/v3d so splash stays on screen until browser starts"
echo

if ! confirm "Proceed with configuring splash screen?"; then
    echo -e "${COLOR_RED}User canceled splash configuration.${COLOR_RESET}"
    exit 1
fi

# ---- Detect framebuffer resolution ----
FB_WIDTH=1280
FB_HEIGHT=800
if [[ -f /sys/class/graphics/fb0/virtual_size ]]; then
    IFS=',' read -r FB_WIDTH FB_HEIGHT < /sys/class/graphics/fb0/virtual_size
fi

# ---- Generate raw framebuffer image from PNG ----
start_spinner "Generating raw framebuffer image (${FB_WIDTH}x${FB_HEIGHT})"
sudo mkdir -p "$SPLASH_DIR"

# 32bpp BGRA for simple-framebuffer
sudo convert "$SPLASH_SOURCE" -resize "${FB_WIDTH}x${FB_HEIGHT}!" -depth 8 BGRA:"${SPLASH_DIR}/splash.fb" 2>/dev/null \
    || {
        stop_spinner
        echo -e "${COLOR_RED}Could not convert splash image. Is imagemagick installed?${COLOR_RESET}"
        exit 1
    }
stop_spinner

# ---- Blacklist vc4 and v3d from auto-loading ----
# This keeps simple-framebuffer alive for the entire boot.
# The kiosk service loads them explicitly via modprobe right before Cage starts.
start_spinner "Blacklisting GPU drivers from auto-loading"
echo "blacklist vc4" | sudo tee /etc/modprobe.d/blacklist-vc4.conf > /dev/null
echo "blacklist v3d" | sudo tee /etc/modprobe.d/blacklist-v3d.conf > /dev/null
stop_spinner

# ---- Remove vc4/v3d from initramfs modules (if present) ----
start_spinner "Cleaning initramfs module list"
sudo sed -i '/^vc4$/d' "$INITRAMFS_MODULES"
sudo sed -i '/^v3d$/d' "$INITRAMFS_MODULES"
stop_spinner

# ---- Install initramfs hook (includes splash.fb in initramfs) ----
start_spinner "Installing initramfs hook"
sudo tee /etc/initramfs-tools/hooks/splash-fb > /dev/null << 'HOOK'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac

. /usr/share/initramfs-tools/hook-functions

# Copy the raw framebuffer splash into initramfs
copy_file splash /usr/share/kiosk-splash/splash.fb /usr/share/splash.fb
HOOK
sudo chmod +x /etc/initramfs-tools/hooks/splash-fb
stop_spinner

# ---- Install initramfs script (writes splash to fb0 at init-top) ----
start_spinner "Installing initramfs splash script"
sudo tee /etc/initramfs-tools/scripts/init-top/splash-fb > /dev/null << 'SCRIPT'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac

# Write splash image to framebuffer as early as possible
if [ -e /dev/fb0 ] && [ -f /usr/share/splash.fb ]; then
    cat /usr/share/splash.fb > /dev/fb0 2>/dev/null
fi
SCRIPT
sudo chmod +x /etc/initramfs-tools/scripts/init-top/splash-fb
stop_spinner

# ---- Back up current initramfs and rebuild ----
KERNEL_VERSION="$(uname -r)"
INITRD_FILE="/boot/initrd.img-${KERNEL_VERSION}"
if [[ -f "$INITRD_FILE" ]]; then
    start_spinner "Backing up current initramfs"
    sudo cp "$INITRD_FILE" "${INITRD_FILE}.bak"
    stop_spinner
fi

start_spinner "Rebuilding initramfs (this may take a moment)"
sudo update-initramfs -u > /dev/null 2>&1
stop_spinner

echo -e "${COLOR_GREEN}Splash screen configured successfully!${COLOR_RESET}"
sleep 1
exit 0
