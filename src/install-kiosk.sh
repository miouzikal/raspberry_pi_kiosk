#!/bin/bash

# Configuration Variables
HOME_ASSISTANT_URL="___HOME_ASSISTANT_URL___"
USERNAME="raspberry"
TOUCH_DEVICE_NAME="Waveshare"
DISPLAY_SETTING=":0"
ROTATION_MATRIX='0 -1 1 1 0 0 0 0 1'
HDMI_OUTPUT="HDMI-1"
ROTATE_ORIENTATION="left"
CPU_OVERCLOCK_FREQUENCY="2000"
GPU_OVERCLOCK_FREQUENCY="750"
GPU_MEMORY="256"
IDLE_TIME_THRESHOLD="300" # 5 minutes in seconds
# Additional Configuration for Audio Trigger Script
AUDIO_THRESHOLD="0.005"     # Audio trigger threshold
AUDIO_TRIGGER_METHOD="PEAK" # PEAK or RMS
AUDIO_TRIGGER_SCRIPT="/home/$USERNAME/wake_on_audio_trigger.sh"
AUDIO_TRIGGER_SERVICE="/etc/systemd/system/wake_on_audio_trigger.service"
# Function to update and upgrade system packages
update_system() {
    echo "Updating system packages..."
    sudo apt-get update -y && sudo apt-get upgrade -y
    sudo apt-get autoremove -y && sudo apt-get autoclean -y
}

# Function to install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt-get install --no-install-recommends vim xserver-xorg x11-xserver-utils openbox lightdm chromium-browser xinput fonts-noto-color-emoji xprintidle ddcutil xdotool bc sox jq python3-pygame python3-numpy -y
}

# Function to configure LightDM
configure_lightdm() {
    echo "Configuring LightDM..."
    if ! grep -q "xserver-command=X -nocursor" /etc/lightdm/lightdm.conf; then
        sudo sed -i -- "s/#xserver-command=X/xserver-command=X -nocursor/" /etc/lightdm/lightdm.conf
    else
        echo "LightDM already configured."
    fi
}

# Function to configure Openbox with integrated screen power management
configure_openbox() {
    echo "Configuring Openbox with integrated screen power management..."
    AUTOSTART_DIR="/home/$USERNAME/.config/openbox"
    AUTOSTART_FILE="$AUTOSTART_DIR/autostart"
    mkdir -p "$AUTOSTART_DIR"
    chown $USERNAME:$USERNAME "$AUTOSTART_DIR"
    cp ./scripts/autostart "$AUTOSTART_FILE"
    chown $USERNAME:$USERNAME "$AUTOSTART_FILE"
}

# Function to overclock Raspberry Pi
overclock_rpi() {
    if ! grep -q "^over_voltage=6" "/boot/config.txt"; then
        echo "Overvolting Raspberry Pi to 6..."
        sudo tee -a "/boot/config.txt" <<<"over_voltage=6"
    else
        echo "Raspberry Pi already overvolted."
    fi

    if ! grep -q "^arm_freq=$CPU_OVERCLOCK_FREQUENCY" "/boot/config.txt"; then
        echo "Overclocking Raspberry Pi to $CPU_OVERCLOCK_FREQUENCY MHz..."
        sudo tee -a "/boot/config.txt" <<<"arm_freq=$CPU_OVERCLOCK_FREQUENCY"
    else
        echo "Raspberry Pi CPU already overclocked."
    fi

    if ! grep -q "^gpu_freq=$GPU_OVERCLOCK_FREQUENCY" "/boot/config.txt"; then
        echo "Overclocking GPU to $GPU_OVERCLOCK_FREQUENCY MHz..."
        sudo tee -a "/boot/config.txt" <<<"gpu_freq=$GPU_OVERCLOCK_FREQUENCY"
    else
        echo "Raspberry Pi GPU already overclocked."
    fi

    if ! grep -q "^gpu_mem=$GPU_MEMORY" "/boot/config.txt"; then
        echo "Assigning $GPU_MEMORY MB of RAM to GPU..."
        sudo tee -a "/boot/config.txt" <<<"gpu_mem=$GPU_MEMORY"
    else
        echo "Raspberry Pi GPU memory already set."
    fi
}

# Function to set HDMI configuration
configure_hdmi() {
    if ! grep -q "^hdmi_group=2" "/boot/config.txt" &&
        ! grep -q "^hdmi_mode=87" "/boot/config.txt" &&
        ! grep -q "^hdmi_cvt 1280 800 60 6 0 0 0" "/boot/config.txt" &&
        ! grep -q "^hdmi_drive=1" "/boot/config.txt"; then
        echo "Appending HDMI configuration to /boot/config.txt..."
        sudo tee -a "/boot/config.txt" <<<"hdmi_group=2"
        sudo tee -a "/boot/config.txt" <<<"hdmi_mode=87"
        sudo tee -a "/boot/config.txt" <<<"hdmi_cvt 1280 800 60 6 0 0 0"
        sudo tee -a "/boot/config.txt" <<<"hdmi_drive=1"
    else
        echo "HDMI configuration already set in /boot/config.txt."
    fi
}

# Disable boot messages
disable_boot_messages() {
    echo "Disabling boot messages..."
    temp_file=$(mktemp)
    original_attributes=$(stat -c '%a' "/boot/cmdline.txt")
    sed "s/tty1/tty3/" "/boot/cmdline.txt" >"$temp_file"
    sudo cp --preserve=ownership "$temp_file" "/boot/cmdline.txt"
    sudo chmod "$original_attributes" "/boot/cmdline.txt"
    if ! grep -q "quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0" "/boot/cmdline.txt"; then
        sudo tee -a "/boot/cmdline.txt" <<<" quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0"
    fi
    if ! grep -q "^disable_splash=1" "/boot/config.txt"; then
        sudo tee -a "/boot/config.txt" <<<"disable_splash=1"
    fi
    rm "$temp_file"
}

# Function to create the audio trigger script
create_audio_trigger_script() {
    echo "Creating audio trigger script..."
    cp ./scripts/wake_on_audio_trigger.sh "$AUDIO_TRIGGER_SCRIPT"
    chmod +x "$AUDIO_TRIGGER_SCRIPT"
    chown $USERNAME:$USERNAME "$AUDIO_TRIGGER_SCRIPT"
}

# Function to create and enable a systemd service for the audio trigger script
create_audio_trigger_service() {
    echo "Creating systemd service for audio trigger script..."
    cp ./scripts/wake_on_audio_trigger.service "$AUDIO_TRIGGER_SERVICE"
    systemctl enable wake_on_audio_trigger.service
    systemctl start wake_on_audio_trigger.service
}

# Main execution
echo "Starting setup for Raspberry Pi Kiosk mode with Chromium browser"
update_system
install_packages
configure_lightdm
configure_openbox
disable_boot_messages
overclock_rpi
configure_hdmi
create_audio_trigger_script
create_audio_trigger_service

# Fix permissions
echo "Fixing permissions on /home/$USERNAME..."
sudo chown -R $USERNAME:$USERNAME "/home/$USERNAME"

echo "Setup complete! Please enable GUI autologin for user $USERNAME in raspi-config (and I2C if you want to use ddcutil)."
