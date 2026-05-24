# CC Status Line

为 Claude Code 底部状态栏添加实时会话数据，包括 Token 消耗、费用统计、请求次数和上下文使用率。

## 效果预览

```
Claude Sonnet 4.6 | 消息: 1.2K $0.003 | 会话: 45K $0.12 | 今日: 200K $0.5 | #8 | Ctx: 28% | /Users/you/project
```

## 字段说明

| 字段 | 说明 |
|------|------|
| `消息: 1.2K $0.003` | 本条消息消耗的 Token 数和费用 |
| `会话: 45K $0.12` | 本次会话累计 Token 数和费用 |
| `今日: 200K $0.5` | 今日所有会话累计（跨会话，午夜重置）|
| `#8` | 本窗口请求次数 |
| `Ctx: 28%` | 当前上下文窗口使用率 |
| 绿色路径 | 当前工作目录 |

## 前置依赖

- [Claude Code](https://claude.ai/code) 已安装
- `jq`

```bash
# macOS
brew install jq
```

## 安装

```bash
bash install_cc_statusline.sh
```

脚本自动完成：

1. 将状态栏渲染脚本写入 `~/.claude/statusline-command.sh`
2. 在 `~/.claude/settings.json` 中注册 `statusLine` 配置

**安装完成后重启 Claude Code 即生效。**

## 卸载

删除 `~/.claude/settings.json` 中的 `statusLine` 字段，并删除 `~/.claude/statusline-command.sh`。

## 说明

- 今日统计存储于 `~/.claude/cache/today_accumulator.json`，每日零点自动重置
- 请求次数为当前窗口计数，新开窗口重新从 1 开始
- `Ctx` 由 Claude Code 提供，首条消息前不显示
