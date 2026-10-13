# Installs the Pause app helper on Windows. CODE is the one on your sign-up page.
#   $env:PAUSE_CODE='CODE'; irm https://travistanguanri.github.io/pause/install.ps1 | iex

$code = ("$env:PAUSE_CODE" -replace "[^A-Za-z]", "").ToUpper()
if ($code.Length -ne 4) {
  Write-Host "Set your 4-letter code first, like this: `$env:PAUSE_CODE='ABCD'"
  return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = Join-Path $env:LOCALAPPDATA "Pause"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
foreach ($file in "helper.ps1", "uninstall.ps1") {
  Invoke-WebRequest -UseBasicParsing -Uri "https://travistanguanri.github.io/pause/$file" -OutFile (Join-Path $dir $file)
}
Set-Content -Path (Join-Path $dir "code.txt") -Value $code -Encoding ASCII

# Start the helper now and at every login (a shortcut in the Startup folder).
$run = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $dir 'helper.ps1')`""
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut(
  (Join-Path ([Environment]::GetFolderPath("Startup")) "Pause.lnk"))
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = $run
$shortcut.WindowStyle = 7
$shortcut.Save()

& (Join-Path $dir "uninstall.ps1") -StopOnly
Start-Process "powershell.exe" -ArgumentList $run -WindowStyle Hidden

Write-Host "Done. The Pause app helper is running for code $code."
Write-Host "To remove it later, run this in PowerShell:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"`$env:LOCALAPPDATA\Pause\uninstall.ps1`""
