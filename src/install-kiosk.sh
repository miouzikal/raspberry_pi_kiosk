#!/bin/bash

# Configuration Variables
USERNAME="raspberry"
CPU_OVERCLOCK_FREQUENCY="2000"
GPU_OVERCLOCK_FREQUENCY="750"
GPU_MEMORY="256"
# Additional Configuration for Audio Trigger Script
AUDIO_TRIGGER_SCRIPT="/home/$USERNAME/wake_on_sound.sh"
AUDIO_TRIGGER_SERVICE="/etc/systemd/system/wake_on_sound.service"
# Function to update and upgrade system packages
update_system() {
    echo "Updating system packages..."
    sudo apt-get update -y && sudo apt-get upgrade -y
    sudo apt-get autoremove -y && sudo apt-get autoclean -y
}

# Function to install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt-get install --no-install-recommends vim xserver-xorg x11-xserver-utils openbox lightdm chromium-browser xinput fonts-noto-color-emoji xprintidle ddcutil xdotool bc sox jq python3-pygame python3-numpy dkms git fbi -y
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
    cp ./scripts/openbox/autostart "$AUTOSTART_FILE"
    chown $USERNAME:$USERNAME "$AUTOSTART_FILE"
}

# Function to overclock Raspberry Pi
overclock_rpi() {
    if ! grep -q "^over_voltage=6" "/boot/firmware/config.txt"; then
        echo "Overvolting Raspberry Pi to 6..."
        sudo tee -a "/boot/firmware/config.txt" <<<"over_voltage=6"
    else
        echo "Raspberry Pi already overvolted."
    fi

    if ! grep -q "^arm_freq=$CPU_OVERCLOCK_FREQUENCY" "/boot/firmware/config.txt"; then
        echo "Overclocking Raspberry Pi to $CPU_OVERCLOCK_FREQUENCY MHz..."
        sudo tee -a "/boot/firmware/config.txt" <<<"arm_freq=$CPU_OVERCLOCK_FREQUENCY"
    else
        echo "Raspberry Pi CPU already overclocked."
    fi

    if ! grep -q "^gpu_freq=$GPU_OVERCLOCK_FREQUENCY" "/boot/firmware/config.txt"; then
        echo "Overclocking GPU to $GPU_OVERCLOCK_FREQUENCY MHz..."
        sudo tee -a "/boot/firmware/config.txt" <<<"gpu_freq=$GPU_OVERCLOCK_FREQUENCY"
    else
        echo "Raspberry Pi GPU already overclocked."
    fi

    if ! grep -q "^gpu_mem=$GPU_MEMORY" "/boot/firmware/config.txt"; then
        echo "Assigning $GPU_MEMORY MB of RAM to GPU..."
        sudo tee -a "/boot/firmware/config.txt" <<<"gpu_mem=$GPU_MEMORY"
    else
        echo "Raspberry Pi GPU memory already set."
    fi
}

# Function to set HDMI configuration
configure_hdmi() {
    if ! grep -q "^hdmi_group=2" "/boot/firmware/config.txt" &&
        ! grep -q "^hdmi_mode=87" "/boot/firmware/config.txt" &&
        ! grep -q "^hdmi_cvt 1280 800 60 6 0 0 0" "/boot/firmware/config.txt" &&
        ! grep -q "^hdmi_drive=1" "/boot/firmware/config.txt"; then
        echo "Appending HDMI configuration to /boot/firmware/config.txt..."
        sudo tee -a "/boot/firmware/config.txt" <<<"hdmi_group=2"
        sudo tee -a "/boot/firmware/config.txt" <<<"hdmi_mode=87"
        sudo tee -a "/boot/firmware/config.txt" <<<"hdmi_cvt 1280 800 60 6 0 0 0"
        sudo tee -a "/boot/firmware/config.txt" <<<"hdmi_drive=1"
    else
        echo "HDMI configuration already set in /boot/firmware/config.txt."
    fi
}

# Disable boot messages
disable_boot_messages() {
    echo "Disabling boot messages..."
    sed -i "s/tty1/tty3/" "/boot/firmware/cmdline.txt"
    if ! grep -q "quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0 fbcon=rotate:3" "/boot/firmware/cmdline.txt"; then
        sudo tee -a "/boot/firmware/cmdline.txt" <<<" quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0 fbcon=rotate:3"
    fi
    if ! grep -q "^disable_splash=1" "/boot/firmware/config.txt"; then
        sudo tee -a "/boot/firmware/config.txt" <<<"disable_splash=1"
    fi

    # install splash screen
    sudo mkdir -p /opt/splash
    cp ./splash.png /opt/splash/splash.png

    # install splash service
    sudo cp ./scripts/splash/splash.service /etc/systemd/system/splash.service
    sudo systemctl enable splash.service
    sudo systemctl start splash.service
}

# Function to create the audio trigger script
create_audio_trigger_script() {
    echo "Creating audio trigger script..."
    cp ./scripts/wake_on_sound/wake_on_sound.sh "$AUDIO_TRIGGER_SCRIPT"
    chmod +x "$AUDIO_TRIGGER_SCRIPT"
    chown $USERNAME:$USERNAME "$AUDIO_TRIGGER_SCRIPT"
}

