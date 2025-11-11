# Quick Run Script - Uses Flutter directly for fresh build
# Run this if you want the latest changes on emulator

Write-Host "Checking for connected devices..." -ForegroundColor Yellow
flutter devices

Write-Host "`nUninstalling old app from emulator (if exists)..." -ForegroundColor Yellow
try {
    & C:\Android\platform-tools\adb.exe -s emulator-5554 uninstall com.example.smartsplit 2>$null
    Write-Host "Old app uninstalled successfully" -ForegroundColor Green
} catch {
    Write-Host "No old app to uninstall (this is OK)" -ForegroundColor Gray
}

Write-Host "`nBuilding and running latest version..." -ForegroundColor Green
Write-Host "This may take a few minutes..." -ForegroundColor Gray

flutter run

Write-Host "`nIf the app started successfully, you should see it running!" -ForegroundColor Cyan
