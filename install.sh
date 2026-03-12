#!/bin/bash

# Telegram MTProto Proxy Checker Bot - Install/Update/Uninstall Script
# This script installs, updates, or uninstalls the bot

set -e

echo "=========================================="
echo "  Telegram MTProto Proxy Checker Bot"
echo "  Install / Update / Uninstall"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_menu() {
    echo -e "${BLUE}[MENU]${NC} $1"
}

# Show main menu
show_menu() {
    echo ""
    log_menu "Please select an option:"
    echo ""
    echo "  1) Install"
    echo "  2) Update"
    echo "  3) Uninstall"
    echo "  4) Exit"
    echo ""
    read -p "Enter choice [1-4]: " choice
    echo ""
    
    case $choice in
        1) do_install ;;
        2) do_update ;;
        3) do_uninstall ;;
        4) exit 0 ;;
        *) log_error "Invalid option"; show_menu ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_warn "Some commands may require sudo. You may be prompted for password."
    fi
}

# Check and install git
check_git() {
    if ! command -v git &> /dev/null; then
        log_warn "Git is not installed. Installing..."
        case $PM in
            apt)
                apt-get install -y -qq git 2>/dev/null || true
                ;;
            yum|dnf)
                yum install -y -q git 2>/dev/null || true
                ;;
            pacman)
                pacman -Sy --noconfirm git 2>/dev/null || true
                ;;
            apk)
                apk add --no-cache git 2>/dev/null || true
                ;;
        esac
        log_info "Git installed"
    else
        log_info "Git is already installed"
    fi
}

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
            apt-get install -y -qq nodejs npm gcc g++ make python3 curl 2>/dev/null || true
            ;;
        yum|dnf)
            yum install -y -q nodejs npm gcc gcc-c++ make python3 curl 2>/dev/null || true
            ;;
        pacman)
            pacman -Sy --noconfirm nodejs npm gcc make python curl 2>/dev/null || true
            ;;
        apk)
            apk add --no-cache nodejs npm gcc g++ make python3 curl 2>/dev/null || true
            ;;
    esac
    
    log_info "System dependencies installed"
}

# Check Node.js version
check_nodejs() {
    NODE_VERSION=$(node -v 2>/dev/null || echo "not installed")
    if [ "$NODE_VERSION" = "not installed" ]; then
        log_error "Node.js is not installed"
        return 1
    fi
    
    NODE_MAJOR=$(node -v | cut -d'.' -f1 | sed 's/v//')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        log_warn "Node.js version is $NODE_VERSION, but 18+ is recommended"
    else
        log_info "Node.js version: $NODE_VERSION ✓"
    fi
    return 0
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
        
        # Stop existing service if running
        systemctl stop telegram-proxy-bot 2>/dev/null || true
        systemctl disable telegram-proxy-bot 2>/dev/null || true
        
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

# Do install
do_install() {
    log_info "Starting installation..."
    echo ""
    
    # Detect package manager
    detect_package_manager
    
    # Check and install git
    check_git
    
    # Check Node.js
    if ! check_nodejs; then
        install_system_deps
        check_nodejs
    fi
    
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
    echo "  - PROJECT_SUMMARY.md - Project overview"
    echo ""
    
    # Ask about systemd setup
    setup_systemd
    
    echo ""
    log_info "Return to menu..."
    sleep 2
    show_menu
}

# Do update
do_update() {
    log_info "Starting update..."
    echo ""
    
    # Check if git repository exists
    if [ ! -d ".git" ]; then
        log_error "Not a git repository. Cannot update."
        echo ""
        log_info "Return to menu..."
        sleep 2
        show_menu
        return
    fi
    
    # Stop service if running
    systemctl stop telegram-proxy-bot 2>/dev/null || true
    
    # Pull latest changes
    log_info "Pulling latest changes from GitHub..."
    git fetch --quiet
    git reset --hard origin/master --quiet
    git pull --quiet
    
    # Install/update npm dependencies
    log_info "Updating npm dependencies..."
    npm install --silent
    
    # Restart service if it was running
    if systemctl is-active --quiet telegram-proxy-bot; then
        systemctl start telegram-proxy-bot
        log_info "Bot service restarted"
    fi
    
    echo ""
    echo "=========================================="
    echo "  Update Complete!"
    echo "=========================================="
    echo ""
    log_info "The bot has been updated to the latest version."
    log_info "Run 'npm run bot' to start (or check systemd service)"
    echo ""
    
    log_info "Return to menu..."
    sleep 2
    show_menu
}

# Do uninstall
do_uninstall() {
    log_warn "This will uninstall the bot and remove all data!"
    echo ""
    read -p "Are you sure? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        echo ""
        log_info "Return to menu..."
        sleep 2
        show_menu
        return
    fi
    
    # Stop and disable systemd service
    log_info "Stopping systemd service..."
    systemctl stop telegram-proxy-bot 2>/dev/null || true
    systemctl disable telegram-proxy-bot 2>/dev/null || true
    rm -f /etc/systemd/system/telegram-proxy-bot.service
    systemctl daemon-reload
    
    # Remove npm dependencies
    log_info "Removing node_modules..."
    rm -rf node_modules
    
    # Remove data files
    log_info "Removing data files..."
    rm -f proxies_db.json
    rm -f bot_settings.json
    rm -f .env
    rm -f *.txt
    
    # Remove temp files
    rm -f working_proxies_*.txt
    rm -f proxy_checked_*.txt
    
    echo ""
    echo "=========================================="
    echo "  Uninstall Complete!"
    echo "=========================================="
    echo ""
    log_info "The bot has been uninstalled."
    log_warn "Your .git directory and source files are preserved."
    log_warn "To reinstall, run this script again and choose 'Install'"
    echo ""
    
    log_info "Return to menu..."
    sleep 2
    show_menu
}

# Main
main() {
    check_root
    show_menu
}

# Run
main
