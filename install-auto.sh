#!/bin/bash

# One-line installer for Telegram MTProto Proxy Checker Bot
# Usage: curl -sL https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/main/install-auto.sh | bash
# This script will download itself to a temp file if run via pipe to avoid execution while downloading

set -e

# Check if running from pipe (curl | bash)
if ! [ -t 0 ]; then
    # Running from pipe - download to temp file first
    TEMP_SCRIPT=$(mktemp)
    curl -sL "https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/main/install-auto.sh" -o "$TEMP_SCRIPT"
    exec bash "$TEMP_SCRIPT"
    exit 0
fi

# Running from file - continue normally
echo "🤖 Telegram MTProto Proxy Checker Bot - Quick Install"
echo ""

# Get script directory or use current directory
if [ -n "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
elif [ -d "telegram-mtproto-proxy-checker" ]; then
    cd telegram-mtproto-proxy-checker
elif [ -d "telegram-mtproto-proxy-checker-1" ]; then
    cd telegram-mtproto-proxy-checker-1
fi

INSTALL_DIR=$(pwd)

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
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "📁 Repository exists, checking remote..."

    # Check if remote points to correct repo
    if ! git remote get-url origin 2>/dev/null | grep -q "Diman331/telegram-mtproto-proxy-checker"; then
        echo "🔄 Fixing remote..."
        git remote remove origin 2>/dev/null || true
        git remote add origin https://github.com/Diman331/telegram-mtproto-proxy-checker.git
    fi

    # Try to fetch and reset (try main first, then master)
    if git fetch origin 2>/dev/null && git reset --hard origin/main 2>/dev/null; then
        echo "✅ Repository updated"
    elif git fetch origin 2>/dev/null && git reset --hard origin/master 2>/dev/null; then
        echo "✅ Repository updated"
    else
        echo "⚠️ Could not update, recloning..."
        # Backup .env before recloning
        if [ -f "$INSTALL_DIR/.env" ]; then
            cp "$INSTALL_DIR/.env" /tmp/backup.env
        fi
        cd /tmp
        rm -rf telegram-mtproto-proxy-checker 2>/dev/null || true
        git clone --quiet https://github.com/Diman331/telegram-mtproto-proxy-checker.git
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        mv telegram-mtproto-proxy-checker "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        # Restore .env
        if [ -f /tmp/backup.env ]; then
            mv /tmp/backup.env .env
            echo "✅ .env restored"
        fi
        echo "✅ Repository recloned"
    fi
else
    echo "📥 Cloning repository from GitHub..."
    cd /tmp
    rm -rf telegram-mtproto-proxy-checker 2>/dev/null || true
    git clone --quiet https://github.com/Diman331/telegram-mtproto-proxy-checker.git
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    mv telegram-mtproto-proxy-checker "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo "✅ Repository cloned"
fi

# Detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PM="apt"
    elif command -v yum &> /dev/null; then
        PM="yum"
    elif command -v dnf &> /dev/null; then
        PM="dnf"
    elif command -v pacman &> /dev/null; then
        PM="pacman"
    elif command -v apk &> /dev/null; then
        PM="apk"
    else
        PM="unknown"
    fi
}

detect_package_manager

# Install system dependencies
echo ""
echo "📦 Installing system dependencies..."
case $PM in
    apt)
        apt-get update -qq
        apt-get install -y -qq nodejs npm curl 2>/dev/null || {
            # Try installing from NodeSource if repo version is too old
            if ! command -v node &> /dev/null || [ "$(node -v | cut -d'.' -f1 | sed 's/v//')" -lt 18 ]; then
                echo "⚙️  Installing Node.js 18+ from NodeSource..."
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
                apt-get install -y -qq nodejs
            fi
        }
        ;;
    yum|dnf)
        $PM install -y -q nodejs npm curl 2>/dev/null || {
            if ! command -v node &> /dev/null || [ "$(node -v | cut -d'.' -f1 | sed 's/v//')" -lt 18 ]; then
                echo "⚙️  Installing Node.js 18+..."
                $PM install -y -q nodejs
            fi
        }
        ;;
    pacman)
        pacman -Sy --noconfirm nodejs npm curl 2>/dev/null || true
        ;;
    apk)
        apk add --no-cache nodejs npm curl 2>/dev/null || true
        ;;
    *)
        echo "⚠️  Unknown package manager. Please install Node.js 18+ and npm manually."
        ;;
