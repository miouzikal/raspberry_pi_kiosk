#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="Configure Greetd"

show_progress

TEMPLATE_FILE="$SCRIPT_DIR/../templates/greetd_configuration.toml.template"
TARGET_FILE="/etc/greetd/config.toml"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo -e "${COLOR_RED}Template file not found: $TEMPLATE_FILE${COLOR_RESET}"
  $IS_SOURCED && return 1 || exit 1
fi

# Show the content of the template
NEW_CONFIG=$(sed "s|___CURRENT_USER___|$(whoami)|g" "$TEMPLATE_FILE")
CONFIRM_MESSAGE=$(cat <<EOF
${BOLD}The following configuration will be written to '$TARGET_FILE':${COLOR_RESET}
------------------------------------------------------------
$NEW_CONFIG
------------------------------------------------------------

Do you want to configure and start greetd?
EOF
)

if ! confirm "$CONFIRM_MESSAGE"; then
  echo -e "${COLOR_RED}User canceled greetd configuration.${COLOR_RESET}"
  $IS_SOURCED && return 1 || exit 1
fi

show_progress

# Write the new configuration
start_spinner "Configuring and starting greetd"
echo "$NEW_CONFIG" | sudo tee "$TARGET_FILE" > /dev/null
sudo systemctl enable greetd > /dev/null 2>&1
sudo systemctl set-default graphical.target > /dev/null
sudo systemctl start greetd > /dev/null
stop_spinner

echo -e "${COLOR_GREEN}greetd configured successfully!${COLOR_RESET}"
sleep 3
$IS_SOURCED && return 0 || exit 0

