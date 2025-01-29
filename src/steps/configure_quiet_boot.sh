#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

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
    $IS_SOURCED && return 0 || exit 0
fi

# Add parameters to the file
echo -e "${BOLD}The following parameters will be added to $CMDLINE_FILE:${COLOR_RESET}"
for parameter in "${parameters_to_add[@]}"; do
    echo "  - $parameter"
done
echo
if ! confirm "Proceed with adding parameters?"; then
    echo -e "${COLOR_RED}User canceled adding parameters.${COLOR_RESET}"
    $IS_SOURCED && return 1 || exit 1
fi

start_spinner "Adding parameters to $CMDLINE_FILE"
sudo sed -i "s/$/ ${parameters_to_add[*]}/" "$CMDLINE_FILE"
stop_spinner

echo -e "${COLOR_GREEN}Quiet boot configured successfully!${COLOR_RESET}"
sleep 1
$IS_SOURCED && return 0 || exit 0
