# Run Flutter Web with Clean Chrome Profile
# This clears Chrome cache and ensures fresh build

Write-Host "Running Flutter Web with clean Chrome profile..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`n1. Stopping existing Chrome/Flutter processes..." -ForegroundColor Yellow
try {
    Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "flutter" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
} catch {}

Write-Host "`n2. Cleaning build cache..." -ForegroundColor Yellow
flutter clean

Write-Host "`n3. Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n4. Launching with clean Chrome profile..." -ForegroundColor Green
Write-Host "======================================`n" -ForegroundColor Cyan

# Run with clean Chrome profile
flutter run -d chrome --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=temp_chrome"

Write-Host "`nDone!" -ForegroundColor Cyan
