#!/usr/bin/env bash
#
# configure_screen.sh
# Configures screen orientation (Cage rotation via wlr-randr, fbcon rotation,
# video mode), touchscreen calibration, transparent cursor theme, and I2C
# brightness control.
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

# ---- Detect current resolution ----
CURRENT_RES=""
if [[ -f /sys/class/graphics/fb0/virtual_size ]]; then
    FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
    CURRENT_RES="${FB_SIZE/,/x}"
fi

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

# Map orientation to wlr-randr transform and touch calibration matrix
# wlr-randr transforms: normal, 90, 180, 270, flipped, flipped-90, flipped-180, flipped-270
case "$ORIENTATION" in
    0) WLR_TRANSFORM="normal";  TOUCH_MATRIX="1 0 0 0 1 0" ;;
    1) WLR_TRANSFORM="180";     TOUCH_MATRIX="-1 0 1 0 -1 1" ;;
    2) WLR_TRANSFORM="270";     TOUCH_MATRIX="0 1 0 -1 0 1" ;;
    3) WLR_TRANSFORM="90";      TOUCH_MATRIX="0 -1 1 1 0 0" ;;
esac

# ---- Framebuffer console rotation ----
if grep -q 'fbcon=rotate:[0-3]' "$CMDLINE_FILE"; then
    start_spinner "Updating framebuffer console orientation"
    sudo sed -i "s|fbcon=rotate:[0-3]|fbcon=rotate:${ORIENTATION}|" "$CMDLINE_FILE"
    stop_spinner
else
    start_spinner "Setting framebuffer console orientation"
    sudo sed -i "1s|\$| fbcon=rotate:${ORIENTATION}|" "$CMDLINE_FILE"
    stop_spinner
fi

