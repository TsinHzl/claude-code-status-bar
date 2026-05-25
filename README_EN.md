# CC Status Line

Adds real-time session stats to the Claude Code bottom status bar: token usage, cost breakdown, request count, and context window utilization.

## Preview

```
Claude Sonnet 4.6 | 消息: 1.2K $0.003 | 会话: 45K $0.12 | 今日: 200K $0.5 | #8 | Ctx: 28% | /Users/you/project
```

## Fields

| Field | Description |
|-------|-------------|
| `消息: 1.2K $0.003` | Tokens and cost for the current message |
| `会话: 45K $0.12` | Cumulative tokens and cost for this session |
| `今日: 200K $0.5` | Total across all sessions today (resets at midnight) |
| `#8` | Request count in the current window |
| `Ctx: 28%` | Context window usage (color-coded in 5 levels) |
| Green path | Current working directory |

`Ctx` changes color based on usage:

| Range | Color |
|-------|-------|
| 0–20% | Green |
| 21–50% | Cyan |
| 51–70% | Yellow |
| 71–85% | Bright red |
| 86–100% | Bold red |

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- `jq`

```bash
# macOS
brew install jq
```

## Installation

```bash
bash install_cc_statusline.sh
```

The script will automatically:

1. Write the rendering script to `~/.claude/statusline-command.sh`
2. Register `statusLine` config in `~/.claude/settings.json`

**Restart Claude Code after installation.**

## Uninstall

Remove the `statusLine` field from `~/.claude/settings.json` and delete `~/.claude/statusline-command.sh`.

## Notes

- Daily stats are stored in `~/.claude/cache/today_accumulator.json` and reset at midnight
- Request count resets per window
- `Ctx` percentage is provided by Claude Code and only appears after the first message
