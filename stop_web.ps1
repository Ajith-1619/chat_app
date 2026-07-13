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

Write-Host 'Skylink employee-directory helper stopped.'
