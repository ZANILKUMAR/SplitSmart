# Force Logo Update Script
# This will clear cache and ensure the new logo is used

Write-Host "Forcing logo update..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`n1. Stopping any running instances..." -ForegroundColor Yellow
try {
    Stop-Process -Name "flutter" -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host "`n2. Cleaning build cache..." -ForegroundColor Yellow
flutter clean

Write-Host "`n3. Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n4. Clearing asset cache..." -ForegroundColor Yellow
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n5. Rebuilding with fresh logo..." -ForegroundColor Green
Write-Host "Starting app with new logo..." -ForegroundColor Gray
Write-Host "======================================`n" -ForegroundColor Cyan

# Run on emulator or chrome
flutter run -d android

Write-Host "`nLogo should now be updated!" -ForegroundColor Cyan
