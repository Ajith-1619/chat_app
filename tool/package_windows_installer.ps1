$ErrorActionPreference = 'Stop'
$Version = '2.0.3'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ReleaseDir = Join-Path $Root 'release'
$WinBuild = Join-Path $Root 'build\windows\x64\runner\Release'
$Stage = 'C:\Temp\skylink_installer_2_0_3'
$PayloadZip = Join-Path $Stage 'SkylinkChatPayload.zip'
$Installer = Join-Path $Stage "Skylink-Chat-Setup-v$Version.exe"
$FinalInstaller = Join-Path $ReleaseDir "Skylink-Chat-Setup-v$Version.exe"
$Sed = Join-Path $Stage 'SkylinkChat.sed'
$InstallCmd = Join-Path $Stage 'install.cmd'

if (-not (Test-Path $WinBuild)) {
  throw "Windows build folder not found: $WinBuild"
}

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
if (Test-Path $Stage) {
  Remove-Item -LiteralPath $Stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
Compress-Archive -Path (Join-Path $WinBuild '*') -DestinationPath $PayloadZip -Force

$installLines = @(
  '@echo off',
  'setlocal',
  'set "DEST=%LOCALAPPDATA%\Programs\Skylink Chat"',
  'set "STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Skylink Chat"',
  'set "LOG=%TEMP%\SkylinkChatInstall.log"',
  'if exist "%DEST%" rmdir /s /q "%DEST%"',
  'mkdir "%DEST%" >nul 2>nul',
  'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference=''Stop''; $zip=''%~dp0SkylinkChatPayload.zip''; $dest=$env:LOCALAPPDATA+''\Programs\Skylink Chat''; Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force; if(-not (Test-Path -LiteralPath ($dest+''\skylink_chat.exe''))){ throw ''skylink_chat.exe was not extracted to ''+$dest }" > "%LOG%" 2>&1',
  'if errorlevel 1 type "%LOG%" & exit /b 1',
  'if not exist "%DEST%\skylink_chat.exe" echo skylink_chat.exe missing after install & exit /b 1',
  'mkdir "%STARTMENU%" >nul 2>nul',
  'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$dest=$env:LOCALAPPDATA+''\Programs\Skylink Chat''; $s=(New-Object -ComObject WScript.Shell).CreateShortcut($env:APPDATA+''\Microsoft\Windows\Start Menu\Programs\Skylink Chat\Skylink Chat.lnk''); $s.TargetPath=$dest+''\skylink_chat.exe''; $s.WorkingDirectory=$dest; $s.Save()"',
  'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$dest=$env:LOCALAPPDATA+''\Programs\Skylink Chat''; $d=[Environment]::GetFolderPath(''Desktop''); $s=(New-Object -ComObject WScript.Shell).CreateShortcut($d+''\Skylink Chat.lnk''); $s.TargetPath=$dest+''\skylink_chat.exe''; $s.WorkingDirectory=$dest; $s.Save()"',
  'start "" "%DEST%\skylink_chat.exe"',
  'exit /b 0'
)
$installLines | Set-Content -LiteralPath $InstallCmd -Encoding ASCII

$sedLines = @(
  '[Version]',
  'Class=IEXPRESS',
  'SEDVersion=3',
  '[Options]',
  'PackagePurpose=InstallApp',
  'ShowInstallProgramWindow=1',
  'HideExtractAnimation=1',
  'UseLongFileName=1',
  'InsideCompressed=0',
  'CAB_FixedSize=0',
  'CAB_ResvCodeSigning=0',
  'RebootMode=N',
  'InstallPrompt=',
  'DisplayLicense=',
  "FinishMessage=Skylink Chat v$Version installed.",
  "TargetName=$Installer",
  "FriendlyName=Skylink Chat v$Version",
  'AppLaunched=install.cmd',
  'PostInstallCmd=<None>',
  'AdminQuietInstCmd=install.cmd',
  'UserQuietInstCmd=install.cmd',
  'SourceFiles=SourceFiles',
  '[Strings]',
  'FILE0="install.cmd"',
  'FILE1="SkylinkChatPayload.zip"',
  '[SourceFiles]',
  "SourceFiles0=$Stage",
  '[SourceFiles0]',
  '%FILE0%=',
  '%FILE1%='
)
$sedLines | Set-Content -LiteralPath $Sed -Encoding ASCII

& "$env:WINDIR\System32\iexpress.exe" /N /Q $Sed
for ($i = 0; $i -lt 90 -and -not (Test-Path $Installer); $i++) {`r`n  Start-Sleep -Milliseconds 500`r`n}
if (-not (Test-Path $Installer)) {
  throw "Installer was not created: $Installer"
}

Copy-Item -LiteralPath $Installer -Destination $FinalInstaller -Force
Get-Item -LiteralPath $FinalInstaller | Select-Object FullName,Length,LastWriteTime
