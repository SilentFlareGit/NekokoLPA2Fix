; Inno Setup Installer Script for NekokoLPA2 (community public build).
; Compiled with Inno Setup Compiler (ISCC.exe).

#define AppName "NekokoLPA 2 Community"
#define AppShortName "nlpa2"
#define AppPublisher "ee.nekoko"
#define AppURL "https://github.com/iebb/NekokoLPA2"
#define AppExeName "nlpa2.exe"

#ifndef AppVersion
#define AppVersion "2.0.0"
#endif

#ifndef AppBuildNumber
#define AppBuildNumber "0"
#endif
#define AppVersionFull AppVersion + "." + AppBuildNumber

[Setup]
AppId={{B0C7D5A1-2E4F-4F4A-9A2B-71F0C2C2A9E1}
AppName={#AppName}
AppVersion={#AppVersionFull}
AppVerName={#AppName} {#AppVersionFull}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\NekokoLPA2
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=..\build\windows\installer
OutputBaseFilename=ee.nekoko.nlpa2.open-{#AppVersion}-{#AppBuildNumber}-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

VersionInfoVersion={#AppVersionFull}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersionFull}
VersionInfoCopyright=Copyright (C) ee.nekoko. All rights reserved.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
