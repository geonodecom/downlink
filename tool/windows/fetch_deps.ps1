# Fetches aria2, yt-dlp, and ffmpeg for Windows x64 release builds.
param(
    [string]$OutputDir = "build/deps/windows-x64/bin"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$VersionsFile = Join-Path $Root "tool/deps/versions.json"
$Versions = Get-Content -Raw $VersionsFile | ConvertFrom-Json
$Windows = $Versions.windows

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$Temp = Join-Path $env:TEMP "downlink-deps-windows"
if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
New-Item -ItemType Directory -Force -Path $Temp | Out-Null

function Save-Url([string]$Url, [string]$Dest) {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

function Extract-FromZip([string]$ZipPath, [string]$Pattern, [string]$Dest) {
    Expand-Archive -Path $ZipPath -DestinationPath (Join-Path $Temp "zip") -Force
    $match = Get-ChildItem -Path (Join-Path $Temp "zip") -Recurse -Filter $Pattern |
        Select-Object -First 1
    if ($null -eq $match) {
        $match = Get-ChildItem -Path (Join-Path $Temp "zip") -Recurse |
            Where-Object { $_.Name -like $Pattern.Replace("*", "*") } |
            Select-Object -First 1
    }
    if ($null -eq $match) {
        throw "Could not find $Pattern in $ZipPath"
    }
    Copy-Item -Force $match.FullName $Dest
}

# yt-dlp.exe
$ytdlpDest = Join-Path $OutputDir $Windows.yt_dlp.filename
Save-Url $Windows.yt_dlp.url $ytdlpDest

# ffmpeg.exe from zip
$ffmpegZip = Join-Path $Temp "ffmpeg.zip"
Save-Url $Windows.ffmpeg.url $ffmpegZip
$ffmpegPattern = ($Windows.ffmpeg.zip_path -split "/")[-1]
Extract-FromZip $ffmpegZip $ffmpegPattern (Join-Path $OutputDir $Windows.ffmpeg.filename)

# aria2c.exe from zip
$ariaZip = Join-Path $Temp "aria2.zip"
Save-Url $Windows.aria2.url $ariaZip
$ariaPattern = ($Windows.aria2.zip_path -split "/")[-1]
Extract-FromZip $ariaZip $ariaPattern (Join-Path $OutputDir $Windows.aria2.filename)

Write-Host "Bundled tools written to $OutputDir"
Get-ChildItem $OutputDir | Format-Table Name, Length
