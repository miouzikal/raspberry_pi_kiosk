from __future__ import annotations

import os
import time
import subprocess
from typing import NoReturn
from RPi import GPIO  # type: ignore

# ============ CONFIGURATION ============

# Set DISPLAY for xdotool (adjust as needed)
os.environ["DISPLAY"] = ":0"

# Debug mode toggle (set to True to enable logging)
DEBUG_MODE = False

# Path to the log file (used only if DEBUG_MODE is True)
LOG_FILE = "/home/raspberry/button_handler.log"

# BCM pin constant
BUTTON_GPIO_PIN = 16  # physical pin 36

# Timing thresholds (seconds)
MULTI_PRESS_INTERVAL = 0.4
HOLD_THRESHOLD = 10.0

# =======================================

GPIO.setmode(GPIO.BCM)
GPIO.setup(BUTTON_GPIO_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)


def log_message(message: str) -> None:
    """
    Log a message to LOG_FILE if DEBUG_MODE is True.
    Each line is prefixed with "YYYY-MM-DD HH:MM:SS - ".
    """
    if not DEBUG_MODE:
        return
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as file_obj:
        file_obj.write(f"{timestamp} - {message}\n")


def refresh_chromium() -> None:
    """
    Refresh Chromium via xdotool by sending F5.
    Requires:
      - xdotool installed
      - Running under an X session (DISPLAY set appropriately)
      - Chromium already open
    """
    log_message("Refreshing Chromium...")
    subprocess.run([
        "xdotool", "search", "--onlyvisible", "--class", "chromium",
        "windowactivate", "--sync", "key", "F5"
    ])


def double_press_placeholder() -> None:
    """
    Placeholder function for a double press.
    Replace with your desired action.
    """
    log_message("Double press detected (placeholder).")


def triple_press_placeholder() -> None:
    """
    Placeholder function for a triple press.
    Replace with your desired action.
    """
    log_message("Triple press detected (placeholder).")


def more_than_triple_press_action() -> None:
    """
    Action when there are more than three presses in quick succession.
    """
    log_message("More than three presses detected! No specific action defined.")


def restart_host() -> None:
    """
    Restart (reboot) the host system.
    """
    log_message("System reboot triggered.")
    subprocess.run(["sudo", "reboot"])


def finalize_presses(press_count: int) -> None:
    """
    Called when the multi-press detection window closes.
    Decide what to do based on the number of short presses detected.
    """
    log_message(f"Finalizing press count: {press_count}")
    if press_count == 1:
        refresh_chromium()
    elif press_count == 2:
        double_press_placeholder()
    elif press_count == 3:
        triple_press_placeholder()
    else:
        # More than three presses
        more_than_triple_press_action()


def main_loop() -> NoReturn:
    """
    Main loop which:
      - Detects short presses (1, 2, 3, and >3)
      - Detects a hold (>=2s) and reboots
    """
    press_count = 0
    last_press_time = 0.0

    try:
        log_message("Button handler started.")
        while True:
            # Check if the button is pressed (LOW when pressed)
            if not GPIO.input(BUTTON_GPIO_PIN):
                press_start = time.time()
                log_message("Button press detected (waiting for release).")

                # Wait while button is still pressed
                while not GPIO.input(BUTTON_GPIO_PIN):
                    elapsed = time.time() - press_start
                    if elapsed >= HOLD_THRESHOLD:
                        # This is a "hold" → reboot
                        log_message("Hold threshold reached. Rebooting.")
                        restart_host()
                        return
                    time.sleep(0.01)

                # Button released before HOLD_THRESHOLD
                now = time.time()

                # Check if the previous press sequence timed out
                if (now - last_press_time) > MULTI_PRESS_INTERVAL and press_count > 0:
                    finalize_presses(press_count)
                    press_count = 0

                # Count this short press
                press_count += 1
                last_press_time = now
                log_message(f"Short press counted. Current count: {press_count}")

            else:
                # If we've started counting short presses but enough time has passed
                # without a new press, finalize the existing press count.
                if press_count > 0 and (time.time() - last_press_time) > MULTI_PRESS_INTERVAL:
                    finalize_presses(press_count)
                    press_count = 0

            time.sleep(0.01)
    finally:
        log_message("Cleaning up GPIO and exiting.")
        GPIO.cleanup()


def main() -> None:
    """
    Entry point for the script.
    """
    main_loop()


if __name__ == "__main__":
    main()
