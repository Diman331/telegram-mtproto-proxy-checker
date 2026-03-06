#!/bin/bash

# One-line installer for Telegram MTProto Proxy Checker Bot
# Usage: curl -sL https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/install-auto.sh | bash

set -e

echo "🤖 Telegram MTProto Proxy Checker Bot - Quick Install"
echo ""

# Clone or update repository
if [ -d "telegram-mtproto-proxy-checker-1" ]; then
    echo "📁 Directory exists, updating..."
    cd telegram-mtproto-proxy-checker-1
    git pull --quiet
else
    echo "📥 Cloning repository..."
    git clone --quiet https://github.com/Diman331/telegram-mtproto-proxy-checker.git
    cd telegram-mtproto-proxy-checker-1
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq && apt-get install -y -qq nodejs npm gcc g++ make python3 2>/dev/null || true
elif command -v yum &> /dev/null; then
    yum install -y -q nodejs npm gcc gcc-c++ make python3 2>/dev/null || true
fi

# Install npm dependencies
echo "📦 Installing npm dependencies..."
npm install --silent

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo "⚙️ Creating .env file..."
    cp .env.example .env 2>/dev/null || echo "TELEGRAM_BOT_TOKEN=your-token-here" > .env
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Edit .env: nano .env"
echo "   2. Add your TELEGRAM_BOT_TOKEN from @BotFather"
echo "   3. (Optional) Add ADMIN_ID from @userinfobot"
echo "   4. Run: npm run bot"
echo ""
echo "📚 Documentation:"
echo "   - README.md"
echo "   - AUTO_START.md (for systemd auto-start)"
echo ""
