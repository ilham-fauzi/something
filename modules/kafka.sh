#!/bin/bash

# Module: Kafka
# Description: Advanced Kafka monitoring for topics, consumer groups, lag, and latency.
# Supports Safety-First Auto-Remediation (Reload/Restart).

module_name="📊 Kafka Monitor"
module_commands=("/kafka_status" "/kafka_lag" "/kafka_members" "/kafka_reload" "/kafka_restart" "/kafka_stop" "/kafka_start")

# Configuration (Defaults)
KAFKA_BROKERS="${KAFKA_BROKERS:-localhost:9092}"
KAFKA_TOPIC="${KAFKA_TOPIC:-}"
KAFKA_GROUP="${KAFKA_GROUP:-}"
KAFKA_MAX_LAG="${KAFKA_MAX_LAG:-1000}"
KAFKA_MAX_LATENCY_SEC="${KAFKA_MAX_LATENCY_SEC:-60}"

# Remediation Config
KAFKA_APP_NAME="${KAFKA_APP_NAME:-}"
KAFKA_APP_MANAGER="${KAFKA_APP_MANAGER:-pm2}" # pm2, systemd, docker, custom
KAFKA_AUTO_FIX="${KAFKA_AUTO_FIX:-false}"

# Metadata for interactive setup
module_vars=(
    "KAFKA_BROKERS:Kafka Bootstrap Servers:localhost:9092"
    "KAFKA_TOPIC:Topic Name to monitor:"
    "KAFKA_GROUP:Consumer Group ID to monitor:"
    "KAFKA_MAX_LAG:Lag threshold for alerts:1000"
    "KAFKA_MAX_LATENCY_SEC:Latency threshold in seconds:60"
    "KAFKA_CHECKS:Checks to enable (lag,members,latency,connectivity):all"
    "KAFKA_APP_NAME:Process name to manage (PM2/Systemd):"
    "KAFKA_APP_MANAGER:Process Manager (pm2/systemd/docker):pm2"
    "KAFKA_AUTO_FIX:Enable Auto-Reload on alert (true/false):false"
)

# Module Dependencies
module_dependencies=("kcat:kcat" "jq")

kafka_setup() {
    echo "🔍 Validating Kafka connectivity..."
    if ! command -v kcat >/dev/null 2>&1; then
        echo "⚠️  kcat not found. Installation will be handled by framework."
    else
        local metadata=$(kcat -L -b "$KAFKA_BROKERS" -t "$KAFKA_TOPIC" -C -e -q 2>&1)
        if [[ "$metadata" == *"Failed to resolve"* ]] || [[ "$metadata" == *"Connection refused"* ]]; then
            echo "❌ Error: Cannot connect to Kafka brokers at $KAFKA_BROKERS"
            return 1
        fi
        echo "✅ Kafka connectivity verified."
    fi
    return 0
}

kafka_get_metrics() {
    # Fetch offset information
    # Returns: partition|current_offset|log_end_offset|lag|timestamp
    kcat -b "$KAFKA_BROKERS" -G "$KAFKA_GROUP" "$KAFKA_TOPIC" -L | grep "partition" # Simplified placeholder for actual logic
}

# Selective Checks Control
# Default to all if not set
KAFKA_CHECKS="${KAFKA_CHECKS:-lag,members,latency}"

