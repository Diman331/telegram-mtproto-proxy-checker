#!/bin/bash

# One-line installer for Telegram MTProto Proxy Checker Bot
# Usage: curl -sL https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/install-auto.sh | bash
# This script will update itself from GitHub if run via curl

set -e

# Check if already downloaded (prevent infinite loop)
if [ "$DOWNLOADED_FROM_GITHUB" = "1" ]; then
    # Already downloaded, proceed with installation
    unset DOWNLOADED_FROM_GITHUB
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
else
    # Check if running from curl (piped input)
    if ! [ -t 0 ]; then
        # Running from pipe (curl), download and save locally first
        echo "🔄 Downloading latest installer from GitHub..."
        SCRIPT_URL="https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/install-auto.sh"
        
        # Try to download to temporary file
        TEMP_SCRIPT=$(mktemp)
        if curl -sL "$SCRIPT_URL" -o "$TEMP_SCRIPT" 2>/dev/null; then
            echo "✅ Downloaded latest version"
            # Replace this script with the downloaded one
            export DOWNLOADED_FROM_GITHUB=1
            exec bash "$TEMP_SCRIPT" "$@"
        else
            echo "⚠️ Could not download latest version, using local version..."
        fi
        rm -f "$TEMP_SCRIPT" 2>/dev/null
    else
        # Running from file, get script directory
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        cd "$SCRIPT_DIR"
    fi
fi

echo "🤖 Telegram MTProto Proxy Checker Bot - Quick Install"
echo ""

# Check and install git if not present
if ! command -v git &> /dev/null; then
    echo "📦 Git not found. Installing..."
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq git 2>/dev/null || true
    elif command -v yum &> /dev/null; then
        yum install -y -q git 2>/dev/null || true
    elif command -v dnf &> /dev/null; then
        dnf install -y -q git 2>/dev/null || true
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm git 2>/dev/null || true
    elif command -v apk &> /dev/null; then
        apk add --no-cache git 2>/dev/null || true
    fi
    echo "✅ Git installed"
fi

# Clone or update repository
if [ -d "telegram-mtproto-proxy-checker" ] && [ -f "telegram-mtproto-proxy-checker/bot.js" ]; then
    echo "📁 Repository exists, updating..."
    cd telegram-mtproto-proxy-checker
    if [ -d ".git" ]; then
        git pull --quiet
    else
        echo "⚠️ Not a git repository, skipping update"
    fi
elif [ -d "telegram-mtproto-proxy-checker-1" ] && [ -f "telegram-mtproto-proxy-checker-1/bot.js" ]; then
    echo "📁 Repository exists (old name), updating..."
    cd telegram-mtproto-proxy-checker-1
    if [ -d ".git" ]; then
        git pull --quiet
    else
        echo "⚠️ Not a git repository, skipping update"
    fi
else
    echo "📥 Cloning repository..."
    git clone --quiet https://github.com/Diman331/telegram-mtproto-proxy-checker.git
    cd telegram-mtproto-proxy-checker
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq nodejs npm gcc g++ make python3 curl git 2>/dev/null || {
        echo "⚠️ apt-get failed, continuing..."
    }
elif command -v yum &> /dev/null; then
    yum install -y -q nodejs npm gcc gcc-c++ make python3 curl git 2>/dev/null || {
        echo "⚠️ yum failed, continuing..."
    }
elif command -v dnf &> /dev/null; then
    dnf install -y -q nodejs npm gcc gcc-c++ make python3 curl git 2>/dev/null || {
        echo "⚠️ dnf failed, continuing..."
    }
fi

# Install npm dependencies
echo "📦 Installing npm dependencies..."
if npm install --silent 2>/dev/null; then
    echo "✅ npm dependencies installed"
else
    echo "⚠️ npm install failed, trying with sudo..."
    npm install --silent --unsafe-perm || echo "❌ npm install failed completely"
fi

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo "⚙️ Creating .env file..."
    cp .env.example .env 2>/dev/null || echo "TELEGRAM_BOT_TOKEN=your-token-here" > .env
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Run: ./manage.sh"
echo "   2. Add your TELEGRAM_BOT_TOKEN from @BotFather"
echo "   3. (Optional) Add ADMIN_ID from @userinfobot"
echo "   4. Start the bot from the menu"
echo ""
echo "📚 Documentation:"
echo "   - README.md"
echo "   - AUTO_START.md (for systemd auto-start)"
echo "   - PROJECT_SUMMARY.md (project overview)"
echo "   - manage.sh (management menu)"
echo ""
