# claude-wsl-toast

Windows toast notifications for [Claude Code](https://claude.com/claude-code) running inside WSL.

- Fires a toast when Claude finishes a turn (`Stop`) or needs your attention (`Notification`).
- Toast title shows the project name (basename of the current working directory).
- **Suppresses the toast if the project's terminal is already the foreground window** — no spam while you're watching.
- Registers a per-user Windows AppID on first run, no admin needed.

## Requirements

- WSL2 on Windows 10/11
- `powershell.exe` reachable from WSL (default)
- `jq` in WSL (for parsing hook JSON). Install with `sudo apt install jq`.

## Install

```
/plugin install github:rcn123/claude-wsl-toast
```

Restart Claude Code after install.

## How the active-window check works

The PowerShell script reads the foreground window title via the Win32
`GetForegroundWindow` + `GetWindowText` API. If that title contains the project
name (as set by Claude Code in the terminal title), the toast is skipped.

If your terminal doesn't reflect the project name in its title, every event
will fire a toast — fix by enabling dynamic titles in your terminal.

## Troubleshooting

- **No toasts appear:** Check Windows **Settings → System → Notifications** and
  make sure **Focus Assist / Do Not Disturb** is off.
- **Clicking the toast opens something weird:** Shouldn't happen — the AppID is
  registered with no launch command. If it does, check
  `HKCU:\Software\Classes\AppUserModelId\Claude.Code` in regedit.
- **Toast fires even when terminal is focused:** Your terminal's window title
  probably doesn't include the project name. Check with the window-title helper
  in PowerShell.

## Disable

Remove from `~/.claude/settings.json` `enabledPlugins`, or `/plugin disable claude-wsl-toast`.
