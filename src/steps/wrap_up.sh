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
echo "  - Hostname"
echo "  - Quiet boot with framebuffer splash screen"
echo "  - Screen orientation, display detection, and touch calibration"
echo "  - Transparent cursor theme"
echo "  - Cage + Chromium kiosk service"
echo "  - CPU performance governor"
echo "  - Disabled unnecessary services"
echo "  - CPU/GPU overclocking (optional)"
echo "  - WiFi adapter driver (optional)"
echo "  - GPIO button handler (optional)"
echo "  - Wake-on-sound (optional)"
echo
echo -e "${BOLD}A reboot is required to apply all changes.${COLOR_RESET}"
echo
if confirm "Reboot now?"; then
    sudo reboot
fi

exit 0
