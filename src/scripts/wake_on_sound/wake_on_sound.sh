#!/bin/bash

# Configuration
THRESHOLD=0.005
RECORD_DURATION=1
DEBUG_MODE=0
TRIGGER_METHOD="PEAK" # PEAK or RMS
export DISPLAY=:0
IDLE_TIME_THRESHOLD_MS=300000
LOG_FILE="/home/raspberry/wake_on_sound.log"

# Function to write messages to a log file
log_message() {
    [[ "$DEBUG_MODE" -eq 1 ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check and return the display state
get_display_state() {
    xset -q | grep "Monitor is" | awk '{print $3}'
}

# Function to wake the display up
wake_display_up() {
    eval "$(xdotool getmouselocation --shell)"
    xdotool mousemove --sync $((X + 1)) $((Y + 1)) mousemove --sync "$X" "$Y"
    log_message "Display woken up."
}

# Function to check if the inactivity time is close to turning off the display
is_close_to_inactivity_timeout() {
    [[ $(xprintidle) -ge $((IDLE_TIME_THRESHOLD_MS - IDLE_TIME_THRESHOLD_MS / 4)) ]]
}

CARD=$(arecord -l | grep -oP 'card \K[0-9]+(?=:.*\[USB.*)' | head -1)
DEVICE=$(arecord -l | grep -oP 'device \K[0-9]+(?=:.*\[USB.*)' | head -1)
if [ -z "$CARD" ] || [ -z "$DEVICE" ]; then
    log_message "No USB audio device found."
    exit 1
fi

# Main loop
while true; do
    AUDIO_STATS=$(arecord -D plughw:$CARD,$DEVICE -d $RECORD_DURATION -t wav -f cd -q | sox -t wav - -n stat 2>&1)
    RMS_LEVEL=$(echo "$AUDIO_STATS" | grep "RMS.*amplitude" | awk '{print $3}')
    PEAK_LEVEL=$(echo "$AUDIO_STATS" | grep "Maximum amplitude" | awk '{print $3}')
    RMS_LEVEL=${RMS_LEVEL:-0}
    PEAK_LEVEL=${PEAK_LEVEL:-0}
    log_message "RMS: $RMS_LEVEL, PEAK: $PEAK_LEVEL, DISPLAY: '$(get_display_state)', IDLE: $(xprintidle)"
    TRIGGER=0
    [[ "$TRIGGER_METHOD" == "RMS" ]] && TRIGGER=$(echo "$RMS_LEVEL > $THRESHOLD" | bc -l)
    [[ "$TRIGGER_METHOD" == "PEAK" ]] && TRIGGER=$(echo "$PEAK_LEVEL > $THRESHOLD" | bc -l)
    # If the trigger is 1 and the display is off or close to turning off, wake it up
    if [[ "$TRIGGER" -eq 1 ]] && ([[ $(get_display_state) == "Off" ]] || is_close_to_inactivity_timeout); then
        wake_display_up
        log_message "Threshold breached. Waking display up."
    elif [[ "$TRIGGER" -eq 1 ]]; then
        log_message "Threshold breached. Not waking display up since it is not close to turning off."
    else
        log_message "$TRIGGER_METHOD level below threshold ($THRESHOLD)."
    fi
    sleep 0.5
done
