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
  echo "This script will:"
  echo " - Update/upgrade packages"
  echo " - Install kiosk dependencies"
  echo " - Configure greetd (and other steps you add)"
  echo
  if ! confirm "Ready to proceed?"; then
    echo -e "${COLOR_RED}Setup canceled by user.${COLOR_RESET}"
    exit 1
  fi

  # Let's run each step in a chain:
  # (Add or remove as needed)
#   run_step "System Update & Upgrade"   "$(dirname "$0")/steps/system_update.sh"
#   run_step "Install Dependencies"      "$(dirname "$0")/steps/install_dependencies.sh"
#   run_step "Configure Greetd"          "$(dirname "$0")/steps/configure_greetd.sh"

#   # Finish / summary step
#   run_step "Finish"                    "$(dirname "$0")/steps/finish_setup.sh"

  echo -e "\n${COLOR_GREEN}All steps completed!${COLOR_RESET}"
}

main
