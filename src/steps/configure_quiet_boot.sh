#!/usr/bin/env bash
#
# configure_quiet_boot.sh
# Configures Raspberry Pi for quiet boot with Plymouth splash support.
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
    "splash"
    "loglevel=0"
    "logo.nologo"
    "vt.global_cursor_default=0"
    "plymouth.ignore-serial-consoles"
)

# Check which parameters are missing
parameters=()
for requirement in "${REQUIREMENTS[@]}"; do
    if ! grep -q "$requirement" "$CMDLINE_FILE"; then
        parameters+=("$requirement")
    fi
done

if [[ ${#parameters[@]} -gt 0 ]]; then
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
    sudo sed -i "1s|\$| ${parameters[*]}|" "$CMDLINE_FILE"
    stop_spinner
else
    echo -e "${COLOR_GREEN}All cmdline.txt parameters already present.${COLOR_RESET}"
fi

# ---- config.txt settings ----
CONFIG_SETTINGS=(
    "disable_splash=1"
    "dtoverlay=vc4-kms-v3d"
    "auto_initramfs=1"
)

config_to_add=()
for setting in "${CONFIG_SETTINGS[@]}"; do
    if ! grep -q "^${setting}$" "$CONFIG_FILE"; then
        config_to_add+=("$setting")
    fi
done

if [[ ${#config_to_add[@]} -gt 0 ]]; then
    echo -e "${BOLD}The following settings will be added to $CONFIG_FILE:${COLOR_RESET}"
    for setting in "${config_to_add[@]}"; do
        echo "  - $setting"
    done
    echo
    if ! confirm "Proceed with adding config.txt settings?"; then
        echo -e "${COLOR_RED}User canceled config.txt configuration.${COLOR_RESET}"
        exit 1
    fi

    start_spinner "Configuring config.txt"
    for setting in "${config_to_add[@]}"; do
        echo "$setting" | sudo tee -a "$CONFIG_FILE" > /dev/null
    done
    stop_spinner
else
    echo -e "${COLOR_GREEN}All config.txt settings already present.${COLOR_RESET}"
fi

echo -e "${COLOR_GREEN}Quiet boot configured successfully!${COLOR_RESET}"
sleep 1
exit 0
