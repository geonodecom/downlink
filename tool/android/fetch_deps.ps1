# Fetches Android ffmpeg into jniLibs as libffmpeg.so and copies the matching
# NDK libc++_shared.so (required to execute ffmpeg). YouTube on Android uses
# youtube_explode_dart; yt-dlp is not packaged for Android.
param(
    [string]$JniLibsRoot = "android/app/src/main/jniLibs",
    [string]$NdkRoot = ""
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
$VersionsFile = Join-Path $Root "tool/deps/versions.json"
$Versions = Get-Content -Raw $VersionsFile | ConvertFrom-Json
$Android = $Versions.android

$Abis = @("arm64-v8a", "armeabi-v7a", "x86_64")
$AbiToNdkTriple = @{
    "arm64-v8a"   = "aarch64-linux-android"
    "armeabi-v7a" = "arm-linux-androideabi"
    "x86_64"      = "x86_64-linux-android"
}

$TempRoot = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
$Temp = Join-Path $TempRoot "downlink-deps-android"
if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
New-Item -ItemType Directory -Force -Path $Temp | Out-Null

function Save-Url([string]$Url, [string]$Dest) {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

function Extract-FfmpegFromZip([string]$ZipPath, [string]$Dest) {
    $extractDir = Join-Path $Temp ([System.IO.Path]::GetRandomFileName())
    Expand-Archive -Path $ZipPath -DestinationPath $extractDir -Force
    $match = Get-ChildItem -Path $extractDir -Recurse -File |
        Where-Object {
            $_.Name -eq 'ffmpeg' -or $_.Name -eq 'ffmpeg.exe'
        } |
        Select-Object -First 1
    if ($null -eq $match) {
        $match = Get-ChildItem -Path $extractDir -Recurse -File |
            Where-Object { $_.Name -like 'ffmpeg*' -and $_.Extension -in @('', '.exe') } |
            Select-Object -First 1
    }
    if ($null -eq $match) {
        Get-ChildItem -Path $extractDir -Recurse | Select-Object FullName | Format-Table | Out-String | Write-Host
        throw "Could not find ffmpeg executable in $ZipPath"
    }
    Copy-Item -Force $match.FullName $Dest
}

function Resolve-AndroidSdk {
    if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        return $env:ANDROID_SDK_ROOT
    }
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
        return $env:ANDROID_HOME
    }
    $localProps = Join-Path $Root "android/local.properties"
    if (Test-Path $localProps) {
        foreach ($line in Get-Content $localProps) {
            if ($line -match '^\s*sdk\.dir\s*=\s*(.+)\s*$') {
                # Java properties escape: C:\\Users\\... -> C:\Users\...
                $dir = $Matches[1].Trim().Replace('\\', '\')
                if (Test-Path $dir) { return $dir }
            }
        }
    }
    return $null
}

function Resolve-NdkRoot {
    if ($NdkRoot -and (Test-Path $NdkRoot)) {
        return (Resolve-Path $NdkRoot).Path
    }
    if ($env:ANDROID_NDK_HOME -and (Test-Path $env:ANDROID_NDK_HOME)) {
        return $env:ANDROID_NDK_HOME
    }
    if ($env:ANDROID_NDK_ROOT -and (Test-Path $env:ANDROID_NDK_ROOT)) {
        return $env:ANDROID_NDK_ROOT
    }
    $sdk = Resolve-AndroidSdk
    if ($null -eq $sdk) {
        throw "Android SDK not found. Set ANDROID_HOME / ANDROID_SDK_ROOT or android/local.properties sdk.dir."
    }
    $ndkDir = Join-Path $sdk "ndk"
    if (-not (Test-Path $ndkDir)) {
        throw "No NDK under $ndkDir. Install an Android NDK (e.g. sdkmanager `"ndk;28.2.13676358`")."
    }
    $latest = Get-ChildItem -Path $ndkDir -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        throw "No NDK versions found under $ndkDir."
    }
    return $latest.FullName
}

function Find-LibcxxShared([string]$Ndk, [string]$Abi) {
    $triple = $AbiToNdkTriple[$Abi]
    if (-not $triple) {
        throw "Unsupported ABI $Abi"
    }
    $matches = Get-ChildItem -Path $Ndk -Recurse -Filter "libc++_shared.so" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match [regex]::Escape($triple) }
    $pick = $matches | Select-Object -First 1
    if ($null -eq $pick) {
        throw "libc++_shared.so for $Abi ($triple) not found under NDK $Ndk"
    }
    return $pick.FullName
}

$ResolvedNdk = Resolve-NdkRoot
Write-Host "Using NDK: $ResolvedNdk"

foreach ($abi in $Abis) {
    $targetDir = Join-Path $JniLibsRoot $abi
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    $keep = Join-Path $targetDir ".gitkeep"
    if (-not (Test-Path $keep)) {
        New-Item -ItemType File -Path $keep | Out-Null
    }

    $ffmpegConfig = $Android.ffmpeg.$abi
    if ($null -eq $ffmpegConfig) {
        throw "Missing ffmpeg config for $abi in versions.json"
    }

    $ffmpegZip = Join-Path $Temp "$abi-ffmpeg.zip"
    Save-Url $ffmpegConfig.url $ffmpegZip
    $ffmpegDest = Join-Path $targetDir "libffmpeg.so"
    Extract-FfmpegFromZip $ffmpegZip $ffmpegDest
    Write-Host "Installed libffmpeg.so for $abi"

    $cxxSrc = Find-LibcxxShared $ResolvedNdk $abi
    $cxxDest = Join-Path $targetDir "libc++_shared.so"
    Copy-Item -Force $cxxSrc $cxxDest
    Write-Host "Installed libc++_shared.so for $abi from $cxxSrc"
}

foreach ($abi in $Abis) {
    foreach ($name in @("libffmpeg.so", "libc++_shared.so")) {
        $path = Join-Path $JniLibsRoot "$abi/$name"
        if (-not (Test-Path $path)) {
            throw "Missing required binary: $path"
        }
    }
}

Write-Host "Done. Android ffmpeg + libc++_shared are ready under $JniLibsRoot"
