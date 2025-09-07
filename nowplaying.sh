#!/bin/bash

# Path to your Conky configuration file for Spotify
CONKY_CONFIG="/home/vramch/.conky/nowplaying/conky_nowplaying"

# Path to your Lua script
LUA_SCRIPT="$HOME/.conky/nowplaying/lua/buttons.lua"

# Function to check if Spotify is running
is_spotify_running() {
    pgrep -x "spotify" > /dev/null
}


# Function to start the Lua script
start_lua_script() {
    if ! pgrep -f "lua $LUA_SCRIPT" > /dev/null; then
        lua "$LUA_SCRIPT" &
    fi
}

# Function to kill the Lua script
kill_lua_script() {
    if pgrep -f "lua $LUA_SCRIPT" > /dev/null; then
        pkill -f "lua $LUA_SCRIPT"
    fi
}

# Function to reload the specific Conky instance (conky_nowplaying)
reload_conky_nowplaying() {
    # Kill only the conky_nowplaying instance
    pkill -f "conky -c $CONKY_CONFIG"

    # Restart the conky_nowplaying instance
    conky -c "$CONKY_CONFIG" &
}

# Track Spotify's previous state
PREVIOUS_STATE=false

# Main loop
while true; do
    CURRENT_STATE=$(is_spotify_running && echo true || echo false)

    if [ "$CURRENT_STATE" != "$PREVIOUS_STATE" ]; then
        if [ "$CURRENT_STATE" = true ]; then
            start_lua_script
        else
            kill_lua_script
        fi
        reload_conky_nowplaying
        PREVIOUS_STATE="$CURRENT_STATE"
    fi

    sleep 2  # Adjust the sleep interval as needed
done