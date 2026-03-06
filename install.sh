#!/bin/bash

# Telegram MTProto Proxy Checker Bot - Auto Install Script
# This script installs all dependencies and sets up the bot

set -e

echo "=========================================="
echo "  Telegram MTProto Proxy Checker Bot"
echo "  Auto Installation Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_warn "Some commands may require sudo. You may be prompted for password."
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
        log_error "Unsupported package manager"
        exit 1
    fi
    log_info "Detected package manager: $PM"
}

# Install system dependencies
install_system_deps() {
    log_info "Installing system dependencies..."
    
    case $PM in
        apt)
            apt-get update -qq
            apt-get install -y -qq nodejs npm gcc g++ make python3 curl
            ;;
        yum|dnf)
            yum install -y -q nodejs npm gcc gcc-c++ make python3 curl
            ;;
        pacman)
            pacman -Sy --noconfirm nodejs npm gcc make python curl
            ;;
        apk)
            apk add --no-cache nodejs npm gcc g++ make python3 curl
            ;;
    esac
    
    log_info "System dependencies installed"
}

# Check Node.js version
check_nodejs() {
    NODE_VERSION=$(node -v 2>/dev/null || echo "not installed")
    if [ "$NODE_VERSION" = "not installed" ]; then
        log_error "Node.js is not installed"
        exit 1
    fi
    
    NODE_MAJOR=$(node -v | cut -d'.' -f1 | sed 's/v//')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        log_warn "Node.js version is $NODE_VERSION, but 18+ is recommended"
    else
        log_info "Node.js version: $NODE_VERSION ✓"
    fi
}

# Install npm dependencies
install_npm_deps() {
    log_info "Installing npm dependencies..."
    npm install --silent
    log_info "npm dependencies installed"
}

# Create .env file
create_env_file() {
    if [ ! -f ".env" ]; then
        log_info "Creating .env file..."
        cp .env.example .env
        log_warn "Please edit .env file and add your TELEGRAM_BOT_TOKEN"
        log_warn "Get token from @BotFather in Telegram"
    else
        log_info ".env file already exists"
    fi
}

# Setup systemd service
setup_systemd() {
    echo ""
    read -p "Setup auto-start with systemd? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setting up systemd service..."
        
        # Get absolute path
        BOT_PATH=$(pwd)
        
        # Read environment variables
        source .env 2>/dev/null || true
        
        # Create service file
        cat > /etc/systemd/system/telegram-proxy-bot.service << EOF
[Unit]
Description=Telegram MTProto Proxy Checker Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_PATH
Environment="TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
Environment="ADMIN_ID=$ADMIN_ID"
ExecStart=/usr/bin/node $BOT_PATH/bot.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload and enable
        systemctl daemon-reload
        systemctl enable telegram-proxy-bot
        systemctl start telegram-proxy-bot
        
        log_info "Systemd service created and started"
        log_info "Check status: systemctl status telegram-proxy-bot"
        log_info "View logs: journalctl -u telegram-proxy-bot -f"
    else
        log_info "Skipping systemd setup"
        log_warn "To run bot manually: npm run bot"
    fi
}

# Main installation
main() {
    echo ""
    log_info "Starting installation..."
    echo ""
    
    # Detect package manager
    detect_package_manager
    
    # Check Node.js
    check_nodejs
    
    # Install system dependencies
    install_system_deps
    
    # Install npm dependencies
    install_npm_deps
    
    # Create .env file
    create_env_file
    
    echo ""
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo ""
    log_info "Next steps:"
    echo "  1. Edit .env file and add your TELEGRAM_BOT_TOKEN"
    echo "  2. (Optional) Add your ADMIN_ID for admin commands"
    echo "  3. Run: npm run bot"
    echo ""
    log_info "Documentation:"
    echo "  - README.md - General documentation"
    echo "  - AUTO_START.md - Auto-start guide"
    echo ""
    
    # Ask about systemd setup
    setup_systemd
}

# Run installation
main
