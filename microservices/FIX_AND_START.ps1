# SmartJudi - Fix Port 8000 and Start All Services
# This script kills processes on port 8000 (usually Docker/WSL relay)
# and starts the local gateway and microservices.

$ErrorActionPreference = "Continue"

# 1. Kill anything on port 8000
Write-Host "Checking for processes on port 8000..." -ForegroundColor Cyan
$port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if ($port8000) {
    Write-Host "Found process(es) on port 8000. Killing them..." -ForegroundColor Yellow
    foreach ($conn in $port8000) {
        try {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            Write-Host "Killed process $($conn.OwningProcess)"
        } catch {
            Write-Host "Could not kill process $($conn.OwningProcess). You might need to stop Docker Desktop manually." -ForegroundColor Red
        }
    }
} else {
    Write-Host "Port 8000 is free." -ForegroundColor Green
}

# 2. Start Microservices (8001-8005)
Write-Host "Starting microservices..." -ForegroundColor Cyan
& "$PSScriptRoot\start_local_services.ps1"

# 3. Start Local Gateway (8000)
Write-Host "Starting Local Gateway on port 8000..." -ForegroundColor Cyan
$env:PYTHONPATH = "$PSScriptRoot\local_gateway"
Start-Process -NoNewWindow python -ArgumentList "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000" -WorkingDirectory "$PSScriptRoot\local_gateway"

Write-Host "`nSuccessfully started all services!" -ForegroundColor Green
Write-Host "Gateway: http://localhost:8000"
Write-Host "Auth:    http://localhost:8001"
Write-Host "Cases:   http://localhost:8002"
Write-Host "Legal:   http://localhost:8003"
Write-Host "Hearings: http://localhost:8004"
Write-Host "Search:  http://localhost:8005"
Write-Host "`nPlease refresh your web app now." -ForegroundColor Cyan
