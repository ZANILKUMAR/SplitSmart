#!/usr/bin/env pwsh
# View Flutter app logs filtered for important messages

Write-Host "📱 Viewing SmartSplit App Logs" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

try {
    # Check if adb is available
    $adbPath = Get-Command adb -ErrorAction SilentlyContinue
    
    if (-not $adbPath) {
        Write-Host "❌ adb not found in PATH" -ForegroundColor Red
        Write-Host ""
        Write-Host "Common adb locations:" -ForegroundColor Yellow
        Write-Host "  - C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe"
        Write-Host "  - C:\Android\platform-tools\adb.exe"
        Write-Host ""
        Write-Host "To add adb to PATH:" -ForegroundColor Cyan
        Write-Host "  1. Find your Android SDK location"
        Write-Host "  2. Add the platform-tools folder to your PATH environment variable"
        Write-Host "  3. Restart PowerShell"
        Write-Host ""
        
        # Try common locations
        $commonPaths = @(
            "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe",
            "C:\Android\platform-tools\adb.exe",
            "C:\Android\Sdk\platform-tools\adb.exe"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-Host "✅ Found adb at: $path" -ForegroundColor Green
                Write-Host "Using this adb for logging..." -ForegroundColor Cyan
                Write-Host ""
                
                & $path -s emulator-5554 logcat | Select-String -Pattern "flutter|Flutter|error|Error|exception|Exception|GroupService|firebase|Firestore"
                exit 0
            }
        }
        
        Write-Host "Could not find adb in common locations." -ForegroundColor Red
        exit 1
    }
    
    # adb is in PATH, use it
    Write-Host "✅ Using adb from PATH" -ForegroundColor Green
    Write-Host ""
    
    # Clear the log first
    adb -s emulator-5554 logcat -c
    
    # Start filtering logs
    adb -s emulator-5554 logcat | Select-String -Pattern "flutter|Flutter|error|Error|exception|Exception|GroupService|firebase|Firestore|PERMISSION"
    
} catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure:" -ForegroundColor Yellow
    Write-Host "  1. The emulator is running (emulator-5554)"
    Write-Host "  2. The app is running"
    Write-Host "  3. adb is installed and in PATH"
    exit 1
}
