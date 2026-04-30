#!/bin/bash

# 'Something' Framework Engine
# Handles module loading, Telegram polling, and health checks

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/config/something.conf"
source "$DIR/lib/utils.sh"
source "$DIR/lib/telegram.sh"

# Global state
LAST_UPDATE_ID=0

# Load Modules
load_modules() {
    log_info "Loading modules..."
    IFS=',' read -ra ADDR <<< "$ENABLED_MODULES"
    for module in "${ADDR[@]}"; do
        local mod_path="$DIR/modules/$module.sh"
        if [ -f "$mod_path" ]; then
            source "$mod_path"
            log_info "Module loaded: $module"
        else
            log_warn "Module not found: $module"
        fi
    done
}

# Process Telegram Messages
process_messages() {
    local updates=$(get_updates $((LAST_UPDATE_ID + 1)))
    local results=$(echo "$updates" | jq -c ".result[]")

    if [ -z "$results" ]; then return; fi

    while read -r update; do
        local update_id=$(echo "$update" | jq -r ".update_id")
        LAST_UPDATE_ID=$update_id
        
        local text=$(echo "$update" | jq -r ".message.text")
        local chat_id=$(echo "$update" | jq -r ".message.chat.id")
        local cmd=$(extract_command "$text")

        if [ -n "$cmd" ]; then
            log_info "Command received: $cmd from $chat_id"
            handle_core_commands "$cmd" "$chat_id" || handle_module_commands "$cmd" "$chat_id"
        fi
    done <<< "$results"
}

handle_core_commands() {
    local cmd=$1
    local chat_id=$2
    case "$cmd" in
        "/start"|"/help")
            local help_msg="<b>Welcome to Something Framework</b>
            
Available Commands:
/status - System & App status
/logs   - Recent logs
/restart - Restart apps
/help   - Show this message"
            send_message "$help_msg" "HTML" "$chat_id"
            return 0
            ;;
    esac
    return 1
}

handle_module_commands() {
    local cmd=$1
    local chat_id=$2
    
    # Iterate through loaded modules
    IFS=',' read -ra ADDR <<< "$ENABLED_MODULES"
    for module in "${ADDR[@]}"; do
        # Each module defines module_commands array
        # We need to check if cmd is in that array
        # Note: Since we source them, we need a way to distinguish them.
        # For simplicity in this bash version, we'll just check the handler.
        # In a more advanced version, we'd use namespaces.
        
        # We'll just call the module's handler and let it decide
        local response=$(module_handle_command "$cmd")
        if [ -n "$response" ]; then
            send_message "$response" "HTML" "$chat_id"
            return 0
        fi
    done
}

# Periodic Health Checks
run_health_checks() {
    log_info "Running health checks..."
    IFS=',' read -ra ADDR <<< "$ENABLED_MODULES"
    for module in "${ADDR[@]}"; do
        local alert=$(module_check)
        if [ $? -ne 0 ]; then
            log_warn "Health check failed in $module: $alert"
            send_message "⚠️ <b>Alert from $module</b>: $alert"
        fi
    done
}

# Main Loop
main() {
    log_info "Starting 'Something' Engine..."
    load_modules
    send_message "🚀 <b>'Something' Monitoring Framework is UP</b>"

    local last_check=0
    while true; do
        process_messages
        
        local now=$(date +%s)
        if (( now - last_check >= CHECK_INTERVAL )); then
            run_health_checks
            last_check=$now
        fi
        
        sleep 2
    done
}

main
