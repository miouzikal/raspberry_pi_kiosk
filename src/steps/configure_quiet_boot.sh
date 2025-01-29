#!/usr/bin/env bash
#
# configure_quiet_boot.sh
# Configures Raspberry Pi to boot without text output.
#
# Standalone usage:
#   ./configure_quiet_boot.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If utils.sh is not already in the environment, source it:
if [[ -z "$COLOR_BLUE" ]]; then
  # Attempt to load from parent directory
  source "$SCRIPT_DIR/../utils.sh"
fi

# Step logic
CURRENT_STEP="Configure Quiet Boot"

show_progress

CMDLINE_FILE="/boot/firmware/cmdline.txt"

# Ask user for screen orientation
echo -e "${BOLD}How is the screen oriented?${COLOR_RESET}"
echo " 1. Landscape - USB ports on the right (default)"
echo " 2. Landscape Inverted - USB ports on the left"
echo " 3. Portrait - USB ports on the bottom"
echo " 4. Portrait Inverted - USB ports on the top"
read answer
case "$answer" in
    1 | "") ORIENTATION="0" ;;
    2) ORIENTATION="2" ;;
    3) ORIENTATION="1" ;;
    4) ORIENTATION="3" ;;
    *) echo -e "${COLOR_RED}Invalid input. Please enter a number 1-4.${COLOR_RESET}" ;;
esac

# Configure boot/firmware/cmdline.txt
start_spinner "Configuring quiet boot"
REQUIREMENTS=(
    "quiet"
    "splash"
    "loglevel=0"
    "logo.nologo"
    "vt.global_cursor_default=0"
    "fbcon=rotate:$ORIENTATION"
)

# Check if requirements are already in the file
parameters=()
for requirement in "${REQUIREMENTS[@]}"; do
    if ! grep -q "$requirement" "$CMDLINE_FILE"; then
        parameters+=("$requirement")
    fi
done

# Add parameters to the file
echo -e "${BOLD}The following parameters will be added to $CMDLINE_FILE:${COLOR_RESET}"
for param in "${parameters[@]}"; do
    echo "  - $param"
done
echo
if ! confirm "Proceed with adding parameters?"; then
    echo -e "${COLOR_RED}User canceled adding parameters.${COLOR_RESET}"
    exit 1
fi

start_spinner "Adding parameters to $CMDLINE_FILE"
sudo sed -i 's/$/ ${parameters[@]}/' "$CMDLINE_FILE"
stop_spinner

echo -e "${COLOR_GREEN}Quiet boot configured successfully!${COLOR_RESET}"
sleep 1
exit 0
