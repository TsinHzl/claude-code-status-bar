#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Cache directory for today's stats
CACHE_DIR="$HOME/.claude/cache"
mkdir -p "$CACHE_DIR"

# Extract a top-level-ish JSON value (string or number) without jq
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

# Function to format token counts with K/M/B units
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

# Function to format token counts with exactly 1 decimal place (for ↓ token display)
format_tokens_1d() {
    local value=$1
    if [ $value -lt 1000 ]; then
        echo "${value}"
    elif [ $value -lt 1000000 ]; then
        awk "BEGIN {printf \"%.1fk\", $value / 1000}"
    elif [ $value -lt 1000000000 ]; then
        awk "BEGIN {printf \"%.1fM\", $value / 1000000}"
    else
        awk "BEGIN {printf \"%.1fB\", $value / 1000000000}"
    fi
}

# Function to calculate today's total stats using a flat-file accumulator
# Args: $1=session_id $2=session_tokens $3=session_cost
calculate_today_stats() {
    local session_id="$1"
    local sess_tokens="$2"
    local sess_cost="$3"
    local today_date=$(date +%Y-%m-%d)

    local date_file="$CACHE_DIR/today_date.txt"
    local total_tokens_file="$CACHE_DIR/today_total_tokens.txt"
    local total_cost_file="$CACHE_DIR/today_total_cost.txt"
    local sess_tokens_file="$CACHE_DIR/sess_${session_id}_tokens.txt"
    local sess_cost_file="$CACHE_DIR/sess_${session_id}_cost.txt"

    # Reset accumulator if date changed
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
    prev_tokens=${prev_tokens:-0}
    prev_cost=${prev_cost:-0}

    # Only update if current values are greater (cumulative values only grow)
    local needs_update=0
    if [ "$sess_tokens" -gt "$prev_tokens" ] 2>/dev/null; then
        needs_update=1
    elif [ "$(awk "BEGIN {print ($sess_cost > $prev_cost) ? 1 : 0}")" = "1" ]; then
        needs_update=1
    fi

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

# Extract model info
model=$(json_val "display_name" "Claude")

# Extract total tokens for session (cumulative)
input_tokens=$(json_val "total_input_tokens" "0")
output_tokens=$(json_val "total_output_tokens" "0")
total_tokens=$((input_tokens + output_tokens))

# Extract session cost from the cost field (matches /cost command)
session_cost=$(json_val "total_cost_usd" "0")

# Extract session ID for today's accumulator
session_id=$(json_val "session_id" "unknown")

# Calculate per-message delta (current session cumulative - last recorded)
LAST_FILE="$CACHE_DIR/last_session_${session_id}.txt"
last_tokens=0
last_cost="0"
if [ -f "$LAST_FILE" ]; then
    last_tokens=$(sed -n '1p' "$LAST_FILE")
    last_cost=$(sed -n '2p' "$LAST_FILE")
fi
last_tokens=${last_tokens:-0}
last_cost=${last_cost:-0}

msg_tokens=$((total_tokens - last_tokens))
msg_cost=$(awk "BEGIN {printf \"%.4f\", $session_cost - $last_cost}")

# Save current cumulative for next round
printf '%d\n%s\n' "$total_tokens" "$session_cost" > "$LAST_FILE"

# Per-window request counter (increments each time a new API response is detected)
REQ_COUNT_FILE="$CACHE_DIR/req_count_${session_id}.txt"
if [ "$msg_tokens" -gt 0 ] 2>/dev/null; then
    req_count=$(cat "$REQ_COUNT_FILE" 2>/dev/null || echo 0)
    req_count=$((req_count + 1))
    echo "$req_count" > "$REQ_COUNT_FILE"
else
    req_count=$(cat "$REQ_COUNT_FILE" 2>/dev/null || echo 0)
fi

# Get today's stats (accumulates across all sessions, resets at midnight)
today_stats=$(calculate_today_stats "$session_id" "$total_tokens" "$session_cost")
today_tokens=$(echo "$today_stats" | cut -d'|' -f1)
today_cost=$(echo "$today_stats" | cut -d'|' -f2)

# Format output
output="${model}"

# Add per-message delta stats
if [ $msg_tokens -gt 0 ]; then
    msg_tokens_formatted=$(format_tokens $msg_tokens)
    # Remove trailing zeros from msg_cost
    msg_cost_formatted=$(echo "$msg_cost" | sed 's/0*$//' | sed 's/\.$//')
    output="${output} | 消息: ${msg_tokens_formatted} \$${msg_cost_formatted}"
fi

# Add session stats (cumulative)
if [ $total_tokens -gt 0 ]; then
    tokens_arrow=$(format_tokens_1d $total_tokens)
    cost_formatted=$(awk "BEGIN {printf \"%.4f\", $session_cost}" | sed 's/0*$//' | sed 's/\.$//')
    output="${output} | 会话: \342\206\223 ${tokens_arrow} tokens \$${cost_formatted}"
fi

# Add today's stats (ALWAYS show, even if 0)
today_tokens_formatted=$(format_tokens $today_tokens)
today_cost_formatted=$(awk "BEGIN {printf \"%.4f\", $today_cost}" | sed 's/0*$//' | sed 's/\.$//')
output="${output} | 今日: ${today_tokens_formatted} \$${today_cost_formatted}"

# Append per-window request count
output="${output} | #${req_count}"

# Append context usage percentage
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

# Append last request time (HH:MM:SS) before cwd
last_request_time=$(date +%H:%M:%S)
output="${output} | \033[36m${last_request_time}\033[0m"

# Append current working directory (rightmost element)
cwd=$(json_val "cwd" "")
if [ -z "$cwd" ]; then
    cwd=$(json_val "current_dir" "")
fi
if [ -n "$cwd" ]; then
    output="${output} | \033[32m${cwd}\033[0m"
fi

printf "%b\n" "$output"
