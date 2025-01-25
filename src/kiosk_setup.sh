#!/usr/bin/env bash
#
# kiosk_setup.sh
#
# This script configures a Raspberry Pi to run in Wayland kiosk mode with greetd, labwc, 
# and Chromium. It also provides optional Pi-specific configurations such as overclocking,
# 1280×800 HDMI settings, display/touch rotation, Realtek USB Wi-Fi driver installation,
# silent boot, hostname changes, I2C enabling, and custom scripts (wake_on_sound, button_handler).
#
# A new feature is the udev rule for touchscreen input rotation. If you choose a rotation,
# you can automatically apply a LIBINPUT_CALIBRATION_MATRIX to match your display orientation.
#
# Usage:
#   1) chmod +x kiosk_setup.sh
#   2) ./kiosk_setup.sh
#   (Do NOT run as root, run as a normal user with sudo privileges.)
#

# -------------------------------
# SPINNER (VISUAL PROGRESS INDICATOR)
# -------------------------------
spinner() {
  # Displays a rotating spinner for background commands
  local pid=$1
  local message=$2
  local delay=0.1
  local frames=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )

  tput civis  # hide cursor
  local i=0
  while [ -d "/proc/$pid" ]; do
    local frame=${frames[$i]}
    printf "\r\e[35m%s\e[0m %s" "$frame" "$message"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep $delay
  done
  printf "\r\e[32m✔\e[0m %s\n" "$message"
  tput cnorm  # show cursor
}


# -------------------------------
# YES/NO PROMPT
# -------------------------------
ask_user() {
  # Offers the user a yes/no prompt and returns 0 for Yes, 1 for No
  local prompt="$1"
  while true; do
    read -r -p "$prompt (y/n): " yn
    case $yn in
      [Yy]* ) return 0 ;;  # "Yes"
      [Nn]* ) return 1 ;;  # "No"
      * ) echo "Please answer yes (y) or no (n)." ;;
    esac
  done
}


# -------------------------------
# CONFIG.TXT PARAMETER SETTER
# -------------------------------
set_config_param() {
  # Sets or updates a parameter in the Pi's config.txt
  local param="$1"
  local value="$2"
  if grep -q "^$param=" "$CONFIG_TXT_PATH"; then
    sudo sed -i "s/^$param=.*/$param=$value/" "$CONFIG_TXT_PATH"
  else
    echo "$param=$value" | sudo tee -a "$CONFIG_TXT_PATH" >/dev/null
  fi
}


# -------------------------------
# SCRIPT START: BASIC CHECK
# -------------------------------
if [ "$(id -u)" -eq 0 ]; then
  echo -e "\e[31mERROR:\e[0m This script should NOT be run as root. Please run as a normal user with sudo privileges."
  exit 1
fi

CONFIG_TXT_PATH="/boot/firmware/config.txt"
CMDLINE_TXT_PATH="/boot/firmware/cmdline.txt"

current_user="$(whoami)"
current_hostname="$(hostname)"

echo
echo "==========================================================="
echo "     RASPBERRY PI WAYLAND KIOSK SETUP SCRIPT               "
echo "==========================================================="
echo "This script will help you configure your Raspberry Pi with:"
echo "  • greetd + labwc (Wayland) + autologin"
echo "  • Chromium in kiosk mode"
echo "  • Optional Pi tweaks (overclock, 1280×800 HDMI, rotate"
echo "    display/touch, Realtek driver, silent boot, etc.)"
echo "  • Custom scripts/services"
echo
echo "IMPORTANT: Only proceed if you have tested this on Raspberry Pi OS Bookworm."
echo "           Some settings may differ on older or custom OS versions."
echo "==========================================================="
echo

# ------------------------------------------------------------------------------
# 1. UPDATE & UPGRADE PACKAGES
# ------------------------------------------------------------------------------
echo "STEP 1: System Update & Upgrade"
if ask_user "Update the package list with 'sudo apt update' now?"; then
  echo -e "\e[90mUpdating package list...\e[0m"
  sudo apt update > /dev/null 2>&1 &
  spinner $! "Updating package list..."
fi

echo
if ask_user "Upgrade installed packages with 'sudo apt upgrade -y' now?"; then
  echo -e "\e[90mUpgrading installed packages (this can take a while)...\e[0m"
  sudo apt upgrade -y > /dev/null 2>&1 &
  spinner $! "Upgrading packages..."
fi

