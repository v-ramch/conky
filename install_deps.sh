#!/bin/bash

# Define the required packages
DEPS=(
    libgtk-3-dev
    libgdk-pixbuf2.0-dev
    libgdk3.0-cil-dev
    libglib2.0-dev
    lua-lgi
)

# Update package list
echo "Updating package list..."
sudo apt update

# Install dependencies
echo "Installing dependencies..."
sudo apt install -y "${DEPS[@]}"

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "All dependencies installed successfully!"
else
    echo "Error installing dependencies."
    exit 1
fi

