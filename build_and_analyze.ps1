#!/usr/bin/env pwsh
# Build and Analyze APK Size Script
# This script builds optimized APKs and provides size analysis

Write-Host "🚀 Building Optimized Release Builds..." -ForegroundColor Cyan
Write-Host ""

# Fix build.gradle.kts if Flutter reverted it
Write-Host "Checking build.gradle.kts..." -ForegroundColor Yellow
$buildGradlePath = "android\app\build.gradle.kts"
$content = Get-Content $buildGradlePath -Raw
if ($content -match "minSdkVersion flutter\.minSdkVersion") {
    Write-Host "⚠️  Fixing Flutter's auto-upgrade changes..." -ForegroundColor Yellow
    $content = $content -replace "minSdkVersion flutter\.minSdkVersion", "minSdk = 23"
    Set-Content -Path $buildGradlePath -Value $content
    Write-Host "✅ Fixed build.gradle.kts" -ForegroundColor Green
}

Write-Host ""

# Build Release APK
Write-Host "📦 Building Release APK..." -ForegroundColor Cyan
Set-Location android
& .\gradlew.bat assembleRelease --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Release APK built successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Release APK build failed!" -ForegroundColor Red
    Set-Location ..
    exit 1
}

Write-Host ""

# Build App Bundle
Write-Host "📦 Building App Bundle (AAB)..." -ForegroundColor Cyan
& .\gradlew.bat bundleRelease --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ App Bundle built successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ App Bundle build failed!" -ForegroundColor Red
}

Set-Location ..

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "📊 SIZE ANALYSIS" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""

# Analyze APK
Write-Host "📱 RELEASE APK (for direct installation):" -ForegroundColor Cyan
$apkPath = "build\app\outputs\apk\release\app-release.apk"
if (Test-Path $apkPath) {
    $apk = Get-Item $apkPath
    $sizeMB = [math]::Round($apk.Length / 1MB, 2)
    Write-Host "   Location: $apkPath" -ForegroundColor White
    Write-Host "   Size: $sizeMB MB" -ForegroundColor Yellow
    
    # Install command
    Write-Host ""
    Write-Host "   📲 To install on device:" -ForegroundColor Cyan
    Write-Host "   adb install `"$apkPath`"" -ForegroundColor White
} else {
    Write-Host "   ❌ APK not found!" -ForegroundColor Red
}

Write-Host ""

# Analyze AAB
Write-Host "📦 APP BUNDLE (for Google Play Store):" -ForegroundColor Cyan
$aabPath = "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    $aab = Get-Item $aabPath
    $sizeMB = [math]::Round($aab.Length / 1MB, 2)
    Write-Host "   Location: $aabPath" -ForegroundColor White
    Write-Host "   Size: $sizeMB MB" -ForegroundColor Yellow
    
    # Size comparison
    $apkSize = (Get-Item $apkPath).Length / 1MB
    $aabSize = $aab.Length / 1MB
    $savings = [math]::Round((($apkSize - $aabSize) / $apkSize) * 100, 1)
    Write-Host "   💰 Savings vs APK: $savings%" -ForegroundColor Green
} else {
    Write-Host "   ❌ AAB not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""

# Show what's inside the APK
Write-Host "🔍 APK CONTENTS BREAKDOWN:" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $apkPath) {
    # Use PowerShell to inspect APK (it's a ZIP file)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
    
    $totalSize = 0
    $libSize = 0
    $assetsSize = 0
    $resSize = 0
    $dexSize = 0
    
    foreach ($entry in $zip.Entries) {
        $totalSize += $entry.Length
        
        if ($entry.FullName -like "lib/*") {
            $libSize += $entry.Length
        } elseif ($entry.FullName -like "assets/*") {
            $assetsSize += $entry.Length
        } elseif ($entry.FullName -like "res/*") {
            $resSize += $entry.Length
        } elseif ($entry.FullName -like "*.dex") {
            $dexSize += $entry.Length
        }
    }
    
    $zip.Dispose()
    
    Write-Host "   Flutter Engine (lib/):     $([math]::Round($libSize/1MB, 2)) MB ($([math]::Round($libSize/$totalSize*100, 1))%)" -ForegroundColor White
    Write-Host "   Code (DEX files):          $([math]::Round($dexSize/1MB, 2)) MB ($([math]::Round($dexSize/$totalSize*100, 1))%)" -ForegroundColor White
    Write-Host "   Resources (res/):          $([math]::Round($resSize/1MB, 2)) MB ($([math]::Round($resSize/$totalSize*100, 1))%)" -ForegroundColor White
    Write-Host "   Assets (assets/):          $([math]::Round($assetsSize/1MB, 2)) MB ($([math]::Round($assetsSize/$totalSize*100, 1))%)" -ForegroundColor White
    Write-Host "   Other:                     $([math]::Round(($totalSize-$libSize-$assetsSize-$resSize-$dexSize)/1MB, 2)) MB" -ForegroundColor White
    
    Write-Host ""
    Write-Host "   💡 To reduce size further:" -ForegroundColor Yellow
    Write-Host "   • Use App Bundle for Play Store (smaller)" -ForegroundColor White
    Write-Host "   • Optimize/compress images in assets/" -ForegroundColor White
    Write-Host "   • Remove unused dependencies" -ForegroundColor White
    Write-Host "   • Use vector graphics instead of PNGs" -ForegroundColor White
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ Build Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""
Write-Host "📖 For more optimization tips, see: APK_SIZE_OPTIMIZATION.md" -ForegroundColor Cyan
