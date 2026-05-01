#!/bin/bash

# Utility functions for 'Something' framework

log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# Wrapper for jq to safely extract values from JSON
get_json_val() {
    local json=$1
    local key=$2
    echo "$json" | jq -r "$key" 2>/dev/null
}

# Format bytes to human readable size
format_bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        awk -v b="$bytes" 'BEGIN {printf "%.2fKB\n", b/1024}'
    elif [[ $bytes -lt 1073741824 ]]; then
        awk -v b="$bytes" 'BEGIN {printf "%.2fMB\n", b/1048576}'
    else
        awk -v b="$bytes" 'BEGIN {printf "%.2fGB\n", b/1073741824}'
    fi
}

# Check if a command exists, if not try to install it
check_package() {
    local cmd=$1
    local pkg_name=${2:-$cmd}
    local custom_install_cmd=$3
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ $cmd is already installed."
        return 0
    else
        echo "⚠️  $cmd not found. Attempting to install $pkg_name..."
        if [ -n "$custom_install_cmd" ]; then
            eval "$custom_install_cmd"
            return $?
        fi

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt update -y && sudo apt install -y "$pkg_name"
            return $?
        else
            echo "❌ Automatic install only supported on Linux (apt). Please install $pkg_name manually."
            return 1
        fi
    fi
}

# Install a list of dependencies
install_dependencies() {
    local deps=("$@")
    for dep in "${deps[@]}"; do
        if [[ "$dep" == *":"* ]]; then
            local cmd=$(echo "$dep" | cut -d':' -f1)
            local pkg=$(echo "$dep" | cut -d':' -f2)
            check_package "$cmd" "$pkg"
        else
            check_package "$dep"
        fi
    done
}
# Encryption/Decryption Helpers
encrypt_file() {
    local input=$1
    local output=$2
    local pass=$3
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$input" -out "$output" -pass "pass:$pass" 2>/dev/null
}

decrypt_file() {
    local input=$1
    local pass=$2
    openssl enc -aes-256-cbc -d -salt -pbkdf2 -in "$input" -pass "pass:$pass" 2>/dev/null
}

