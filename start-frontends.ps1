param(
  [string]$Backend = "http://localhost:8006"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrontendDir = Join-Path $Root "ai-interview-frontend"
$AdminDir = Join-Path $Root "ai-interview-admin"

function Ensure-Dependencies {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath (Join-Path $Path "node_modules"))) {
    Push-Location $Path
    try {
      npm install
    } finally {
      Pop-Location
    }
  }
}

Ensure-Dependencies $FrontendDir
Ensure-Dependencies $AdminDir

$frontendCommand = "Set-Location -LiteralPath '$FrontendDir'; `$env:VITE_API_TARGET='$Backend'; npm run dev"
$adminCommand = "Set-Location -LiteralPath '$AdminDir'; `$env:VITE_API_TARGET='$Backend'; npm run dev"

Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCommand
Start-Process powershell -ArgumentList "-NoExit", "-Command", $adminCommand

Write-Host "Frontend target backend: $Backend"
Write-Host "User frontend:  http://localhost:3000"
Write-Host "Admin frontend: http://localhost:3001"
