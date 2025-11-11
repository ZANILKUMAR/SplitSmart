# Enable Developer Mode Helper Script
# This script will open Windows Settings to enable Developer Mode

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Enable Developer Mode for Flutter" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`nFlutter requires Developer Mode to be enabled on Windows" -ForegroundColor Yellow
Write-Host "to create symlinks for plugins." -ForegroundColor Yellow

Write-Host "`nOpening Windows Settings..." -ForegroundColor Green
Write-Host "`nPlease follow these steps:" -ForegroundColor White
Write-Host "1. In the Settings window that opens, go to 'For developers'" -ForegroundColor Gray
Write-Host "2. Toggle 'Developer Mode' to ON" -ForegroundColor Gray
Write-Host "3. Click 'Yes' if prompted by User Account Control" -ForegroundColor Gray
Write-Host "4. Close the Settings window" -ForegroundColor Gray
Write-Host "5. Restart your terminal/PowerShell" -ForegroundColor Gray
Write-Host "6. Run your Flutter commands again" -ForegroundColor Gray

Write-Host "`nPress any key to open Settings..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Open Developer Settings
Start-Process "ms-settings:developers"

Write-Host "`nSettings opened! Follow the steps above." -ForegroundColor Green
Write-Host "`nAfter enabling Developer Mode:" -ForegroundColor Yellow
Write-Host "- Close this terminal" -ForegroundColor White
Write-Host "- Open a NEW terminal window" -ForegroundColor White
Write-Host "- Then run: flutter run -d chrome" -ForegroundColor White
Write-Host "`nDone!" -ForegroundColor Cyan
