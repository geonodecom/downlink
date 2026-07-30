# Build Downlink-Setup-<version>.exe (per-user Inno Setup installer).
param(
    [string] $Version = "",
    [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

function Get-PubspecVersion {
    $line = Get-Content (Join-Path $Root "pubspec.yaml") |
        Where-Object { $_ -match '^\s*version:\s*' } |
        Select-Object -First 1
    if (-not $line) {
        throw "Could not read version from pubspec.yaml"
    }
    $raw = ($line -replace '^\s*version:\s*', '').Trim()
    # Strip +build suffix (e.g. 0.1.0+1 -> 0.1.0)
    return ($raw -split '\+')[0]
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-PubspecVersion
}

$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$HostSrc = Join-Path $Root "build\downlink-host.exe"
$StageDir = Join-Path $Root "build\installer-stage"
$DistDir = Join-Path $Root "dist"
$IssPath = Join-Path $Root "packaging\windows\downlink.iss"

if (-not $SkipBuild -or -not (Test-Path (Join-Path $ReleaseDir "downlink.exe"))) {
    Write-Host "Building Windows release bundle..."
    & (Join-Path $PSScriptRoot "build.ps1")
}

if (-not (Test-Path (Join-Path $ReleaseDir "downlink.exe"))) {
    throw "Missing release binary: $(Join-Path $ReleaseDir 'downlink.exe')"
}
if (-not (Test-Path $HostSrc)) {
    throw "Missing host binary: $HostSrc - run tool/windows/build.ps1 first."
}

Write-Host "Staging installer payload at $StageDir"
if (Test-Path $StageDir) {
    Remove-Item -Recurse -Force $StageDir
}
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
Copy-Item -Path (Join-Path $ReleaseDir "*") -Destination $StageDir -Recurse -Force
Copy-Item -Force $HostSrc (Join-Path $StageDir "downlink-host.exe")

foreach ($tool in @("aria2c.exe", "yt-dlp.exe", "ffmpeg.exe")) {
    $path = Join-Path $StageDir "bin\$tool"
    if (-not (Test-Path $path)) {
        throw "Missing bundled tool in stage: $path"
    }
}

$applyUpdate = Join-Path $StageDir "apply_update.ps1"
if (-not (Test-Path $applyUpdate)) {
    throw "Missing apply_update.ps1 in stage (required for in-app updates)."
}

function Resolve-Iscc {
    if ($env:ISCC -and (Test-Path $env:ISCC)) {
        return (Resolve-Path $env:ISCC).Path
    }
    $pf86 = ${env:ProgramFiles(x86)}
    $candidates = @(
        (Join-Path $pf86 "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }
    return $null
}

$iscc = Resolve-Iscc
if (-not $iscc) {
    throw "ISCC.exe not found. Install Inno Setup 6 (winget install JRSoftware.InnoSetup or choco install innosetup -y), or set the ISCC environment variable."
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host "Compiling installer with $iscc"
Write-Host "  Version:  $Version"
Write-Host "  StageDir: $StageDir"
Write-Host "  DistDir:  $DistDir"

& $iscc "/DAppVersion=$Version" "/DStageDir=$StageDir" "/DDistDir=$DistDir" $IssPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

$OutExe = Join-Path $DistDir "Downlink-Setup-$Version.exe"
if (-not (Test-Path $OutExe)) {
    throw "Installer was not produced: $OutExe"
}

Get-Item $OutExe | Format-List FullName, Length
Write-Host "Installer ready: $OutExe"