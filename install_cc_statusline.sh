#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SCRIPT_PATH="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_PATH="$CLAUDE_DIR/settings.json"
CACHE_DIR="$CLAUDE_DIR/cache"

echo "Installing CC Status Line..."
mkdir -p "$CLAUDE_DIR" "$CACHE_DIR"

# Copy the statusline script from repo
cp "$SCRIPT_DIR/statusline-command.sh" "$SCRIPT_PATH"
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
        if echo "$content" | grep -q '[^{[:space:}}]'; then
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
