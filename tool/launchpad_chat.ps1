$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginBody = @{
  username = "sky-$($payload.employee_id)"
  password = [string]$payload.password
} | ConvertTo-Json -Compress

try {
  $null = Invoke-RestMethod `
    -Uri 'https://dns.watchtower247.in/router_login/mobile_auth_api.php' `
    -Method Post `
    -ContentType 'application/json' `
    -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
    -Body $loginBody `
    -WebSession $session

  if ($payload.action -eq 'history') {
    $encodedJid = [Uri]::EscapeDataString([string]$payload.jid)
    $result = Invoke-RestMethod `
      -Uri "https://dns.watchtower247.in/router_login/chat/history.php?jid=$encodedJid" `
      -Method Get `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -WebSession $session
  }
  elseif ($payload.action -eq 'recent') {
    $result = Invoke-RestMethod `
      -Uri 'https://dns.watchtower247.in/router_login/chat/recent_chats.php' `
      -Method Get `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -WebSession $session
  }
  elseif ($payload.action -eq 'send') {
    $messageBody = @{
      to = [string]$payload.to
      message = [string]$payload.message
      reply_to_id = [string]$payload.reply_to_id
      mentions = @($payload.mentions)
      thread_root_id = [string]$payload.thread_root_id
      source_device = [string]$payload.source_device
      source_name = [string]$payload.source_name
    } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod `
      -Uri 'https://dns.watchtower247.in/router_login/chat/send_message.php' `
      -Method Post `
      -ContentType 'application/json' `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -Body $messageBody `
      -WebSession $session
  }
  elseif ($payload.action -eq 'create_group') {
    $groupBody = @{
      group_name = [string]$payload.group_name
      members = @($payload.members)
    } | ConvertTo-Json -Depth 5 -Compress
    $result = Invoke-RestMethod `
      -Uri 'https://dns.watchtower247.in/router_login/chat/create_group.php' `
      -Method Post `
      -ContentType 'application/json' `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -Body $groupBody `
      -WebSession $session
  }
  elseif ($payload.action -eq 'group_members') {
    $groupId = [Uri]::EscapeDataString([string]$payload.group_id)
    $result = Invoke-RestMethod `
      -Uri "https://dns.watchtower247.in/router_login/chat/group_members.php?group_id=$groupId" `
      -Method Get `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -WebSession $session
  }
  elseif ($payload.proxy_action -eq 'manage_group') {
    $manageBody = @{
      group_id = [int]$payload.group_id
      emp_id = [int]$payload.emp_id
      action = [string]$payload.action
    } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod `
      -Uri 'https://dns.watchtower247.in/router_login/chat/manage_group.php' `
      -Method Post `
      -ContentType 'application/json' `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -Body $manageBody `
      -WebSession $session
  }
  elseif ($payload.proxy_action -eq 'delete_message') {
    $deleteBody = @{
      message_id = [int]$payload.message_id
    } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod `
      -Uri 'https://dns.watchtower247.in/router_login/chat/delete_message.php' `
      -Method Post `
      -ContentType 'application/json' `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -Body $deleteBody `
      -WebSession $session
  }
  elseif ($payload.proxy_action -eq 'edit_message') {
    $editBody = @{
      message_id = [int]$payload.message_id
      message = [string]$payload.message
    } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod `
      -Uri 'https://dns.watchtower247.in/router_login/chat/edit_message.php' `
      -Method Post `
      -ContentType 'application/json' `
      -Headers @{ 'User-Agent' = 'SkylinkMessenger/1.0' } `
      -Body $editBody `
      -WebSession $session
  }
  else {
    throw 'Unsupported chat action'
  }

  @{
    status_code = 200
    body = $result
  } | ConvertTo-Json -Depth 10 -Compress
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
      $errorBody = @{
        status = $false
        error = $_.ErrorDetails.Message
      }
    }
  }
  if (-not $errorBody) {
    $errorBody = @{
      status = $false
      error = 'Launchpad chat request failed'
    }
  }
  @{
    status_code = $statusCode
    body = $errorBody
  } | ConvertTo-Json -Depth 10 -Compress
}
