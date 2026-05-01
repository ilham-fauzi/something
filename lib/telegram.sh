# Telegram API helper functions
# Note: $TOKEN must be set before calling these functions

get_telegram_api() {
    echo "https://api.telegram.org/bot$TOKEN"
}

send_message() {
    local text=$1
    local parse_mode=${2:-"HTML"}
    local target_ids=${3:-$CHAT_ID}
    local api_url=$(get_telegram_api)

    # Support multiple Chat IDs (comma separated)
    IFS=',' read -ra ADDR <<< "$target_ids"
    for id in "${ADDR[@]}"; do
        # Trim whitespace
        local clean_id=$(echo "$id" | xargs)
        [ -z "$clean_id" ] && continue
        
        curl -s -X POST "$api_url/sendMessage" \
            -d chat_id="$clean_id" \
            -d text="$text" \
            -d parse_mode="$parse_mode" > /dev/null
    done
}

# Get latest updates
get_updates() {
    local offset=$1
    local api_url=$(get_telegram_api)
    curl -s "$api_url/getUpdates?offset=$offset&timeout=30"
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

# --- Setup & Configuration Functions ---

auto_detect_chat_id() {
    local active_token="$TOKEN"
    [ -z "$active_token" ] && { echo "❌ Error: Bot Token not set." >&2; return 1; }

    echo "🔍 Attempting to auto-detect Chat ID..." >&2
    echo "👉 STEP 1: Open your Telegram app." >&2
    echo "👉 STEP 2: Search for your bot." >&2
    echo "👉 STEP 3: Send the command /start to the bot." >&2
    
    while true; do
        read -p "Press ENTER once command is sent (or type 'skip'): " choice < /dev/tty
        [ "$choice" == "skip" ] && return 1
        
        echo "📡 Fetching updates from Telegram..." >&2
        local api_url=$(get_telegram_api)
        local update=$(curl -s "$api_url/getUpdates?limit=5&offset=-1")
        
        local found_id=$(echo "$update" | jq -r '
            .result | reverse | .[] | 
            ( .message.chat.id // .my_chat_member.chat.id // .callback_query.message.chat.id // .channel_post.chat.id )
        ' 2>/dev/null | head -n 1)
        
        if [ "$found_id" != "null" ] && [ -n "$found_id" ]; then
            echo "✅ Found Chat ID: $found_id" >&2
            echo "$found_id"
            return 0
        else
            echo "❌ Could not find any new messages/commands." >&2
            echo "------------------------------------------------" >&2
        fi
    done
}

configure_gatekeeper() {
    # Ensure config is loaded
    [ -z "$CHAT_ID" ] && load_config > /dev/null 2>&1
    
    echo ""
    echo "🛡  Gatekeeper Security Configuration"
    
    # If multiple Chat IDs exist, offer a menu
    if [[ "$CHAT_ID" == *","* ]]; then
        echo "Multiple Chat IDs detected: $CHAT_ID"
        echo "Who should be allowed to unlock the system at boot?"
        echo "1) All authorized users (default)"
        echo "2) Select specific users"
        read -p "Select option [1]: " gk_opt
        
        if [ "$gk_opt" == "2" ]; then
            IFS=',' read -ra ADDR <<< "$CHAT_ID"
            local selected_ids=()
            for i in "${!ADDR[@]}"; do
                local cid=$(echo "${ADDR[$i]}" | xargs)
                read -p "   Allow $cid? (y/n) [n]: " allow_cid
                if [[ "$allow_cid" =~ ^[Yy]$ ]]; then
                    selected_ids+=("$cid")
                fi
            done
            
            if [ ${#selected_ids[@]} -eq 0 ]; then
                echo "⚠️  No users selected. Defaulting to ALL users."
                update_conf_val "GATEKEEPER_IDS" "all"
            else
                local combined_ids=$(IFS=,; echo "${selected_ids[*]}")
                update_conf_val "GATEKEEPER_IDS" "$combined_ids"
                echo "✅ Gatekeeper restricted to: $combined_ids"
            fi
        else
            update_conf_val "GATEKEEPER_IDS" "all"
            echo "✅ All users can act as Gatekeepers."
        fi
    else
        # Only one user, they are the default gatekeeper
        update_conf_val "GATEKEEPER_IDS" "all"
    fi
}

sequential_telegram_config() {
    # Refresh config
    load_config || return 1
    echo ""
    echo "⚙️  Telegram Configuration"
    echo "-------------------------"
    
    # 1. Bot Token
    local current_token="$TOKEN"
    local display_token="${current_token:0:10}..."
    [ -z "$current_token" ] && display_token="None"
    
    read -p "Bot Token [$display_token]: " new_token
    new_token=$(echo "$new_token" | xargs) # Trim whitespace
    if [ -n "$new_token" ]; then
        update_conf_val "TOKEN" "$new_token"
        echo "✅ Bot Token updated."
    fi

    # 2. Chat ID
    local current_id="$CHAT_ID"
    [ -z "$current_id" ] && current_id="None"
    
    echo "💡 Note: You can enter multiple Chat IDs separated by comma (e.g. 123,456)"
    read -p "Chat ID [$current_id] (Type 'auto' to detect): " new_id
    new_id=$(echo "$new_id" | xargs) # Trim whitespace
    if [ -n "$new_id" ]; then
        if [ "$new_id" == "auto" ]; then
            local found=$(auto_detect_chat_id)
            if [ -n "$found" ]; then
                # If existing ID exists, ask if user wants to append
                if [ -n "$CHAT_ID" ] && [ "$CHAT_ID" != "None" ]; then
                    read -p "Append to existing IDs? (y/n) [default: y]: " append
                    if [[ ! "$append" =~ ^[Nn]$ ]]; then
                        new_id="$CHAT_ID,$found"
                    else
                        new_id="$found"
                    fi
                else
                    new_id="$found"
                fi
                update_conf_val "CHAT_ID" "$new_id"
            fi
        else
            update_conf_val "CHAT_ID" "$new_id"
            echo "✅ Chat ID updated."
        fi
    fi

    # 3. Gatekeeper Selective IDs
    configure_gatekeeper
}
