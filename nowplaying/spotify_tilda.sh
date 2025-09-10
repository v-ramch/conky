#!/bin/bash

# Function to check if Spotify is running
is_spotify_running() {
    pgrep -x "spotify" > /dev/null
}

# Function to start tilda if it's not already running
start_tilda() {
    if ! pgrep -x "tilda" > /dev/null; then
        tilda &
    fi
}

# Function to kill tilda if it's running
kill_tilda() {
    if pgrep -x "tilda" > /dev/null; then
        pkill -x "tilda"
    fi
}

# Main loop
while true; do
    if is_spotify_running; then
        start_tilda
    else
        kill_tilda
    fi
    sleep 2  # Adjust the sleep interval as needed
done
