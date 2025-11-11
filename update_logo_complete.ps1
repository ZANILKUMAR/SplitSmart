# Complete Logo Update Script
# This will regenerate all icons and clean caches to use your new logo

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Complete Logo Update Process" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Step 1: Check logo
Write-Host "`n[1/5] Checking logo file..." -ForegroundColor Yellow
if (Test-Path "assets\logo.png") {
    $logo = Get-Item "assets\logo.png"
    Write-Host "  ✓ Found: $($logo.Name)" -ForegroundColor Green
    Write-Host "    Size: $([math]::Round($logo.Length/1KB,2)) KB" -ForegroundColor Gray
    
    # Get image dimensions
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($logo.FullName)
    Write-Host "    Dimensions: $($img.Width) x $($img.Height) pixels" -ForegroundColor Gray
    $img.Dispose()
} else {
    Write-Host "  ✗ Logo not found at assets\logo.png" -ForegroundColor Red
    exit 1
}

# Step 2: Generate icons for all platforms
Write-Host "`n[2/5] Generating platform icons..." -ForegroundColor Yellow
Write-Host "  Generating for: Android, iOS, Web, Windows, macOS" -ForegroundColor Gray
flutter pub run flutter_launcher_icons
Write-Host "  ✓ Icons generated" -ForegroundColor Green

# Step 3: Clean old build
Write-Host "`n[3/5] Cleaning old builds..." -ForegroundColor Yellow
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
flutter clean
Write-Host "  ✓ Build cleaned" -ForegroundColor Green

# Step 4: Get dependencies
Write-Host "`n[4/5] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host "  ✓ Dependencies updated" -ForegroundColor Green

# Step 5: Launch app
Write-Host "`n[5/5] Launching app..." -ForegroundColor Yellow
Write-Host "  Opening in Chrome with fresh assets..." -ForegroundColor Gray
Write-Host "======================================`n" -ForegroundColor Cyan

flutter run -d chrome

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "✓ Logo update complete!" -ForegroundColor Green
Write-Host "`nYour app now uses the new logo from:" -ForegroundColor White
Write-Host "  assets/logo.png (1024x1024)" -ForegroundColor Gray
Write-Host "`nIf logo still looks old:" -ForegroundColor Yellow
Write-Host "  - Press Ctrl+Shift+R in Chrome (hard refresh)" -ForegroundColor White
Write-Host "  - Or open in Incognito mode (Ctrl+Shift+N)" -ForegroundColor White
Write-Host "======================================" -ForegroundColor Cyan
