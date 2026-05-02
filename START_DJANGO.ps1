Write-Host "Starting Django server on 0.0.0.0:9000..." -ForegroundColor Green
Set-Location smartju
python manage.py runserver 0.0.0.0:9000
