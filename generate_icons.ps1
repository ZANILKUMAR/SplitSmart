# Generate App Icons Script
# This will create all launcher icons and favicons from your logo.png

Write-Host "Generating app icons from assets/logo.png..." -ForegroundColor Green

# Generate icons
flutter pub run flutter_launcher_icons

Write-Host "`nIcons generated successfully!" -ForegroundColor Cyan
Write-Host "`nGenerated icons for:" -ForegroundColor Yellow
Write-Host "  - Android (launcher icon)" -ForegroundColor White
Write-Host "  - iOS (app icon)" -ForegroundColor White
Write-Host "  - Web (favicon)" -ForegroundColor White
Write-Host "  - Windows (app icon)" -ForegroundColor White
Write-Host "  - macOS (app icon)" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run: flutter clean" -ForegroundColor White
Write-Host "2. Run: flutter pub get" -ForegroundColor White
Write-Host "3. Run your app to see the new icons!" -ForegroundColor White
