# Run Flutter Web Without Developer Mode
# This script runs the web version without requiring symlinks

Write-Host "Running Flutter Web (no Developer Mode needed)..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`nCleaning previous build..." -ForegroundColor Yellow
flutter clean

Write-Host "`nGetting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`nLaunching on Chrome..." -ForegroundColor Green
Write-Host "======================================`n" -ForegroundColor Cyan

# Run on web - doesn't need symlinks for Android/iOS plugins
flutter run -d chrome

Write-Host "`nDone!" -ForegroundColor Cyan
