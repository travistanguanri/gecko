# Gecko app helper (Windows).
# Every 2 seconds it looks at which app is in front. While that is Claude,
# ChatGPT or VS Code, and the laptop is being used, it tells the sheet so (at
# most once a minute per app) and opens the form tab when the sheet says a
# form is due. Separately, each time one of those apps comes to the front, it
# tells the sheet how long it stayed there. Outside a discussion the sheet
# records nothing.
# It never looks inside any app, and no other app's name ever leaves the laptop.

$endpoint = "https://script.google.com/macros/s/AKfycbzzvFWZZp-xoufGymrCWWDuZzNkuG7kjfGOglel1QkP1NMFvMZPq_Ut0YVq76HqccK0/exec"
$site = "https://travistanguanri.github.io/gecko"
$code = (Get-Content (Join-Path $env:LOCALAPPDATA "Gecko\code.txt") -Raw).Trim()
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

# Bringing Chrome to the front once the form tab is open. Windows resists a
# background program doing this (the taskbar icon flashes instead), so it is
# done in two steps: borrow the front window's right to switch, and if that is
# not enough, signal an Alt key being let go, which Windows reads as the user
# asking for a switch. The key is never pressed, so no app acts on it.
# Kept apart from the code above so that a fault here cannot stop the helper.
try {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PauseFocus {
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint thread, uint toThread, bool attach);
  [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int show);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll")] static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  public static void BringForward(IntPtr window) {
    if (IsIconic(window)) ShowWindow(window, 9);  // it was minimised: restore it
    uint processId;
    uint front = GetWindowThreadProcessId(GetForegroundWindow(), out processId);
    uint here = GetCurrentThreadId();
    AttachThreadInput(here, front, true);
    BringWindowToTop(window);
    SetForegroundWindow(window);
    AttachThreadInput(here, front, false);
    if (GetForegroundWindow() != window) {
      keybd_event(0x12, 0, 2, UIntPtr.Zero);  // Alt, let go only
      SetForegroundWindow(window);
    }
  }
}
"@
} catch {}

# An AI app was in front from $start to $end (seconds). Sent without waiting
# for the reply, so the checks carry on; outside a discussion the sheet keeps nothing.
function Send-Open($tool, $start, $end) {
  try {
    $url = "${endpoint}?action=open&code=${code}&tool=$([uri]::EscapeDataString($tool))&source=app-win&start=${start}&end=${end}"
    (New-Object Net.WebClient).DownloadStringAsync([uri]$url)
  } catch {}
}

$lastTool = ""
$lastSent = 0
$frontTool = ""   # the AI app in front, and when it was first seen there
$frontSince = 0
$lastTick = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()  # a long gap since then means the laptop slept

while ($true) {
  Start-Sleep -Seconds 2
  [uint32]$processId = 0
  [void][PauseWindow]::GetWindowThreadProcessId([PauseWindow]::GetForegroundWindow(), [ref]$processId)
  $name = ""
  try { $name = (Get-Process -Id $processId -ErrorAction Stop).ProcessName.ToLower() } catch {}
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $inFront = ""
  if ($tools.ContainsKey($name)) { $inFront = $tools[$name] }
  # Asleep since the last check: the app stopped being looked at then.
  if ($frontTool -and ($now - $lastTick) -gt 30) {
    Send-Open $frontTool $frontSince $lastTick
    $frontTool = ""
  }
  $lastTick = $now
  if ($inFront -ne $frontTool) {
    if ($frontTool) { Send-Open $frontTool $frontSince $now }
    $frontTool = $inFront
    $frontSince = $now
  }

  if (-not $inFront) { continue }
  if ([PauseWindow]::IdleSeconds() -ge 30) { continue }  # in front, but nobody is using it
  $tool = $inFront
  if ($tool -eq $lastTool -and ($now - $lastSent) -lt 60) { continue }
  $lastTool = $tool
  $lastSent = $now

  $reply = ""
  try {
    $url = "${endpoint}?action=use&code=${code}&tool=$([uri]::EscapeDataString($tool))&source=app-win&t=${now}"
    $reply = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content.Trim()
  } catch {}

  if ($reply -eq "yes") {
    # After the #: which sign-up this helper is linked to. That part of an
    # address stays in the browser; Gecko compares it with its own.
    $page = "${site}/form.html?tool=$([uri]::EscapeDataString($tool))&source=app-win#helper=${code}"
    try { Start-Process "chrome.exe" -ArgumentList "`"$page`"" -ErrorAction Stop }
    catch { Start-Process $page }
    # Give Chrome a moment to open the tab, then bring its window to the front.
    try {
      Start-Sleep -Milliseconds 1200
      $chrome = Get-Process chrome -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
      if ($chrome) { [PauseFocus]::BringForward($chrome.MainWindowHandle) }
    } catch {}
  }
}
