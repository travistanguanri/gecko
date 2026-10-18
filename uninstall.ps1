# Removes the Snapshot app helper from Windows: stops it, and deletes its Startup
# shortcut and its folder. Nothing else was installed.
# -StopOnly just stops a running helper (used by the installer).
param([switch]$StopOnly)

Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -like "*\Snapshot\helper.ps1*" -or $_.CommandLine -like "*\Pause\helper.ps1*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if ($StopOnly) { return }

# Also the shortcut and folder from when this was called Pause, if still there.
foreach ($name in "Snapshot", "Pause") {
  Remove-Item (Join-Path ([Environment]::GetFolderPath("Startup")) "$name.lnk") -ErrorAction SilentlyContinue
}
# This script lives in the folder it deletes, so step out of it first.
Set-Location $env:TEMP
foreach ($name in "Snapshot", "Pause") {
  Remove-Item (Join-Path $env:LOCALAPPDATA $name) -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Snapshot app helper removed."
