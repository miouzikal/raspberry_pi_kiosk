#!/usr/bin/env bash
#
# configure_hostname.sh
# Optionally changes the system hostname.
#
# Standalone usage:
#   ./configure_hostname.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Hostname"
show_progress

CURRENT_HOSTNAME="$(hostname)"

if confirm "Change the current hostname (${CURRENT_HOSTNAME})?"; then
    while true; do
        echo -e "${BOLD}Enter the new hostname:${COLOR_RESET}"
        read -r NEW_HOSTNAME

        if [[ -z "$NEW_HOSTNAME" ]]; then
            echo -e "${COLOR_RED}Hostname cannot be empty.${COLOR_RESET}"
            continue
        fi

        if [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
            echo -e "${COLOR_RED}Invalid hostname. Use only letters, numbers, and hyphens.${COLOR_RESET}"
            continue
        fi

        break
    done

    if confirm "Set hostname to '${NEW_HOSTNAME}'?"; then
        start_spinner "Updating hostname"
        sudo hostnamectl set-hostname "$NEW_HOSTNAME"
        stop_spinner
        echo -e "${COLOR_GREEN}Hostname changed to '${NEW_HOSTNAME}'.${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}Hostname change canceled. Keeping '${CURRENT_HOSTNAME}'.${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_GREEN}Keeping hostname '${CURRENT_HOSTNAME}'.${COLOR_RESET}"
fi

sleep 1
exit 0
