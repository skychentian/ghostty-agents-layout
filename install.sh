#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAMMERSPOON_DIR="${HOME}/.hammerspoon"
INIT_FILE="${HAMMERSPOON_DIR}/init.lua"
MODULE_FILE="${HAMMERSPOON_DIR}/ghostty_agents_layout.lua"
SOURCE_FILE="${ROOT_DIR}/ghostty_agents_layout.lua"
LOCAL_BIN_DIR="${HOME}/.local/bin"
CLI_SOURCE_FILE="${ROOT_DIR}/bin/ghostty-agents"
CLI_TARGET_FILE="${LOCAL_BIN_DIR}/ghostty-agents"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Ghostty Agents Layout only supports macOS." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "Missing ${SOURCE_FILE}" >&2
  exit 1
fi

if [[ ! -f "${CLI_SOURCE_FILE}" ]]; then
  echo "Missing ${CLI_SOURCE_FILE}" >&2
  exit 1
fi

if [[ ! -d "/Applications/Hammerspoon.app" && ! -d "${HOME}/Applications/Hammerspoon.app" ]]; then
  echo "Hammerspoon is not installed."
  echo "Install it with: brew install --cask hammerspoon"
  exit 1
fi

mkdir -p "${HAMMERSPOON_DIR}"
cp "${SOURCE_FILE}" "${MODULE_FILE}"

mkdir -p "${LOCAL_BIN_DIR}"
cp "${CLI_SOURCE_FILE}" "${CLI_TARGET_FILE}"
chmod +x "${CLI_TARGET_FILE}"

if [[ -f "${INIT_FILE}" ]]; then
  BACKUP_FILE="${INIT_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  cp "${INIT_FILE}" "${BACKUP_FILE}"
  echo "Backed up ${INIT_FILE} to ${BACKUP_FILE}"
else
  touch "${INIT_FILE}"
fi

if ! grep -q "ghostty_agents_layout" "${INIT_FILE}"; then
  cat >> "${INIT_FILE}" <<'LUA'

-- Ghostty Agents Layout
pcall(function()
  hs.ipc.cliInstall()
end)

local okGhosttyAgentsLayout, ghosttyAgentsLayout = pcall(require, "ghostty_agents_layout")
if okGhosttyAgentsLayout then
  ghosttyAgentsLayout.bindHotkeys()
else
  hs.alert.show("Ghostty Agents Layout failed to load")
end
LUA
  echo "Added Ghostty Agents Layout to ${INIT_FILE}"
else
  echo "${INIT_FILE} already loads ghostty_agents_layout"
fi

if ! grep -q "hs.ipc.cliInstall" "${INIT_FILE}"; then
  cat >> "${INIT_FILE}" <<'LUA'

-- Install Hammerspoon CLI for Ghostty Agents Layout
pcall(function()
  hs.ipc.cliInstall()
end)
LUA
  echo "Added Hammerspoon CLI installation to ${INIT_FILE}"
fi

if command -v hs >/dev/null 2>&1; then
  hs -c 'hs.reload()' >/dev/null 2>&1 || true
else
  open -a Hammerspoon
fi

echo "Installed Ghostty Agents Layout."
echo
echo "CLI installed:"
echo "  ${CLI_TARGET_FILE}"
echo
if [[ ":${PATH}:" != *":${LOCAL_BIN_DIR}:"* ]]; then
  echo "Add this to your shell profile if ghostty-agents is not found:"
  echo "  export PATH=\"${LOCAL_BIN_DIR}:\$PATH\""
  echo
fi
echo "Next steps:"
echo "  1. Open Hammerspoon and grant Accessibility permission if hotkeys do not work."
echo "  2. Open two or more terminal agent windows in Ghostty, Terminal, iTerm2, Warp, or another supported terminal."
echo "     If you do not use Ghostty, set a recognizable title first:"
echo "     ${CLI_TARGET_FILE} title \"Claude Code - my-project\""
echo "  3. Run: ${CLI_TARGET_FILE} doctor"
echo "  4. Run: ${CLI_TARGET_FILE} sidebar"
echo "  5. Run: ${CLI_TARGET_FILE} grid"
