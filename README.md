# Ghostty Agents Layout

一个基于 [Hammerspoon](https://www.hammerspoon.org/) 的 macOS 小工具，用来整理同时打开的多个 Ghostty / Claude Code agent 窗口。

它不是 Ghostty 插件，而是一个窗口管理自动化脚本。

## 能做什么

- 一键把多个 Ghostty 窗口排成网格
- 左侧显示一个 agents 侧边栏，按窗口标题自动分组
- 点击侧边栏条目，把对应窗口放大到右侧工作区
- 一键恢复网格
- 支持 10 个、16 个甚至更多窗口
- 可按自己的窗口标题关键词自定义分组

## 安装前准备

需要：

- macOS
- Ghostty
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

```bash
git clone https://github.com/skychentian/ghostty-agents-layout.git
cd ghostty-agents-layout
./install.sh
```

安装脚本会做三件事：

1. 把 `ghostty_agents_layout.lua` 复制到 `~/.hammerspoon/`
2. 如果 `~/.hammerspoon/init.lua` 里还没有加载本工具，就自动追加加载代码
3. 重新加载 Hammerspoon 配置

如果你已经有 `~/.hammerspoon/init.lua`，脚本会先备份成：

```text
~/.hammerspoon/init.lua.bak.YYYYmmddHHMMSS
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

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Ctrl + Option + Cmd + G` | 把 Ghostty 窗口恢复成网格 |
| `Ctrl + Option + Cmd + S` | 显示 / 隐藏左侧 agents 侧边栏 |
| `Ctrl + Option + Cmd + Shift + G` | 弹出当前 Ghostty 窗口列表 |
| `Ctrl + Option + Cmd + F1..F12` | 快速切换侧边栏第 1 到 12 个窗口 |
| `Ctrl + Option + Cmd + D` | 实验性：尝试进入 agents 桌面 |

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

这个工具会真实校验窗口是否移动成功。如果 macOS 拒绝迁移，它会停留在当前 Ghostty 工作台并恢复侧边栏，不会把你带到一个空桌面。

更稳定的用法是：

1. 手动切到一个专门放 agents 的桌面
2. 打开多个 Ghostty / Claude Code 窗口
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

