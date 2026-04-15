# claude-wsl-toast

Claude Code plugin that fires Windows toast notifications for `Stop` and `Notification` hook events when Claude Code runs inside WSL. Toasts are suppressed when the project's terminal is the foreground window.

## Layout

- `plugins/claude-wsl-toast/` — plugin root (per marketplace schema)
  - `.claude-plugin/plugin.json` — plugin manifest
  - `hooks/hooks.json` — registers `Stop` / `Notification` hooks calling `toast.sh`
  - `scripts/toast.sh` — WSL-side shell; parses hook JSON with `jq`, invokes PowerShell
  - `scripts/toast.ps1` — Windows-side; foreground-window check + toast via per-user AppID
- `.claude-plugin/marketplace.json` — lets the repo be installed as a plugin source
- `README.md` — user-facing install/usage docs

## How it works

1. Claude Code fires `Stop` or `Notification` hook → runs `bash scripts/toast.sh`.
2. `toast.sh` reads hook JSON from stdin, extracts `cwd`, derives project name (basename), shells out to `powershell.exe` with `toast.ps1`.
3. `toast.ps1` calls Win32 `GetForegroundWindow` + `GetWindowText`; if the title contains the project name, it exits silently. Otherwise it registers the `Claude.Code` AppID under `HKCU` (first run only) and shows a toast.

## Conventions

- Invoke `toast.sh` via `bash` in `hooks.json` — the exec bit is unreliable on Windows clones.
- Keep the AppID registration HKCU-only (no admin required).
- Project-name detection depends on the terminal reflecting cwd in its window title; document this caveat rather than working around it.

## Requirements

- WSL2, `powershell.exe` on PATH, `jq` installed in WSL.
