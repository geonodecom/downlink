# Build Downlink for Windows (release) and downlink-host.exe
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

Write-Host "Fetching bundled download tools..."
& (Join-Path $PSScriptRoot "fetch_deps.ps1")

Write-Host "Building Flutter Windows release..."
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release

$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$BinDir = Join-Path $ReleaseDir "bin"
$DepsBin = Join-Path $Root "build\deps\windows-x64\bin"
$NoticesSrc = Join-Path $Root "packaging\THIRD_PARTY_NOTICES.md"

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Copy-Item -Path (Join-Path $DepsBin "*") -Destination $BinDir -Force
if (Test-Path $NoticesSrc) {
  Copy-Item -Force $NoticesSrc (Join-Path $ReleaseDir "THIRD_PARTY_NOTICES.md")
}

$ApplyUpdateScript = Join-Path $PSScriptRoot "apply_update.ps1"
if (Test-Path $ApplyUpdateScript) {
  Copy-Item -Force $ApplyUpdateScript (Join-Path $ReleaseDir "apply_update.ps1")
}

Write-Host "Building downlink-host..."
$HostOut = Join-Path $Root "build\downlink-host-cli"
dart build cli -t bin/downlink_host.dart -o $HostOut

$HostBin = Join-Path $HostOut "bundle\bin\downlink_host.exe"
if (-not (Test-Path $HostBin)) {
  # Older/dart layout may omit .exe in path listing
  $alt = Get-ChildItem -Path (Join-Path $HostOut "bundle\bin") -Filter "downlink_host*" | Select-Object -First 1
  if ($null -eq $alt) { throw "downlink-host binary not found under $HostOut" }
  $HostBin = $alt.FullName
}

$HostCopy = Join-Path $Root "build\downlink-host.exe"
Copy-Item -Force $HostBin $HostCopy
Write-Host "Built: $HostCopy"
Write-Host "App bundle: $(Join-Path $Root 'build\windows\x64\runner\Release')"
