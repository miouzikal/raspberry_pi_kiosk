#!/usr/bin/env bash
#
# configure_greetd.sh
# Configures greetd using a template file.
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

# Step logic
CURRENT_STEP="Configure Greetd"

show_progress

TEMPLATE_FILE="$SCRIPT_DIR/../templates/greetd_config.toml.template"
TARGET_FILE="/etc/greetd/config.toml"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo -e "${COLOR_RED}Template file not found: $TEMPLATE_FILE${COLOR_RESET}"
  exit 1
fi

# Show the content of the template
echo -e "${BOLD}Configuring greetd will install the following configuration:${COLOR_RESET}"
NEW_CONFIG=$(sed "s|___CURRENT_USER___|$(whoami)|g" "$TEMPLATE_FILE")
echo "------------------------------------------------------------"
echo "$NEW_CONFIG"
echo "------------------------------------------------------------"

if ! confirm "Proceed with configuring greetd?"; then
  echo -e "${COLOR_RED}User canceled greetd configuration.${COLOR_RESET}"
  exit 1
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
exit 0

