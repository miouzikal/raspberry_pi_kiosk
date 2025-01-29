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

# Required boot parameters
REQUIREMENTS=(
    "quiet"
    "splash"
    "loglevel=0"
    "logo.nologo"
    "vt.global_cursor_default=0"
)

# Check if rotation is set; add prompt only if missing
if ! grep -q "fbcon=rotate:" "$CMDLINE_FILE"; then
    while true; do
        echo -e "${BOLD}How is the screen oriented?${COLOR_RESET}"
        echo " 0. Landscape - USB ports on the right (default)"
        echo " 1. Landscape Inverted - USB ports on the left"
        echo " 2. Portrait - USB ports on the top"
        echo " 3. Portrait Inverted - USB ports on the bottom"
        read answer
        case "$answer" in
        0 | 1 | 2 | 3)
            ORIENTATION="$answer"
            REQUIREMENTS+=("fbcon=rotate:$ORIENTATION")
            break
            ;;
        *)
            echo -e "${COLOR_RED}Invalid input. Please enter 0, 1, 2, or 3.${COLOR_RESET}"
            ;;
        esac
    done
fi

# Determine which parameters need to be added
parameters_to_add=()
for requirement in "${REQUIREMENTS[@]}"; do
    if ! grep -q "$requirement" "$CMDLINE_FILE"; then
        parameters_to_add+=("$requirement")
    fi
done

if [[ ${#parameters_to_add[@]} -eq 0 ]]; then
    echo -e "${COLOR_GREEN}All quiet boot parameters are already set.${COLOR_RESET}"
    sleep 1
    exit 0
fi

# Add parameters to the file
echo -e "${BOLD}The following parameters will be added to $CMDLINE_FILE:${COLOR_RESET}"
for parameter in "${parameters_to_add[@]}"; do
    echo "  - $parameter"
done
echo
if ! confirm "Proceed with adding parameters?"; then
    echo -e "${COLOR_RED}User canceled adding parameters.${COLOR_RESET}"
    exit 1
fi

start_spinner "Adding parameters to $CMDLINE_FILE"
sudo sed -i "s/$/ ${parameters_to_add[*]}/" "$CMDLINE_FILE"
stop_spinner

echo -e "${COLOR_GREEN}Quiet boot configured successfully!${COLOR_RESET}"
sleep 1
exit 0
