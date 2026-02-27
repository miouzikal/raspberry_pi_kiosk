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
  echo " - Install kiosk dependencies (Cage, Chromium)"
  echo " - Configure hostname"
  echo " - Configure quiet boot and RPi firmware"
  echo " - Configure screen orientation and display"
  echo " - Configure framebuffer splash screen"
  echo " - Configure the kiosk service (Cage + Chromium)"
  echo " - Configure performance (overclocking, WiFi driver)"
  echo " - Configure extras (GPIO button handler, wake-on-sound)"
  echo
  if ! confirm "Ready to proceed?"; then
    echo -e "${COLOR_RED}Setup canceled by user.${COLOR_RESET}"
    exit 1
  fi

  run_step "System Update & Upgrade"     "$(dirname "$0")/steps/system_update.sh"
  run_step "Install Dependencies"        "$(dirname "$0")/steps/install_dependencies.sh"    true
  run_step "Configure Hostname"          "$(dirname "$0")/steps/configure_hostname.sh"      true
  run_step "Configure Quiet Boot"        "$(dirname "$0")/steps/configure_quiet_boot.sh"    true
  run_step "Configure Screen"            "$(dirname "$0")/steps/configure_screen.sh"         true
  run_step "Configure Splash Screen"     "$(dirname "$0")/steps/configure_splash.sh"         true
  run_step "Configure Kiosk Service"     "$(dirname "$0")/steps/configure_kiosk_service.sh"  true
  run_step "Configure Performance"        "$(dirname "$0")/steps/configure_performance.sh"    true
  run_step "Configure Extras"            "$(dirname "$0")/steps/configure_extras.sh"         true

  bash "$(dirname "$0")/steps/wrap_up.sh"
}

main
