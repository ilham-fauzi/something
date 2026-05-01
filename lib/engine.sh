#!/bin/bash

# 'Something' Framework Engine
# Handles module loading, Telegram polling, and health checks

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$DIR/logs/something.log"
source "$DIR/lib/utils.sh"
load_config "$DIR" || { log_error "Failed to load configuration. Engine exiting."; exit 1; }
# Security: Unset MASTER_KEY from environment after successful load
unset MASTER_KEY
source "$DIR/lib/telegram.sh"

# Global state
LAST_UPDATE_ID=0

# Load Modules
load_modules() {
    local requested_modules=$@
    log_info "Loading modules..."
    
    local modules_to_load=""
    if [ -n "$requested_modules" ]; then
        # Use modules provided in arguments
        modules_to_load=$(echo "$requested_modules" | tr ' ' ',')
        # Update ENABLED_MODULES globally for this session so other functions use it
        ENABLED_MODULES="$modules_to_load"
    else
        # Use modules from config
        modules_to_load="$ENABLED_MODULES"
    fi

    IFS=',' read -ra ADDR <<< "$modules_to_load"
    for module in "${ADDR[@]}"; do
        module=$(echo "$module" | xargs) # Trim whitespace
        [ -z "$module" ] && continue
        
        local mod_file="$DIR/modules/$module.sh"
        local mod_dir_file="$DIR/modules/$module/module.sh"
        local mod_path=""

        if [ -f "$mod_file" ]; then
            mod_path="$mod_file"
        elif [ -f "$mod_dir_file" ]; then
            mod_path="$mod_dir_file"
        fi

        if [ -n "$mod_path" ]; then
            # Collision Detection: Check if namespaced functions already exist
            if declare -f "${module}_check" > /dev/null; then
                log_warn "Collision Warning: Module functions for '$module' already defined. Overwriting..."
            fi
            
            source "$mod_path"
            log_info "Module loaded: $module (via $mod_path)"
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
    
    IFS=',' read -ra ADDR <<< "$ENABLED_MODULES"
    for module in "${ADDR[@]}"; do
        module=$(echo "$module" | xargs)
        [ -z "$module" ] && continue
        
        # Prefer namespaced handler: [module]_handle_command
        # Fallback to legacy: module_handle_command (not recommended for multiple modules)
        local response=""
        if declare -f "${module}_handle_command" > /dev/null; then
            response=$("${module}_handle_command" "$cmd")
        elif declare -f "module_handle_command" > /dev/null; then
            response=$(module_handle_command "$cmd")
        fi

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
        [ -z "$module" ] && continue
        
        local alert=""
        if declare -f "${module}_check" > /dev/null; then
            alert=$("${module}_check")
        elif declare -f "module_check" > /dev/null; then
            alert=$(module_check)
        fi

        if [ $? -ne 0 ] && [ -n "$alert" ]; then
            log_warn "Health check failed in $module: $alert"
            
            # Check for auto-remediation
            local auto_fix_var=$(echo "${module}_AUTO_FIX" | tr '[:lower:]' '[:upper:]')
            if [[ "${!auto_fix_var}" == "true" ]] && declare -f "${module}_remediate" > /dev/null; then
                send_message "⚠️ <b>Alert from $module</b>: $alert\n\n🛠 <b>Auto-Remediation</b>: Attempting safe reload..."
                local fix_result=$("${module}_remediate" "reload")
                if [ $? -eq 0 ]; then
                    send_message "✅ <b>Auto-Remediation Success</b> ($module): System restored."
                else
                    send_message "❌ <b>Auto-Remediation Failed</b> ($module): $fix_result"
                fi
            else
                send_message "⚠️ <b>Alert from $module</b>: $alert"
            fi
        fi
    done
}


# Main Loop
main() {
    log_info "Starting 'Something' Engine..."
    load_modules "$@"
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

main "$@"
