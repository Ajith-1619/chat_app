
$ErrorActionPreference = 'Continue'
$urls = @(
  'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.4.apk',
  'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v2.0.4.exe',
  'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v2.0.4.zip',
  'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.4.apk.sha256',
  'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v2.0.4.exe.sha256',
  'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v2.0.4.zip.sha256'
)
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 30
    [pscustomobject]@{ Url = $u; Status = $r.StatusCode; Length = $r.Headers['Content-Length'] }
  } catch {
    [pscustomobject]@{ Url = $u; Status = 'ERR'; Length = $_.Exception.Message }
  }
}
