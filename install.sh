#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAMMERSPOON_DIR="${HOME}/.hammerspoon"
INIT_FILE="${HAMMERSPOON_DIR}/init.lua"
MODULE_FILE="${HAMMERSPOON_DIR}/ghostty_agents_layout.lua"
SOURCE_FILE="${ROOT_DIR}/ghostty_agents_layout.lua"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Ghostty Agents Layout only supports macOS." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "Missing ${SOURCE_FILE}" >&2
  exit 1
fi

if [[ ! -d "/Applications/Hammerspoon.app" && ! -d "${HOME}/Applications/Hammerspoon.app" ]]; then
  echo "Hammerspoon is not installed."
  echo "Install it with: brew install --cask hammerspoon"
  exit 1
fi

mkdir -p "${HAMMERSPOON_DIR}"
cp "${SOURCE_FILE}" "${MODULE_FILE}"

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

if command -v hs >/dev/null 2>&1; then
  hs -c 'hs.reload()' >/dev/null 2>&1 || true
else
  open -a Hammerspoon
fi

echo "Installed Ghostty Agents Layout."
echo "Open Hammerspoon and grant Accessibility permission if hotkeys do not work."

