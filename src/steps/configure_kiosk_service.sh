#!/usr/bin/env bash
#
# configure_kiosk_service.sh
# Configures the kiosk systemd service using Cage + Chromium.
#
# Standalone usage:
#   ./configure_kiosk_service.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Kiosk Service"
show_progress

TEMPLATE_FILE="$SCRIPT_DIR/../templates/kiosk.service.template"
PAM_TEMPLATE="$SCRIPT_DIR/../templates/cage.pam.template"
SERVICE_FILE="/etc/systemd/system/kiosk.service"
PAM_FILE="/etc/pam.d/cage"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${COLOR_RED}Template file not found: $TEMPLATE_FILE${COLOR_RESET}"
    exit 1
fi

if [[ ! -f "$PAM_TEMPLATE" ]]; then
    echo -e "${COLOR_RED}PAM template not found: $PAM_TEMPLATE${COLOR_RESET}"
    exit 1
fi

# ---- Prompt for Home Assistant URL ----
while true; do
    echo -e "${BOLD}Enter the Home Assistant URL:${COLOR_RESET}"
    echo -e "(e.g., https://homeassistant.local:8123)"
    read -r HA_URL

    if [[ -z "$HA_URL" ]]; then
        echo -e "${COLOR_RED}No URL provided. Please enter a URL.${COLOR_RESET}"
        continue
    fi

    if [[ ! "$HA_URL" =~ ^https?:// ]]; then
        echo -e "${COLOR_RED}URL must start with http:// or https://${COLOR_RESET}"
        continue
    fi

    break
done

CURRENT_USER="$(whoami)"

# Generate config from template
NEW_CONFIG=$(cat "$TEMPLATE_FILE")
NEW_CONFIG="${NEW_CONFIG//___CURRENT_USER___/$CURRENT_USER}"
NEW_CONFIG="${NEW_CONFIG//___HA_URL___/$HA_URL}"

echo -e "${BOLD}The following systemd service will be installed:${COLOR_RESET}"
echo "------------------------------------------------------------"
echo "$NEW_CONFIG"
echo "------------------------------------------------------------"
echo
echo -e "${BOLD}PAM configuration will be installed to: $PAM_FILE${COLOR_RESET}"
echo

if ! confirm "Proceed with configuring the kiosk service?"; then
    echo -e "${COLOR_RED}User canceled kiosk service configuration.${COLOR_RESET}"
    exit 1
fi

# ---- Clean up old greetd/labwc artifacts ----
if dpkg -s greetd &>/dev/null || [[ -f /etc/greetd/config.toml ]]; then
    start_spinner "Removing old greetd/labwc configuration"
    sudo systemctl disable --now greetd 2>/dev/null || true
    sudo rm -f /etc/greetd/config.toml
    sudo rm -f "/home/${CURRENT_USER}/.config/labwc/autostart"
    stop_spinner
fi

# ---- Install PAM file ----
start_spinner "Installing PAM configuration"
sudo cp "$PAM_TEMPLATE" "$PAM_FILE"
stop_spinner

# ---- Install service file ----
start_spinner "Installing kiosk service"
echo "$NEW_CONFIG" | sudo tee "$SERVICE_FILE" > /dev/null
stop_spinner

# ---- Add user to required groups ----
start_spinner "Adding $CURRENT_USER to video and input groups"
sudo usermod -aG video,input "$CURRENT_USER"
stop_spinner

# ---- Disable unnecessary services ----
start_spinner "Disabling unnecessary services"
for svc in ModemManager bluetooth triggerhappy udisks2 NetworkManager-wait-online; do
    sudo systemctl disable --now "$svc" 2>/dev/null || true
done
stop_spinner

# ---- Set CPU governor to performance ----
start_spinner "Setting CPU governor to performance"
sudo tee /etc/tmpfiles.d/cpu-performance.conf > /dev/null << 'EOF'
w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor - - - - performance
w /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor - - - - performance
w /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor - - - - performance
w /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor - - - - performance
EOF
# Apply immediately
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo 'performance' | sudo tee "$cpu" > /dev/null 2>&1 || true
done
stop_spinner

# ---- Enable service ----
start_spinner "Enabling kiosk service"
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service > /dev/null
sudo systemctl set-default graphical.target > /dev/null
stop_spinner

echo -e "${COLOR_GREEN}Kiosk service configured successfully!${COLOR_RESET}"
sleep 1
exit 0
