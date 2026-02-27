"""
Button handler for Raspberry Pi kiosk.

Monitors a GPIO button and performs actions based on press patterns:
  - Single press:  Refresh the kiosk browser (restarts kiosk service)
  - Double press:  (placeholder)
  - Triple press:  (placeholder)
  - Hold >=10s:    Reboot the system

Works under Wayland (Cage) — no X11/xdotool dependency.
"""

from __future__ import annotations

import os
import time
import subprocess
from typing import NoReturn
from RPi import GPIO  # type: ignore

# ============ CONFIGURATION ============

DEBUG_MODE = False
LOG_FILE = "/var/log/button_handler.log"

# BCM pin constant
BUTTON_GPIO_PIN = 16  # physical pin 36

# Timing thresholds (seconds)
MULTI_PRESS_INTERVAL = 0.4
HOLD_THRESHOLD = 10.0

# =======================================

GPIO.setmode(GPIO.BCM)
GPIO.setup(BUTTON_GPIO_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)


def log_message(message: str) -> None:
    if not DEBUG_MODE:
        return
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"{timestamp} - {message}\n")


def refresh_kiosk() -> None:
    """Refresh the kiosk by restarting the kiosk service."""
    log_message("Refreshing kiosk (restarting service)...")
    subprocess.run(["sudo", "systemctl", "restart", "kiosk.service"])


def double_press_placeholder() -> None:
    log_message("Double press detected (placeholder).")


def triple_press_placeholder() -> None:
    log_message("Triple press detected (placeholder).")


def reboot_system() -> None:
    log_message("System reboot triggered.")
    subprocess.run(["sudo", "reboot"])


def finalize_presses(press_count: int) -> None:
    log_message(f"Finalizing press count: {press_count}")
    if press_count == 1:
        refresh_kiosk()
    elif press_count == 2:
        double_press_placeholder()
    elif press_count == 3:
        triple_press_placeholder()


def main_loop() -> NoReturn:
    press_count = 0
    last_press_time = 0.0

    try:
        log_message("Button handler started.")
        while True:
            if not GPIO.input(BUTTON_GPIO_PIN):
                press_start = time.time()
                log_message("Button press detected (waiting for release).")

                while not GPIO.input(BUTTON_GPIO_PIN):
                    elapsed = time.time() - press_start
                    if elapsed >= HOLD_THRESHOLD:
                        log_message("Hold threshold reached. Rebooting.")
                        reboot_system()
                        return
                    time.sleep(0.01)

                now = time.time()

                if (now - last_press_time) > MULTI_PRESS_INTERVAL and press_count > 0:
                    finalize_presses(press_count)
                    press_count = 0

                press_count += 1
                last_press_time = now
                log_message(f"Short press counted. Current count: {press_count}")
            else:
                if press_count > 0 and (time.time() - last_press_time) > MULTI_PRESS_INTERVAL:
                    finalize_presses(press_count)
                    press_count = 0

            time.sleep(0.01)
    finally:
        log_message("Cleaning up GPIO and exiting.")
        GPIO.cleanup()


if __name__ == "__main__":
    main_loop()
