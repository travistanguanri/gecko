# Installs the Snapshot app helper on Windows. CODE is the one on your sign-up page.
# The sign-up page gives the full line to paste into PowerShell; it sets
# $env:SNAPSHOT_CODE and then runs this file straight from the website.

$code = ("$env:SNAPSHOT_CODE$env:PAUSE_CODE" -replace "[^A-Za-z]", "").ToUpper()  # PAUSE_CODE: the old name
if ($code.Length -ne 4) {
  Write-Host "Set your 4-letter code first, like this: `$env:SNAPSHOT_CODE='ABCD'"
  return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = Join-Path $env:LOCALAPPDATA "Snapshot"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
foreach ($file in "helper.ps1", "uninstall.ps1") {
  Invoke-WebRequest -UseBasicParsing -Uri "https://travistanguanri.github.io/snapshot/$file" -OutFile (Join-Path $dir $file)
}
Set-Content -Path (Join-Path $dir "code.txt") -Value $code -Encoding ASCII

# Start the helper now and at every login (a shortcut in the Startup folder).
$run = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $dir 'helper.ps1')`""
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut(
  (Join-Path ([Environment]::GetFolderPath("Startup")) "Snapshot.lnk"))
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = $run
$shortcut.WindowStyle = 7
$shortcut.Save()

# Stop a helper that is already running. Windows will not run a script file
# unless it is told this one is allowed, hence -ExecutionPolicy Bypass.
# That includes the helper from when this was called Pause, whose shortcut and
# folder are then removed, so only one helper runs.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir "uninstall.ps1") -StopOnly
Remove-Item (Join-Path ([Environment]::GetFolderPath("Startup")) "Pause.lnk") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA "Pause") -Recurse -Force -ErrorAction SilentlyContinue
Start-Process "powershell.exe" -ArgumentList $run -WindowStyle Hidden

Write-Host "Done. The Snapshot app helper is running for code $code."
Write-Host "To remove it later, run this in PowerShell:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"`$env:LOCALAPPDATA\Snapshot\uninstall.ps1`""
