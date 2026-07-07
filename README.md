# Ghostty Agents Layout

一个基于 [Hammerspoon](https://www.hammerspoon.org/) 的 macOS 小工具，用来整理同时打开的多个终端 agent 窗口。

它不是 Ghostty 插件，而是一个窗口管理自动化脚本。除了 Ghostty，也支持 macOS Terminal、iTerm2、Warp、WezTerm、Alacritty、kitty、Tabby、Hyper 等终端里启动的 Claude Code / Codex。

## 能做什么

- 一键把多个终端 agent 窗口排成网格
- 左侧显示一个 agents 侧边栏，按窗口标题自动分组
- 点击侧边栏条目，把对应窗口放大到右侧工作区
- 一键恢复网格
- 支持 10 个、16 个甚至更多窗口
- 可按自己的窗口标题关键词自定义分组

## 安装前准备

需要：

- macOS
- Ghostty、Terminal、iTerm2、Warp、WezTerm 等终端之一
- Hammerspoon
- 给 Hammerspoon 开启 Accessibility 权限

如果没有安装 Hammerspoon：

```bash
brew install --cask hammerspoon
```

然后打开一次 Hammerspoon，并在：

`System Settings -> Privacy & Security -> Accessibility`

里允许 Hammerspoon 控制电脑。

## 一键安装

最短方式：

```bash
curl -fsSL https://raw.githubusercontent.com/skychentian/ghostty-agents-layout/main/install-remote.sh | bash
```

或者手动 clone：

```bash
git clone https://github.com/skychentian/ghostty-agents-layout.git
cd ghostty-agents-layout
./install.sh
```

安装脚本会做三件事：

1. 把 `ghostty_agents_layout.lua` 复制到 `~/.hammerspoon/`
2. 把终端命令 `ghostty-agents` 安装到 `~/.local/bin/`
3. 如果 `~/.hammerspoon/init.lua` 里还没有加载本工具，就自动追加加载代码
4. 重新加载 Hammerspoon 配置

如果你已经有 `~/.hammerspoon/init.lua`，脚本会先备份成：

```text
~/.hammerspoon/init.lua.bak.YYYYmmddHHMMSS
```

如果终端找不到 `ghostty-agents`，把下面这行加入你的 shell 配置：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 让 AI agent 帮你安装

你可以把这段话发给 Codex、Claude Code 或其他本机 coding agent：

```text
请帮我在 macOS 上安装 Ghostty Agents Layout，它用 Hammerspoon 管理 Ghostty、Terminal、iTerm2、Warp 等终端里启动的 Claude Code / Codex agent 窗口：

1. 检查是否安装 Hammerspoon；如果没有，用 Homebrew 安装：brew install --cask hammerspoon
2. 优先运行一行安装命令：
   curl -fsSL https://raw.githubusercontent.com/skychentian/ghostty-agents-layout/main/install-remote.sh | bash
3. 如果 curl 方式失败，再手动 clone 仓库并运行 ./install.sh
4. 提醒我给 Hammerspoon 开启 Accessibility 权限
5. 安装后运行 ~/.local/bin/ghostty-agents doctor
6. 如果 doctor 正常，告诉我怎么用 ghostty-agents sidebar 和 ghostty-agents grid
7. 如果我不是用 Ghostty，而是用 Terminal/iTerm2/Warp 启动 Claude Code，教我用 ghostty-agents title 设置窗口标题，让工具能识别这个 agent 窗口
```

安装完成后，让 agent 用这几个命令验收：

```bash
~/.local/bin/ghostty-agents doctor
~/.local/bin/ghostty-agents list
~/.local/bin/ghostty-agents sidebar
~/.local/bin/ghostty-agents grid
```

## 手动安装

如果你不想运行安装脚本，也可以手动复制：

```bash
mkdir -p ~/.hammerspoon
cp ghostty_agents_layout.lua ~/.hammerspoon/
```

然后在 `~/.hammerspoon/init.lua` 里加入：

```lua
local ghosttyAgentsLayout = require("ghostty_agents_layout")
ghosttyAgentsLayout.bindHotkeys()
```

最后在 Hammerspoon 菜单里点 `Reload Config`。

## 终端命令

安装后可以直接在终端里运行：

```bash
ghostty-agents doctor
ghostty-agents sidebar
ghostty-agents grid
```

完整命令：

| 命令 | 功能 |
| --- | --- |
| `ghostty-agents doctor` | 检查 Hammerspoon、终端应用、agent 窗口和下一步 |
| `ghostty-agents grid` | 把当前桌面的终端 agent 窗口排成网格 |
| `ghostty-agents sidebar` | 显示 / 隐藏左侧 agents 侧边栏 |
| `ghostty-agents show` | 显示侧边栏 |
| `ghostty-agents hide` | 隐藏侧边栏 |
| `ghostty-agents list` | 在终端打印当前 agent 窗口列表 |
| `ghostty-agents focus 1` | 聚焦侧边栏第 1 个窗口 |
| `ghostty-agents title "Claude Code - my-project"` | 给当前终端窗口设置可识别标题 |
| `ghostty-agents desktop` | 实验性：尝试进入 agents 桌面 |
| `ghostty-agents help` | 查看命令帮助 |

推荐第一次使用按这个顺序：

```bash
ghostty-agents doctor
ghostty-agents sidebar
ghostty-agents grid
```

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Ctrl + Option + Cmd + G` | 把终端 agent 窗口恢复成网格 |
| `Ctrl + Option + Cmd + S` | 显示 / 隐藏左侧 agents 侧边栏 |
| `Ctrl + Option + Cmd + Shift + G` | 弹出当前 agent 窗口列表 |
| `Ctrl + Option + Cmd + F1..F12` | 快速切换侧边栏第 1 到 12 个窗口 |
| `Ctrl + Option + Cmd + D` | 实验性：尝试进入 agents 桌面 |

## 适配 Terminal / iTerm2 / Warp 里启动的 cc

Ghostty 默认会收集所有窗口。其他终端为了避免误排普通 shell，默认只收集窗口标题里像 agent 的窗口，例如包含：

- `Claude Code`
- `claude`
- `Codex`
- `agent`
- `✳`

如果你是这样启动 Claude Code：

```bash
claude
```

建议先给当前终端窗口设置标题：

```bash
ghostty-agents title "Claude Code - my-project"
claude
```

Codex 也一样：

```bash
ghostty-agents title "Codex - my-project"
codex
```

也可以放进 shell 函数里：

```bash
cc-agent() {
  ghostty-agents title "Claude Code - ${PWD##*/}"
  claude "$@"
}

codex-agent() {
  ghostty-agents title "Codex - ${PWD##*/}"
  codex "$@"
}
```

之后用：

```bash
cc-agent
codex-agent
```

如果你确实想把所有受支持终端窗口都纳入管理，可以在 `~/.hammerspoon/ghostty_agents_layout.lua` 里设置：

```lua
M.config.includeAllTerminalWindows = true
```

侧边栏里还有三个按钮：

| 按钮 | 功能 |
| --- | --- |
| `G` | 恢复右侧网格 |
| `R` | 刷新窗口列表 |
| `X` | 关闭侧边栏 |

## 自定义分组

默认会按窗口标题关键词分成：

- Code
- Docs
- Content
- Strategy
- Research
- Other

如果你想按自己的项目名、客户名或任务类型分组，编辑：

```text
~/.hammerspoon/ghostty_agents_layout.lua
```

找到 `titleRules`：

```lua
titleRules = {
  { label = "code", rank = 10, contains = { "Claude Code", "Codex", "main", "server", "test" } },
  { label = "docs", rank = 20, contains = { "docs", "README", "PRD", "文档", "方案" } },
}
```

`contains` 里写窗口标题会出现的关键词即可。`rank` 越小，排序越靠前。

## 已知限制

`Ctrl + Option + Cmd + D` 依赖 macOS Spaces API。某些 macOS 版本、全屏窗口、Stage Manager 或部分应用窗口会拒绝跨桌面移动。

这个工具会真实校验窗口是否移动成功。如果 macOS 拒绝迁移，它会停留在当前 agents 工作台并恢复侧边栏，不会把你带到一个空桌面。

更稳定的用法是：

1. 手动切到一个专门放 agents 的桌面
2. 打开多个 Ghostty / Terminal / iTerm2 / Warp 里的 Claude Code 或 Codex 窗口
3. 按 `Ctrl + Option + Cmd + S` 打开侧边栏
4. 按 `Ctrl + Option + Cmd + G` 恢复网格

## 卸载

删除脚本：

```bash
rm ~/.hammerspoon/ghostty_agents_layout.lua
```

然后从 `~/.hammerspoon/init.lua` 里删除：

```lua
local ghosttyAgentsLayout = require("ghostty_agents_layout")
ghosttyAgentsLayout.bindHotkeys()
```

重新加载 Hammerspoon 即可。
