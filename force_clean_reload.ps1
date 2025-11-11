# Force Clean Reload - Clear All Caches
Write-Host "Forcing complete clean reload..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`n1. Stopping Chrome and Flutter..." -ForegroundColor Yellow
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "flutter" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "`n2. Deleting build cache..." -ForegroundColor Yellow
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".flutter-plugins" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".flutter-plugins-dependencies" -Force -ErrorAction SilentlyContinue

Write-Host "`n3. Running flutter clean..." -ForegroundColor Yellow
flutter clean

Write-Host "`n4. Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n5. Launching with clean cache..." -ForegroundColor Green
Write-Host "Press Ctrl+Shift+Delete in Chrome to clear browser cache if needed" -ForegroundColor Gray
Write-Host "Or use Incognito mode (Ctrl+Shift+N) to test without cache" -ForegroundColor Gray
Write-Host "======================================`n" -ForegroundColor Cyan

flutter run -d chrome

Write-Host "`nDone!" -ForegroundColor Cyan
