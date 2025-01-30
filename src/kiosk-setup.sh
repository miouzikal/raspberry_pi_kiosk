#!/usr/bin/env bash
#
# kiosk-setup.sh
# Main script that orchestrates the kiosk setup steps.

# ----------------------------------------------------------------------
# 1) Source the utilities (for spinner, progress, confirm, etc.)
# ----------------------------------------------------------------------
source "$(dirname "$0")/utils.sh"

# ----------------------------------------------------------------------
# 2) MAIN SCRIPT
# ----------------------------------------------------------------------
main() {
  # Don't run as root check
  if [[ "$(id -u)" -eq 0 ]]; then
    echo -e "${COLOR_RED}Do not run as root. Exiting.${COLOR_RESET}"
    exit 1
  fi

  # Introduction
  clear
  echo -e "${BOLD}${COLOR_BLUE}=== Welcome to the Kiosk Setup Script ===${COLOR_RESET}\n"
  echo -e "This script will:\n"
  echo " - Update/Upgrade Packages"
  echo " - Install Kiosk Dependencies"
  echo " - Configure System Parameters"
  echo " - Configure Autologin"
  echo " - Configure Display"
  echo " - Set Kiosk URL"
  echo
  if ! confirm "Ready to proceed?"; then
    echo -e "${COLOR_RED}Setup canceled by user.${COLOR_RESET}"
    exit 1
  fi

  # Let's run each step in a chain:
  run_step "System Update & Upgrade" "$(dirname "$0")/steps/system_update.sh"
  run_step "Install Dependencies" "$(dirname "$0")/steps/install_dependencies.sh" true
  run_step "Configure System Parameters" "$(dirname "$0")/steps/configure_system_parameters.sh" true
  run_step "Configure Autologin" "$(dirname "$0")/steps/configure_autologin.sh" true
  run_step "Configure Display" "$(dirname "$0")/steps/configure_display.sh" true
  run_step "Set Kiosk URL" "$(dirname "$0")/steps/set_kiosk_url.sh" true

  run_step "Finalize" "$(dirname "$0")/steps/wrap_up.sh" true true
}

main
