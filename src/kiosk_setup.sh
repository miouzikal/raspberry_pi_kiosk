#!/usr/bin/env bash
#
# kiosk_setup.sh
#
# This script configures a Raspberry Pi to run Wayland kiosk mode using:
#  - greetd (autologin) + labwc (Wayland window manager)
#  - Chromium in kiosk mode
#  - Optionally custom overclock settings
#  - Optionally sets 1280×800 HDMI config in /boot/firmware/config.txt
#  - Optionally rotate display/touch via wlr-randr
#  - Optionally install Realtek USB Wi-Fi driver if hardware is detected
#  - Optionally silence the boot process
#  - Optionally change hostname
#  - Optionally enable I2C
#  - Optionally install custom scripts + services (wake_on_sound, button_handler)
#
# Tested on Raspberry Pi OS Bookworm (64-bit), which uses:
#   /boot/firmware/config.txt
#   /boot/firmware/cmdline.txt
#
# Usage:
#   1) chmod +x pi_wayland_kiosk_setup.sh
#   2) ./pi_wayland_kiosk_setup.sh
#   (Do NOT run as root, run as a normal user with sudo privileges.)

# ----- 1. Spinner Function (visual progress) -----
spinner() {
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
  tput cnorm  # show cursor again
}

# ----- 2. ask_user() for Yes/No prompts -----
ask_user() {
  local prompt="$1"
  while true; do
    read -r -p "$prompt (y/n): " yn
    case $yn in
      [Yy]* ) return 0 ;;  # "yes"
      [Nn]* ) return 1 ;;  # "no"
      * ) echo "Please answer yes (y) or no (n)." ;;
    esac
  done
}

# ----- 3. Set or update a config.txt parameter -----
# If param exists, update it; otherwise append it.
set_config_param() {
  local param="$1"
  local value="$2"
  if grep -q "^$param=" "$CONFIG_TXT_PATH"; then
    sudo sed -i "s/^$param=.*/$param=$value/" "$CONFIG_TXT_PATH"
  else
    echo "$param=$value" | sudo tee -a "$CONFIG_TXT_PATH" >/dev/null
  fi
}

# ----- 4. Basic Checks -----
if [ "$(id -u)" -eq 0 ]; then
  echo "This script should NOT be run as root. Please run as a normal user with sudo privileges."
  exit 1
fi

# Paths on Raspberry Pi OS Bookworm
CONFIG_TXT_PATH="/boot/firmware/config.txt"
CMDLINE_TXT_PATH="/boot/firmware/cmdline.txt"

current_user="$(whoami)"
current_hostname="$(hostname)"

echo
echo "===== Raspberry Pi Wayland Kiosk Setup ====="
echo "This script will configure your Pi as a Wayland kiosk"
echo "with greetd + labwc + Chromium, plus extra Pi features."
echo "============================================"
echo

# ------------------------------------------------------------------------------
# 1. Update + Upgrade
# ------------------------------------------------------------------------------
if ask_user "Do you want to update the package list?"; then
  echo -e "\e[90mUpdating package list...\e[0m"
  sudo apt update > /dev/null 2>&1 &
  spinner $! "Updating package list..."
fi

echo
if ask_user "Do you want to upgrade installed packages?"; then
  echo -e "\e[90mUpgrading installed packages (this can take a while)...\e[0m"
  sudo apt upgrade -y > /dev/null 2>&1 &
  spinner $! "Upgrading packages..."
fi

# ------------------------------------------------------------------------------
# 2. Install greetd + labwc + seatd + wlr-randr
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to install greetd + labwc + seatd + wlr-randr?"; then
  echo -e "\e[90mInstalling greetd, labwc, seatd, and wlr-randr...\e[0m"
  sudo apt install --no-install-recommends -y greetd labwc seatd wlr-randr > /dev/null 2>&1 &
  spinner $! "Installing greetd + labwc..."

  echo -e "\e[90mEnabling greetd to start at boot...\e[0m"
  sudo systemctl enable greetd > /dev/null 2>&1 &
  spinner $! "Enabling greetd service..."

  echo -e "\e[90mSetting default boot target to graphical...\e[0m"
  sudo systemctl set-default graphical.target > /dev/null 2>&1 &
  spinner $! "Setting system default to graphical.target..."

  # Configure greetd for autologin as $current_user
  echo -e "\e[90mConfiguring greetd for autologin as '$current_user'...\e[0m"
  sudo mkdir -p /etc/greetd
  sudo bash -c "cat <<EOL > /etc/greetd/config.toml
