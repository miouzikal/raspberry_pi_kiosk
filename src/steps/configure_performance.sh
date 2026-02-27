#!/usr/bin/env bash
#
# configure_performance.sh
# Optional CPU/GPU overclocking and WiFi driver configuration.
#
# Standalone usage:
#   ./configure_performance.sh
#   (Ensure you source ../utils.sh or run in an environment where it's loaded.)

# Source the utils if not running from main script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$COLOR_BLUE" ]]; then
  source "$SCRIPT_DIR/../utils.sh"
fi

CURRENT_STEP="Configure Performance"
show_progress

CONFIG_FILE="/boot/firmware/config.txt"

# ---- CPU/GPU Overclocking ----
echo -e "${BOLD}CPU/GPU Overclocking${COLOR_RESET}"
echo "  Overclocking increases performance but requires adequate cooling."
echo "  Default: arm_freq=2000, gpu_freq=750, over_voltage=6"
echo

if confirm "Enable CPU/GPU overclocking?"; then
    # CPU frequency
    echo -e "${BOLD}Enter CPU frequency in MHz [2000]:${COLOR_RESET}"
    read -r CPU_FREQ
    CPU_FREQ="${CPU_FREQ:-2000}"

    # GPU frequency
    echo -e "${BOLD}Enter GPU frequency in MHz [750]:${COLOR_RESET}"
    read -r GPU_FREQ
    GPU_FREQ="${GPU_FREQ:-750}"

    # Over-voltage
    echo -e "${BOLD}Enter over_voltage level (0-8) [6]:${COLOR_RESET}"
    read -r OVER_VOLTAGE
    OVER_VOLTAGE="${OVER_VOLTAGE:-6}"

    echo
    echo "  CPU: ${CPU_FREQ} MHz"
    echo "  GPU: ${GPU_FREQ} MHz"
    echo "  Over-voltage: ${OVER_VOLTAGE}"
    echo

    if confirm "Apply these overclocking settings?"; then
        start_spinner "Configuring overclocking"

        # Update or add arm_freq
        if grep -q '^arm_freq=' "$CONFIG_FILE"; then
            sudo sed -i "s|^arm_freq=.*|arm_freq=${CPU_FREQ}|" "$CONFIG_FILE"
        else
            echo "arm_freq=${CPU_FREQ}" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi

        # Update or add gpu_freq
        if grep -q '^gpu_freq=' "$CONFIG_FILE"; then
            sudo sed -i "s|^gpu_freq=.*|gpu_freq=${GPU_FREQ}|" "$CONFIG_FILE"
        else
            echo "gpu_freq=${GPU_FREQ}" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi

        # Update or add over_voltage
        if grep -q '^over_voltage=' "$CONFIG_FILE"; then
            sudo sed -i "s|^over_voltage=.*|over_voltage=${OVER_VOLTAGE}|" "$CONFIG_FILE"
        else
            echo "over_voltage=${OVER_VOLTAGE}" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi

        stop_spinner
        echo -e "${COLOR_GREEN}Overclocking configured.${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}Skipped overclocking.${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_YELLOW}Skipped overclocking.${COLOR_RESET}"
fi

echo

# ---- WiFi Adapter Driver ----
if lsusb 2>/dev/null | grep -q "2357:012d"; then
    echo -e "${BOLD}TP-Link Archer T3U WiFi adapter detected${COLOR_RESET}"
    echo "  The 88x2bu driver may need to be installed for this adapter."
    echo "  On newer kernels (6.x+) the rtw88 in-kernel driver may already work."
    echo

    if confirm "Install 88x2bu WiFi driver?"; then
        start_spinner "Installing WiFi driver dependencies"
        sudo apt-get install --no-install-recommends -y dkms git > /dev/null 2>&1
        stop_spinner

        start_spinner "Cloning and installing 88x2bu driver"
        DRIVER_DIR="/tmp/88x2bu-driver"
        rm -rf "$DRIVER_DIR"
        git clone https://github.com/morrownr/88x2bu-20210702.git "$DRIVER_DIR" > /dev/null 2>&1
        cd "$DRIVER_DIR" && sudo ./install-driver.sh NoPrompt > /dev/null 2>&1
        cd - > /dev/null
        stop_spinner

        # Configure driver options
        CONF_FILE="/etc/modprobe.d/88x2bu.conf"
        if [[ -f "$CONF_FILE" ]]; then
            start_spinner "Configuring WiFi driver options"
            # Ensure USB3 mode and power management disabled
            if grep -q '^options 88x2bu' "$CONF_FILE"; then
                for opt in "rtw_switch_usb_mode=1" "rtw_country_code=CA" "rtw_power_mgnt=0"; do
                    key="${opt%%=*}"
                    if grep -q "$key=" "$CONF_FILE"; then
                        sudo sed -i "s|${key}=[^ ]*|${opt}|" "$CONF_FILE"
                    else
                        sudo sed -i "s|^options 88x2bu.*|& ${opt}|" "$CONF_FILE"
                    fi
                done
            fi
            stop_spinner
        fi

        # Disable onboard WiFi if USB adapter is being used
        if confirm "Disable onboard WiFi (recommended when using USB adapter)?"; then
            if ! grep -q '^dtoverlay=disable-wifi' "$CONFIG_FILE"; then
                echo "dtoverlay=disable-wifi" | sudo tee -a "$CONFIG_FILE" > /dev/null
            fi
            echo -e "${COLOR_GREEN}Onboard WiFi disabled.${COLOR_RESET}"
        fi

        echo -e "${COLOR_GREEN}WiFi driver installed.${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}Skipped WiFi driver installation.${COLOR_RESET}"
    fi
fi

echo
echo -e "${COLOR_GREEN}Performance configuration complete!${COLOR_RESET}"
sleep 1
exit 0
