$ErrorActionPreference = 'Stop'
$expectedProxyVersion = '2026.06.23.2'
$minimumFreeSpaceGB = 2

$systemDriveName = $env:SystemDrive.TrimEnd(':')
$systemDrive = Get-PSDrive -Name $systemDriveName
$freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 2)
if ($freeSpaceGB -lt $minimumFreeSpaceGB) {
  throw "Not enough free space on $($env:SystemDrive). Flutter web needs at least $minimumFreeSpaceGB GB free; currently $freeSpaceGB GB is available."
}

function Stop-SkylinkProxy {
  $listeners = Get-NetTCPConnection `
    -LocalPort 8787 `
    -State Listen `
    -ErrorAction SilentlyContinue

  foreach ($listener in $listeners) {
    Stop-Process `
      -Id $listener.OwningProcess `
      -Force `
      -ErrorAction SilentlyContinue
  }

  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $remaining = Get-NetTCPConnection `
      -LocalPort 8787 `
      -State Listen `
      -ErrorAction SilentlyContinue
    if (-not $remaining) {
      return
    }
    Start-Sleep -Milliseconds 250
  }
}

Stop-SkylinkProxy

$securePassword = Read-Host 'Ejabberd admin password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)

try {
  $env:SKYLINK_EJABBERD_ADMIN_JID = 'admin@chat.skylinkonline.net'
  $env:SKYLINK_EJABBERD_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
}
finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
}

$proxy = Start-Process `
  -FilePath 'dart' `
  -ArgumentList @('run', 'tool/dev_api_proxy.dart') `
  -WorkingDirectory $PSScriptRoot `
  -WindowStyle Hidden `
  -PassThru

$ready = $false
$reportedVersion = $null
for ($attempt = 0; $attempt -lt 60; $attempt++) {
  Start-Sleep -Milliseconds 500

  if ($proxy.HasExited) {
    break
  }

  try {
    $health = Invoke-RestMethod `
      -Uri 'http://127.0.0.1:8787/health' `
      -TimeoutSec 2

    $reportedVersion = $health.version
    if (
      $health.status -eq $true -and
      $reportedVersion -eq $expectedProxyVersion
    ) {
      $ready = $true
      break
    }
  }
  catch {}
}

if (-not $ready) {
  Stop-SkylinkProxy
  Stop-Process -Id $proxy.Id -Force -ErrorAction SilentlyContinue
  if ($reportedVersion) {
    throw "Skylink API helper version mismatch. Expected $expectedProxyVersion but received $reportedVersion."
  }
  if ($proxy.HasExited) {
    throw "Skylink API helper exited during startup with code $($proxy.ExitCode)."
  }
  throw 'Skylink API helper failed to start within 30 seconds.'
}

Write-Host 'Skylink employee-directory helper is ready on port 8787.' `
  -ForegroundColor Green
Write-Host 'The helper stays active until the next run or stop_web.ps1.'

Remove-Item Env:SKYLINK_EJABBERD_ADMIN_JID -ErrorAction SilentlyContinue
Remove-Item Env:SKYLINK_EJABBERD_ADMIN_PASSWORD -ErrorAction SilentlyContinue

flutter run -d chrome
