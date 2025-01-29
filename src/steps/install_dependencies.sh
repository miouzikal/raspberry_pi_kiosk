#!/usr/bin/env bash
#
# install_dependencies.sh
# Installs required kiosk packages.
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

# create list of packages to install
packages_to_install=()
for pkg in "${PREREQUISITES[@]}"; do
  if ! dpkg -l "$pkg" &>/dev/null; then
    packages_to_install+=("$pkg")
  fi
done

if [[ ${#packages_to_install[@]} -eq 0 ]]; then
  echo -e "${COLOR_GREEN}All dependencies are already installed.${COLOR_RESET}"
  sleep 1
  exit 0
fi

echo -e "${BOLD}The following packages will be installed:${COLOR_RESET}"
for pkg in "${packages_to_install[@]}"; do
  echo "  - $pkg"
done
echo
if ! confirm "Proceed with installing packages?"; then
  echo -e "${COLOR_RED}User canceled prerequisites installation.${COLOR_RESET}"
  exit 1
fi

start_spinner "Installing dependencies"
sudo apt-get install --no-install-recommends -y "${packages_to_install[@]}" >/dev/null 2>&1
stop_spinner

echo -e "${COLOR_GREEN}Dependency installation complete!${COLOR_RESET}"
sleep 1
exit 0
