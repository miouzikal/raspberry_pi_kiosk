#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="Configure Display & Touch"

show_progress

CMDLINE_FILE="/boot/firmware/cmdline.txt"

# Get rotation from kernel parameters
CURRENT_ROTATION=$(grep -o 'fbcon=rotate:[0-9]' "$CMDLINE_FILE" | cut -d':' -f2)

# fbcon to wlr-randr transformation mapping
declare -A ROTATION_MAP=(
    [0]="normal"
    [1]="270"
    [2]="180"
    [3]="90"
)

# fbcon to libinput calibration matrix mapping
declare -A TOUCH_MATRIX_MAP=(
    [0]="1 0 0 0 1 0 0 0 1"
    [1]="-1 0 1 0 -1 1 0 0 1"
    [2]="0 1 0 -1 0 1 0 0 1"
    [3]="0 -1 1 1 0 0 0 0 1"
)

# Display rotation to human-readable mapping
DISPLAY_ROTATION_TRANSFORM=${ROTATION_MAP[$CURRENT_ROTATION]}
TOUCH_INPUT_CALIBRATION=${TOUCH_MATRIX_MAP[$CURRENT_ROTATION]}

# Detect primary display
declare -A DISPLAYS
declare SELECTED_DISPLAY

detect_displays() {
    start_spinner "Detecting displays"
    while IFS= read -r line; do
        # Extract the display ID and name using regex
        if [[ $line =~ ^([^\ ]+)\ \"(.+)\"$ ]]; then
            id="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            DISPLAYS["$id"]="$name"
        fi
    done < <(wlr-randr | grep "^[^ ]")
    stop_spinner

    if [[ ${#DISPLAYS[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}No displays detected!${COLOR_RESET}"
        $IS_SOURCED && return 1 || exit 1
    fi
}


select_display() {
    echo -e "${BOLD}Detected displays:${COLOR_RESET}\n"

    # Create an array to store keys (IDs)
    keys=()
    index=1

    # Display the numbered list
    for id in "${!DISPLAYS[@]}"; do
        echo "  $index) ${DISPLAYS[$id]}"
        keys+=("$id")
        ((index++))
    done
    echo

    # Auto-select if only one display is available
    if [[ ${#keys[@]} -eq 1 ]]; then
        SELECTED_DISPLAY="${keys[0]}"
        return
    fi

    # Prompt user for selection
    while true; do
        read -rp "Select a display by number: " selection
        # Validate input: check if it's a number and within range
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#keys[@]} )); then
            SELECTED_DISPLAY="${keys[selection-1]}"
            break
        else
            echo -e "${COLOR_RED}Invalid selection! Please enter a number between 1 and ${#keys[@]}.${COLOR_RESET}"
        fi
    done
}


detect_displays
select_display

# Validate display selection
if ! confirm "Configure display '${DISPLAYS[$SELECTED_DISPLAY]}'?"; then
    echo -e "${COLOR_RED}User canceled display configuration.${COLOR_RESET}"
    $IS_SOURCED && return 1 || exit 1
fi

show_progress

CONFIG_SUMMARY=$(cat <<EOF
Configuration Summary:

  - Display: ${DISPLAYS[$SELECTED_DISPLAY]}
  - Rotation: $DISPLAY_ROTATION_TRANSFORM
  - Touch Device: ${selected_touch:-None detected}
  - Touch Calibration Matrix: $TOUCH_INPUT_CALIBRATION
EOF
)

if ! confirm "${CONFIG_SUMMARY}\n\nApply these settings?"; then
    echo -e "${COLOR_YELLOW}Skipping display & touch configuration.${COLOR_RESET}"
    $IS_SOURCED && return 0 || exit 0
fi
