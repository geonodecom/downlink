; Downlink Windows per-user installer (Inno Setup 6).
; Build with tool/windows/build_installer.ps1 (passes StageDir, AppVersion, DistDir).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef StageDir
  #define StageDir "..\..\build\installer-stage"
#endif
#ifndef DistDir
  #define DistDir "..\..\dist"
#endif

#define MyAppName "Downlink"
#define MyAppPublisher "Geonode Labs"
#define MyAppURL "https://geonode.com"
#define MyAppExeName "downlink.exe"
#define MyAppHostName "downlink-host.exe"
#define NativeHostName "com.geonode.downlink"

[Setup]
; Stable AppId — do not change across releases (upgrades replace this install).
AppId={{9D4F2E1A-8B7C-4D6E-A1F3-2C5B8E9D0A7F}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppVerName={#MyAppName} {#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\downlink
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
OutputDir={#DistDir}
OutputBaseFilename=Downlink-Setup-{#AppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\com.geonode.downlink.json"; Flags: dontcopy

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Google\Chrome\NativeMessagingHosts\{#NativeHostName}"; ValueType: string; ValueName: ""; ValueData: "{app}\NativeMessagingHosts\{#NativeHostName}.json"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Chromium\NativeMessagingHosts\{#NativeHostName}"; ValueType: string; ValueName: ""; ValueData: "{app}\NativeMessagingHosts\{#NativeHostName}.json"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Edge\NativeMessagingHosts\{#NativeHostName}"; ValueType: string; ValueName: ""; ValueData: "{app}\NativeMessagingHosts\{#NativeHostName}.json"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\{#NativeHostName}"; ValueType: string; ValueName: ""; ValueData: "{app}\NativeMessagingHosts\{#NativeHostName}.json"; Flags: uninsdeletekey

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\NativeMessagingHosts"
Type: files; Name: "{app}\extension-endpoint.json"

[Code]
procedure WriteNativeHostManifest;
var
  TemplatePath: String;
  ManifestDir: String;
  ManifestPath: String;
  HostPath: String;
  JsonHostPath: String;
  Content: AnsiString;
  ContentWide: String;
begin
  ExtractTemporaryFile('com.geonode.downlink.json');
  TemplatePath := ExpandConstant('{tmp}\com.geonode.downlink.json');
  ManifestDir := ExpandConstant('{app}\NativeMessagingHosts');
  ManifestPath := ManifestDir + '\{#NativeHostName}.json';
  HostPath := ExpandConstant('{app}\{#MyAppHostName}');

  if not ForceDirectories(ManifestDir) then
    RaiseException('Unable to create NativeMessagingHosts directory.');

  if not LoadStringFromFile(TemplatePath, Content) then
    RaiseException('Unable to load native messaging host template.');

  ContentWide := String(Content);
  JsonHostPath := HostPath;
  StringChangeEx(JsonHostPath, '\', '\\', True);
  if StringChangeEx(ContentWide, 'DOWNLINK_HOST_PATH', JsonHostPath, True) = 0 then
    RaiseException('Native messaging template missing DOWNLINK_HOST_PATH placeholder.');

  if not SaveStringToFile(ManifestPath, AnsiString(ContentWide), False) then
    RaiseException('Unable to write native messaging host manifest.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    WriteNativeHostManifest;
end;