kafka_check() {
    [ -z "$KAFKA_TOPIC" ] || [ -z "$KAFKA_GROUP" ] && return 0
    local alerts=()

    # 1. Connectivity Check (Implicitly needed for others, but can be standalone)
    if [[ "$KAFKA_CHECKS" == *"all"* ]] || [[ "$KAFKA_CHECKS" == *"connectivity"* ]]; then
        local metadata=$(kcat -b "$KAFKA_BROKERS" -L -t "$KAFKA_TOPIC" -q -e 2>&1)
        if [ $? -ne 0 ]; then
            echo "CRITICAL: Kafka Broker unreachable at <code>$KAFKA_BROKERS</code>"
            return 1
        fi
    fi

    # 2. Member Monitoring
    if [[ "$KAFKA_CHECKS" == *"all"* ]] || [[ "$KAFKA_CHECKS" == *"members"* ]]; then
        local group_info=$(kcat -b "$KAFKA_BROKERS" -L -J 2>/dev/null | jq -c '.groups[] | select(.group == "'$KAFKA_GROUP'")')
        local member_count=$(echo "$group_info" | jq '.members | length')

        if [ "$member_count" -eq 0 ]; then
            alerts+=("Consumer group <code>$KAFKA_GROUP</code> has <b>0 members</b>")
        fi
    fi

    # 3. Lag Monitoring
    if [[ "$KAFKA_CHECKS" == *"all"* ]] || [[ "$KAFKA_CHECKS" == *"lag"* ]]; then
        # Logic to get lag via kcat:
        # Compare partition High Watermark with Group Offset
        # Note: kcat -G -L is the standard way to get offsets for a group
        local total_lag=0
        
        # Real-time lag fetch (sum of lag across all partitions)
        # Using a more accurate kcat command to fetch partition offsets
        local offsets=$(kcat -b "$KAFKA_BROKERS" -G "$KAFKA_GROUP" "$KAFKA_TOPIC" -L -J 2>/dev/null | jq '.topics[0].partitions')
        if [ -n "$offsets" ] && [ "$offsets" != "null" ]; then
            total_lag=$(echo "$offsets" | jq '[.[] | .query_offset - .next_offset] | map(select(. > 0)) | add // 0' | awk '{print ($1 < 0) ? -$1 : $1}')
            # Note: next_offset is where the consumer is, query_offset is the end
            # Lag = query_offset - next_offset
        fi

        if [ "$total_lag" -gt "$KAFKA_MAX_LAG" ]; then
            alerts+=("High lag detected: <b>$total_lag</b> (Threshold: $KAFKA_MAX_LAG)")
        fi
    fi

    # 4. Latency Monitoring
    if [[ "$KAFKA_CHECKS" == *"all"* ]] || [[ "$KAFKA_CHECKS" == *"latency"* ]]; then
        local last_ts=$(kcat -b "$KAFKA_BROKERS" -C -t "$KAFKA_TOPIC" -p 0 -o -1 -c 1 -T -q 2>/dev/null | jq -r '.timestamp')
        if [ -n "$last_ts" ] && [ "$last_ts" != "null" ]; then
            local now=$(date +%s)
            local ts_sec=$(( last_ts / 1000 ))
            local latency=$(( now - ts_sec ))
            
            if [ "$latency" -gt "$KAFKA_MAX_LATENCY_SEC" ]; then
                alerts+=("High latency: <b>${latency}s</b> (Threshold: ${KAFKA_MAX_LATENCY_SEC}s)")
            fi
        fi
    fi

    # Final result aggregation
    if [ ${#alerts[@]} -gt 0 ]; then
        # Join alerts with line breaks
        local combined_alert=$(IFS=$'\n'; echo "${alerts[*]}")
        echo "$combined_alert"
        return 1
    fi

    return 0
}


kafka_remediate() {
    local action=${1:-"reload"} # reload, restart, stop, start
    
    if [ -z "$KAFKA_APP_NAME" ]; then
        echo "Error: KAFKA_APP_NAME not configured for remediation."
        return 1
    fi

    log_info "Kafka Module: Triggering $action for $KAFKA_APP_NAME"
    app_manage_action "$action" "$KAFKA_APP_NAME" "$KAFKA_APP_MANAGER"
    return $?
}

kafka_handle_command() {
    local cmd=$1
    case "$cmd" in
        "/kafka_status")
            # Fetch status info
            local group_info=$(kcat -b "$KAFKA_BROKERS" -L -J | jq -c '.groups[] | select(.group == "'$KAFKA_GROUP'")')
            local members=$(echo "$group_info" | jq '.members | length')
            local state=$(echo "$group_info" | jq -r '.state')

            echo "<b>$module_name</b>
            
📍 <b>Brokers:</b> <code>$KAFKA_BROKERS</code>
📁 <b>Topic:</b> <code>$KAFKA_TOPIC</code>
👥 <b>Group:</b> <code>$KAFKA_GROUP</code>
🚦 <b>State:</b> $state
👤 <b>Members:</b> $members
⚙️  <b>Manager:</b> $KAFKA_APP_MANAGER ($KAFKA_APP_NAME)"
            ;;
        "/kafka_lag")
            echo "📊 <b>Kafka Lag Breakdown</b>
            
[Calculating partition offsets...]"
            # Detailed lag logic would go here
            ;;
        "/kafka_members")
            local group_info=$(kcat -b "$KAFKA_BROKERS" -L -J | jq -c '.groups[] | select(.group == "'$KAFKA_GROUP'")')
            local member_list=$(echo "$group_info" | jq -r '.members[] | "• \(.client_id) (@\(.client_host))"')
            echo "👥 <b>Active Members in $KAFKA_GROUP</b>:
            
$member_list"
            ;;
        "/kafka_reload")
            echo "🔄 <b>Manual Safe Reload</b> triggered for <code>$KAFKA_APP_NAME</code>..."
            local out=$(kafka_remediate "reload")
            if [ $? -eq 0 ]; then
                echo "✅ Reload successful."
            else
                echo "❌ Reload failed: <code>$out</code>"
            fi
            ;;
        "/kafka_restart")
            echo "⚡️ <b>Manual Force Restart</b> triggered for <code>$KAFKA_APP_NAME</code>..."
            local out=$(kafka_remediate "restart")
            if [ $? -eq 0 ]; then
                echo "✅ Restart successful."
            else
                echo "❌ Restart failed: <code>$out</code>"
            fi
            ;;
        "/kafka_stop")
            echo "🛑 <b>Manual Stop</b> triggered for <code>$KAFKA_APP_NAME</code>..."
            local out=$(kafka_remediate "stop")
            if [ $? -eq 0 ]; then
                echo "✅ Service stopped."
            else
                echo "❌ Stop failed: <code>$out</code>"
            fi
            ;;
        "/kafka_start")
            echo "▶️ <b>Manual Start</b> triggered for <code>$KAFKA_APP_NAME</code>..."
            local out=$(kafka_remediate "start")
            if [ $? -eq 0 ]; then
                echo "✅ Service started."
            else
                echo "❌ Start failed: <code>$out</code>"
            fi
            ;;
    esac
}
