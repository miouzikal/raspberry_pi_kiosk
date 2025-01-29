#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="Configure Greetd"

show_progress

TEMPLATE_FILE="$SCRIPT_DIR/../templates/greetd_config.toml.template"
TARGET_FILE="/etc/greetd/config.toml"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo -e "${COLOR_RED}Template file not found: $TEMPLATE_FILE${COLOR_RESET}"
  $IS_SOURCED && return 1 || exit 1
fi

# Show the content of the template
echo -e "${BOLD}Configuring greetd will install the following configuration:${COLOR_RESET}"
NEW_CONFIG=$(sed "s|___CURRENT_USER___|$(whoami)|g" "$TEMPLATE_FILE")
echo "------------------------------------------------------------"
echo "$NEW_CONFIG"
echo "------------------------------------------------------------"

if ! confirm "Proceed with configuring greetd?"; then
  echo -e "${COLOR_RED}User canceled greetd configuration.${COLOR_RESET}"
  $IS_SOURCED && return 1 || exit 1
fi

# Write the new configuration
start_spinner "Configuring greetd"
echo "$NEW_CONFIG" | sudo tee "$TARGET_FILE" > /dev/null
sudo systemctl enable greetd > /dev/null
sudo systemctl set-default graphical.target > /dev/null
sudo systemctl start greetd > /dev/null
stop_spinner

echo -e "${COLOR_GREEN}greetd configured successfully!${COLOR_RESET}"
sleep 1
$IS_SOURCED && return 0 || exit 0

