#!/usr/bin/env bash
#
# configure_plymouth.sh
# Configures Plymouth boot splash with a custom theme.
#
# Standalone usage:
#   ./configure_plymouth.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Plymouth"
show_progress

THEME_NAME="kiosk-splash"
THEME_DIR="/usr/share/plymouth/themes/${THEME_NAME}"
SPLASH_SOURCE="$SCRIPT_DIR/../resources/splash.png"
PLYMOUTH_CONF="/etc/plymouth/plymouthd.conf"
INITRAMFS_MODULES="/etc/initramfs-tools/modules"
PLYMOUTH_TEMPLATE="$SCRIPT_DIR/../templates/plymouthd.conf.template"
THEME_PLYMOUTH_TEMPLATE="$SCRIPT_DIR/../templates/kiosk-splash.plymouth.template"
THEME_SCRIPT_TEMPLATE="$SCRIPT_DIR/../templates/kiosk-splash.script.template"

# Verify resources exist
for f in "$SPLASH_SOURCE" "$PLYMOUTH_TEMPLATE" "$THEME_PLYMOUTH_TEMPLATE" "$THEME_SCRIPT_TEMPLATE"; do
    if [[ ! -f "$f" ]]; then
        echo -e "${COLOR_RED}Required file not found: $f${COLOR_RESET}"
        exit 1
    fi
done

echo -e "${BOLD}Plymouth will be configured with the '${THEME_NAME}' theme.${COLOR_RESET}"
echo "  Theme directory: $THEME_DIR"
echo "  Splash image:    $SPLASH_SOURCE"
echo

if ! confirm "Proceed with configuring Plymouth?"; then
    echo -e "${COLOR_RED}User canceled Plymouth configuration.${COLOR_RESET}"
    exit 1
fi

# ---- Install theme files ----
start_spinner "Installing Plymouth theme"
sudo mkdir -p "$THEME_DIR"
sudo cp "$SPLASH_SOURCE" "$THEME_DIR/splash.png"
sudo cp "$THEME_PLYMOUTH_TEMPLATE" "$THEME_DIR/${THEME_NAME}.plymouth"
sudo cp "$THEME_SCRIPT_TEMPLATE" "$THEME_DIR/${THEME_NAME}.script"
stop_spinner

# ---- Configure plymouthd.conf ----
start_spinner "Configuring plymouthd.conf"
sudo cp "$PLYMOUTH_TEMPLATE" "$PLYMOUTH_CONF"
stop_spinner

# ---- Add vc4/v3d to initramfs modules for early DRM ----
start_spinner "Ensuring DRM modules in initramfs"
for module in vc4 v3d; do
    if ! grep -q "^${module}$" "$INITRAMFS_MODULES"; then
        echo "$module" | sudo tee -a "$INITRAMFS_MODULES" > /dev/null
    fi
done
stop_spinner

# ---- Back up current initramfs ----
KERNEL_VERSION="$(uname -r)"
INITRD_FILE="/boot/initrd.img-${KERNEL_VERSION}"
if [[ -f "$INITRD_FILE" ]]; then
    start_spinner "Backing up current initramfs"
    sudo cp "$INITRD_FILE" "${INITRD_FILE}.bak"
    stop_spinner
fi

# ---- Set theme and rebuild initramfs ----
start_spinner "Setting Plymouth theme and rebuilding initramfs (this may take a moment)"
sudo plymouth-set-default-theme -R "$THEME_NAME" > /dev/null 2>&1
stop_spinner

echo -e "${COLOR_GREEN}Plymouth configured successfully!${COLOR_RESET}"
sleep 1
exit 0
