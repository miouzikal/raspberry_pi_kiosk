#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="Configure Kiosk URL"

show_progress

TARGET_FILE="/home/$(whoami)/.config/labwc/autostart"

if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${COLOR_RED}LabWC is not installed. Aborting.${COLOR_RESET}"
    $IS_SOURCED && return 1 || exit 1
fi

declare KIOSK_URL
while true; do
    read -rp "Enter the URL to display in kiosk mode: " KIOSK_URL
    if [[ -z "$KIOSK_URL" ]]; then
        echo -e "${COLOR_RED}URL cannot be empty.${COLOR_RESET}"
    else
        break
    fi
done

# Replace the URL in the autostart file
start_spinner "Configuring kiosk URL"
sed -i "s|___KIOSK_URL___|$KIOSK_URL|" "$TARGET_FILE"
stop_spinner

echo -e "${COLOR_GREEN}Kiosk URL configured successfully.${COLOR_RESET}"
sleep 3
$IS_SOURCED && return 0 || exit 0