# Function to create and enable a systemd service for the audio trigger script
create_audio_trigger_service() {
    echo "Creating systemd service for audio trigger script..."
    cp ./scripts/wake_on_sound/wake_on_sound.service "$AUDIO_TRIGGER_SERVICE"
    systemctl enable wake_on_sound.service
    systemctl start wake_on_sound.service
}

# Function to create the button handler script
create_button_handler_script() {
    echo "Creating button handler script..."
    cp ./scripts/button_handler/button_handler.py "/home/$USERNAME/button_handler.py"
    chown $USERNAME:$USERNAME "/home/$USERNAME/button_handler.py"
}

# Function to create and enable a systemd service for the button handler script
create_button_handler_service() {
    echo "Creating systemd service for button handler script..."
    cp ./scripts/button_handler/button_handler.service "/etc/systemd/system/button_handler.service"
    systemctl enable button_handler.service
    systemctl start button_handler.service
}

# Install Wifi adapter driver
install_wifi_adapter_driver() {
    if lsusb | grep "2357:012d" >/dev/null; then
        echo "Installing driver for Wifi adapter..."
        git clone https://github.com/morrownr/88x2bu-20210702.git /home/$USERNAME/wifi-driver
        cd /home/$USERNAME/wifi-driver || echo "Failed to change directory to /home/$USERNAME/wifi-driver"
        sudo ./install-driver.sh NoPrompt
        CONF_FILE="/etc/modprobe.d/88x2bu.conf"
        if [ ! -f "$CONF_FILE" ]; then
            echo -e "\e[31mFailed to install Wifi adapter driver. Please install it manually.\e[0m"
        fi
        if ! grep -q "^dtoverlay=disable-wifi" "/boot/firmware/config.txt"; then
            echo "Disabling onboard Wifi..."
            echo "dtoverlay=disable-wifi" | sudo tee -a /boot/firmware/config.txt
        fi

        # Function to update or add an option
        update_or_add_option() {
            local option="$1"
            local value="$2"
            local pattern="^options 88x2bu .*${option}="
            if grep -qE "$pattern" "$CONF_FILE"; then
                # Update the existing option
                sudo sed -i -r "s/($pattern)[^ ]*/\1$value/" "$CONF_FILE"
            else
                # Add the option
                sudo sed -i "/^options 88x2bu /s/$/ ${option}=${value}/" "$CONF_FILE"
            fi
        }

        # Update or add rtw_switch_usb_mode and rtw_country_code
        update_or_add_option "rtw_switch_usb_mode" "1"
        update_or_add_option "rtw_country_code" "CA"
        update_or_add_option "rtw_power_mgnt" "0"
    fi
}

# Function to configure hostname
configure_hostname() {
    while true; do
        read -rp "Enter a hostname for the system: " HOSTNAME
        read -rp "Confirm hostname '$HOSTNAME'? [Y/n] " CONFIRM
        if [[ -z "$CONFIRM" || "$CONFIRM" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    if sudo raspi-config nonint do_hostname "$HOSTNAME"; then
        echo "Hostname set to '$HOSTNAME'."
    else
        echo "Failed to set hostname to '$HOSTNAME'. Please change it with 'sudo raspi-config'."
    fi
}

# Function to configure Home Assistant URL
configure_home_assistant_url() {
    while true; do
        read -rp "Enter the URL of your Home Assistant instance: " HOME_ASSISTANT_URL
        read -rp "Confirm Home Assistant URL '$HOME_ASSISTANT_URL'? [Y/n] " CONFIRM
        if [[ -z "$CONFIRM" || "$CONFIRM" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    sed -i "s|___HOME_ASSISTANT_URL___|$HOME_ASSISTANT_URL|" /home/$USERNAME/.config/openbox/autostart
    if grep -q "$HOME_ASSISTANT_URL" "/home/$USERNAME/.config/openbox/autostart"; then
        echo "Home Assistant URL successfully set to $HOME_ASSISTANT_URL."
    else
        echo "Failed to set Home Assistant URL to $HOME_ASSISTANT_URL. Please change it manually in /home/$USERNAME/.config/openbox/autostart."
        exit 1
    fi
}

# Function to enable I2C
enable_ic2() {
    echo "Enabling I2C..."
    if sudo raspi-config nonint do_i2c 0; then
        echo "I2C enabled."
    else
        echo "Failed to enable I2C. Please enable it with 'sudo raspi-config'."
    fi
}

# Function to enable GUI autologin
enable_gui_autologin() {
    echo "Enabling GUI autologin..."
    if sudo raspi-config nonint do_boot_behaviour B4; then
        echo "GUI autologin enabled."
    else
        echo "Failed to enable GUI autologin. Please enable it with 'sudo raspi-config'."
    fi
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
create_button_handler_script
create_button_handler_service
install_wifi_adapter_driver

echo -e "\n\nAlmost done! Please provide the following information to complete the setup:\n"
configure_hostname
configure_home_assistant_url
enable_ic2
enable_gui_autologin

# Fix permissions
echo "Fixing permissions on /home/$USERNAME..."
sudo chown -R $USERNAME:$USERNAME "/home/$USERNAME"

echo "Setup complete! You can now reboot the system."
