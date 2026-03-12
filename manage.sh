#!/bin/bash

# Telegram MTProto Proxy Checker Bot - Management Menu
# This script provides an interactive menu for bot management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    clear
    echo ""
    echo "=========================================="
    echo "  Telegram MTProto Proxy Checker Bot"
    echo "  Management Menu"
    echo "=========================================="
    echo ""
    log_menu "Please select an option:"
    echo ""
    echo "  1) 📝 Add/Change Bot Token"
    echo "  2) 👤 Add/Change Admin ID"
    echo "  3) 🔄 Update Bot from GitHub"
    echo "  4) 🚀 Start Bot"
    echo "  5) 🛑 Stop Bot"
    echo "  6) 📊 View Bot Status"
    echo "  7) 🗑️ Uninstall Bot"
    echo "  8) 📖 View Documentation"
    echo "  9) ❌ Exit"
    echo ""
    read -p "Enter choice [1-9]: " choice
    echo ""
    
    case $choice in
        1) set_bot_token ;;
        2) set_admin_id ;;
        3) update_bot ;;
        4) start_bot ;;
        5) stop_bot ;;
        6) view_status ;;
        7) uninstall_bot ;;
        8) view_docs ;;
        9) exit 0 ;;
        *) log_error "Invalid option"; sleep 2; show_menu ;;
    esac
}

