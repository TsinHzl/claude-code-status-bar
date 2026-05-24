# CC Status Line

Adds real-time session stats to the Claude Code bottom status bar: token usage, cost breakdown, request count, and context window utilization.

## Preview

```
Claude Sonnet 4.6 | 消息: 1.2K $0.003 | 会话: 45K $0.12 | 今日: 200K $0.5 | #8 | Ctx: 28% | /Users/you/project
```
<img width="1778" height="158" alt="image" src="https://github.com/user-attachments/assets/676b821f-b565-46f9-9138-41506f97e0b9" />
## Fields

| Field | Description |
|-------|-------------|
| `消息: 1.2K $0.003` | Tokens and cost for the current message |
| `会话: 45K $0.12` | Cumulative tokens and cost for this session |
| `今日: 200K $0.5` | Total across all sessions today (resets at midnight) |
| `#8` | Request count in the current window |
| `Ctx: 28%` | Context window usage percentage |
| Green path | Current working directory |

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
