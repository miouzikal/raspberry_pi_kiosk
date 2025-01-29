#!/usr/bin/env bash
#
# utils.sh
# Provides spinner, color codes, progress display, and helper functions.

# -----------------------------------------------------------------------------
# ANSI Colors & Formatting
# -----------------------------------------------------------------------------
BOLD="\033[1m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_RESET="\033[0m"

# -----------------------------------------------------------------------------
# Spinner Characters
# -----------------------------------------------------------------------------
SPINNER=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')

# -----------------------------------------------------------------------------
# Shared Variables
# -----------------------------------------------------------------------------
declare -a STEPS_COMPLETED  # Stores list of completed steps
CURRENT_STEP=""
SPIN_PID=0
SPIN_MSG=""

# -----------------------------------------------------------------------------
# Spinner Functions
# -----------------------------------------------------------------------------
spinner() {
  local i=0
  while :; do
    i=$(( (i+1) % 8 ))
    printf "\r${COLOR_YELLOW}%s${COLOR_RESET} %s" "${SPINNER[$i]}" "$SPIN_MSG"
    sleep 0.1
  done
}

start_spinner() {
  SPIN_MSG="$1"
  spinner &
  SPIN_PID=$!
  disown
}

stop_spinner() {
  kill -9 "$SPIN_PID" 2>/dev/null || true
  printf "\r"
  tput el  # clear line
}

# -----------------------------------------------------------------------------
# Progress Display
# -----------------------------------------------------------------------------
show_progress() {
  clear
  echo -e "${BOLD}${COLOR_BLUE}=== Kiosk Setup Progress ===${COLOR_RESET}"

  # Completed steps
  for step in "${STEPS_COMPLETED[@]}"; do
    echo -e " ${COLOR_GREEN}✓${COLOR_RESET} $step"
  done

  # Current step
  if [[ -n "$CURRENT_STEP" ]]; then
    echo
    echo -e "${COLOR_YELLOW}=> $CURRENT_STEP${COLOR_RESET}"
    echo
  fi
}

# -----------------------------------------------------------------------------
# Confirmation Prompt
# -----------------------------------------------------------------------------
confirm() {
    local prompt="$1"
    while true; do
        echo -n -e "${BOLD}${prompt}${COLOR_RESET} [Y/n] "
        read answer
        case "$answer" in
            [Yy]* | "") return 0 ;;
            [Nn]*) return 1 ;;
            *) echo -e "${COLOR_RED}Invalid input. Please enter Y or N.${COLOR_RESET}" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Run a Step Script
# -----------------------------------------------------------------------------
run_step() {
  local step_title="$1"
  local step_script="$2"

  CURRENT_STEP="$step_title"
  show_progress

  # If the step script doesn't exist, skip
  if [[ ! -f "$step_script" ]]; then
    echo -e "${COLOR_RED}Script $step_script not found. Skipping.${COLOR_RESET}"
    sleep 2
    return
  fi

  # Confirm with user?
  if ! confirm "Proceed with '$step_title'?"; then
    echo -e "${COLOR_RED}Skipped '${step_title}'.${COLOR_RESET}"
    sleep 1
    return
  fi

  # Run the step
  # The step script can also do its own user prompts if needed.
  bash "$step_script"
  if [[ $? -ne 0 ]]; then
    echo -e "${COLOR_RED}'$step_title' failed or was aborted.${COLOR_RESET}"
    # You can decide to exit here or continue
    # exit 1
  else
    STEPS_COMPLETED+=("$step_title")
  fi
}

# -----------------------------------------------------------------------------
# Ensure spinner is stopped on exit
# -----------------------------------------------------------------------------
trap 'stop_spinner' EXIT