[terminal]
vt = 7

[default_session]
command = \"/usr/bin/labwc\"
user = \"$current_user\"
EOL"
  echo -e "\e[32m✔ greetd configured for autologin (Wayland, labwc).\e[0m"
fi

# ------------------------------------------------------------------------------
# 3. Chromium Browser for kiosk
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to install Chromium Browser for kiosk?"; then
  echo -e "\e[90mInstalling Chromium Browser...\e[0m"
  sudo apt install --no-install-recommends -y chromium-browser > /dev/null 2>&1 &
  spinner $! "Installing Chromium..."
fi

# ------------------------------------------------------------------------------
# 4. Overclocking
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to configure overclock parameters individually?"; then
  # Prompt for each parameter with defaults (blank to skip)
  echo
  read -r -p "Enter over_voltage [default=6, blank to skip]: " ov_in
  if [ -n "$ov_in" ]; then
    ov_in="${ov_in:-6}"
    set_config_param "over_voltage" "$ov_in"
    echo -e "\e[32m✔ over_voltage set to $ov_in.\e[0m"
  else
    echo -e "\e[90mSkipping over_voltage.\e[0m"
  fi

  echo
  read -r -p "Enter arm_freq [default=2000, blank to skip]: " arm_in
  if [ -n "$arm_in" ]; then
    arm_in="${arm_in:-2000}"
    set_config_param "arm_freq" "$arm_in"
    echo -e "\e[32m✔ arm_freq set to $arm_in.\e[0m"
  else
    echo -e "\e[90mSkipping arm_freq.\e[0m"
  fi

  echo
  read -r -p "Enter gpu_freq [default=750, blank to skip]: " gpu_in
  if [ -n "$gpu_in" ]; then
    gpu_in="${gpu_in:-750}"
    set_config_param "gpu_freq" "$gpu_in"
    echo -e "\e[32m✔ gpu_freq set to $gpu_in.\e[0m"
  else
    echo -e "\e[90mSkipping gpu_freq.\e[0m"
  fi

  echo
  read -r -p "Enter gpu_mem [default=256, blank to skip]: " gpum_in
  if [ -n "$gpum_in" ]; then
    gpum_in="${gpum_in:-256}"
    set_config_param "gpu_mem" "$gpum_in"
    echo -e "\e[32m✔ gpu_mem set to $gpum_in.\e[0m"
  else
    echo -e "\e[90mSkipping gpu_mem.\e[0m"
  fi
else
  echo -e "\e[90mSkipping overclock configuration.\e[0m"
fi

# ------------------------------------------------------------------------------
# 5. 1280×800 Screen config in config.txt
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to set 1280×800 HDMI config in $CONFIG_TXT_PATH?"; then
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
  echo -e "\e[32m✔ 1280×800 config added/ensured in config.txt.\e[0m"
else
  echo -e "\e[90mSkipping 1280×800 screen config.\e[0m"
fi

# ------------------------------------------------------------------------------
# 6. (Optional) Display + Touch Rotation via wlr-randr
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to rotate your display (and touch) with wlr-randr?"; then
  echo -e "\nWhich rotation do you want?"
  echo "1) normal (no rotation)"
  echo "2) 90 degrees (clockwise)"
  echo "3) 180 degrees"
  echo "4) 270 degrees (clockwise)"
  read -r -p "Enter a number [1-4, default=1]: " rot_choice
  rot_choice="${rot_choice:-1}"
  
  case "$rot_choice" in
    1) transform="normal";;
    2) transform="90";;
    3) transform="180";;
    4) transform="270";;
    *) transform="normal";;
  esac
  
  echo -e "\e[90mWe will add 'wlr-randr' commands in labwc autostart.\e[0m"
  echo -e "\e[94mNote:\e[0m This example uses output 'HDMI-A-1' for display + pointer/touch rotation.\n"
  echo "If your Pi uses a different output name, please manually adjust in your autostart."
  
  # We'll insert lines in labwc autostart near the kiosk section below.
  # The actual commands:
  #   wlr-randr --output HDMI-A-1 --transform $transform
  #   wlr-randr --output HID-xyz-??? --transform $transform  # for a touch device if recognized
  # The user might need to tweak the device name for touch. We'll just put a placeholder.
  
  rotation_script="# Rotate display output (adjust 'HDMI-A-1' if needed)
