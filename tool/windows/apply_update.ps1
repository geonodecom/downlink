# Apply a GitHub release zip over an existing Geonode Download Manager install and relaunch.
param(
    [Parameter(Mandatory = $true)]
    [string] $InstallDir,

    [Parameter(Mandatory = $true)]
    [string] $ZipPath,

    [string] $ExeName = "geonode-download-manager.exe"
)

$ErrorActionPreference = "Stop"

$InstallDir = (Resolve-Path $InstallDir).Path
$ZipPath = (Resolve-Path $ZipPath).Path
$ExePath = Join-Path $InstallDir $ExeName

if (-not (Test-Path $ZipPath)) {
    throw "Zip not found: $ZipPath"
}

$Staging = Join-Path ([System.IO.Path]::GetTempPath()) "geonode-update-$(Get-Random)"
New-Item -ItemType Directory -Path $Staging -Force | Out-Null

try {
    Expand-Archive -Path $ZipPath -DestinationPath $Staging -Force

    $payload = $Staging
  $inner = Get-ChildItem -Path $Staging -Directory | Select-Object -First 1
  if ($null -ne $inner -and -not (Test-Path (Join-Path $Staging $ExeName))) {
      $payload = $inner.FullName
  }

  if (-not (Test-Path (Join-Path $payload $ExeName))) {
      throw "Update zip does not contain $ExeName"
  }

  Get-ChildItem -Path $payload -Force | ForEach-Object {
      $dest = Join-Path $InstallDir $_.Name
      if ($_.PSIsContainer) {
          if (Test-Path $dest) {
              Remove-Item -Recurse -Force $dest
          }
          Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
      } else {
          Copy-Item -Path $_.FullName -Destination $dest -Force
      }
  }

  $Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
  $ManifestTemplate = Join-Path $Root "packaging\com.geonode.geonode_download_manager.json"
  $NativeHostName = "com.geonode.geonode_download_manager"
  $HostPath = Join-Path $InstallDir "geonode-download-manager-host.exe"

  if ((Test-Path $ManifestTemplate) -and (Test-Path $HostPath)) {
      $ManifestDir = Join-Path $InstallDir "NativeMessagingHosts"
      New-Item -ItemType Directory -Path $ManifestDir -Force | Out-Null
      $ManifestPath = Join-Path $ManifestDir "$NativeHostName.json"
      $template = Get-Content -Raw $ManifestTemplate
      $jsonHostPath = $HostPath.Replace('\', '\\')
      $manifest = $template.Replace('GEONODE_HOST_PATH', $jsonHostPath)
      Set-Content -Path $ManifestPath -Value $manifest -Encoding UTF8

      $RegistryKeys = @(
          "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$NativeHostName",
          "HKCU:\Software\Chromium\NativeMessagingHosts\$NativeHostName",
          "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$NativeHostName",
          "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\$NativeHostName"
      )
      foreach ($key in $RegistryKeys) {
          New-Item -Path $key -Force | Out-Null
          Set-ItemProperty -Path $key -Name "(default)" -Value $ManifestPath
      }
  }

  if (-not (Test-Path $ExePath)) {
      throw "Updated executable missing: $ExePath"
  }

  Start-Process -FilePath $ExePath -WorkingDirectory $InstallDir
}
finally {
  if (Test-Path $Staging) {
      Remove-Item -Recurse -Force $Staging
  }
}