# ------------------------------------------------------------------------------
# 2. INSTALL GREETD + LABWC + SEATD + WLR-RANDR
# ------------------------------------------------------------------------------
echo
echo "STEP 2: Wayland Components (greetd, labwc, seatd, wlr-randr)"
if ask_user "Install greetd, labwc, seatd, and wlr-randr now?"; then
  echo -e "\e[90mInstalling greetd, labwc, seatd, and wlr-randr...\e[0m"
  sudo apt install --no-install-recommends -y greetd labwc seatd wlr-randr > /dev/null 2>&1 &
  spinner $! "Installing greetd + labwc..."

  echo -e "\e[90mEnabling greetd to start at boot...\e[0m"
  sudo systemctl enable greetd > /dev/null 2>&1 &
  spinner $! "Enabling greetd service..."

  echo -e "\e[90mSetting default boot target to graphical...\e[0m"
  sudo systemctl set-default graphical.target > /dev/null 2>&1 &
  spinner $! "Setting system default to graphical.target..."

  # Configure greetd for autologin as current_user
  echo -e "\e[90mConfiguring greetd for autologin (Wayland, labwc) as '$current_user'...\e[0m"
  sudo mkdir -p /etc/greetd
  sudo bash -c "cat <<EOL > /etc/greetd/config.toml
[terminal]
vt = 7

[default_session]
command = \"/usr/bin/labwc\"
user = \"$current_user\"
EOL"
  echo -e "\e[32m✔ greetd is configured for autologin.\e[0m"
fi

# ------------------------------------------------------------------------------
# 3. INSTALL CHROMIUM BROWSER FOR KIOSK
# ------------------------------------------------------------------------------
echo
echo "STEP 3: Chromium Browser for Kiosk"
if ask_user "Install Chromium Browser now?"; then
  echo -e "\e[90mInstalling Chromium Browser...\e[0m"
  sudo apt install --no-install-recommends -y chromium-browser > /dev/null 2>&1 &
  spinner $! "Installing Chromium..."
fi

# ------------------------------------------------------------------------------
# 4. OVERCLOCKING SETTINGS
# ------------------------------------------------------------------------------
echo
echo "STEP 4: Overclocking (OPTIONAL)"
if ask_user "Would you like to set overclock parameters individually?"; then
  echo -e "\nYou can set each parameter or press Enter to skip."

  read -r -p "• over_voltage [recommended=6, skip by leaving blank]: " ov_in
  if [ -n "$ov_in" ]; then
    set_config_param "over_voltage" "$ov_in"
    echo -e "\e[32m✔ over_voltage set to $ov_in.\e[0m"
  else
    echo -e "\e[90mSkipping over_voltage.\e[0m"
  fi

  read -r -p "• arm_freq [recommended=2000, skip by leaving blank]: " arm_in
  if [ -n "$arm_in" ]; then
    set_config_param "arm_freq" "$arm_in"
    echo -e "\e[32m✔ arm_freq set to $arm_in.\e[0m"
  else
    echo -e "\e[90mSkipping arm_freq.\e[0m"
  fi

  read -r -p "• gpu_freq [recommended=750, skip by leaving blank]: " gpu_in
  if [ -n "$gpu_in" ]; then
    set_config_param "gpu_freq" "$gpu_in"
    echo -e "\e[32m✔ gpu_freq set to $gpu_in.\e[0m"
  else
    echo -e "\e[90mSkipping gpu_freq.\e[0m"
  fi

  read -r -p "• gpu_mem [recommended=256, skip by leaving blank]: " gpum_in
  if [ -n "$gpum_in" ]; then
    set_config_param "gpu_mem" "$gpum_in"
    echo -e "\e[32m✔ gpu_mem set to $gpum_in.\e[0m"
  else
    echo -e "\e[90mSkipping gpu_mem.\e[0m"
  fi
else
  echo -e "\e[90mSkipping overclock configuration.\e[0m"
fi

# ------------------------------------------------------------------------------
# 5. SET 1280×800 HDMI CONFIG
# ------------------------------------------------------------------------------
echo
echo "STEP 5: 1280×800 HDMI Configuration"
if ask_user "Configure 1280×800 HDMI in '$CONFIG_TXT_PATH'?"; then
  if ! grep -q "^hdmi_group=2" "$CONFIG_TXT_PATH"; then
    echo "hdmi_group=2" | sudo tee -a "$CONFIG_TXT_PATH" >/dev/null
  fi
  if ! grep -q "^hdmi_mode=87" "$CONFIG_TXT_PATH"; then
    echo "hdmi_mode=87" | sudo tee -a "$CONFIG_TXT_PATH" >/dev/null
  fi
  if ! grep -q "^hdmi_cvt 1280 800 60 6 0 0 0" "$CONFIG_TXT_PATH"; then
    echo "hdmi_cvt 1280 800 60 6 0 0 0" | sudo tee -a "$CONFIG_TXT_PATH" >/dev/null
  fi
  if ! grep -q "^hdmi_drive=1" "$CONFIG_TXT_PATH"; then
    echo "hdmi_drive=1" | sudo tee -a "$CONFIG_TXT_PATH" >/dev/null
  fi
  echo -e "\e[32m✔ 1280×800 config added to $CONFIG_TXT_PATH.\e[0m"
