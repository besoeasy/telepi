#!/bin/bash
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install a package
install_package() {
    sudo apt-get update -y
    sudo apt-get install -y "$1"
}

# Function to check if the Telegram bot token is valid
check_telegram_token() {
    local bot_token="$1"
    local response=$(curl -s "https://api.telegram.org/bot${bot_token}/getMe")
    
    if [[ $response == *"ok\":true"* ]]; then
        echo "Telegram bot token is valid."
    else
        echo "Telegram bot token is invalid or the bot could not be reached."
        exit 1
    fi
}

# Check for sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo."
    exit 1
fi

# Update and install necessary packages
install_package ca-certificates
install_package curl
install_package gnupg
install_package aria2
install_package neofetch

sudo neofetch

# Check and install Node.js
if command_exists node; then
    echo "Node.js is already installed."
else
    # Install Node.js from NodeSource repository
    install_package nodejs
    node --version
    echo "Node.js installation complete!"
fi

# Check and install npm
if command_exists npm; then
    echo "npm is already installed."
else
    # Install Node.js from NodeSource repository
    install_package npm
    npm --version
    echo "npm installation complete!"
fi

# Check and update telepi
if command_exists telepi; then
    sudo systemctl stop telepi.service
    sudo npm install -g telepi@latest
    sudo systemctl start telepi.service
    echo "Telepi service stopped, updated, and started again."
else
    # Prompt user for TELEGRAMBOT variable with regex check
    while true; do
        read -p "Please enter your Telegram bot token: " TELEGRAMBOT
        if [[ $TELEGRAMBOT =~ ^[0-9]{9,10}:[A-Za-z0-9_-]{35}$ ]]; then
            break
        else
            echo "Invalid Telegram bot token. Please try again."
        fi
    done

    check_telegram_token "$TELEGRAMBOT"

    # Set TELEGRAMBOT as an environment variable
    if grep -q "TELEGRAMBOT" /etc/environment; then
        sudo sed -i '/TELEGRAMBOT/d' /etc/environment
    fi
    echo "export TELEGRAMBOT=$TELEGRAMBOT" | sudo tee -a /etc/environment

    export TELEGRAMBOT="$TELEGRAMBOT"

    # Install telepi globally
    sudo npm install -g telepi

    # Create telepi systemd service
    sudo tee /etc/systemd/system/telepi.service >/dev/null <<EOF
[Unit]
Description=telepi Service
After=network.target

[Service]
ExecStart=/usr/bin/env telepi
Restart=always
Environment="TELEGRAMBOT=$TELEGRAMBOT"

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd daemon and enable telepi service
    sudo systemctl daemon-reload
    sudo systemctl enable telepi.service

    echo "telepi installation and service setup complete!"
fi
