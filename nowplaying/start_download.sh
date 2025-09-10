#!/bin/bash
ARTIST="$1"
cd ~/.conky/nowplaying/lua/
lua download_artist_images.lua "$ARTIST"
