#!/bin/bash

# Log file for debugging
 LOGFILE="/home/vramch/.conky/spotify_buttons.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Function to check if Spotify is running
is_spotify_running() {
    pgrep -x spotify > /dev/null 2>&1
}

# Function to check if GLava is running
is_glava_running() {
    pgrep -x glava > /dev/null 2>&1
}

#log_message "Script started."

# Variable to track GLava process
GLAVA_PID=0

while true; do
    if is_spotify_running; then
        if ! is_glava_running; then
   #         log_message "Spotify is running. Starting GLava..."
            glava &
            GLAVA_PID=$! # Capture GLava process ID
   #         log_message "GLava started with PID $GLAVA_PID."
        fi
    else
        if is_glava_running; then
    #        log_message "Spotify is not running. Killing GLava..."
            kill $GLAVA_PID 2 >/dev/null
   #         log_message "GLava terminated."
        fi
    fi
    sleep 2
done
