#!/usr/bin/env bash
#
# configure_extras.sh
# Configures optional extras: GPIO button handler and wake-on-sound.
#
# Standalone usage:
#   ./configure_extras.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Extras"
show_progress

CURRENT_USER="$(whoami)"
SCRIPTS_DIR="$SCRIPT_DIR/../scripts"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# ---- GPIO Button Handler ----
echo -e "${BOLD}GPIO Button Handler${COLOR_RESET}"
echo "  Single press: refresh kiosk browser"
echo "  Hold 10s: reboot system"
echo "  Requires: python3-rpi.gpio, GPIO pin 16 (physical pin 36)"
echo

if confirm "Install GPIO button handler?"; then
    start_spinner "Installing button handler"

    # Install python3-rpi.gpio if needed
    if ! dpkg -s python3-rpi.gpio &>/dev/null; then
        sudo apt-get install --no-install-recommends -y python3-rpi.gpio > /dev/null 2>&1
    fi

    # Copy script
    cp "$SCRIPTS_DIR/button_handler.py" "/home/${CURRENT_USER}/button_handler.py"

    # Install service from template
    SERVICE_CONTENT=$(cat "$TEMPLATES_DIR/button_handler.service.template")
    SERVICE_CONTENT="${SERVICE_CONTENT//___CURRENT_USER___/$CURRENT_USER}"
    echo "$SERVICE_CONTENT" | sudo tee /etc/systemd/system/button_handler.service > /dev/null

    # Add user to gpio group for GPIO access
    sudo usermod -aG gpio "$CURRENT_USER"

    # Allow user to restart kiosk and reboot without password
    sudo tee /etc/sudoers.d/button-handler > /dev/null << SUDOEOF
${CURRENT_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart kiosk.service
${CURRENT_USER} ALL=(ALL) NOPASSWD: /sbin/reboot
SUDOEOF
    sudo chmod 0440 /etc/sudoers.d/button-handler

    sudo systemctl daemon-reload
    sudo systemctl enable button_handler.service > /dev/null

    stop_spinner
    echo -e "${COLOR_GREEN}Button handler installed.${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}Skipped button handler.${COLOR_RESET}"
fi

echo

# ---- Wake on Sound ----
echo -e "${BOLD}Wake on Sound${COLOR_RESET}"
echo "  Monitors USB microphone and wakes display on sound"
echo "  Requires: USB microphone, alsa-utils, sox, bc"
echo

if confirm "Install wake-on-sound service?"; then
    start_spinner "Installing wake-on-sound"

    # Install dependencies if needed
    for pkg in sox bc; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            sudo apt-get install --no-install-recommends -y "$pkg" > /dev/null 2>&1
        fi
    done

    # Copy script
    cp "$SCRIPTS_DIR/wake_on_sound.sh" "/home/${CURRENT_USER}/wake_on_sound.sh"
    chmod +x "/home/${CURRENT_USER}/wake_on_sound.sh"

    # Detect display output from rotation script or default to HDMI-A-1
    DISPLAY_OUTPUT="HDMI-A-1"
    if [[ -f /usr/local/bin/kiosk-rotate.sh ]]; then
        DETECTED=$(grep -oP -- '--output \K[^ ]+' /usr/local/bin/kiosk-rotate.sh)
        [[ -n "$DETECTED" ]] && DISPLAY_OUTPUT="$DETECTED"
    fi

    # Install service from template
    SERVICE_CONTENT=$(cat "$TEMPLATES_DIR/wake_on_sound.service.template")
    SERVICE_CONTENT="${SERVICE_CONTENT//___CURRENT_USER___/$CURRENT_USER}"
    SERVICE_CONTENT="${SERVICE_CONTENT//___DISPLAY_OUTPUT___/$DISPLAY_OUTPUT}"
    echo "$SERVICE_CONTENT" | sudo tee /etc/systemd/system/wake_on_sound.service > /dev/null

    sudo systemctl daemon-reload
    sudo systemctl enable wake_on_sound.service > /dev/null

    stop_spinner
    echo -e "${COLOR_GREEN}Wake-on-sound installed.${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}Skipped wake-on-sound.${COLOR_RESET}"
fi

echo
echo -e "${COLOR_GREEN}Extras configured successfully!${COLOR_RESET}"
sleep 1
exit 0
