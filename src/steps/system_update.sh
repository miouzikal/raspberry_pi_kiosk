#!/usr/bin/env bash
#
# system_update.sh
# This step updates and upgrades system packages.
#
# Standalone usage:
#   ./system_update.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If utils.sh is not already in the environment, source it:
if [[ -z "$COLOR_BLUE" ]]; then
  # Attempt to load from parent directory
  source "$SCRIPT_DIR/../utils.sh"
fi

# Step logic
CURRENT_STEP="System Update & Upgrade"

show_progress

start_spinner "Updating package lists"
sudo apt-get update &>/dev/null
stop_spinner

if ! confirm "Would you like to fully upgrade the system?"; then
  echo -e "${COLOR_RED}User skipped system upgrade.${COLOR_RESET}"
  exit 0
fi

start_spinner "Upgrading system packages"
sudo apt-get upgrade -y &>/dev/null
stop_spinner

echo -e "${COLOR_GREEN}System update & upgrade completed successfully!${COLOR_RESET}"
sleep 1
exit 0
