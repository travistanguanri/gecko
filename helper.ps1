# Pause app helper (Windows).
# Every 3 seconds it looks at which app is in front. While that is Claude,
# ChatGPT or VS Code, and the laptop is being used, it tells the sheet so (at
# most once a minute per app) and opens the form tab when the sheet says a
# form is due. Outside a discussion the sheet records nothing.
# It never looks inside any app, and no other app's name ever leaves the laptop.

$endpoint = "https://script.google.com/macros/s/AKfycbzzvFWZZp-xoufGymrCWWDuZzNkuG7kjfGOglel1QkP1NMFvMZPq_Ut0YVq76HqccK0/exec"
$site = "https://travistanguanri.github.io/pause"
$code = (Get-Content (Join-Path $env:LOCALAPPDATA "Pause\code.txt") -Raw).Trim()
# Process name (lower case) -> name written to the sheet
$tools = @{ "claude" = "Claude"; "chatgpt" = "ChatGPT"; "code" = "VS Code" }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PauseWindow {
  [StructLayout(LayoutKind.Sequential)] struct LastInput { public uint size; public uint tick; }
  [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LastInput info);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  // Seconds since the keyboard or mouse was last touched, in any app.
  public static uint IdleSeconds() {
    LastInput info = new LastInput();
    info.size = (uint)Marshal.SizeOf(info);
    GetLastInputInfo(ref info);
    return ((uint)Environment.TickCount - info.tick) / 1000;
  }
}
"@

$lastTool = ""
$lastSent = 0

while ($true) {
  Start-Sleep -Seconds 3
  [uint32]$processId = 0
  [void][PauseWindow]::GetWindowThreadProcessId([PauseWindow]::GetForegroundWindow(), [ref]$processId)
  $name = ""
  try { $name = (Get-Process -Id $processId -ErrorAction Stop).ProcessName.ToLower() } catch {}
  if (-not $tools.ContainsKey($name)) { continue }
  if ([PauseWindow]::IdleSeconds() -ge 30) { continue }  # in front, but nobody is using it
  $tool = $tools[$name]
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if ($tool -eq $lastTool -and ($now - $lastSent) -lt 60) { continue }
  $lastTool = $tool
  $lastSent = $now

  $reply = ""
  try {
    $url = "${endpoint}?action=use&code=${code}&tool=$([uri]::EscapeDataString($tool))&source=app-win&t=${now}"
    $reply = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content.Trim()
  } catch {}

  if ($reply -eq "yes") {
    $page = "${site}/form.html?tool=$([uri]::EscapeDataString($tool))&source=app-win"
    try { Start-Process "chrome.exe" -ArgumentList "`"$page`"" -ErrorAction Stop }
    catch { Start-Process $page }
  }
}
