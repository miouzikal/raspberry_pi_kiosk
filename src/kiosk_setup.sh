#!/usr/bin/env bash
#
# kiosk_setup.sh
#
# Merged Raspberry Pi kiosk setup script that uses:
#  - greetd + labwc (Wayland)
#  - Chromium for kiosk
#  - Optional per-parameter overclock prompts (with defaults)
#  - Optional Waveshare LCD config fot config.txt
#  - Realtek Wi-Fi driver if hardware present
#  - Silent boot, hostname change, I2C enable
#  - Installs custom wake_on_sound + button_handler scripts + services
#  - Creates labwc autostart with kiosk URL
#
# Tested on Raspberry Pi OS Bookworm (64-bit) with /boot/firmware/config.txt
# Run as a normal user with sudo privileges, not as root.

# ----- Spinner Function -----
spinner() {
    local pid=$1         # PID of the background process
    local message=$2     # Message to display with spinner
    local delay=0.1
    local frames=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
    tput civis           # Hide cursor
    local i=0
    while [ -d "/proc/$pid" ]; do
        local frame=${frames[$i]}
        printf "\r\e[35m%s\e[0m %s" "$frame" "$message"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep $delay
    done
    printf "\r\e[32m✔\e[0m %s\n" "$message"
    tput cnorm           # Restore cursor
}

# Simple function to prompt user for y/n
ask_user() {
    local prompt="$1"
    while true; do
        read -r -p "$prompt (y/n): " yn
        case $yn in
            [Yy]* ) return 0 ;;  # yes
            [Nn]* ) return 1 ;;  # no
            * ) echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}

# Function to set or update a config.txt parameter
# If the parameter exists, we update it; otherwise, we append.
set_config_param() {
    local param="$1"
    local value="$2"
    if grep -q "^$param=" "$CONFIG_TXT"; then
        # update
        sudo sed -i "s/^$param=.*/$param=$value/" "$CONFIG_TXT"
    else
        # append
        echo "$param=$value" | sudo tee -a "$CONFIG_TXT" >/dev/null
    fi
}

# ----- Basic Checks -----
if [ "$(id -u)" -eq 0 ]; then
  echo "This script should NOT be run as root. Please run as a normal user with sudo."
  exit 1
fi

CURRENT_USER="$(whoami)"
CONFIG_TXT="/boot/firmware/config.txt"
CMDLINE_TXT="/boot/firmware/cmdline.txt"

echo
echo "========== Raspberry Pi Wayland Kiosk Setup =========="
echo "This script will configure your Pi as a Wayland kiosk"
echo "with greetd + labwc + Chromium, plus additional Pi features."
echo "======================================================"
echo

# ---- 1. Update the package list? ----
if ask_user "Do you want to update the package list?"; then
    echo -e "\e[90mUpdating package list...\e[0m"
    sudo apt update > /dev/null 2>&1 &
    spinner $! "Updating package list..."
fi

# ---- 2. Upgrade installed packages? ----
echo
if ask_user "Do you want to upgrade installed packages?"; then
    echo -e "\e[90mUpgrading installed packages (this can take a while)...\e[0m"
    sudo apt upgrade -y > /dev/null 2>&1 &
    spinner $! "Upgrading packages..."
fi

# ---- 3. Install greetd + labwc + seatd + wlr-randr? ----
echo
if ask_user "Do you want to install greetd + labwc (Wayland) + seatd + wlr-randr?"; then
    echo -e "\e[90mInstalling greetd, labwc, seatd, and wlr-randr...\e[0m"
    sudo apt install --no-install-recommends -y greetd labwc seatd wlr-randr > /dev/null 2>&1 &
    spinner $! "Installing greetd + labwc..."
    
    echo -e "\e[90mEnabling greetd to start at boot...\e[0m"
    sudo systemctl enable greetd > /dev/null 2>&1 &
    spinner $! "Enabling greetd service..."
    
    # Set system to boot into graphical.target
    echo -e "\e[90mSetting default target to graphical...\e[0m"
    sudo systemctl set-default graphical.target > /dev/null 2>&1 &
    spinner $! "Setting system default to graphical.target..."
    
    # Create /etc/greetd/config.toml for autologin as CURRENT_USER
    echo -e "\e[90mConfiguring greetd for autologin as $CURRENT_USER...\e[0m"
    sudo mkdir -p /etc/greetd
    sudo bash -c "cat <<EOL > /etc/greetd/config.toml
[terminal]
vt = 7

