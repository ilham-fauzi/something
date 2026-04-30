#!/bin/bash

# Module: PM2
# Description: Monitor PM2 processes and app health

module_name="🚀 PM2 Monitor"
module_commands=("/status" "/logs" "/restart")

# Configuration for this module (Defaults)
APP_NAME="${APP_NAME:-v60.pro}"
APP_URL="${APP_URL:-http://localhost:3000}"


# Metadata for interactive setup
module_vars=(
    "APP_NAME:PM2 App Name:v60.pro"
    "APP_URL:App URL:http://localhost:3000"
)

# Module Dependencies
module_dependencies=("jq" "curl")

module_setup() {
    echo "🔍 Checking PM2 installation..."
    if ! command -v pm2 >/dev/null 2>&1; then
        echo "⚠️  PM2 not found. Attempting to install via npm..."
        if command -v npm >/dev/null 2>&1; then
            npm install pm2 -g
        else
            echo "❌ npm not found. Please install Node.js and PM2 manually."
            return 1
        fi
    else
        echo "✅ PM2 is already installed."
    fi
    return 0
}

module_check() {
    # Proactive health check
    local status=$(pm2 jlist | jq -r ".[] | select(.name==\"$APP_NAME\") | .pm2_env.status")
    
    if [ "$status" != "online" ]; then
        echo "ALERT: $APP_NAME is $status! Attempting restart..."
        pm2 restart "$APP_NAME"
        return 1
    fi

    # URL Check
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$APP_URL")
    if [[ "$http_code" == 5* ]]; then
        echo "ALERT: $APP_NAME returned $http_code! Restarting..."
        pm2 restart "$APP_NAME"
        return 1
    fi

    return 0
}

module_handle_command() {
    local cmd=$1
    case "$cmd" in
        "/status")
            local data=$(pm2 jlist | jq -r ".[] | select(.name==\"$APP_NAME\")")
            if [ -z "$data" ]; then
                echo "❌ App <b>$APP_NAME</b> not found in PM2."
                return
            fi

            local status=$(echo "$data" | jq -r ".pm2_env.status")
            local cpu=$(echo "$data" | jq -r ".monit.cpu")
            local mem_bytes=$(echo "$data" | jq -r ".monit.memory")
            local mem=$(format_bytes "$mem_bytes")
            local uptime_ms=$(echo "$data" | jq -r ".pm2_env.pm_uptime")
            local now=$(date +%s%3N)
            local uptime_sec=$(( (now - uptime_ms) / 1000 ))
            local uptime_fmt=$(printf '%dd %dh %dm %ds' $((uptime_sec/86400)) $((uptime_sec%86400/3600)) $((uptime_sec%3600/60)) $((uptime_sec%60)))

            local icon="🟢"
            [ "$status" != "online" ] && icon="🔴"

            echo "<b>$module_name</b>
            
📱 <b>App:</b> $APP_NAME
🚦 <b>Status:</b> $icon $status
⚡ <b>CPU:</b> $cpu%
🧠 <b>Memory:</b> $mem
⏱ <b>Uptime:</b> $uptime_fmt"
            ;;
        "/logs")
            local logs=$(pm2 logs "$APP_NAME" --lines 10 --nostream --raw | tail -c 3000)
            echo "<b>📄 Last Logs for $APP_NAME:</b>
<pre>$logs</pre>"
            ;;
        "/restart")
            pm2 restart "$APP_NAME" > /dev/null
            echo "🔄 App <b>$APP_NAME</b> has been restarted."
            ;;
    esac
}