esac

# Check Node.js version
NODE_VERSION=$(node -v 2>/dev/null || echo "not installed")
if [ "$NODE_VERSION" = "not installed" ]; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ manually."
    exit 1
fi

NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'.' -f1 | sed 's/v//')
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "❌ Node.js version is $NODE_VERSION, but 18+ is required."
    echo "   Please upgrade Node.js: https://nodejs.org/"
    exit 1
fi
echo "✅ Node.js version: $NODE_VERSION"

# Install npm dependencies
echo ""
echo "📦 Installing npm dependencies..."
if npm install --silent 2>/dev/null; then
    echo "✅ npm dependencies installed"
else
    echo "⚠️ npm install failed, trying with --unsafe-perm..."
    npm install --silent --unsafe-perm || echo "❌ npm install failed completely"
fi

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo ""
    echo "⚙️ Creating .env file..."
    cp .env.example .env 2>/dev/null || echo "TELEGRAM_BOT_TOKEN=your-token-here" > .env
    echo "✅ .env created. Please edit it and add your bot token."
fi

# Create global command wrapper
echo ""
echo "🔧 Setting up global command..."
if [ -w "/usr/local/bin" ]; then
    printf '%s\n' '#!/bin/bash' '# Telegram MTProto Proxy Checker Bot Manager' "exec \"$INSTALL_DIR/manage.sh\" \"\$@\"" > /usr/local/bin/mtprotobot
    chmod +x /usr/local/bin/mtprotobot
    echo "✅ Global command 'mtprotobot' installed"
else
    echo "⚠️ Cannot install global command (no write access to /usr/local/bin)"
    echo "   Run bot manually: cd $INSTALL_DIR && npm run bot"
fi

# Ask about systemd auto-start
echo ""
read -p "Setup systemd auto-start? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔧 Setting up systemd service..."

    # Load env to validate
    if [ -f ".env" ]; then
        source .env 2>/dev/null || true
    fi

    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ "$TELEGRAM_BOT_TOKEN" != "your-bot-token-here" ]; then
        # Create service file
        cat > /etc/systemd/system/telegram-proxy-bot.service << EOF
[Unit]
Description=Telegram MTProto Proxy Checker Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=/usr/bin/node $INSTALL_DIR/bot.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        # Reload and enable
        systemctl daemon-reload
        systemctl enable telegram-proxy-bot
        systemctl start telegram-proxy-bot

        echo "✅ Systemd service installed and started!"
        echo "   View logs: journalctl -u telegram-proxy-bot -f"
        echo "   Check status: systemctl status telegram-proxy-bot"
    else
        echo "⚠️ Skipping systemd setup (bot token not set in .env)"
        echo "   Run 'mtprotobot' or edit .env and run: systemctl start telegram-proxy-bot"
    fi
fi

echo ""
echo "=========================================="
echo "✅ Installation complete!"
echo "=========================================="
echo ""
echo "📝 Next steps:"
echo "   1. Edit .env file: nano $INSTALL_DIR/.env"
echo "   2. Add TELEGRAM_BOT_TOKEN from @BotFather"
echo "   3. (Optional) Add ADMIN_ID from @userinfobot"
echo "   4. Start the bot:"
echo "      - Manual: mtprotobot  (or cd $INSTALL_DIR && npm run bot)"
echo "      - Systemd: systemctl start telegram-proxy-bot"
echo ""
echo "📚 Documentation:"
echo "   - README.md"
echo "   - AUTO_START.md (for systemd auto-start)"
echo "   - PROJECT_SUMMARY.md (project overview)"
echo ""
echo "🚀 Quick start:"
if [ -x "/usr/local/bin/mtprotobot" ]; then
    echo "   mtprotobot  # Run from anywhere!"
else
    echo "   cd $INSTALL_DIR && npm run bot"
fi
echo ""