# Set bot token
set_bot_token() {
    echo ""
    echo "=========================================="
    echo "  Add/Change Bot Token"
    echo "=========================================="
    echo ""
    
    # Show current token (masked)
    if [ -f ".env" ]; then
        current_token=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d'=' -f2)
        if [ -n "$current_token" ]; then
            masked="${current_token:0:10}...${current_token: -5}"
            log_info "Current token: $masked"
        else
            log_warn "No token set"
        fi
    else
        log_warn "No .env file found"
    fi
    
    echo ""
    echo "Get your token from @BotFather in Telegram"
    echo ""
    read -p "Enter new bot token: " new_token
    
    if [ -z "$new_token" ]; then
        log_error "Token cannot be empty"
        sleep 2
        show_menu
        return
    fi
    
    # Create or update .env
    if [ -f ".env" ]; then
        # Remove existing token line
        grep -v "^TELEGRAM_BOT_TOKEN=" .env > .env.tmp || true
        mv .env.tmp .env
    else
        touch .env
    fi
    
    # Add new token
    echo "TELEGRAM_BOT_TOKEN=$new_token" >> .env
    
    log_info "Bot token updated!"
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Set admin ID
set_admin_id() {
    echo ""
    echo "=========================================="
    echo "  Add/Change Admin ID"
    echo "=========================================="
    echo ""
    
    # Show current admin ID
    if [ -f ".env" ]; then
        current_admin=$(grep "^ADMIN_ID=" .env 2>/dev/null | cut -d'=' -f2)
        if [ -n "$current_admin" ]; then
            log_info "Current Admin ID: $current_admin"
        else
            log_warn "No Admin ID set"
        fi
    else
        log_warn "No .env file found"
    fi
    
    echo ""
    echo "Get your ID from @userinfobot in Telegram"
    echo ""
    read -p "Enter new Admin ID (or press Enter to skip): " new_admin
    
    if [ -z "$new_admin" ]; then
        log_info "Admin ID unchanged"
        sleep 1
        show_menu
        return
    fi
    
    # Create or update .env
    if [ -f ".env" ]; then
        # Remove existing admin line
        grep -v "^ADMIN_ID=" .env > .env.tmp || true
        mv .env.tmp .env
    else
        touch .env
    fi
    
    # Add new admin ID
    echo "ADMIN_ID=$new_admin" >> .env
    
    log_info "Admin ID updated!"
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Update bot
update_bot() {
    echo ""
    echo "=========================================="
    echo "  Update Bot from GitHub"
    echo "=========================================="
    echo ""
    
    if [ ! -d ".git" ]; then
        log_error "Not a git repository. Cannot update."
        sleep 2
        show_menu
        return
    fi
    
    log_info "Pulling latest changes from GitHub..."
    
    # Stop bot if running via systemd
    systemctl stop telegram-proxy-bot 2>/dev/null || true
    
    # Pull changes
    if git fetch --quiet && git reset --hard origin/master --quiet && git pull --quiet; then
        log_info "Repository updated!"
        
        # Download manage.sh if not present
        if [ ! -f "manage.sh" ]; then
            log_info "Downloading manage.sh..."
            curl -sL "https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/manage.sh" -o manage.sh 2>/dev/null && chmod +x manage.sh && log_info "✅ manage.sh downloaded"
        fi
        
        log_info "Installing npm dependencies..."
        npm install --silent
        log_info "Dependencies updated!"
        
        # Restart systemd if it was running
        if systemctl is-active --quiet telegram-proxy-bot; then
            systemctl start telegram-proxy-bot
            log_info "Bot service restarted"
        else
            log_info "Update complete! Start the bot with option 4"
        fi
    else
        log_error "Failed to update repository"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Start bot
start_bot() {
    echo ""
    echo "=========================================="
    echo "  Start Bot"
    echo "=========================================="
    echo ""
    
    # Check if .env exists and has token
    if [ ! -f ".env" ]; then
        log_error ".env file not found. Please set bot token first (option 1)"
        sleep 2
        show_menu
        return
    fi
    
    token=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d'=' -f2)
    if [ -z "$token" ] || [ "$token" = "your-bot-token-here" ]; then
        log_error "Bot token not set. Please set it first (option 1)"
        sleep 2
        show_menu
        return
    fi
    
    # Check if systemd service exists
    if [ -f "/etc/systemd/system/telegram-proxy-bot.service" ]; then
        log_info "Starting bot via systemd..."
        systemctl start telegram-proxy-bot
        log_info "Bot started!"
        systemctl status telegram-proxy-bot --no-pager -l
    else
        log_info "Starting bot in foreground..."
        log_warn "Press Ctrl+C to stop"
        echo ""
        node bot.js
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Stop bot
stop_bot() {
    echo ""
    echo "=========================================="
    echo "  Stop Bot"
    echo "=========================================="
    echo ""
    
    if systemctl is-active --quiet telegram-proxy-bot 2>/dev/null; then
        log_info "Stopping systemd service..."
        systemctl stop telegram-proxy-bot
        log_info "Bot stopped!"
    else
        # Try to kill node process
        pkill -f "node bot.js" 2>/dev/null && log_info "Bot process killed!" || log_warn "No running bot found"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# View status
view_status() {
    echo ""
    echo "=========================================="
    echo "  Bot Status"
    echo "=========================================="
    echo ""
    
    # Check .env
    if [ -f ".env" ]; then
        log_info "Configuration:"
        token=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d'=' -f2)
        admin=$(grep "^ADMIN_ID=" .env 2>/dev/null | cut -d'=' -f2)
        
        if [ -n "$token" ] && [ "$token" != "your-bot-token-here" ]; then
            masked="${token:0:10}...${token: -5}"
            echo "  Bot Token: $masked ✅"
        else
            echo "  Bot Token: Not set ❌"
        fi
        
        if [ -n "$admin" ]; then
            echo "  Admin ID: $admin ✅"
        else
            echo "  Admin ID: Not set ⚠️"
        fi
    else
        log_warn ".env file not found"
    fi
    
    echo ""
    
    # Check systemd service
    if [ -f "/etc/systemd/system/telegram-proxy-bot.service" ]; then
        log_info "Systemd Service:"
        if systemctl is-active --quiet telegram-proxy-bot; then
            echo "  Status: Running ✅"
        else
            echo "  Status: Stopped ❌"
        fi
        systemctl status telegram-proxy-bot --no-pager -l 2>/dev/null || true
    else
        log_warn "Systemd service not installed"
    fi
    
    echo ""
    
    # Check node_modules
    if [ -d "node_modules" ]; then
        echo "  Dependencies: Installed ✅"
    else
        echo "  Dependencies: Not installed ❌"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Uninstall bot
uninstall_bot() {
    echo ""
    echo "=========================================="
    echo "  Uninstall Bot"
    echo "=========================================="
    echo ""
    
    log_warn "This will:"
    echo "  - Stop and remove systemd service"
    echo "  - Remove node_modules"
    echo "  - Remove data files (proxies_db.json, bot_settings.json)"
    echo "  - Remove .env file"
    echo ""
    log_warn "Source files will be preserved!"
    echo ""
    
    read -p "Are you sure? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        sleep 2
        show_menu
        return
    fi
    
    # Stop service
    systemctl stop telegram-proxy-bot 2>/dev/null || true
    systemctl disable telegram-proxy-bot 2>/dev/null || true
    rm -f /etc/systemd/system/telegram-proxy-bot.service
    systemctl daemon-reload
    log_info "Service removed"
    
    # Remove files
    rm -rf node_modules
    rm -f proxies_db.json
    rm -f bot_settings.json
    rm -f .env
    rm -f *.txt
    
    log_info "Files removed"
    
    echo ""
    echo "=========================================="
    echo "  Uninstall Complete!"
    echo "=========================================="
    echo ""
    log_info "To reinstall, run install-auto.sh again"
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# View documentation
view_docs() {
    echo ""
    echo "=========================================="
    echo "  Documentation"
    echo "=========================================="
    echo ""
    echo "Available documentation files:"
    echo ""
    
    if [ -f "README.md" ]; then
        echo "  📄 README.md - Main documentation"
    fi
    if [ -f "AUTO_START.md" ]; then
        echo "  📄 AUTO_START.md - Auto-start guide"
    fi
    if [ -f "PROJECT_SUMMARY.md" ]; then
        echo "  📄 PROJECT_SUMMARY.md - Project overview"
    fi
    if [ -f "CONTRIBUTING.md" ]; then
        echo "  📄 CONTRIBUTING.md - Contributing guide"
    fi
    
    echo ""
    read -p "View which file? (1-4, or Enter to skip): " doc_choice
    
    case $doc_choice in
        1) less README.md ;;
        2) less AUTO_START.md ;;
        3) less PROJECT_SUMMARY.md ;;
        4) less CONTRIBUTING.md ;;
    esac
    
    show_menu
}

# Main
main() {
    show_menu
}

# Run
main
