#!/bin/bash
#
# wake_on_sound.sh
# Monitors USB microphone and wakes the display when sound is detected.
# Adapted for Wayland (Cage) — uses DPMS via wlr-randr instead of xdotool.

# Configuration
THRESHOLD=0.005
RECORD_DURATION=1
DEBUG_MODE=0
TRIGGER_METHOD="PEAK" # PEAK or RMS
LOG_FILE="/var/log/wake_on_sound.log"
DISPLAY_OUTPUT="${KIOSK_DISPLAY_OUTPUT:-HDMI-A-1}"

# Wayland environment (needed for wlr-randr)
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

log_message() {
    [[ "$DEBUG_MODE" -eq 1 ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

wake_display() {
    wlr-randr --output "$DISPLAY_OUTPUT" --on 2>/dev/null
    log_message "Display woken up via wlr-randr ($DISPLAY_OUTPUT)."
}

CARD=$(arecord -l | grep -oP 'card \K[0-9]+(?=:.*\[USB.*)' | head -1)
DEVICE=$(arecord -l | grep -oP 'device \K[0-9]+(?=:.*\[USB.*)' | head -1)
if [ -z "$CARD" ] || [ -z "$DEVICE" ]; then
    log_message "No USB audio device found."
    exit 1
fi

while true; do
    AUDIO_STATS=$(arecord -D "plughw:$CARD,$DEVICE" -d "$RECORD_DURATION" -t wav -f cd -q | sox -t wav - -n stat 2>&1)
    RMS_LEVEL=$(echo "$AUDIO_STATS" | grep "RMS.*amplitude" | awk '{print $3}')
    PEAK_LEVEL=$(echo "$AUDIO_STATS" | grep "Maximum amplitude" | awk '{print $3}')
    RMS_LEVEL=${RMS_LEVEL:-0}
    PEAK_LEVEL=${PEAK_LEVEL:-0}
    log_message "RMS: $RMS_LEVEL, PEAK: $PEAK_LEVEL"

    TRIGGER=0
    [[ "$TRIGGER_METHOD" == "RMS" ]] && TRIGGER=$(echo "$RMS_LEVEL > $THRESHOLD" | bc -l)
    [[ "$TRIGGER_METHOD" == "PEAK" ]] && TRIGGER=$(echo "$PEAK_LEVEL > $THRESHOLD" | bc -l)

    if [[ "$TRIGGER" -eq 1 ]]; then
        wake_display
        log_message "Threshold breached. Waking display."
    fi

    sleep 0.5
done
