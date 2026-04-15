param(
    [string]$Title = "Claude Code",
    [string]$Message = "Notification",
    [string]$Project = "",
    [string]$Hotkey = "ctrl+shift+space"
)

# --- One-time AppID registration (idempotent, per-user, no admin) ---
$appId = "Claude.Code"
$regPath = "HKCU:\Software\Classes\AppUserModelId\$appId"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    New-ItemProperty -Path $regPath -Name DisplayName -Value "Claude Code" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name ShowInSettings -Value 0 -PropertyType DWord -Force | Out-Null
}

# --- Win32 interop: foreground check + window enumeration + activation + hotkey ---
if (-not ("Win32Helper" -as [type])) {
    Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Win32Helper {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG {
        public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam;
        public uint time; public int pt_x; public int pt_y;
    }
    [DllImport("user32.dll")] public static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

    public const int SW_RESTORE = 9;
    public const uint MOD_ALT = 0x1, MOD_CONTROL = 0x2, MOD_SHIFT = 0x4, MOD_WIN = 0x8, MOD_NOREPEAT = 0x4000;
    public const uint WM_HOTKEY = 0x0312;
    public const uint PM_REMOVE = 0x0001;

    public static List<IntPtr> FindWindowsByTitle(string needle) {
        var matches = new List<IntPtr>();
        var lower = needle.ToLowerInvariant();
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            int len = GetWindowTextLength(hWnd);
            if (len <= 0) return true;
            var sb = new StringBuilder(len + 1);
            GetWindowText(hWnd, sb, sb.Capacity);
            if (sb.ToString().ToLowerInvariant().Contains(lower)) matches.Add(hWnd);
            return true;
        }, IntPtr.Zero);
        return matches;
    }
}
"@
}

function Get-ForegroundTitle {
    $hwnd = [Win32Helper]::GetForegroundWindow()
    $sb = New-Object Text.StringBuilder 512
    [void][Win32Helper]::GetWindowText($hwnd, $sb, 512)
    return $sb.ToString()
}

# --- Suppress if the foreground window title contains the project name ---
if ($Project) {
    $fg = Get-ForegroundTitle
    if ($fg -and $fg.ToLower().Contains($Project.ToLower())) {
        exit 0
    }
}

# --- Find candidate window to focus on click (first visible match wins) ---
$targetHwnd = [IntPtr]::Zero
if ($Project) {
    $hits = [Win32Helper]::FindWindowsByTitle($Project)
    if ($hits.Count -gt 0) { $targetHwnd = $hits[0] }
}

function Focus-TargetWindow {
    if ($script:targetHwnd -ne [IntPtr]::Zero) {
        if ([Win32Helper]::IsIconic($script:targetHwnd)) {
            [void][Win32Helper]::ShowWindow($script:targetHwnd, [Win32Helper]::SW_RESTORE)
        }
        [void][Win32Helper]::SetForegroundWindow($script:targetHwnd)
    }
}

# --- Parse hotkey string like "ctrl+shift+space" into (modifiers, vk) ---
function Parse-Hotkey([string]$spec) {
    if (-not $spec) { return $null }
    $mods = 0
    $vk = 0
    foreach ($part in $spec.ToLower().Split('+') | ForEach-Object { $_.Trim() }) {
        switch ($part) {
            'ctrl'    { $mods = $mods -bor [Win32Helper]::MOD_CONTROL }
            'control' { $mods = $mods -bor [Win32Helper]::MOD_CONTROL }
            'alt'     { $mods = $mods -bor [Win32Helper]::MOD_ALT }
            'shift'   { $mods = $mods -bor [Win32Helper]::MOD_SHIFT }
            'win'     { $mods = $mods -bor [Win32Helper]::MOD_WIN }
            'meta'    { $mods = $mods -bor [Win32Helper]::MOD_WIN }
            default {
                if ($part.Length -eq 1) {
                    $c = [char]$part.ToUpper()
                    if ($c -ge 'A' -and $c -le 'Z') { $vk = [int]$c }
                    elseif ($c -ge '0' -and $c -le '9') { $vk = [int]$c }
                }
                elseif ($part -eq 'space')   { $vk = 0x20 }
                elseif ($part -eq 'enter')   { $vk = 0x0D }
                elseif ($part -eq 'tab')     { $vk = 0x09 }
                elseif ($part -eq 'escape' -or $part -eq 'esc') { $vk = 0x1B }
                elseif ($part -match '^f([1-9]|1[0-9]|2[0-4])$') { $vk = 0x6F + [int]$Matches[1] }
            }
        }
    }
    if ($vk -eq 0 -or $mods -eq 0) { return $null }
    return @{ Mods = [uint32]($mods -bor [Win32Helper]::MOD_NOREPEAT); Vk = [uint32]$vk }
}

# --- Fire the toast ---
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$xmlText = @"
<toast activationType="foreground" launch="focus">
  <visual>
    <binding template="ToastGeneric">
      <text>$([System.Security.SecurityElement]::Escape($Title))</text>
      <text>$([System.Security.SecurityElement]::Escape($Message))</text>
    </binding>
  </visual>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($xmlText)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

# --- Wire up click → focus target window ---
$done = New-Object System.Threading.ManualResetEventSlim $false
$script:targetHwnd = $targetHwnd

$activated = Register-ObjectEvent -InputObject $toast -EventName Activated -Action {
    try { Focus-TargetWindow } finally { $done.Set() }
}
$dismissed = Register-ObjectEvent -InputObject $toast -EventName Dismissed -Action { $done.Set() }
$failed    = Register-ObjectEvent -InputObject $toast -EventName Failed    -Action { $done.Set() }

[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)

# --- Register global hotkey (scoped to this toast's lifetime) ---
$hotkeyId = 0xC1A1  # arbitrary; thread-local registration so collisions only matter per-process
$hotkeyRegistered = $false
$parsed = Parse-Hotkey $Hotkey
if ($parsed) {
    $hotkeyRegistered = [Win32Helper]::RegisterHotKey([IntPtr]::Zero, $hotkeyId, $parsed.Mods, $parsed.Vk)
}

# --- Wait for click/dismiss/hotkey/timeout, pumping messages for WM_HOTKEY ---
$deadline = [DateTime]::UtcNow.AddSeconds(120)
while (-not $done.IsSet -and [DateTime]::UtcNow -lt $deadline) {
    if ($hotkeyRegistered) {
        $msg = New-Object Win32Helper+MSG
        while ([Win32Helper]::PeekMessage([ref]$msg, [IntPtr]::Zero, 0, 0, [Win32Helper]::PM_REMOVE)) {
            if ($msg.message -eq [Win32Helper]::WM_HOTKEY -and [int]$msg.wParam -eq $hotkeyId) {
                Focus-TargetWindow
                $done.Set()
                break
            }
        }
    }
    [void]$done.Wait(50)
}

if ($hotkeyRegistered) { [void][Win32Helper]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) }
Unregister-Event -SourceIdentifier $activated.Name -ErrorAction SilentlyContinue
Unregister-Event -SourceIdentifier $dismissed.Name -ErrorAction SilentlyContinue
Unregister-Event -SourceIdentifier $failed.Name    -ErrorAction SilentlyContinue
