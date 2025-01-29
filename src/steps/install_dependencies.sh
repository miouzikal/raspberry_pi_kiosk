#!/usr/bin/env bash
#
# install_dependencies.sh
# Installs required kiosk packages.
#
# Standalone usage:
#   ./install_dependencies.sh
#   (Ensure utils.sh is sourced or in the environment.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Install Dependencies"
show_progress

# List of packages
packages=(
    chromium-browser \
    git \
    greetd \
    labwc \
    libinput-tools \
    seatd \
    vim \
    wlr-randr
)

# create list of packages to install
pkgs_to_install=()
for pkg in "${packages[@]}"; do
  if ! dpkg -l "$pkg" &>/dev/null; then
    pkgs_to_install+=("$pkg")
  fi
done

if [[ ${#pkgs_to_install[@]} -eq 0 ]]; then
  echo -e "${COLOR_GREEN}All dependencies are already installed.${COLOR_RESET}"
  sleep 1
  exit 0
fi

echo -e "${BOLD}The following packages will be installed:${COLOR_RESET}"
for pkg in "${packages[@]}"; do
  echo "  - $pkg"
done
echo
if ! confirm "Proceed with installing packages?"; then
  echo -e "${COLOR_RED}User canceled installation.${COLOR_RESET}"
  echo -e "- Setup cannot continue without installing dependencies."
  exit 1
fi

start_spinner "Installing dependencies"
sudo apt-get install --no-install-recommends -y "${packages[@]}" > /dev/null 2>&1
stop_spinner

echo -e "${COLOR_GREEN}Dependency installation complete!${COLOR_RESET}"
sleep 1
exit 0