else
  echo -e "\e[90mSkipping 1280×800 screen config.\e[0m"
fi

# ------------------------------------------------------------------------------
# 6. DISPLAY & TOUCH ROTATION (wlr-randr) AND UDEV RULE
# ------------------------------------------------------------------------------
rotation_script=""
touch_transform_matrix="1 0 0 0 1 0"  # Default is normal
echo
echo "STEP 6: Display & Touch Rotation"
if ask_user "Would you like to rotate your display with wlr-randr?"; then
  echo -e "\nChoose a rotation angle:"
  echo "  1) normal (no rotation)"
  echo "  2) 90 degrees clockwise"
  echo "  3) 180 degrees"
  echo "  4) 270 degrees clockwise"
  read -r -p "Enter a number [1-4, default=1]: " rot_choice
  rot_choice="${rot_choice:-1}"

  case "$rot_choice" in
    1)
      transform="normal"
      touch_transform_matrix="1 0 0 0 1 0"
      ;;
    2)
      transform="90"
      # Touch rotation: 90° => x -> y, y -> -x
      #   LIBINPUT_CALIBRATION_MATRIX format: [ a b c; d e f ]
      #   So for 90 deg: [ 0 -1 1; 1 0 0 ]
      touch_transform_matrix="0 -1 1 1 0 0"
      ;;
    3)
      transform="180"
      # 180° => x -> -x+1, y -> -y+1
      #   matrix: [ -1 0 1; 0 -1 1 ]
      touch_transform_matrix="-1 0 1 0 -1 1"
      ;;
    4)
      transform="270"
      # 270° => x -> -y+1, y -> x
      #   matrix: [ 0 1 0; -1 0 1 ]
      touch_transform_matrix="0 1 0 -1 0 1"
      ;;
    *)
      transform="normal"
      touch_transform_matrix="1 0 0 0 1 0"
      ;;
  esac

  # For display rotation, we'll add lines to labwc autostart.
  rotation_script="# Rotate display output (adjust 'HDMI-A-1' if needed)
wlr-randr --output HDMI-A-1 --transform $transform

# (Optional) If you have another output name for touch, you can rotate it similarly:
# wlr-randr --output <TOUCH_OUTPUT> --transform $transform
"
  echo -e "\e[94mNote:\e[0m This uses 'HDMI-A-1' for the display. Adjust for your actual output."
fi

# Ask if we also want to create a udev rule for touch input rotation
echo
if [ "$rotation_script" != "" ]; then
  if ask_user "Create a udev rule to apply the same rotation to a touchscreen device?"; then
    echo -e "\nPlease specify the name of your touchscreen device as recognized by the system."
    echo "You can find this by running 'sudo libinput list-devices' or 'xinput list' (on X)."
    echo "Device 'Name' might be something like 'ILITEK Multi-Touch' or 'FT5406 memory based driver'."
    read -r -p "Enter EXACT device name (or leave blank to skip): " touch_device_name

    if [ -n "$touch_device_name" ]; then
      echo -e "\e[90mCreating /etc/udev/rules.d/99-touch-rotation.rules...\e[0m"
      sudo bash -c "cat <<EOF > /etc/udev/rules.d/99-touch-rotation.rules
ACTION==\"add|change\", KERNEL==\"event*\", SUBSYSTEM==\"input\",
  ATTRS{name}==\"$touch_device_name\",
  ENV{LIBINPUT_CALIBRATION_MATRIX}=\"$touch_transform_matrix\"
EOF"

      echo -e "\e[90mReloading udev rules...\e[0m"
      sudo udevadm control --reload-rules && sudo udevadm trigger
      echo -e "\e[32m✔ Created a udev rule for $touch_device_name with rotation transform.\e[0m"
    else
      echo -e "\e[90mNo device name entered; skipping udev rule.\e[0m"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 7. REALTEK USB WI-FI DRIVER INSTALL (2357:012D)
