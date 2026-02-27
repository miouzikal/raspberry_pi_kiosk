#!/usr/bin/env bash
#
# configure_quiet_boot.sh
# Configures Raspberry Pi for quiet boot with framebuffer splash support.
#
# Standalone usage:
#   ./configure_quiet_boot.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Quiet Boot"
show_progress

CMDLINE_FILE="/boot/firmware/cmdline.txt"
CONFIG_FILE="/boot/firmware/config.txt"

# ---- cmdline.txt parameters ----
REQUIREMENTS=(
    "quiet"
    "loglevel=0"
    "logo.nologo"
    "vt.global_cursor_default=0"
    "fbcon=map:1"
)

# Check which parameters are missing
parameters=()
for requirement in "${REQUIREMENTS[@]}"; do
    if ! grep -q "$requirement" "$CMDLINE_FILE"; then
        parameters+=("$requirement")
    fi
done

# Redirect console away from tty1 (where Cage will run) to tty2
if grep -q 'console=tty1' "$CMDLINE_FILE"; then
    parameters+=("(replace console=tty1 → console=tty2)")
fi

# Remove stale 'splash' parameter (leftover from Plymouth, no longer needed)
if grep -q ' splash ' "$CMDLINE_FILE" || grep -q ' splash$' "$CMDLINE_FILE"; then
    parameters+=("(remove stale 'splash' parameter)")
fi

if [[ ${#parameters[@]} -gt 0 ]]; then
    echo -e "${BOLD}The following changes will be made to $CMDLINE_FILE:${COLOR_RESET}"
    for param in "${parameters[@]}"; do
        echo "  - $param"
    done
    echo
    if ! confirm "Proceed with cmdline.txt changes?"; then
        echo -e "${COLOR_RED}User canceled cmdline.txt changes.${COLOR_RESET}"
        exit 1
    fi

    start_spinner "Updating $CMDLINE_FILE"

    # Replace console=tty1 with console=tty2
    if grep -q 'console=tty1' "$CMDLINE_FILE"; then
        sudo sed -i 's|console=tty1|console=tty2|g' "$CMDLINE_FILE"
    fi

    # Remove stale 'splash' parameter (Plymouth leftover)
    sudo sed -i 's| splash | |g; s| splash$||g' "$CMDLINE_FILE"

    # Add missing parameters (filter out the console replacement note)
    real_params=()
    for param in "${parameters[@]}"; do
        if [[ "$param" != "("* ]]; then
            real_params+=("$param")
        fi
    done
    if [[ ${#real_params[@]} -gt 0 ]]; then
        sudo sed -i "1s|\$| ${real_params[*]}|" "$CMDLINE_FILE"
    fi

    stop_spinner
else
    echo -e "${COLOR_GREEN}All cmdline.txt parameters already present.${COLOR_RESET}"
fi

# ---- config.txt settings ----
CONFIG_SETTINGS=(
    "disable_splash=1"
    "auto_initramfs=1"
    "gpu_mem=64"
)

config_to_add=()
for setting in "${CONFIG_SETTINGS[@]}"; do
    if ! grep -q "^${setting}$" "$CONFIG_FILE"; then
        config_to_add+=("$setting")
    fi
done

# Update vc4 overlay to disable unused HDMI port and audio for faster init
if grep -q '^dtoverlay=vc4-kms-v3d$' "$CONFIG_FILE"; then
    config_to_add+=("(update dtoverlay=vc4-kms-v3d → vc4-kms-v3d,nohdmi1,noaudio)")
fi

if [[ ${#config_to_add[@]} -gt 0 ]]; then
    echo -e "${BOLD}The following changes will be made to $CONFIG_FILE:${COLOR_RESET}"
    for setting in "${config_to_add[@]}"; do
        echo "  - $setting"
    done
    echo
    if ! confirm "Proceed with config.txt changes?"; then
        echo -e "${COLOR_RED}User canceled config.txt configuration.${COLOR_RESET}"
        exit 1
    fi

    start_spinner "Configuring config.txt"

    # Update vc4 overlay
    if grep -q '^dtoverlay=vc4-kms-v3d$' "$CONFIG_FILE"; then
        sudo sed -i 's|^dtoverlay=vc4-kms-v3d$|dtoverlay=vc4-kms-v3d,nohdmi1,noaudio|' "$CONFIG_FILE"
    fi

    # Add missing settings
    for setting in "${config_to_add[@]}"; do
        if [[ "$setting" != "("* ]]; then
            echo "$setting" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi
    done

    stop_spinner
else
    echo -e "${COLOR_GREEN}All config.txt settings already present.${COLOR_RESET}"
fi

echo -e "${COLOR_GREEN}Quiet boot configured successfully!${COLOR_RESET}"
sleep 1
exit 0
