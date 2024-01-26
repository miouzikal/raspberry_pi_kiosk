
# Raspberry Pi Kiosk Mode Setup

Set up a Raspberry Pi to operate in Kiosk mode using the Chromium browser, specifically for Raspbian Lite (Bookworm 64-bit). This guide is intended for users who have basic knowledge of Raspberry Pi and Linux commands.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Flashing Raspbian Lite](#flashing-raspbian-lite)
3. [Setting Up Kiosk Mode](#setting-up-kiosk-mode)
4. [Post-Setup Instructions](#post-setup-instructions)
5. [Troubleshooting](#troubleshooting)

## Prerequisites
- Raspberry Pi (compatible with Raspbian Lite Bookworm 64-bit)
- SD card (with sufficient capacity for the Raspbian Lite image)
- A computer with an SD card reader
- A monitor, keyboard, and mouse for initial setup
- Stable internet connection

## Flashing Raspbian Lite
### 1. Download and Install Raspberry Pi Imager
- Download the Raspberry Pi Imager from the [Raspberry Pi website](https://www.raspberrypi.org/downloads/)
- Install and open the Imager on your computer

### 2. Flash Raspbian Lite with WiFi and User Configuration
- In the Raspberry Pi Imager, select "Choose OS" and then "Raspbian Lite (Bookworm 64-bit)"
- Select "Choose SD card" and choose your SD card
- Before flashing, click on the gear icon to open the advanced options
  - Set up WiFi by entering your WiFi credentials
  - Optionally change the default hostname
  - Under "Set username and password," set the username to `raspberry` and create a password
  - Enable SSH for remote access
- Click "SAVE" and then "WRITE" to flash the SD card

## Setting Up Kiosk Mode
### 1. Boot and Log Into Raspberry Pi
- Insert the flashed SD card into your Raspberry Pi
- Connect it to a monitor, keyboard, and power source
- Boot up and log in using the username `raspberry` and your password

### 2. Install Git and Clone Kiosk Repository
- Open the terminal and install Git:
  ```bash
  sudo apt-get update
  sudo apt-get install git -y
  ```
- Clone the Kiosk repository:
  ```bash
  git clone https://github.com/miouzikal/raspberry_pi_kiosk
  ```

### 3. Modify Kiosk Script with Home Assistant URL
- Change directory to the cloned repository's source folder:
  ```bash
  cd raspberry_pi_kiosk/src
  ```
- Use `sed` to replace the `___HOME_ASSISTANT_URL___` placeholder with your actual Home Assistant URL:
  ```bash
  sed -i 's|___HOME_ASSISTANT_URL___|https://your-home-assistant-url.com/desired_page|g' install_kiosk.sh
  ```

### 4. Run Kiosk Installation Script
- Ensure the script is executable and then run it:
  ```bash
  chmod +x install-kiosk.sh
  sudo ./install-kiosk.sh
  ```

### 5. Change Hostname, Enable GUI Autologin and IC2 Interface
- Execute `sudo raspi-config`
- Navigate to "System Options" > "Hostname"
  - Change the hostname to your desired name
- Navigate to "System Options" > "Boot / Auto Login"
  - Select "Desktop Autologin"
- Navigate to "Interface Options" > "I2C"
  - Select "Yes" to enable the I2C interface
- Exit raspi-config and reboot

## Post-Setup Instructions
Upon rebooting, the Raspberry Pi should launch into the GUI and open the Chromium browser in kiosk mode, displaying your specified Home Assistant UI.

## Troubleshooting
- Verify all steps were followed correctly
- Double-check WiFi credentials
- Confirm script permissions and execution
- Consult Raspberry Pi forums and documentation for specific issues

