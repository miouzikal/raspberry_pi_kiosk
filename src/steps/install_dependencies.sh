#!/usr/bin/env bash

# Determine if the script is being sourced or executed
[[ "${BASH_SOURCE[0]}" != "$0" ]] && IS_SOURCED=true || IS_SOURCED=false

# Ensure utils.sh is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -p STEPS_COMPLETED &>/dev/null || source "$SCRIPT_DIR/../utils.sh"

# Step logic
CURRENT_STEP="Install Dependencies"

show_progress

# List of packages
PREREQUISITES=(
  chromium-browser
  git
  greetd
  labwc
  libinput-tools
  seatd
  vim
  wlr-randr
)

# Create list of packages to install
packages_to_install=()
for pkg in "${PREREQUISITES[@]}"; do
  if ! dpkg -l "$pkg" &>/dev/null; then
    packages_to_install+=("$pkg")
  fi
done

if [[ ${#packages_to_install[@]} -eq 0 ]]; then
  echo -e "${COLOR_GREEN}All dependencies are already installed.${COLOR_RESET}"
  sleep 3
  $IS_SOURCED && return 0 || exit 0
fi

echo -e "${BOLD}The following packages will be installed:${COLOR_RESET}"
for pkg in "${packages_to_install[@]}"; do
  echo "  - $pkg"
done
echo

if ! confirm "Proceed with installing packages?"; then
  echo -e "${COLOR_RED}User canceled prerequisites installation.${COLOR_RESET}"
  $IS_SOURCED && return 1 || exit 1
fi

show_progress

start_spinner "Installing dependencies"
sudo apt-get install --no-install-recommends -y "${packages_to_install[@]}" >/dev/null 2>&1
stop_spinner

echo -e "${COLOR_GREEN}Dependency installation complete!${COLOR_RESET}"
sleep 3
$IS_SOURCED && return 0 || exit 0