[default_session]
# Launch labwc as your user (autologin).
command = \"/usr/bin/labwc\"
user = \"$CURRENT_USER\"
EOL"
    echo -e "\e[32m✔ greetd configured for autologin with labwc.\e[0m"
fi

# ---- 4. Install Chromium Browser? ----
echo
if ask_user "Do you want to install Chromium Browser for kiosk?"; then
    echo -e "\e[90mInstalling Chromium Browser...\e[0m"
    sudo apt install --no-install-recommends -y chromium-browser > /dev/null 2>&1 &
    spinner $! "Installing Chromium..."
fi

# ---- 5. Overclocking - ask individually for each parameter with defaults ----
echo
if ask_user "Do you want to configure overclock parameters?"; then
    # Over_voltage
    echo
    read -r -p "Enter over_voltage [default=6, blank to skip]: " OV
    if [ -n "$OV" ]; then
        OV="${OV:-6}"
        set_config_param "over_voltage" "$OV"
        echo -e "\e[32m✔ over_voltage set to $OV.\e[0m"
    else
        echo -e "\e[90mSkipping over_voltage.\e[0m"
    fi

    # arm_freq
    echo
    read -r -p "Enter arm_freq [default=2000, blank to skip]: " ARMF
    if [ -n "$ARMF" ]; then
        ARMF="${ARMF:-2000}"
        set_config_param "arm_freq" "$ARMF"
        echo -e "\e[32m✔ arm_freq set to $ARMF.\e[0m"
    else
        echo -e "\e[90mSkipping arm_freq.\e[0m"
    fi

    # gpu_freq
    echo
    read -r -p "Enter gpu_freq [default=750, blank to skip]: " GPUF
    if [ -n "$GPUF" ]; then
        GPUF="${GPUF:-750}"
        set_config_param "gpu_freq" "$GPUF"
        echo -e "\e[32m✔ gpu_freq set to $GPUF.\e[0m"
    else
        echo -e "\e[90mSkipping gpu_freq.\e[0m"
    fi

    # gpu_mem
    echo
    read -r -p "Enter gpu_mem [default=256, blank to skip]: " GPUM
    if [ -n "$GPUM" ]; then
        GPUM="${GPUM:-256}"
        set_config_param "gpu_mem" "$GPUM"
        echo -e "\e[32m✔ gpu_mem set to $GPUM.\e[0m"
    else
        echo -e "\e[90mSkipping gpu_mem.\e[0m"
    fi
else
    echo -e "\e[90mSkipping overclock configuration entirely.\e[0m"
fi

# ---- 6. Screen configuration (1280×800) in config.txt? ----
echo
if ask_user "Do you want to set the Waveshare 10.1DP-CAPLCD hdmi config in $CONFIG_TXT?"; then
    # We'll check individually instead of all-in-one, so if the user reruns we won't spam duplicates
    if ! grep -q "^hdmi_group=2" "$CONFIG_TXT"; then
        echo "hdmi_group=2" | sudo tee -a "$CONFIG_TXT" >/dev/null
    fi
    if ! grep -q "^hdmi_mode=87" "$CONFIG_TXT"; then
        echo "hdmi_mode=87" | sudo tee -a "$CONFIG_TXT" >/dev/null
    fi
    if ! grep -q "^hdmi_cvt 1280 800 60 6 0 0 0" "$CONFIG_TXT"; then
        echo "hdmi_cvt 1280 800 60 6 0 0 0" | sudo tee -a "$CONFIG_TXT" >/dev/null
    fi
    if ! grep -q "^hdmi_drive=1" "$CONFIG_TXT"; then
        echo "hdmi_drive=1" | sudo tee -a "$CONFIG_TXT" >/dev/null
    fi
    echo -e "\e[32m✔ 1280×800 screen config added/ensured.\e[0m"
else
    echo -e "\e[90mSkipping 1280×800 screen config.\e[0m"
fi

