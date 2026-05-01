#!/bin/bash

# Something Framework - Global Installer
# Usage: curl -sSL https://raw.githubusercontent.com/ilham-fauzi/something/main/scripts/install-global.sh | bash

set -e

REPO_URL="https://github.com/ilham-fauzi/something.git"
INSTALL_DIR="$HOME/.something"
BIN_LINK="/usr/local/bin/something"

echo "🛸 Initializing 'Something' Framework Global Installation..."

# Check dependencies
if ! command -v git >/dev/null 2>&1; then
    echo "❌ Error: git is not installed. Please install git first."
    exit 1
fi

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 Found existing installation at $INSTALL_DIR. Updating..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "📦 Cloning Something Framework to $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Run the framework's internal installer
echo "⚙️ Running internal setup..."
chmod +x install.sh
./install.sh

# Create global symlink
echo "🔗 Creating global symlink at $BIN_LINK..."
if [ -L "$BIN_LINK" ] || [ -f "$BIN_LINK" ]; then
    sudo rm -f "$BIN_LINK"
fi

if sudo ln -sf "$INSTALL_DIR/bin/something" "$BIN_LINK"; then
    echo "✅ Global command 'something' is now available!"
else
    echo "⚠️  Failed to create symlink in /usr/local/bin. You might need to add $INSTALL_DIR/bin to your PATH manually."
fi

echo ""
echo "✨ Installation Complete!"
echo "Try running: something help"
