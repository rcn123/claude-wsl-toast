#!/usr/bin/env bash
# Usage: toast.sh "<message>"
# Reads Claude Code hook JSON on stdin, derives project name from cwd,
# then fires a Windows toast via PowerShell (suppressed if the project's
# terminal is the active foreground window).
set -eu

MESSAGE="${1:-Notification}"

# Only run on WSL; silent no-op elsewhere.
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  exit 0
fi

# Extract cwd from hook JSON (fallback to $PWD).
INPUT="$(cat || true)"
CWD=""
if command -v jq >/dev/null 2>&1; then
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi
if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
PROJECT="$(basename "$CWD")"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PS1_WIN="$(wslpath -w "$SCRIPT_DIR/toast.ps1")"

HOTKEY="${CLAUDE_TOAST_HOTKEY:-ctrl+shift+space}"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" \
  -Title "Claude Code — $PROJECT" \
  -Message "$MESSAGE" \
  -Project "$PROJECT" \
  -Hotkey "$HOTKEY" \
  >/dev/null 2>&1 &
