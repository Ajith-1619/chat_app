$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$body = @{
  username = "sky-$($payload.employee_id)"
  password = [string]$payload.password
} | ConvertTo-Json -Compress

try {
  $result = Invoke-RestMethod `
    -Uri 'https://dns.watchtower247.in/router_login/mobile_auth_api.php' `
    -Method Post `
    -ContentType 'application/json' `
    -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
    -Body $body `
    -WebSession $session

  $directory = Invoke-RestMethod `
    -Uri 'https://dns.watchtower247.in/router_login/chat/search_users.php?search=' `
    -Method Get `
    -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
    -WebSession $session

  $employees = @(
    $directory.users | ForEach-Object {
      @{
        emp_id = [string]$_.emp_id
        name = [string]$_.name
        designation = [string]$_.designation
        jid = [string]$_.jid
      }
    }
  )

  $cookies = $session.Cookies.GetCookies(
    [Uri]'https://dns.watchtower247.in/router_login/'
  ) | ForEach-Object {
    "$($_.Name)=$($_.Value)"
  }

  @{
    status_code = 200
    body = $result
    cookies = ($cookies -join '; ')
    users = $employees
  } | ConvertTo-Json -Depth 8 -Compress
}
catch {
  $statusCode = 500
  if ($_.Exception.Response) {
    $statusCode = [int]$_.Exception.Response.StatusCode
  }
  $errorBody = $null
  if ($_.ErrorDetails.Message) {
    try {
      $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    }
    catch {
      $errorBody = @{ ok = $false; error = $_.ErrorDetails.Message }
    }
  }
  if (-not $errorBody) {
    $errorBody = @{ ok = $false; error = 'Launchpad login failed' }
  }
  @{
    status_code = $statusCode
    body = $errorBody
    cookies = ''
    users = @()
  } | ConvertTo-Json -Depth 8 -Compress
}
