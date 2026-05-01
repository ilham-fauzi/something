#!/bin/bash

# Module: System
# Description: Monitor system resources (CPU, RAM, Disk)

module_name="🖥 System Monitor"
module_commands=("/system" "/top")

# Configuration (Defaults)
RAM_THRESHOLD="${RAM_THRESHOLD:-95}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"


# Metadata for interactive setup
module_vars=(
    "RAM_THRESHOLD:RAM Alert Threshold (%):95"
    "DISK_THRESHOLD:Disk Alert Threshold (%):90"
)

# Module Dependencies
module_dependencies=()


system_setup() {
    echo "Setting up $module_name..."
    return 0
}

system_check() {
    # System health check logic
    local ram_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    if [ "$ram_usage" -gt "$RAM_THRESHOLD" ]; then
        echo "CRITICAL: RAM usage is high ($ram_usage%)"
        return 1
    fi

    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        echo "CRITICAL: Disk usage is high ($disk_usage%)"
        return 1
    fi

    return 0
}

system_handle_command() {
    local cmd=$1
    case "$cmd" in
        "/system")
            local cpu_load=$(top -bn1 | grep "load average" | awk '{print $12 $13 $14}' | sed 's/,//g')
            local ram_info=$(free -h | grep Mem | awk '{print $3 "/" $2}')
            local disk_info=$(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')
            local uptime=$(uptime -p)

            local msg="<b>$module_name</b>
            
📈 <b>CPU Load:</b> $cpu_load
🧠 <b>RAM:</b> $ram_info
💾 <b>Disk:</b> $disk_info
⏱ <b>Uptime:</b> $uptime"
            
            echo "$msg"
            ;;
        "/top")
            local top_procs=$(ps aux --sort=-%cpu | head -6 | awk '{print $11 " (" $3 "%)"}' | tail -n +2)
            echo "<b>🔝 Top Processes:</b>
<pre>$top_procs</pre>"
            ;;
    esac
}
