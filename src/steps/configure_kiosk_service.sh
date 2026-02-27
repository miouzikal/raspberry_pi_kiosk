#!/usr/bin/env bash
#
# configure_kiosk_service.sh
# Configures the kiosk systemd service using Cage + Cog.
#
# Standalone usage:
#   ./configure_kiosk_service.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Kiosk Service"
show_progress

TEMPLATE_FILE="$SCRIPT_DIR/../templates/kiosk.service.template"
PAM_TEMPLATE="$SCRIPT_DIR/../templates/cage.pam.template"
SERVICE_FILE="/etc/systemd/system/kiosk.service"
PAM_FILE="/etc/pam.d/cage"
CAGE_ROTATION_FILE="/etc/kiosk-cage-rotation"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${COLOR_RED}Template file not found: $TEMPLATE_FILE${COLOR_RESET}"
    exit 1
fi

if [[ ! -f "$PAM_TEMPLATE" ]]; then
    echo -e "${COLOR_RED}PAM template not found: $PAM_TEMPLATE${COLOR_RESET}"
    exit 1
fi

# ---- Prompt for Home Assistant URL ----
while true; do
    echo -e "${BOLD}Enter the Home Assistant URL:${COLOR_RESET}"
    echo -e "(e.g., http://homeassistant.local:8123)"
    read -r HA_URL

    if [[ -z "$HA_URL" ]]; then
        echo -e "${COLOR_RED}No URL provided. Please enter a URL.${COLOR_RESET}"
        continue
    fi

    if [[ ! "$HA_URL" =~ ^https?:// ]]; then
        echo -e "${COLOR_RED}URL must start with http:// or https://${COLOR_RESET}"
        continue
    fi

    break
done

CURRENT_USER="$(whoami)"

# Read Cage rotation setting from configure_screen.sh
CAGE_ROTATION=""
if [[ -f "$CAGE_ROTATION_FILE" ]]; then
    CAGE_ROTATION="$(cat "$CAGE_ROTATION_FILE")"
fi

# Generate config from template using envsubst to safely handle special chars in URL
export HA_URL CURRENT_USER CAGE_ROTATION
NEW_CONFIG=$(cat "$TEMPLATE_FILE")
NEW_CONFIG="${NEW_CONFIG//___CURRENT_USER___/$CURRENT_USER}"
NEW_CONFIG="${NEW_CONFIG//___HA_URL___/$HA_URL}"
# Handle cage rotation: replace placeholder (and trailing space if empty)
if [[ -n "$CAGE_ROTATION" ]]; then
    NEW_CONFIG="${NEW_CONFIG//___CAGE_ROTATION___/$CAGE_ROTATION}"
else
    NEW_CONFIG="${NEW_CONFIG//___CAGE_ROTATION___ /}"
fi

echo -e "${BOLD}The following systemd service will be installed:${COLOR_RESET}"
echo "------------------------------------------------------------"
echo "$NEW_CONFIG"
echo "------------------------------------------------------------"
echo
echo -e "${BOLD}PAM configuration will be installed to: $PAM_FILE${COLOR_RESET}"
echo

if ! confirm "Proceed with configuring the kiosk service?"; then
    echo -e "${COLOR_RED}User canceled kiosk service configuration.${COLOR_RESET}"
    exit 1
fi

# ---- Install PAM file ----
start_spinner "Installing PAM configuration"
sudo cp "$PAM_TEMPLATE" "$PAM_FILE"
stop_spinner

# ---- Install service file ----
start_spinner "Installing kiosk service"
echo "$NEW_CONFIG" | sudo tee "$SERVICE_FILE" > /dev/null
stop_spinner

# ---- Add user to required groups ----
start_spinner "Adding $CURRENT_USER to video and input groups"
sudo usermod -aG video,input "$CURRENT_USER"
stop_spinner

# ---- Enable service ----
start_spinner "Enabling kiosk service"
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service > /dev/null
sudo systemctl set-default graphical.target > /dev/null
stop_spinner

echo -e "${COLOR_GREEN}Kiosk service configured successfully!${COLOR_RESET}"
sleep 1
exit 0
