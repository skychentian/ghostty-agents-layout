# Agent-assisted install

Copy this prompt into Codex, Claude Code, or another local coding agent:

```text
Please install Ghostty Agents Layout on this macOS machine.

Repository: https://github.com/skychentian/ghostty-agents-layout

Steps:
1. Check whether Hammerspoon is installed.
2. If Hammerspoon is missing and Homebrew is available, install it with:
   brew install --cask hammerspoon
3. Prefer the one-line install:
   curl -fsSL https://raw.githubusercontent.com/skychentian/ghostty-agents-layout/main/install-remote.sh | bash
4. If the one-line install fails, clone the repository and run ./install.sh from the cloned repository.
5. Ask me to grant Accessibility permission to Hammerspoon if it is not already granted.
6. Validate the install with:
   ~/.local/bin/ghostty-agents doctor
7. If validation passes, show me these first-use commands:
   ~/.local/bin/ghostty-agents sidebar
   ~/.local/bin/ghostty-agents grid
   ~/.local/bin/ghostty-agents list

Do not overwrite my existing ~/.hammerspoon/init.lua without backing it up.
```

Expected post-install flow:

```bash
~/.local/bin/ghostty-agents doctor
~/.local/bin/ghostty-agents sidebar
~/.local/bin/ghostty-agents grid
```