# ---- Detect displays and select output ----
SELECTED_DISPLAY="HDMI-A-1"
if command -v wlr-randr &>/dev/null && [[ -n "$WAYLAND_DISPLAY" ]]; then
    declare -A DISPLAYS
    while IFS= read -r line; do
        if [[ $line =~ ^([^\ ]+)\ \"(.+)\"$ ]]; then
            DISPLAYS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        fi
    done < <(wlr-randr 2>/dev/null | grep "^[^ ]")

    if [[ ${#DISPLAYS[@]} -gt 1 ]]; then
        echo -e "${BOLD}Detected displays:${COLOR_RESET}"
        keys=()
        index=1
        for id in "${!DISPLAYS[@]}"; do
            echo "  $index) ${DISPLAYS[$id]} ($id)"
            keys+=("$id")
            ((index++))
        done
        echo
        while true; do
            echo -n "Select a display by number [1]: "
            read -r selection
            selection="${selection:-1}"
            if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#keys[@]} )); then
                SELECTED_DISPLAY="${keys[selection-1]}"
                break
            else
                echo -e "${COLOR_RED}Invalid selection.${COLOR_RESET}"
            fi
        done
    elif [[ ${#DISPLAYS[@]} -eq 1 ]]; then
        SELECTED_DISPLAY="${!DISPLAYS[*]}"
    fi
fi
echo -e "Using display: ${BOLD}${SELECTED_DISPLAY}${COLOR_RESET}"

# ---- Video mode (forces vc4 to use exact resolution, speeds up init) ----
if [[ -n "$CURRENT_RES" ]]; then
    VIDEO_MODE="video=${SELECTED_DISPLAY}:${CURRENT_RES}@60e"
    if grep -q "video=${SELECTED_DISPLAY}:" "$CMDLINE_FILE"; then
        start_spinner "Updating video mode to ${CURRENT_RES}"
        sudo sed -i "s|video=${SELECTED_DISPLAY}:[^ ]*|${VIDEO_MODE}|" "$CMDLINE_FILE"
        stop_spinner
    elif grep -q 'video=HDMI-A-1:' "$CMDLINE_FILE"; then
        start_spinner "Updating video mode to ${CURRENT_RES}"
        sudo sed -i "s|video=HDMI-A-1:[^ ]*|${VIDEO_MODE}|" "$CMDLINE_FILE"
        stop_spinner
    else
        start_spinner "Setting video mode to ${CURRENT_RES}"
        sudo sed -i "1s|\$| ${VIDEO_MODE}|" "$CMDLINE_FILE"
        stop_spinner
    fi
fi

# ---- Install kiosk rotation service (wlr-randr, runs after Cage starts) ----
if [[ "$ORIENTATION" != "0" ]]; then
    start_spinner "Installing kiosk rotation service"

    # Rotation wrapper script (waits for Cage's Wayland socket)
    sudo tee /usr/local/bin/kiosk-rotate.sh > /dev/null << ROTSCRIPT
#!/bin/sh
SOCKET=/run/user/\$(id -u)/wayland-0
TIMEOUT=30
i=0
while [ ! -e "\$SOCKET" ] && [ \$i -lt \$TIMEOUT ]; do
    sleep 0.5
    i=\$((i + 1))
done
if [ -e "\$SOCKET" ]; then
    exec /usr/bin/wlr-randr --output ${SELECTED_DISPLAY} --transform ${WLR_TRANSFORM}
else
    echo 'Timeout waiting for Wayland socket'
    exit 1
fi
ROTSCRIPT
    sudo chmod +x /usr/local/bin/kiosk-rotate.sh

    CURRENT_UID=$(id -u)
    sudo tee /etc/systemd/system/kiosk-rotate.service > /dev/null << EOF
[Unit]
Description=Rotate kiosk display
After=kiosk.service
Requires=kiosk.service
PartOf=kiosk.service

[Service]
Type=oneshot
User=$(whoami)
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/${CURRENT_UID}
ExecStart=/usr/local/bin/kiosk-rotate.sh
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable kiosk-rotate.service > /dev/null
    stop_spinner
else
    # No rotation needed — disable rotation service if it exists
    if systemctl is-enabled kiosk-rotate.service &>/dev/null; then
        start_spinner "Disabling rotation service (landscape mode)"
        sudo systemctl disable kiosk-rotate.service > /dev/null
        stop_spinner
    fi
fi

# ---- Touchscreen calibration ----
start_spinner "Configuring touchscreen calibration"
sudo tee /etc/udev/rules.d/99-touchscreen-calibration.rules > /dev/null << EOF
# Rotate touchscreen to match display orientation
ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="*Waveshare*", ENV{LIBINPUT_CALIBRATION_MATRIX}="${TOUCH_MATRIX}"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger
stop_spinner

# ---- Transparent cursor theme (hide cursor for kiosk) ----
if [[ ! -d /usr/share/icons/transparent/cursors ]]; then
    start_spinner "Creating transparent cursor theme"
    sudo python3 -c '
import struct, os

magic = b"Xcur"
header_size = 16
version = 0x00010000
ntoc = 1
toc_type = 0xfffd0002
toc_subtype = 1
toc_position = 16 + 12

data = struct.pack("<4sIII", magic, header_size, version, ntoc)
data += struct.pack("<III", toc_type, toc_subtype, toc_position)
data += struct.pack("<IIIIIIIII", 36, toc_type, toc_subtype, version, 1, 1, 0, 0, 0)
data += struct.pack("<I", 0x00000000)

theme_dir = "/usr/share/icons/transparent/cursors"
os.makedirs(theme_dir, exist_ok=True)

for name in ["left_ptr", "default", "arrow", "pointer", "hand", "hand2", "grab",
             "grabbing", "text", "xterm", "crosshair", "move", "wait", "watch",
             "progress", "not-allowed", "no-drop", "copy", "alias", "context-menu",
             "cell", "col-resize", "row-resize", "n-resize", "s-resize", "e-resize",
             "w-resize", "ne-resize", "nw-resize", "se-resize", "sw-resize",
             "ew-resize", "ns-resize", "nesw-resize", "nwse-resize", "zoom-in",
             "zoom-out", "help", "all-scroll", "top_left_arrow", "X_cursor", "fleur"]:
    with open(os.path.join(theme_dir, name), "wb") as f:
        f.write(data)
'
    sudo tee /usr/share/icons/transparent/index.theme > /dev/null << 'IDX'
[Icon Theme]
Name=Transparent
Comment=Invisible cursor for kiosk
IDX
    stop_spinner
else
    echo -e "${COLOR_GREEN}Transparent cursor theme already exists.${COLOR_RESET}"
fi

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
echo "  Display transform: ${WLR_TRANSFORM}"
[[ -n "$CURRENT_RES" ]] && echo "  Video mode: ${CURRENT_RES}@60"
sleep 1
exit 0
