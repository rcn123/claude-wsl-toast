# claude-wsl-toast

Windows toast notifications for [Claude Code](https://claude.com/claude-code) running inside WSL.

- Fires a toast when Claude finishes a turn (`Stop`) or needs your attention (`Notification`).
- Toast title shows the project name (basename of the current working directory).
- **Suppresses the toast if the project's terminal is already the foreground window** — no spam while you're watching.
- **Clicking the toast focuses the matching terminal window** — no alt-tab hunting.
- **Global hotkey while the toast is visible** focuses the same window — default `Ctrl+Shift+Space`, override with `CLAUDE_TOAST_HOTKEY`.
- Registers a per-user Windows AppID on first run, no admin needed.

## Requirements

- WSL2 on Windows 10/11
- `powershell.exe` reachable from WSL (default)
- `jq` in WSL (for parsing hook JSON): `sudo apt install jq`

## Install

Inside Claude Code (running in WSL):

```
/plugin marketplace add rcn123/claude-wsl-toast
/plugin install claude-wsl-toast@claude-wsl-toast
```

Then restart Claude Code so the `Stop` / `Notification` hooks register.

Verify: in any project, send a message and wait for Claude to finish — you should see a toast titled `Claude Code — <project>` (unless that terminal is the active window).

### Customizing the hotkey

Default is `Ctrl+Shift+Space`. Override by exporting `CLAUDE_TOAST_HOTKEY` in the shell that launches Claude Code (e.g. in `~/.bashrc` or `~/.zshrc`):

```bash
export CLAUDE_TOAST_HOTKEY="ctrl+alt+c"
```

Supported formats:

- Modifiers: `ctrl`, `alt`, `shift`, `win`
- Keys: single letter (`a`-`z`), digit (`0`-`9`), `space`, `enter`, `tab`, `esc`, `f1`-`f24`
- Combine with `+`: `ctrl+alt+space`, `win+shift+f9`, etc.

At least one modifier plus one key is required. Invalid specs silently disable the hotkey (click still works).

## How the active-window check works

The PowerShell script reads the foreground window title via the Win32
`GetForegroundWindow` + `GetWindowText` API. If that title contains the project
name (as set by Claude Code in the terminal title), the toast is skipped.

Click-to-focus and the hotkey use the same matching: first visible top-level
window whose title contains the project name.

If your terminal doesn't reflect the project name in its title, every event
will fire a toast and click/hotkey focus will have nothing to target — fix by
enabling dynamic titles in your terminal.

## Troubleshooting

- **No toasts appear:** Check Windows **Settings → System → Notifications** and
  make sure **Focus Assist / Do Not Disturb** is off.
- **Click or hotkey doesn't focus the terminal:** Your terminal's window title
  probably doesn't include the project name. Enable dynamic titles in your
  terminal settings.
- **Toast fires even when terminal is focused:** Same cause — terminal title
  isn't reflecting cwd.
- **Hotkey doesn't fire:** Another app may have already registered the same
  combo globally. Pick a different one via `CLAUDE_TOAST_HOTKEY`. The hotkey
  is only live while a toast is visible (≤120s) and only for one toast at a
  time — if two projects both have active toasts, the first one wins.

## Disable

```
/plugin disable claude-wsl-toast
```

Or remove it from `enabledPlugins` in `~/.claude/settings.json`.
