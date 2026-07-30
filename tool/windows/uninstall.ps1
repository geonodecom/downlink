# Uninstall Downlink Windows install and native messaging registration.
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "downlink"
$NativeHostName = "com.geonode.downlink"
$ShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Downlink.lnk"

$RegistryKeys = @(
  "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$NativeHostName",
  "HKCU:\Software\Chromium\NativeMessagingHosts\$NativeHostName",
  "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$NativeHostName",
  "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\$NativeHostName"
)

foreach ($key in $RegistryKeys) {
  if (Test-Path $key) {
    Remove-Item -Path $key -Recurse -Force
    Write-Host "Removed $key"
  }
}

if (Test-Path $ShortcutPath) {
  Remove-Item -Force $ShortcutPath
  Write-Host "Removed Start Menu shortcut"
}

if (Test-Path $InstallDir) {
  Remove-Item -Recurse -Force $InstallDir
  Write-Host "Removed $InstallDir"
}

$Endpoint = Join-Path $env:LOCALAPPDATA "downlink\extension-endpoint.json"
if (Test-Path $Endpoint) {
  Remove-Item -Force $Endpoint -ErrorAction SilentlyContinue
}

Write-Host "Uninstall complete."