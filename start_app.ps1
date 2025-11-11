# Simple Run Script
# Automatically detects and runs on available device

Write-Host "SplitSmart - Starting App..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`nChecking available devices..." -ForegroundColor Yellow
flutter devices

Write-Host "`nStarting app..." -ForegroundColor Green
Write-Host "Flutter will automatically select a device" -ForegroundColor Gray
Write-Host "Press 'r' to hot reload, 'R' to hot restart" -ForegroundColor Gray
Write-Host "======================================`n" -ForegroundColor Cyan

flutter run
