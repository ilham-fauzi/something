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
