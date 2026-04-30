#!/bin/bash

# Telegram API helper functions

TELEGRAM_API="https://api.telegram.org/bot$TOKEN"

send_message() {
    local text=$1
    local parse_mode=${2:-"HTML"}
    local chat_id=${3:-$CHAT_ID}

    curl -s -X POST "$TELEGRAM_API/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$text" \
        -d parse_mode="$parse_mode" > /dev/null
}

# Get latest updates
get_updates() {
    local offset=$1
    curl -s "$TELEGRAM_API/getUpdates?offset=$offset&timeout=30"
}

# Extract command from message
# Returns the first word if it starts with /
extract_command() {
    local text=$1
    if [[ "$text" == /* ]]; then
        echo "$text" | cut -d' ' -f1 | cut -d'@' -f1
    else
        echo ""
    fi
}
