# Run on Android Emulator
# This script runs the app on Android emulator

Write-Host "SplitSmart - Running on Android Emulator" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "`nChecking for Android emulator..." -ForegroundColor Yellow
flutter devices

Write-Host "`nStarting app on emulator..." -ForegroundColor Green
Write-Host "Building and installing... (this may take a minute)" -ForegroundColor Gray
Write-Host "`nTip: Press 'r' to hot reload, 'R' to hot restart" -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor Cyan

# Run on Android
flutter run -d android

Write-Host "`nApp should now be running on your emulator!" -ForegroundColor Cyan
