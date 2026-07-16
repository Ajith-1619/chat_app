
$ErrorActionPreference = 'Stop'
$fz = Join-Path $env:APPDATA 'FileZilla\sitemanager.xml'
[xml]$xml = Get-Content -LiteralPath $fz
$server = $xml.SelectNodes('//Server') | Where-Object { $_.Host -eq '168.144.88.207' } | Select-Object -First 1
if (-not $server) { throw 'FileZilla server entry not found for 168.144.88.207' }
$user = $server.User.InnerText
if ([string]::IsNullOrWhiteSpace($user)) { $user = 'root' }
$passNode = $server.Pass
$pass = $passNode.InnerText
if ($passNode.encoding -eq 'base64') {
  $pass = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pass))
}
& 'C:\Program Files\PuTTY\psftp.exe' -batch -hostkey 'SHA256:s0r3VTUY8FhV/L74jV+ASCExl4DhKYusLqKj/mY6NPg' -pw $pass ($user + '@168.144.88.207') -b '.\tool\deploy_2_0_4.psftp'
if ($LASTEXITCODE -ne 0) { throw "psftp failed with exit code $LASTEXITCODE" }
