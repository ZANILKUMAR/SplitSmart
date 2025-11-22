# Splitzo App Runner Script (PowerShell)
# This script builds and runs the app without Flutter's auto-upgrade issues

Write-Host "Cleaning old build..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host "`nBuilding Splitzo app..." -ForegroundColor Green
Set-Location android
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
& .\gradlew.bat clean
& .\gradlew.bat assembleDebug
Set-Location ..

Write-Host "`nUninstalling old version from emulator..." -ForegroundColor Yellow
& C:\Android\platform-tools\adb.exe -s emulator-5554 uninstall com.example.smartsplit

Write-Host "`nInstalling new app to emulator..." -ForegroundColor Green
& C:\Android\platform-tools\adb.exe -s emulator-5554 install build\app\outputs\flutter-apk\app-debug.apk

Write-Host "`nLaunching app..." -ForegroundColor Green
& C:\Android\platform-tools\adb.exe -s emulator-5554 shell am start -n com.example.smartsplit/.MainActivity

Write-Host "`nApp is running on emulator!" -ForegroundColor Cyan
Write-Host "To view logs: adb -s emulator-5554 logcat" -ForegroundColor Yellow
