# SmartJudi - Start Essential Local Services
# This script starts auth, cases, and legal Django services locally
# when Docker is not available.

$env:PYTHONPATH = "$PSScriptRoot\shared;$PSScriptRoot\services\auth;$PSScriptRoot\services\cases;$PSScriptRoot\services\legal;$PSScriptRoot\services\hearings;$PSScriptRoot\services\search"
$env:JWT_SECRET_KEY = "django-insecure-4cyci@v!&=khm4+b)(^n@&k0((=5o5=o^r8w&)#4h=wdl)cjx="
$env:INTERNAL_API_KEY = "smartjudi-internal-2026"
$env:DEBUG = "1"

# Auth Service -> port 8001
$env:DATABASE_URL = "postgres://smartjudi:smartjudi_secret@localhost:5432/smartjudi_auth"
$env:DJANGO_SETTINGS_MODULE = "auth_service.settings"
Start-Process -NoNewWindow python -ArgumentList "-m", "django", "runserver", "0.0.0.0:8001" -WorkingDirectory "$PSScriptRoot\services\auth"

# Cases Service -> port 8002
$env:DATABASE_URL = "postgres://smartjudi:smartjudi_secret@localhost:5432/smartjudi_cases"
$env:DJANGO_SETTINGS_MODULE = "cases_service.settings"
$env:AUTH_SERVICE_URL = "http://127.0.0.1:8001"
Start-Process -NoNewWindow python -ArgumentList "-m", "django", "runserver", "0.0.0.0:8002" -WorkingDirectory "$PSScriptRoot\services\cases"

# Legal Service -> port 8003
$env:DATABASE_URL = "postgres://smartjudi:smartjudi_secret@localhost:5432/smartjudi_legal"
$env:DJANGO_SETTINGS_MODULE = "legal_service.settings"
Start-Process -NoNewWindow python -ArgumentList "-m", "django", "runserver", "0.0.0.0:8003" -WorkingDirectory "$PSScriptRoot\services\legal"

# Hearings Service -> port 8004
$env:DATABASE_URL = "postgres://smartjudi:smartjudi_secret@localhost:5432/smartjudi_hearings"
$env:DJANGO_SETTINGS_MODULE = "hearings_service.settings"
Start-Process -NoNewWindow python -ArgumentList "-m", "django", "runserver", "0.0.0.0:8004" -WorkingDirectory "$PSScriptRoot\services\hearings"

# Search Service -> port 8005
$env:DATABASE_URL = "postgres://smartjudi:smartjudi_secret@localhost:5432/smartjudi_search"
$env:DJANGO_SETTINGS_MODULE = "search_service.settings"
Start-Process -NoNewWindow python -ArgumentList "-m", "django", "runserver", "0.0.0.0:8005" -WorkingDirectory "$PSScriptRoot\services\search"

Write-Host "All services starting..."
Write-Host "Auth    -> http://localhost:8001"
Write-Host "Cases   -> http://localhost:8002"
Write-Host "Legal   -> http://localhost:8003"
Write-Host "Hearings-> http://localhost:8004"
Write-Host "Search  -> http://localhost:8005"
Write-Host "Gateway -> http://localhost:8000 (already running)"