# ------------------------------------------------------------------------------
echo
echo "STEP 7: Realtek USB Wi-Fi Driver (88x2bu)"
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

    # Check if installed
    driver_conf="/etc/modprobe.d/88x2bu.conf"
    if [ ! -f "$driver_conf" ]; then
      echo -e "\e[31mFailed to install driver. Check logs or install manually.\e[0m"
    else
      echo -e "\e[32m✔ Wi-Fi driver installed. Updating module options.\e[0m"

      # Helper to update options
      update_or_add_option() {
        local option="$1"
        local value="$2"
        local pattern="^options 88x2bu .*${option}="
        if grep -qE "$pattern" "$driver_conf"; then
          sudo sed -i -r "s/($pattern)[^ ]*/\1$value/" "$driver_conf"
        else
          sudo sed -i "/^options 88x2bu /s/\$/ ${option}=${value}/" "$driver_conf"
        fi
      }

      update_or_add_option "rtw_switch_usb_mode" "1"
      update_or_add_option "rtw_country_code" "CA"
      update_or_add_option "rtw_power_mgnt" "0"

      # Disable onboard Wi-Fi
      if ! grep -q "^dtoverlay=disable-wifi" "$CONFIG_TXT_PATH"; then
        echo "dtoverlay=disable-wifi" | sudo tee -a "$CONFIG_TXT_PATH" > /dev/null
        echo -e "\e[32m✔ Onboard Wi-Fi disabled.\e[0m"
      fi
    fi

    cd ~
    rm -rf /tmp/wifi-driver
  fi
else
  echo -e "\e[90mNo Realtek (2357:012d) USB Wi-Fi adapter detected; skipping driver installation.\e[0m"
fi

# ------------------------------------------------------------------------------
# 8. SILENT BOOT
# ------------------------------------------------------------------------------
echo
echo "STEP 8: Silent Boot"
if ask_user "Hide console messages at boot by enabling 'silent boot'?"; then
  echo -e "\e[90mApplying silent boot settings...\e[0m"
  # Add quiet, loglevel=0, etc. to cmdline.txt
  if ! grep -q "quiet" "$CMDLINE_TXT_PATH"; then
    sudo sed -i 's/$/ quiet loglevel=0 logo.nologo vt.global_cursor_default=0/' "$CMDLINE_TXT_PATH"
  else
    echo -e "\e[33m$CMDLINE_TXT_PATH already has 'quiet' or similar; skipping.\e[0m"
  fi

  # disable_splash=1 in config.txt
  if ! grep -q "^disable_splash=1" "$CONFIG_TXT_PATH"; then
    echo "disable_splash=1" | sudo tee -a "$CONFIG_TXT_PATH" > /dev/null
  else
    echo -e "\e[33m$CONFIG_TXT_PATH already has 'disable_splash=1'; skipping.\e[0m"
  fi

  echo -e "\e[32m✔ Silent boot configured.\e[0m"
fi

# ------------------------------------------------------------------------------
# 9. CHANGE HOSTNAME
# ------------------------------------------------------------------------------
echo
echo "STEP 9: Hostname Change"
echo "Current hostname is: $current_hostname"
if ask_user "Change the hostname from '$current_hostname'?"; then
  read -r -p "Enter a new hostname: " new_hostname
  if [ -n "$new_hostname" ]; then
    echo -e "\e[90mAttempting to set new hostname via raspi-config...\e[0m"
    sudo raspi-config nonint do_hostname "$new_hostname" || {
      echo -e "\e[31mFailed to set hostname. Please do it manually.\e[0m"
    }
    echo -e "\e[32m✔ Hostname set to '$new_hostname'.\e[0m"
  else
    echo -e "\e[90mNo hostname provided; skipping.\e[0m"
  fi
else
  echo -e "\e[90mKeeping current hostname: '$current_hostname'.\e[0m"
fi

# ------------------------------------------------------------------------------
# 10. ENABLE I2C
# ------------------------------------------------------------------------------
echo
echo "STEP 10: Enable I2C"
if ask_user "Enable I2C via raspi-config?"; then
  echo -e "\e[90mEnabling I2C...\e[0m"
  sudo raspi-config nonint do_i2c 0 || {
    echo -e "\e[31mFailed to enable I2C. Please enable manually.\e[0m"
  }
  echo -e "\e[32m✔ I2C enabled.\e[0m"
fi