# ---- 7. Realtek USB Wi-Fi driver (2357:012d)? ----
echo
if lsusb | grep "2357:012d" >/dev/null; then
    if ask_user "Realtek USB Wi-Fi (2357:012d) detected. Install driver and disable onboard Wi-Fi?"; then
        echo -e "\e[90mCloning and installing Realtek 88x2bu driver...\e[0m"
        git clone https://github.com/morrownr/88x2bu-20210702.git /tmp/wifi-driver > /dev/null 2>&1
        cd /tmp/wifi-driver || {
            echo "Failed to enter driver directory."
            exit 1
        }
        sudo ./install-driver.sh NoPrompt > /dev/null 2>&1 &
        spinner $! "Installing Realtek 88x2bu driver..."
        
        # Check if conf file installed
        CONF_FILE="/etc/modprobe.d/88x2bu.conf"
        if [ ! -f "$CONF_FILE" ]; then
            echo -e "\e[31mFailed to install Wi-Fi adapter driver. Please check manually.\e[0m"
        else
            echo -e "\e[32mWi-Fi driver installed. Updating settings...\e[0m"
            # function to update or add an option
            update_or_add_option() {
                local option="$1"
                local value="$2"
                local pattern="^options 88x2bu .*${option}="
                if grep -qE "$pattern" "$CONF_FILE"; then
                    # update existing
                    sudo sed -i -r "s/($pattern)[^ ]*/\1$value/" "$CONF_FILE"
                else
                    # add
                    sudo sed -i "/^options 88x2bu /s/\$/ ${option}=${value}/" "$CONF_FILE"
                fi
            }
            update_or_add_option "rtw_switch_usb_mode" "1"
            update_or_add_option "rtw_country_code" "CA"
            update_or_add_option "rtw_power_mgnt" "0"
            
            # Disable onboard Wi-Fi
            if ! grep -q "^dtoverlay=disable-wifi" "$CONFIG_TXT"; then
                echo "dtoverlay=disable-wifi" | sudo tee -a "$CONFIG_TXT" > /dev/null
                echo -e "\e[32mOnboard Wi-Fi disabled.\e[0m"
            fi
        fi
        cd ~ || exit
        rm -rf /tmp/wifi-driver
    fi
else
    echo -e "\e[90mNo Realtek (2357:012d) USB Wi-Fi adapter detected. Skipping driver prompt.\e[0m"
fi

# ---- 8. Silent Boot? ----
echo
if ask_user "Do you want a silent boot (hide console messages)?"; then
    echo -e "\e[90mApplying silent boot settings...\e[0m"
    
    # Modify cmdline.txt: add quiet loglevel=0 logo.nologo vt.global_cursor_default=0
    if ! grep -q "quiet" "$CMDLINE_TXT"; then
        echo -e "\e[90mAdding 'quiet loglevel=0 logo.nologo vt.global_cursor_default=0' to $CMDLINE_TXT...\e[0m"
        sudo sed -i 's/$/ quiet loglevel=0 logo.nologo vt.global_cursor_default=0/' "$CMDLINE_TXT"
    else
        echo -e "\e[33m$CMDLINE_TXT already has 'quiet' or similar. Check manually if needed.\e[0m"
    fi
    
    # Modify config.txt: disable_splash=1
    if ! grep -q "^disable_splash=1" "$CONFIG_TXT"; then
        echo "disable_splash=1" | sudo tee -a "$CONFIG_TXT" > /dev/null
    else
        echo -e "\e[33m$CONFIG_TXT already has 'disable_splash=1'.\e[0m"
    fi
    
    echo -e "\e[32m✔ Silent boot configured.\e[0m"
fi

# ---- 9. Hostname Handling ----
echo
CURRENT_HOSTNAME="$(hostname)"
echo "Current hostname is: $CURRENT_HOSTNAME"
if ask_user "Do you want to change the hostname? (Otherwise keep '$CURRENT_HOSTNAME')"; then
    read -r -p "Enter a new hostname: " NEW_HOSTNAME
    if [ -n "$NEW_HOSTNAME" ]; then
        echo -e "\e[90mAttempting to set new hostname via raspi-config...\e[0m"
        sudo raspi-config nonint do_hostname "$NEW_HOSTNAME" || {
            echo "Failed to set hostname with raspi-config. Please do it manually."
        }
        echo -e "\e[32m✔ Hostname set to '$NEW_HOSTNAME'.\e[0m"
    else
        echo "No hostname provided, skipping."
    fi
else
    echo -e "\e[90mKeeping current hostname: $CURRENT_HOSTNAME.\e[0m"
fi

# ---- 10. Enable I2C? ----
echo
if ask_user "Do you want to enable I2C via raspi-config?"; then
    echo -e "\e[90mEnabling I2C...\e[0m"
    sudo raspi-config nonint do_i2c 0 || {
        echo -e "\e[31mFailed to enable I2C. Please enable manually.\e[0m"
    }
    echo -e "\e[32m✔ I2C enabled.\e[0m"
