#!/bin/bash
set -e

CLAUDE_DIR="$HOME/.claude"
SCRIPT_PATH="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_PATH="$CLAUDE_DIR/settings.json"
CACHE_DIR="$CLAUDE_DIR/cache"

echo "Installing CC Status Line..."
mkdir -p "$CLAUDE_DIR" "$CACHE_DIR"

cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
input=$(cat)
CACHE_DIR="$HOME/.claude/cache"
mkdir -p "$CACHE_DIR"

json_val() {
    local key="$1" default="$2"
    local flat val
    flat=$(echo "$input" | tr -d '\n')
    val=$(echo "$flat" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -z "$val" ]; then
        val=$(echo "$flat" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9.eE+-]*\).*/\1/p')
    fi
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

format_tokens() {
    local value=$1
    local result
    if [ $value -lt 1000 ]; then
        echo "$value"
    elif [ $value -lt 1000000 ]; then
        result=$(awk "BEGIN {printf \"%.4f\", $value / 1000}" | sed 's/0*$//' | sed 's/\.$//')
        echo "${result}K"
    elif [ $value -lt 1000000000 ]; then
        result=$(awk "BEGIN {printf \"%.4f\", $value / 1000000}" | sed 's/0*$//' | sed 's/\.$//')
        echo "${result}M"
    else
        result=$(awk "BEGIN {printf \"%.4f\", $value / 1000000000}" | sed 's/0*$//' | sed 's/\.$//')
        echo "${result}B"
    fi
}

calculate_today_stats() {
    local session_id="$1" sess_tokens="$2" sess_cost="$3"
    local today_date=$(date +%Y-%m-%d)
    local date_file="$CACHE_DIR/today_date.txt"
    local total_tokens_file="$CACHE_DIR/today_total_tokens.txt"
    local total_cost_file="$CACHE_DIR/today_total_cost.txt"
    local sess_tokens_file="$CACHE_DIR/sess_${session_id}_tokens.txt"
    local sess_cost_file="$CACHE_DIR/sess_${session_id}_cost.txt"

    local stored_date=""
    [ -f "$date_file" ] && stored_date=$(cat "$date_file")
    if [ "$stored_date" != "$today_date" ]; then
        echo "$today_date" > "$date_file"
        echo "0" > "$total_tokens_file"
        echo "0" > "$total_cost_file"
        rm -f "$CACHE_DIR"/sess_*_tokens.txt "$CACHE_DIR"/sess_*_cost.txt
    fi

    local prev_tokens=$(cat "$sess_tokens_file" 2>/dev/null || echo 0)
    local prev_cost=$(cat "$sess_cost_file" 2>/dev/null || echo 0)
    prev_tokens=${prev_tokens:-0}; prev_cost=${prev_cost:-0}

    local needs_update=0
    [ "$sess_tokens" -gt "$prev_tokens" ] 2>/dev/null && needs_update=1
    [ "$(awk "BEGIN {print ($sess_cost > $prev_cost) ? 1 : 0}")" = "1" ] && needs_update=1

    if [ "$needs_update" = "1" ]; then
        local delta_tokens=$((sess_tokens - prev_tokens))
        local delta_cost=$(awk "BEGIN {printf \"%.6f\", $sess_cost - $prev_cost}")
        local cur_total_tokens=$(cat "$total_tokens_file" 2>/dev/null || echo 0)
        local cur_total_cost=$(cat "$total_cost_file" 2>/dev/null || echo 0)
        echo $((cur_total_tokens + delta_tokens)) > "$total_tokens_file"
        awk "BEGIN {printf \"%.6f\", $cur_total_cost + $delta_cost}" > "$total_cost_file"
        echo "$sess_tokens" > "$sess_tokens_file"
        echo "$sess_cost" > "$sess_cost_file"
    fi

    local total_tokens=$(cat "$total_tokens_file" 2>/dev/null || echo 0)
    local total_cost=$(cat "$total_cost_file" 2>/dev/null || echo 0)
    echo "${total_tokens}|${total_cost}"
}

model=$(json_val "display_name" "Claude")
input_tokens=$(json_val "total_input_tokens" "0")
output_tokens=$(json_val "total_output_tokens" "0")
total_tokens=$((input_tokens + output_tokens))
session_cost=$(json_val "total_cost_usd" "0")
session_id=$(json_val "session_id" "unknown")

LAST_FILE="$CACHE_DIR/last_session_${session_id}.txt"
last_tokens=0; last_cost="0"
if [ -f "$LAST_FILE" ]; then
    last_tokens=$(sed -n '1p' "$LAST_FILE")
    last_cost=$(sed -n '2p' "$LAST_FILE")
fi
last_tokens=${last_tokens:-0}; last_cost=${last_cost:-0}
msg_tokens=$((total_tokens - last_tokens))
msg_cost=$(awk "BEGIN {printf \"%.4f\", $session_cost - $last_cost}")
printf '%d\n%s\n' "$total_tokens" "$session_cost" > "$LAST_FILE"