# ------------------------------------------------------------------------------
# 11. INSTALL CUSTOM SCRIPTS (wake_on_sound)
# ------------------------------------------------------------------------------
echo
echo "STEP 11: Custom Scripts (wake_on_sound)"
if ask_user "Install your custom wake_on_sound script + service?"; then
  audio_trigger_script="/home/$current_user/wake_on_sound.sh"
  audio_trigger_service="/etc/systemd/system/wake_on_sound.service"

  echo -e "\e[90mCopying from ./scripts/wake_on_sound/... (ensure files exist)\e[0m"
  if [ -f ./scripts/wake_on_sound/wake_on_sound.sh ] && [ -f ./scripts/wake_on_sound/wake_on_sound.service ]; then
    sudo cp ./scripts/wake_on_sound/wake_on_sound.sh "$audio_trigger_script"
    sudo chmod +x "$audio_trigger_script"
    sudo chown "$current_user:$current_user" "$audio_trigger_script"

    sudo cp ./scripts/wake_on_sound/wake_on_sound.service "$audio_trigger_service"
    sudo systemctl enable wake_on_sound.service
    sudo systemctl start wake_on_sound.service
    echo -e "\e[32m✔ wake_on_sound script + service installed.\e[0m"
  else
    echo -e "\e[31mFiles missing in ./scripts/wake_on_sound/. Skipping.\e[0m"
  fi
fi

# ------------------------------------------------------------------------------
# 12. INSTALL CUSTOM SCRIPTS (button_handler)
# ------------------------------------------------------------------------------
echo
echo "STEP 12: Custom Scripts (button_handler)"
if ask_user "Install your custom button_handler script + service?"; then
  button_handler_script="/home/$current_user/button_handler.py"
  button_handler_service="/etc/systemd/system/button_handler.service"

  echo -e "\e[90mCopying from ./scripts/button_handler/... (ensure files exist)\e[0m"
  if [ -f ./scripts/button_handler/button_handler.py ] && [ -f ./scripts/button_handler/button_handler.service ]; then
    sudo cp ./scripts/button_handler/button_handler.py "$button_handler_script"
    sudo chown "$current_user:$current_user" "$button_handler_script"

    sudo cp ./scripts/button_handler/button_handler.service "$button_handler_service"
    sudo systemctl enable button_handler.service
    sudo systemctl start button_handler.service
    echo -e "\e[32m✔ button_handler script + service installed.\e[0m"
  else
    echo -e "\e[31mFiles missing in ./scripts/button_handler/. Skipping.\e[0m"
  fi
fi

# ------------------------------------------------------------------------------
# 13. CREATE LABWC AUTOSTART (CHROMIUM KIOSK) + OPTIONAL ROTATION
# ------------------------------------------------------------------------------
echo
echo "STEP 13: Configure labwc Autostart with Chromium Kiosk"
if command -v chromium-browser &> /dev/null; then
  read -r -p "Enter the kiosk URL [default: https://homeassistant.local:8123 ]: " kiosk_url
  kiosk_url="${kiosk_url:-https://homeassistant.local:8123}"

  labwc_dir="/home/$current_user/.config/labwc"
  mkdir -p "$labwc_dir"
  labwc_autostart="$labwc_dir/autostart"

  # Only insert kiosk lines if not present
  if ! grep -q "chromium-browser" "$labwc_autostart" 2>/dev/null; then
    echo -e "\e[90mAdding kiosk command to $labwc_autostart...\e[0m"

    cat <<EOL >> "$labwc_autostart"
#!/usr/bin/env bash
# Labwc Autostart file

${rotation_script}

# Launch Chromium in kiosk mode
chromium-browser --incognito \
  --force-dark-mode \
  --noerrdialogs \
  --disable-infobars \
  --disable-pinch \
  --remote-debugging-port=9222 \
  --check-for-update-interval=31536000 \
  --enable-features=OverlayScrollbar \
  --disable-restore-session-state \
  --kiosk "$kiosk_url" &
EOL

    chmod +x "$labwc_autostart"
    echo -e "\e[32m✔ labwc autostart set to open '$kiosk_url' in kiosk mode.\e[0m"
  else
    echo -e "\e[33mChromium kiosk entry already found in $labwc_autostart; not modifying.\e[0m"
  fi
else
  echo -e "\e[33mChromium is not installed or was not found. Skipping kiosk autostart.\e[0m"
fi

# ------------------------------------------------------------------------------
# 14. CLEAN APT CACHE
# ------------------------------------------------------------------------------
echo
echo "STEP 14: Clean APT Cache"
echo -e "\e[90mCleaning apt caches...\e[0m"
sudo apt clean > /dev/null 2>&1 &
spinner $! "Cleaning apt cache..."

# ------------------------------------------------------------------------------
# FINISHED
# ------------------------------------------------------------------------------
echo
echo -e "\e[32mAll done!\e[0m"
echo "You may want to reboot now to apply all changes (especially greetd, overclock, etc.)."
echo -e "Use: \e[96msudo reboot\e[0m"
