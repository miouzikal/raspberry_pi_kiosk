#!/usr/bin/env bash
#
# configure_screen.sh
# Configures screen orientation, framebuffer console rotation, Cage rotation,
# and I2C brightness control.
#
# Standalone usage:
#   ./configure_screen.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Screen"
show_progress

CMDLINE_FILE="/boot/firmware/cmdline.txt"
CAGE_ROTATION_FILE="/etc/kiosk-cage-rotation"

# ---- Screen Orientation ----
while true; do
    echo -e "${BOLD}How is the screen oriented?${COLOR_RESET}"
    echo " 0. Landscape - USB ports on the right (default)"
    echo " 1. Landscape Inverted - USB ports on the left"
    echo " 2. Portrait - USB ports on the top"
    echo " 3. Portrait Inverted - USB ports on the bottom"
    read -r answer
    case "$answer" in
        0 | "") ORIENTATION="0"; break ;;
        1) ORIENTATION="1"; break ;;
        2) ORIENTATION="2"; break ;;
        3) ORIENTATION="3"; break ;;
        *) echo -e "${COLOR_RED}Invalid input. Please enter 0, 1, 2, or 3.${COLOR_RESET}" ;;
    esac
done

# Map orientation to Cage -r flags (each -r rotates 90° clockwise)
# 0 = no rotation, 1 = 180°, 2 = 90°, 3 = 270°
case "$ORIENTATION" in
    0) CAGE_ROTATION="" ;;
    1) CAGE_ROTATION="-r -r" ;;
    2) CAGE_ROTATION="-r" ;;
    3) CAGE_ROTATION="-r -r -r" ;;
esac

# ---- Framebuffer console rotation (for Plymouth/text console) ----
if grep -q 'fbcon=rotate:[0-3]' "$CMDLINE_FILE"; then
    start_spinner "Updating framebuffer console orientation"
    sudo sed -i "s|fbcon=rotate:[0-3]|fbcon=rotate:${ORIENTATION}|" "$CMDLINE_FILE"
    stop_spinner
else
    start_spinner "Setting framebuffer console orientation"
    sudo sed -i "1s|\$| fbcon=rotate:${ORIENTATION}|" "$CMDLINE_FILE"
    stop_spinner
fi

# ---- Store Cage rotation for the kiosk service template ----
start_spinner "Saving Cage rotation setting"
echo "$CAGE_ROTATION" | sudo tee "$CAGE_ROTATION_FILE" > /dev/null
stop_spinner

# ---- I2C for Brightness Control ----
echo
if confirm "Enable I2C for screen brightness control?"; then
    start_spinner "Enabling I2C"
    sudo raspi-config nonint do_i2c 0
    stop_spinner
    echo -e "${COLOR_GREEN}I2C enabled.${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}Skipped I2C configuration.${COLOR_RESET}"
fi

echo
echo -e "${COLOR_GREEN}Screen configured successfully!${COLOR_RESET}"
echo "  Orientation: $ORIENTATION"
echo "  Cage rotation flags: ${CAGE_ROTATION:-none}"
sleep 1
exit 0