REQ_COUNT_FILE="$CACHE_DIR/req_count_${session_id}.txt"
if [ "$msg_tokens" -gt 0 ] 2>/dev/null; then
    req_count=$(cat "$REQ_COUNT_FILE" 2>/dev/null || echo 0)
    req_count=$((req_count + 1))
    echo "$req_count" > "$REQ_COUNT_FILE"
else
    req_count=$(cat "$REQ_COUNT_FILE" 2>/dev/null || echo 0)
fi

today_stats=$(calculate_today_stats "$session_id" "$total_tokens" "$session_cost")
today_tokens=$(echo "$today_stats" | cut -d'|' -f1)
today_cost=$(echo "$today_stats" | cut -d'|' -f2)

output="${model}"

if [ $msg_tokens -gt 0 ]; then
    msg_tokens_formatted=$(format_tokens $msg_tokens)
    msg_cost_formatted=$(echo "$msg_cost" | sed 's/0*$//' | sed 's/\.$//')
    output="${output} | 消息: ${msg_tokens_formatted} \$${msg_cost_formatted}"
fi

if [ $total_tokens -gt 0 ]; then
    tokens_formatted=$(format_tokens $total_tokens)
    cost_formatted=$(awk "BEGIN {printf \"%.4f\", $session_cost}" | sed 's/0*$//' | sed 's/\.$//')
    output="${output} | 会话: ${tokens_formatted} \$${cost_formatted}"
fi

today_tokens_formatted=$(format_tokens $today_tokens)
today_cost_formatted=$(awk "BEGIN {printf \"%.4f\", $today_cost}" | sed 's/0*$//' | sed 's/\.$//')
output="${output} | 今日: ${today_tokens_formatted} \$${today_cost_formatted}"
output="${output} | #${req_count}"

used_pct=$(json_val "used_percentage" "")
if [ -n "$used_pct" ]; then
    used_pct_int=$(printf "%.0f" "$used_pct")
    if [ "$used_pct_int" -le 20 ]; then
        ctx_color="\033[32m"
    elif [ "$used_pct_int" -le 50 ]; then
        ctx_color="\033[36m"
    elif [ "$used_pct_int" -le 70 ]; then
        ctx_color="\033[33m"
    elif [ "$used_pct_int" -le 85 ]; then
        ctx_color="\033[91m"
    else
        ctx_color="\033[1;31m"
    fi
    output="${output} | ${ctx_color}Ctx: ${used_pct_int}%\033[0m"
fi

cwd=$(json_val "cwd" "")
[ -z "$cwd" ] && cwd=$(json_val "current_dir" "")
[ -n "$cwd" ] && output="${output} | \033[32m${cwd}\033[0m"

printf "%b\n" "$output"
EOF

chmod +x "$SCRIPT_PATH"
echo "✓ 状态栏脚本已写入 $SCRIPT_PATH"

# 更新 settings.json
if [ ! -f "$SETTINGS_PATH" ]; then
    echo '{}' > "$SETTINGS_PATH"
fi

update_settings_python() {
    python3 -c "
import json, sys
path = sys.argv[1]
cmd = sys.argv[2]
with open(path) as f:
    data = json.load(f)
data['statusLine'] = {'type': 'command', 'command': cmd}
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" "$SETTINGS_PATH" "$SCRIPT_PATH"
}

update_settings_sed() {
    local tmp=$(mktemp)
    local escaped_path=$(echo "$SCRIPT_PATH" | sed 's/[\/&]/\\&/g')
    local new_entry="\"statusLine\": {\"type\": \"command\", \"command\": \"${SCRIPT_PATH}\"}"

    if grep -q '"statusLine"' "$SETTINGS_PATH"; then
        sed 's/"statusLine"[[:space:]]*:[[:space:]]*{[^}]*}/"statusLine": {"type": "command", "command": "'"$escaped_path"'"}/' "$SETTINGS_PATH" > "$tmp" && mv "$tmp" "$SETTINGS_PATH"
    else
        local content=$(cat "$SETTINGS_PATH")
        if echo "$content" | grep -q '[^{[:space:]}]'; then
            sed 's/}[[:space:]]*$/,'"$(echo "$new_entry" | sed 's/[\/&]/\\&/g')"'\n}/' "$SETTINGS_PATH" > "$tmp" && mv "$tmp" "$SETTINGS_PATH"
        else
            echo "{" > "$SETTINGS_PATH"
            echo "  $new_entry" >> "$SETTINGS_PATH"
            echo "}" >> "$SETTINGS_PATH"
        fi
    fi
}

if command -v python3 >/dev/null 2>&1; then
    update_settings_python
elif command -v sed >/dev/null 2>&1; then
    update_settings_sed
else
    echo "⚠️  请手动在 $SETTINGS_PATH 中添加："
    echo "  \"statusLine\": {\"type\": \"command\", \"command\": \"$SCRIPT_PATH\"}"
    exit 1
fi

echo "✓ settings.json 已更新"
echo "✓ 完成！重启 Claude Code 后状态栏生效。"