wlr-randr --output HDMI-A-1 --transform $transform

# If you have a touch device, also rotate it similarly (replace <TOUCH_OUTPUT>):
# wlr-randr --output <TOUCH_OUTPUT> --transform $transform
"
else
  rotation_script=""
fi

# ------------------------------------------------------------------------------
# 7. Realtek USB Wi-Fi (2357:012d)
# ------------------------------------------------------------------------------
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
    
    conf_file="/etc/modprobe.d/88x2bu.conf"
    if [ ! -f "$conf_file" ]; then
      echo -e "\e[31mFailed to install driver. Check logs or install manually.\e[0m"
    else
      echo -e "\e[32m✔ Wi-Fi driver installed. Updating module options.\e[0m"
      update_or_add_option() {
        local option="$1"
        local value="$2"
        local pattern="^options 88x2bu .*${option}="
        if grep -qE "$pattern" "$conf_file"; then
          sudo sed -i -r "s/($pattern)[^ ]*/\1$value/" "$conf_file"
        else
          sudo sed -i "/^options 88x2bu /s/\$/ ${option}=${value}/" "$conf_file"
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
  echo -e "\e[90mNo Realtek (2357:012d) USB Wi-Fi adapter detected. Skipping driver install.\e[0m"
fi

# ------------------------------------------------------------------------------
# 8. Silent Boot
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want a silent boot (hide console messages)?"; then
  echo -e "\e[90mApplying silent boot settings...\e[0m"
  
  if ! grep -q "quiet" "$CMDLINE_TXT_PATH"; then
    echo -e "\e[90mAdding 'quiet loglevel=0 logo.nologo vt.global_cursor_default=0' to $CMDLINE_TXT_PATH...\e[0m"
    sudo sed -i 's/$/ quiet loglevel=0 logo.nologo vt.global_cursor_default=0/' "$CMDLINE_TXT_PATH"
  else
    echo -e "\e[33m$CMDLINE_TXT_PATH already has 'quiet'. Check manually if needed.\e[0m"
  fi
  
  if ! grep -q "^disable_splash=1" "$CONFIG_TXT_PATH"; then
    echo "disable_splash=1" | sudo tee -a "$CONFIG_TXT_PATH" > /dev/null
  else
    echo -e "\e[33m$CONFIG_TXT_PATH already has 'disable_splash=1'.\e[0m"
  fi
  
  echo -e "\e[32m✔ Silent boot configured.\e[0m"
fi

# ------------------------------------------------------------------------------
# 9. Hostname
# ------------------------------------------------------------------------------
echo
echo "Current hostname is: $current_hostname"
if ask_user "Do you want to change the hostname? (otherwise keep '$current_hostname')"; then
  read -r -p "Enter a new hostname: " new_hostname
  if [ -n "$new_hostname" ]; then
    echo -e "\e[90mAttempting to set new hostname via raspi-config...\e[0m"
    sudo raspi-config nonint do_hostname "$new_hostname" || {
      echo "Failed to set hostname with raspi-config. Please do it manually."
    }
    echo -e "\e[32m✔ Hostname set to '$new_hostname'.\e[0m"
  else
    echo "No hostname provided, skipping."
  fi
else
  echo -e "\e[90mKeeping current hostname: $current_hostname.\e[0m"
fi

# ------------------------------------------------------------------------------
# 10. I2C
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to enable I2C via raspi-config?"; then
  echo -e "\e[90mEnabling I2C...\e[0m"
  sudo raspi-config nonint do_i2c 0 || {
    echo -e "\e[31mFailed to enable I2C. Please enable manually.\e[0m"
  }
  echo -e "\e[32m✔ I2C enabled.\e[0m"
fi

# ------------------------------------------------------------------------------
# 11. Install custom scripts (wake_on_sound)  -- separate
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to install your custom wake_on_sound script + service?"; then
  audio_trigger_script="/home/$current_user/wake_on_sound.sh"
  audio_trigger_service="/etc/systemd/system/wake_on_sound.service"

  echo -e "\e[90mCopying from ./scripts/wake_on_sound/... Please ensure files exist.\e[0m"
  if [ -f ./scripts/wake_on_sound/wake_on_sound.sh ] && [ -f ./scripts/wake_on_sound/wake_on_sound.service ]; then
    sudo cp ./scripts/wake_on_sound/wake_on_sound.sh "$audio_trigger_script"
    sudo chmod +x "$audio_trigger_script"
    sudo chown "$current_user:$current_user" "$audio_trigger_script"
    
    sudo cp ./scripts/wake_on_sound/wake_on_sound.service "$audio_trigger_service"
    sudo systemctl enable wake_on_sound.service
    sudo systemctl start wake_on_sound.service
    echo -e "\e[32m✔ wake_on_sound script + service installed.\e[0m"
  else
    echo -e "\e[31mCould not find wake_on_sound.sh or .service in ./scripts/wake_on_sound/. Skipping.\e[0m"
  fi
fi

# ------------------------------------------------------------------------------
# 12. Install custom scripts (button_handler) -- separate
# ------------------------------------------------------------------------------
echo
if ask_user "Do you want to install your custom button_handler script + service?"; then
  button_handler_script="/home/$current_user/button_handler.py"
  button_handler_service="/etc/systemd/system/button_handler.service"

  echo -e "\e[90mCopying from ./scripts/button_handler/... Please ensure files exist.\e[0m"
  if [ -f ./scripts/button_handler/button_handler.py ] && [ -f ./scripts/button_handler/button_handler.service ]; then
    sudo cp ./scripts/button_handler/button_handler.py "$button_handler_script"
    sudo chown "$current_user:$current_user" "$button_handler_script"

    sudo cp ./scripts/button_handler/button_handler.service "$button_handler_service"
    sudo systemctl enable button_handler.service
    sudo systemctl start button_handler.service
    echo -e "\e[32m✔ button_handler script + service installed.\e[0m"
  else
    echo -e "\e[31mCould not find button_handler.py or .service in ./scripts/button_handler/. Skipping.\e[0m"
  fi
fi

# ------------------------------------------------------------------------------
# 13. Create labwc autostart (Chromium kiosk) + optional rotation
# ------------------------------------------------------------------------------
echo
if command -v chromium-browser &> /dev/null; then
  read -r -p "Enter the kiosk URL [default: https://homeassistant.local:8123 ]: " kiosk_url
  kiosk_url="${kiosk_url:-https://homeassistant.local:8123}"

  labwc_dir="/home/$current_user/.config/labwc"
  mkdir -p "$labwc_dir"

  labwc_autostart="$labwc_dir/autostart"

  # Insert kiosk lines only if not present
  if ! grep -q "chromium-browser" "$labwc_autostart" 2>/dev/null; then
    echo -e "\e[90mAdding kiosk command to labwc autostart...\e[0m"

    # We integrate the rotation_script (if defined) plus kiosk command
    # "rotation_script" was set earlier if user said yes to rotation
    cat <<EOL >> "$labwc_autostart"
#!/usr/bin/env bash
# Labwc Autostart file

${rotation_script}

# Launch Chromium in kiosk mode
chromium-browser --incognito --force-dark-mode --noerrdialogs --disable-infobars --disable-pinch --remote-debugging-port=9222 --check-for-update-interval=31536000 --enable-features=OverlayScrollbar --disable-restore-session-state --kiosk "$kiosk_url" &
EOL

    chmod +x "$labwc_autostart"
    echo -e "\e[32m✔ labwc autostart set to open '$kiosk_url' in kiosk mode.\e[0m"
  else
    echo -e "\e[33mChromium entry already found in $labwc_autostart. Not modifying.\e[0m"
  fi
else
  echo -e "\e[33mChromium not installed or not found. Skipping kiosk autostart.\e[0m"
fi

# ------------------------------------------------------------------------------
# 14. Clean apt cache
# ------------------------------------------------------------------------------
echo
echo -e "\e[90mCleaning apt caches...\e[0m"
sudo apt clean > /dev/null 2>&1 &
spinner $! "Cleaning apt cache..."

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
echo -e "\n\e[32mAll done!\e[0m"
echo "You may want to reboot now to apply all changes (especially greetd, overclock, etc.)."
echo "Use: sudo reboot"
