# Update Web Favicon and Icons
Write-Host "Updating web favicon and icons..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Copy logo as favicon
Write-Host "`nCopying logo to favicon..." -ForegroundColor Yellow
Copy-Item "assets\logo.png" "web\favicon.png" -Force
Write-Host "✓ web\favicon.png updated" -ForegroundColor Green

# Load logo for resizing
Write-Host "`nCreating web icons..." -ForegroundColor Yellow
Add-Type -AssemblyName System.Drawing
$logo = [System.Drawing.Image]::FromFile("$PWD\assets\logo.png")

# Create 192x192
$icon192 = New-Object System.Drawing.Bitmap(192, 192)
$g = [System.Drawing.Graphics]::FromImage($icon192)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($logo, 0, 0, 192, 192)
$icon192.Save("$PWD\web\icons\Icon-192.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$icon192.Dispose()
Write-Host "✓ web\icons\Icon-192.png created" -ForegroundColor Green

# Create 512x512
$icon512 = New-Object System.Drawing.Bitmap(512, 512)
$g = [System.Drawing.Graphics]::FromImage($icon512)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($logo, 0, 0, 512, 512)
$icon512.Save("$PWD\web\icons\Icon-512.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$icon512.Dispose()
Write-Host "✓ web\icons\Icon-512.png created" -ForegroundColor Green

$logo.Dispose()

# Copy as maskable icons
Copy-Item "web\icons\Icon-192.png" "web\icons\Icon-maskable-192.png" -Force
Write-Host "✓ web\icons\Icon-maskable-192.png created" -ForegroundColor Green

Copy-Item "web\icons\Icon-512.png" "web\icons\Icon-maskable-512.png" -Force
Write-Host "✓ web\icons\Icon-maskable-512.png created" -ForegroundColor Green

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "✓ All web icons updated!" -ForegroundColor Green
Write-Host "`nNext: Clear browser cache or use Incognito mode" -ForegroundColor Yellow
Write-Host "  Press Ctrl+Shift+Delete in Chrome to clear cache" -ForegroundColor Gray
Write-Host "======================================" -ForegroundColor Cyan
