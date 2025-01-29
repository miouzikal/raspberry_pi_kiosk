#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="System Update & Upgrade"

show_progress

start_spinner "Updating package lists"
sudo apt-get update &>/dev/null
stop_spinner

if ! confirm "Would you like to fully upgrade the system?"; then
  echo -e "${COLOR_RED}User skipped system upgrade.${COLOR_RESET}"
  $IS_SOURCED && return 0 || exit 0
fi

show_progress

start_spinner "Upgrading system packages"
sudo apt-get upgrade -y &>/dev/null
stop_spinner

echo -e "${COLOR_GREEN}System update & upgrade completed successfully!${COLOR_RESET}"
sleep 3
$IS_SOURCED && return 0 || exit 0
