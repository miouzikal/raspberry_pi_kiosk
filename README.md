
# Raspberry Pi Kiosk Mode Setup

This guide is a personal project to create a Raspberry Pi 4B kiosk for my Home Assistant UI. It is intended to be a reference for myself and others who may be interested in doing the same.
The hardware i used for this project are as follows:
- Raspberry Pi 4B 4GB
- [64GB Raddor SD Card](https://www.amazon.ca/-/fr/dp/B0CD2SR4XM?ref=ppx_yo2ov_dt_b_product_details&th=1)
- [WaveShare 10.1DP-CAPLCD screen](https://www.amazon.ca/-/fr/dp/B0BPM9VTY6?ref=ppx_yo2ov_dt_b_product_details&th=1)
- [Copper Heatsink](https://www.amazon.ca/-/fr/Dissipateur-thermique-acrylique-Raspberry-d%C3%A9paisseur/dp/B0CP5SLMLM/ref=sr_1_14?__mk_fr_CA=%C3%85M%C3%85%C5%BD%C3%95%C3%91&crid=1QVUH3VEBV6A3&keywords=copper+raspberry+pi+heatsink&qid=1706462908&s=electronics&sprefix=copper+raspberry+pi+heatsink%2Celectronics%2C84&sr=1-14)
- [TP-Link Archer T3U](https://www.amazon.ca/dp/B07P6N2TZH?psc=1&ref=ppx_yo2ov_dt_b_product_details) (copper heatsink interferes with onboard WiFi)
- [USB Microphone](https://www.amazon.ca/-/fr/gp/product/B01KLRBHGM/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&psc=1) (for wake on sound)

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
  git clone https://github.com/miouzikal/raspberry_pi_kiosk ~/raspberry_pi_kiosk
  ```

### 3. Run Kiosk Installation Script
- Change directory to the cloned repository and run the installation script:
  ```bash
  cd ~/raspberry_pi_kiosk/src
  chmod +x install-kiosk.sh
  sudo ./install-kiosk.sh
  ```

### 4. Before Rebooting, Enter the Following Information when Prompted:
- New hostname of the Raspberry Pi
- Home Assistant URL (Chromium will open to this URL in kiosk mode)

### 5. Automatic Setup
- The script will also enable I2C for brightness control and GUI autologin before prompting to reboot

## Post-Setup Instructions
Upon rebooting, the Raspberry Pi should launch into the GUI and open the Chromium browser in kiosk mode, displaying your specified Home Assistant UI.

## Troubleshooting
- Verify all steps were followed correctly
- Double-check WiFi credentials and Home Assistant URL
- Confirm script permissions and execution
- Consult Raspberry Pi forums and documentation for specific issues
