# Removes the Pause app helper from Windows: stops it, and deletes its Startup
# shortcut and its folder. Nothing else was installed.
# -StopOnly just stops a running helper (used by the installer).
param([switch]$StopOnly)

Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -like "*\Pause\helper.ps1*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if ($StopOnly) { return }

Remove-Item (Join-Path ([Environment]::GetFolderPath("Startup")) "Pause.lnk") -ErrorAction SilentlyContinue
# This script lives in the folder it deletes, so step out of it first.
Set-Location $env:TEMP
Remove-Item (Join-Path $env:LOCALAPPDATA "Pause") -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Pause app helper removed."
