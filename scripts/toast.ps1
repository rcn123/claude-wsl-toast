param(
    [string]$Title = "Claude Code",
    [string]$Message = "Notification",
    [string]$Project = ""
)

# --- One-time AppID registration (idempotent, per-user, no admin) ---
$appId = "Claude.Code"
$regPath = "HKCU:\Software\Classes\AppUserModelId\$appId"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    New-ItemProperty -Path $regPath -Name DisplayName -Value "Claude Code" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name ShowInSettings -Value 0 -PropertyType DWord -Force | Out-Null
}

# --- Suppress if the foreground window title contains the project name ---
if ($Project) {
    if (-not ("Win32ForegroundHelper" -as [type])) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32ForegroundHelper {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}
"@
    }
    $hwnd = [Win32ForegroundHelper]::GetForegroundWindow()
    $sb = New-Object Text.StringBuilder 512
    [void][Win32ForegroundHelper]::GetWindowText($hwnd, $sb, 512)
    $fgTitle = $sb.ToString()
    if ($fgTitle -and $fgTitle.ToLower().Contains($Project.ToLower())) {
        exit 0
    }
}

# --- Fire the toast ---
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$xmlText = @"
<toast>
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
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
