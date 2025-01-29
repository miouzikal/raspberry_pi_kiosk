#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="Wrapping Up"

show_progress

echo -e "${COLOR_GREEN}We reached the end of the kiosk setup script.${COLOR_RESET}"
echo " - A reboot is recommended to apply changes."
sleep 2
exit 0
