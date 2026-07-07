#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${GHOSTTY_AGENTS_REPO_URL:-https://github.com/skychentian/ghostty-agents-layout.git}"
INSTALL_DIR="${GHOSTTY_AGENTS_INSTALL_DIR:-${HOME}/.local/share/ghostty-agents-layout}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Ghostty Agents Layout only supports macOS." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to install Ghostty Agents Layout." >&2
  exit 1
fi

mkdir -p "$(dirname "${INSTALL_DIR}")"

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  git -C "${INSTALL_DIR}" pull --ff-only
elif [[ -e "${INSTALL_DIR}" ]]; then
  BACKUP_DIR="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
  mv "${INSTALL_DIR}" "${BACKUP_DIR}"
  echo "Moved existing ${INSTALL_DIR} to ${BACKUP_DIR}"
  git clone "${REPO_URL}" "${INSTALL_DIR}"
else
  git clone "${REPO_URL}" "${INSTALL_DIR}"
fi

exec "${INSTALL_DIR}/install.sh"
