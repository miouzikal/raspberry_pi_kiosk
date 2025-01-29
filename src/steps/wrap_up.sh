#!/usr/bin/env bash
#
# wrap_up.sh
# Final step to wrap up the kiosk setup.
#
# Standalone usage:
#   ./install_dependencies.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If utils.sh is not already in the environment, source it:
if [[ -z "$COLOR_BLUE" ]]; then
  # Attempt to load from parent directory
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Wrapping Up"
show_progress

echo -e "${COLOR_GREEN}We reached the end of the kiosk setup script.${COLOR_RESET}"
echo "A reboot is recommended to apply changes."
sleep 2
exit 0
