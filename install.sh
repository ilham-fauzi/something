#!/bin/bash

# Installation script for 'Something' Framework

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Setting up 'Something' Framework..."

# Dependency check function
check_and_install() {
    local cmd=$1
    local install_cmd=$2
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ $cmd is already installed."
    else
        echo "⚠️  $cmd not found. Installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            eval "$install_cmd"
        else
            echo "❌ Automatic install only supported on Linux (apt). Please install $cmd manually."
        fi
    fi
}

# Update packages list first if on Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🔄 Updating package list..."
    sudo apt update -y
fi

# Check and install core dependencies
check_and_install "jq" "sudo apt install jq -y"
check_and_install "curl" "sudo apt install curl -y"


# Create config directory and default config if missing
mkdir -p "$DIR/config"
if [ ! -f "$DIR/config/something.conf" ]; then
    echo "📝 Creating configuration from template..."
    cp "$DIR/config/something.conf.example" "$DIR/config/something.conf"
    # Set absolute log path in the new config
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|LOG_FILE=.*|LOG_FILE=\"$DIR/logs/something.log\"|" "$DIR/config/something.conf"
    else
        sed -i "s|LOG_FILE=.*|LOG_FILE=\"$DIR/logs/something.log\"|" "$DIR/config/something.conf"
    fi
fi

# Make scripts executable
chmod +x "$DIR/bin/something"
chmod +x "$DIR/lib/engine.sh"

# Create logs directory if it doesn't exist
mkdir -p "$DIR/logs"
touch "$DIR/logs/something.log"

echo "✅ Framework prepared at $DIR"
echo ""
echo "Next steps:"
echo "1. Configure your bot: something setup"
echo "2. Start the framework: something start"
echo ""
echo "To use 'something' command globally, run:"
echo "  sudo ln -sf $DIR/bin/something /usr/local/bin/something"
echo ""