fi

# ---- 11. Install custom scripts (wake_on_sound, button_handler) ----
echo
if ask_user "Do you want to install your custom wake_on_sound and button handler scripts + services?"; then
    echo -e "\e[90mCopying custom scripts from ./scripts/... Please ensure they exist.\e[0m"

    # 11a. Audio Trigger Script
    AUDIO_TRIGGER_SCRIPT="/home/$CURRENT_USER/wake_on_sound.sh"
    AUDIO_TRIGGER_SERVICE="/etc/systemd/system/wake_on_sound.service"

    if [ -f ./scripts/wake_on_sound/wake_on_sound.sh ] && [ -f ./scripts/wake_on_sound/wake_on_sound.service ]; then
        sudo cp ./scripts/wake_on_sound/wake_on_sound.sh "$AUDIO_TRIGGER_SCRIPT"
        sudo chmod +x "$AUDIO_TRIGGER_SCRIPT"
        sudo chown "$CURRENT_USER:$CURRENT_USER" "$AUDIO_TRIGGER_SCRIPT"
        
        sudo cp ./scripts/wake_on_sound/wake_on_sound.service "$AUDIO_TRIGGER_SERVICE"
        
        # Enable + start
        sudo systemctl enable wake_on_sound.service
        sudo systemctl start wake_on_sound.service
        echo -e "\e[32m✔ wake_on_sound script + service installed.\e[0m"
    else
        echo -e "\e[31mwake_on_sound script/service not found in ./scripts/wake_on_sound/. Skipping.\e[0m"
    fi

    # 11b. Button Handler Script
    BUTTON_HANDLER_SCRIPT="/home/$CURRENT_USER/button_handler.py"
    BUTTON_HANDLER_SERVICE="/etc/systemd/system/button_handler.service"

    if [ -f ./scripts/button_handler/button_handler.py ] && [ -f ./scripts/button_handler/button_handler.service ]; then
        sudo cp ./scripts/button_handler/button_handler.py "$BUTTON_HANDLER_SCRIPT"
        sudo chown "$CURRENT_USER:$CURRENT_USER" "$BUTTON_HANDLER_SCRIPT"
        
        sudo cp ./scripts/button_handler/button_handler.service "$BUTTON_HANDLER_SERVICE"
        
        # Enable + start
        sudo systemctl enable button_handler.service
        sudo systemctl start button_handler.service
        echo -e "\e[32m✔ button_handler script + service installed.\e[0m"
    else
        echo -e "\e[31mbutton_handler script/service not found in ./scripts/button_handler/. Skipping.\e[0m"
    fi
fi

# ---- 12. Create labwc autostart (Chromium kiosk) with Home Assistant URL ----
echo
if command -v chromium-browser &> /dev/null; then
    read -r -p "Enter the URL to open in kiosk mode [default: https://homeassistant.local:8123 ]: " USER_URL
    USER_URL="${USER_URL:-https://homeassistant.local:8123}"

    # Ensure labwc config dir
    LABWC_DIR="/home/$CURRENT_USER/.config/labwc"
    mkdir -p "$LABWC_DIR"
    
    LABWC_AUTOSTART="$LABWC_DIR/autostart"
    if ! grep -q "chromium-browser" "$LABWC_AUTOSTART" 2>/dev/null; then
        echo -e "\e[90mAdding kiosk command to labwc autostart...\e[0m"
        cat <<EOL >> "$LABWC_AUTOSTART"
#!/usr/bin/env bash
# Launch Chromium in kiosk mode
chromium-browser --incognito --autoplay-policy=no-user-gesture-required --kiosk "$USER_URL" &
EOL
        chmod +x "$LABWC_AUTOSTART"
        echo -e "\e[32m✔ labwc autostart set to open $USER_URL in kiosk mode.\e[0m"
    else
        echo -e "\e[33mChromium entry already found in $LABWC_AUTOSTART. Not modifying.\e[0m"
    fi
else
    echo -e "\e[33mChromium not installed or not found. Skipping kiosk autostart.\e[0m"
fi

# ---- 13. Final apt clean ----
echo
echo -e "\e[90mCleaning up apt caches...\e[0m"
sudo apt clean > /dev/null 2>&1 &
spinner $! "Cleaning apt cache..."

# ---- All Done ----
echo -e "\n\e[32mAll done!\e[0m"
echo "You may want to reboot now to apply all changes (especially greetd, overclock, etc.)."
echo "Use: sudo reboot"
