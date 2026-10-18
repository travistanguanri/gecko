# Installs the Gecko app helper on Windows. CODE is the one on your sign-up page.
# The sign-up page gives the full line to paste into PowerShell; it sets
# $env:GECKO_CODE and then runs this file straight from the website.

$code = ("$env:GECKO_CODE" -replace "[^A-Za-z]", "").ToUpper()
if ($code.Length -ne 4) {
  Write-Host "Set your 4-letter code first, like this: `$env:GECKO_CODE='ABCD'"
  return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = Join-Path $env:LOCALAPPDATA "Gecko"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
foreach ($file in "helper.ps1", "uninstall.ps1") {
  Invoke-WebRequest -UseBasicParsing -Uri "https://travistanguanri.github.io/gecko/$file" -OutFile (Join-Path $dir $file)
}
Set-Content -Path (Join-Path $dir "code.txt") -Value $code -Encoding ASCII

# Start the helper now and at every login (a shortcut in the Startup folder).
$run = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $dir 'helper.ps1')`""
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut(
  (Join-Path ([Environment]::GetFolderPath("Startup")) "Gecko.lnk"))
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = $run
$shortcut.WindowStyle = 7
$shortcut.Save()

# Stop a helper that is already running. Windows will not run a script file
# unless it is told this one is allowed, hence -ExecutionPolicy Bypass.
# That includes a helper from when this was called Pause or Snapshot, whose
# shortcut and folder are then removed, so only one helper runs.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir "uninstall.ps1") -StopOnly
foreach ($old in "Pause", "Snapshot") {
  Remove-Item (Join-Path ([Environment]::GetFolderPath("Startup")) "$old.lnk") -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $env:LOCALAPPDATA $old) -Recurse -Force -ErrorAction SilentlyContinue
}
Start-Process "powershell.exe" -ArgumentList $run -WindowStyle Hidden

Write-Host "Done. The Gecko app helper is running for code $code."
Write-Host "To remove it later, run this in PowerShell:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"`$env:LOCALAPPDATA\Gecko\uninstall.ps1`""