load_config() {
    local base_dir=${1:-$DIR}
    local conf_file="$base_dir/config/something.conf"
    local enc_file="$base_dir/config/something.conf.enc"
    
    if [ -f "$conf_file" ]; then
        # Check permissions
        local perms=$(stat -c %a "$conf_file" 2>/dev/null || stat -f %Lp "$conf_file" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            chmod 600 "$conf_file"
            log_info "Corrected permissions for something.conf to 600"
        fi
        source "$conf_file"
        log_info "Configuration loaded from plaintext file"
        return 0
    elif [ -f "$enc_file" ]; then
        local master_key="$MASTER_KEY"
        if [ -z "$master_key" ]; then
            echo "🔐 Config is LOCKED."
            read -s -p "🔑 Enter Master Key to continue: " master_key
            echo ""
        fi
        
        local decrypted_content
        decrypted_content=$(decrypt_file "$enc_file" "$master_key")
        local decrypt_status=$?
        
        if [ $decrypt_status -ne 0 ] || [ -z "$decrypted_content" ]; then
            log_error "Failed to load config: Incorrect key or decryption error (Status: $decrypt_status)"
            echo "❌ Error: Incorrect key or corrupted vault."
            return 1
        fi
        
        eval "$decrypted_content"

        # Security Verification: Cross-check if unlocked via Gatekeeper
        # This prevents 'Identity Hijacking' where boot.conf is modified to use a different bot/chat
        if [ -n "$G_SENDER_ID" ]; then
            # Determine effective authorized list for Gatekeeper
            local authorized_list="$GATEKEEPER_IDS"
            if [ -z "$authorized_list" ] || [ "$authorized_list" == "all" ]; then
                authorized_list="$CHAT_ID"
            fi

            # Support multiple Chat IDs (comma separated)
            if [[ ",$authorized_list," != *",$G_SENDER_ID,"* ]]; then
                log_error "SECURITY ALERT: Gatekeeper sender ($G_SENDER_ID) NOT in authorized list ($authorized_list). ABORTING."
                echo "🚨 SECURITY VIOLATION: Unauthorized Gatekeeper sender ID detected."
                echo "   The system refuses to start because the unlock request came from an untrusted account."
                exit 1
            fi
            log_info "Gatekeeper Sender ID verified against encrypted vault identity ($G_SENDER_ID)."
        fi

        # Export the key for sub-processes
        export MASTER_KEY="$master_key"
        log_info "Configuration loaded from encrypted vault"
        return 0
    else
        log_warn "No configuration file found at $conf_file or $enc_file"
        return 0
    fi
}

update_conf_val() {
    local key=$1
    local val=$2
    local target_file=${3:-"$DIR/config/something.conf"}
    
    # Ensure directory exists
    mkdir -p "$(dirname "$target_file")"
    touch "$target_file"

    if grep -q "^[[:space:]]*$key=" "$target_file"; then
        # Key exists, update it
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^[[:space:]]*$key=.*|$key=\"$val\"|" "$target_file"
        else
            sed -i "s|^[[:space:]]*$key=.*|$key=\"$val\"|" "$target_file"
        fi
    else
        # Key doesn't exist, append it
        if [ -s "$target_file" ] && [ -n "$(tail -c1 "$target_file" 2>/dev/null)" ]; then
            echo "" >> "$target_file"
        fi
        echo "$key=\"$val\"" >> "$target_file"
    fi
    
    # Special case: Sync TOKEN, CHAT_ID, and GATEKEEPER_IDS to boot.conf for Gatekeeper
    if [[ "$key" == "TOKEN" || "$key" == "CHAT_ID" || "$key" == "GATEKEEPER_IDS" ]] && [[ "$target_file" == *"/config/something.conf" ]]; then
        update_conf_val "$key" "$val" "$DIR/config/boot.conf"
    fi

    # Update current shell variable
    printf -v "$key" "%s" "$val"
}

# Registry: Resolve short name to Git URL
resolve_module_url() {
    local name=$1
    case "$name" in
        "redis") echo "https://github.com/something-framework/module-redis.git" ;;
        "pm2")   echo "https://github.com/something-framework/module-pm2.git" ;;
        "mysql") echo "https://github.com/something-framework/module-mysql.git" ;;
        "nginx") echo "https://github.com/something-framework/module-nginx.git" ;;
        "docker") echo "https://github.com/something-framework/module-docker.git" ;;
        *) return 1 ;;
    esac
    return 0
}

# Generic application management (PM2, Systemd, Docker)
# Usage: app_manage_action <action> <app_name> <manager>
# Actions: reload, restart, stop, start
app_manage_action() {
    local action=$1
    local app_name=$2
    local manager=$3
    local result=""

    log_info "Executing $action on $app_name via $manager"

    case "$manager" in
        "pm2")
            if ! command -v pm2 >/dev/null 2>&1; then
                echo "Error: pm2 not found"
                return 1
            fi
            case "$action" in
                "reload")  result=$(pm2 reload "$app_name" 2>&1) ;;
                "restart") result=$(pm2 restart "$app_name" 2>&1) ;;
                "stop")    result=$(pm2 stop "$app_name" 2>&1) ;;
                "start")   result=$(pm2 start "$app_name" 2>&1) ;;
            esac
            ;;
        "systemd")
            case "$action" in
                "reload")  result=$(sudo systemctl reload "$app_name" 2>&1) ;;
                "restart") result=$(sudo systemctl restart "$app_name" 2>&1) ;;
                "stop")    result=$(sudo systemctl stop "$app_name" 2>&1) ;;
                "start")   result=$(sudo systemctl start "$app_name" 2>&1) ;;
            esac
            ;;
        "docker")
            case "$action" in
                "reload")  result=$(docker kill -s HUP "$app_name" 2>&1) ;;
                "restart") result=$(docker restart "$app_name" 2>&1) ;;
                "stop")    result=$(docker stop "$app_name" 2>&1) ;;
                "start")   result=$(docker start "$app_name" 2>&1) ;;
            esac
            ;;
        "custom")
            # For custom, we assume app_name is the full command or path to script
            result=$(eval "$app_name $action" 2>&1)
            ;;
        *)
            echo "Error: Unknown manager '$manager'"
            return 1
            ;;
    esac

    local status=$?
    if [ $status -eq 0 ]; then
        return 0
    else
        echo "$result"
        return $status
    fi
}

