#!/bin/bash

# Module: Redis
# Description: Monitor Redis server health
# Dependencies: redis-tools (for redis-cli)

module_name="⚡️ Redis Monitor"
module_commands=("/redis_status" "/redis_ping")

# Configuration (Defaults)
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASS="${REDIS_PASS:-}"

# Metadata for interactive setup
module_vars=(
    "REDIS_HOST:Redis Host:127.0.0.1"
    "REDIS_PORT:Redis Port:6379"
    "REDIS_PASS:Redis Password (optional):"
)

# Module Dependencies
module_dependencies=("redis-tools")

redis_setup() {
    echo "🔍 Checking Redis tools..."
    if ! command -v redis-cli >/dev/null 2>&1; then
        echo "⚠️  redis-cli not found. It will be installed via dependencies."
    else
        echo "✅ redis-cli is already installed."
    fi
    return 0
}

redis_check() {
    # Health check logic
    local auth_cmd=""
    [ -n "$REDIS_PASS" ] && auth_cmd="-a $REDIS_PASS"
    
    local ping_result=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" $auth_cmd ping 2>&1)
    
    if [ "$ping_result" != "PONG" ]; then
        echo "CRITICAL: Redis at $REDIS_HOST:$REDIS_PORT is down! Error: $ping_result"
        return 1
    fi
    
    return 0
}

redis_handle_command() {
    local cmd=$1
    local auth_cmd=""
    [ -n "$REDIS_PASS" ] && auth_cmd="-a $REDIS_PASS"

    case "$cmd" in
        "/redis_status")
            local info=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" $auth_cmd info section server 2>/dev/null)
            if [ -z "$info" ]; then
                echo "❌ Could not connect to Redis at <code>$REDIS_HOST:$REDIS_PORT</code>"
                return
            fi
            
            local version=$(echo "$info" | grep "redis_version:" | cut -d: -f2 | tr -d '\r')
            local uptime=$(echo "$info" | grep "uptime_in_days:" | cut -d: -f2 | tr -d '\r')
            local clients=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" $auth_cmd info clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
            local mem=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" $auth_cmd info memory | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')

            echo "<b>$module_name</b>
            
📍 <b>Host:</b> $REDIS_HOST:$REDIS_PORT
🔢 <b>Version:</b> $version
👥 <b>Clients:</b> $clients
🧠 <b>Memory:</b> $mem
⏱ <b>Uptime:</b> $uptime days"
            ;;
        "/redis_ping")
            local start=$(date +%s%N)
            local ping_result=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" $auth_cmd ping 2>/dev/null)
            local end=$(date +%s%N)
            local duration=$(( (end - start) / 1000000 ))
            
            if [ "$ping_result" == "PONG" ]; then
                echo "🏓 <b>PONG!</b> (Response time: ${duration}ms)"
            else
                echo "❌ <b>FAILED!</b> Could not ping Redis."
            fi
            ;;
    esac
}

