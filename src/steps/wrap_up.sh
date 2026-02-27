#!/usr/bin/env bash
#
# wrap_up.sh
# Final step to wrap up the kiosk setup.
#
# Standalone usage:
#   ./wrap_up.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Wrapping Up"
show_progress

echo -e "${COLOR_GREEN}Kiosk setup complete!${COLOR_RESET}"
echo
echo "The following has been configured:"
echo "  - Quiet boot with Plymouth splash screen"
echo "  - Screen orientation and display settings"
echo "  - Cage + Cog kiosk service (WPE WebKit)"
echo
echo -e "${BOLD}A reboot is required to apply all changes.${COLOR_RESET}"
echo
if confirm "Reboot now?"; then
    sudo reboot
fi

exit 0
