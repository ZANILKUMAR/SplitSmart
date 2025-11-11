# Build Release APK for Android
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Building Release APK" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`n[1/4] Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

Write-Host "`n[2/4] Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[3/4] Building release APK..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
flutter build apk --release

Write-Host "`n[4/4] Build complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`nAPK Location:" -ForegroundColor Yellow
Write-Host "  build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White

# Check if APK was created
if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
    $apk = Get-Item "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "`nAPK Details:" -ForegroundColor Green
    Write-Host "  File: $($apk.Name)" -ForegroundColor Gray
    Write-Host "  Size: $([math]::Round($apk.Length/1MB,2)) MB" -ForegroundColor Gray
    Write-Host "  Path: $($apk.FullName)" -ForegroundColor Gray
    
    Write-Host "`n✓ Release APK built successfully!" -ForegroundColor Green
    Write-Host "`nTo install on device:" -ForegroundColor Yellow
    Write-Host "  1. Connect your Android device via USB" -ForegroundColor White
    Write-Host "  2. Enable USB debugging" -ForegroundColor White
    Write-Host "  3. Run: flutter install" -ForegroundColor White
    Write-Host "  Or copy APK to device and install manually" -ForegroundColor White
} else {
    Write-Host "`n✗ APK not found. Check errors above." -ForegroundColor Red
}

Write-Host "======================================" -ForegroundColor Cyan
