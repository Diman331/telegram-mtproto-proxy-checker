#!/bin/bash

# One-line installer for Telegram MTProto Proxy Checker Bot
# Usage: curl -sL https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/install-auto.sh | bash

set -e

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

# Install system dependencies
echo ""
echo "📦 Installing system dependencies..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq nodejs npm gcc g++ make python3 curl 2>/dev/null || {
        echo "⚠️ apt-get failed, continuing..."
    }
elif command -v yum &> /dev/null; then
    yum install -y -q nodejs npm gcc gcc-c++ make python3 curl 2>/dev/null || {
        echo "⚠️ yum failed, continuing..."
    }
elif command -v dnf &> /dev/null; then
    dnf install -y -q nodejs npm gcc gcc-c++ make python3 curl 2>/dev/null || {
        echo "⚠️ dnf failed, continuing..."
    }
fi

# Install npm dependencies
echo ""
echo "📦 Installing npm dependencies..."
if npm install --silent 2>/dev/null; then
    echo "✅ npm dependencies installed"
else
    echo "⚠️ npm install failed, trying with sudo..."
    npm install --silent --unsafe-perm || echo "❌ npm install failed completely"
fi

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo ""
    echo "⚙️ Creating .env file..."
    cp .env.example .env 2>/dev/null || echo "TELEGRAM_BOT_TOKEN=your-token-here" > .env
fi

# Create global command wrapper
echo ""
echo "🔧 Setting up global command..."
cat > /usr/local/bin/mtprotobot << WRAPPER
#!/bin/bash
# Telegram MTProto Proxy Checker Bot Manager
exec "$INSTALL_DIR/manage.sh" "\$@"
WRAPPER
chmod +x /usr/local/bin/mtprotobot
echo "✅ Global command 'mtprotobot' installed"

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
Environment="LD_LIBRARY_PATH=$INSTALL_DIR/node_modules/@prebuilt-tdlib/linux-arm64-glibc"
ExecStart=/usr/bin/node $INSTALL_DIR/bot.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload and enable
        systemctl daemon-reload
        systemctl enable telegram-proxy-bot
        systemctl start telegram-proxy-bot
        
        echo "✅ Systemd service installed and started!"
        echo "   View logs: journalctl -u telegram-proxy-bot -f"
    else
        echo "⚠️ Skipping systemd setup (bot token not set)"
        echo "   Run 'mtprotobot' and use menu to configure later"
    fi
fi

echo ""
echo "=========================================="
echo "✅ Installation complete!"
echo "=========================================="
echo ""
echo "📝 Next steps:"
echo "   1. Run: mtprotobot (from any directory)"
echo "   2. Add your TELEGRAM_BOT_TOKEN from @BotFather"
echo "   3. (Optional) Add ADMIN_ID from @userinfobot"
echo "   4. Start the bot from the menu"
echo ""
echo "📚 Documentation:"
echo "   - README.md"
echo "   - AUTO_START.md (for systemd auto-start)"
echo "   - PROJECT_SUMMARY.md (project overview)"
echo ""
echo "🚀 Quick start:"
echo "   mtprotobot  # Run from anywhere!"
echo ""
