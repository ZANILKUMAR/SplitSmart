# SplitSmart App Icon Generation Guide

## Quick Method (Recommended)

Since SVG files are created but flutter_launcher_icons needs PNG files, you have two options:

### Option 1: Use an online converter (Easiest)
1. Open https://cloudconvert.com/svg-to-png or https://svgtopng.com/
2. Upload `assets/icon/app_icon.svg`
3. Set size to 1024x1024
4. Download as `app_icon.png` and save to `assets/icon/`
5. Upload `assets/icon/app_icon_foreground.svg`
6. Set size to 1024x1024
7. Download as `app_icon_foreground.png` and save to `assets/icon/`

### Option 2: Skip PNG conversion (Use SVG directly with modified config)

I'll create a simplified approach using the SVG files we already have for web,
and manually create the Android icons.

## After getting PNG files:

Run these commands in your terminal:

```bash
# Install dependencies
flutter pub get

# Generate all launcher icons
flutter pub run flutter_launcher_icons

# Or use dart command
dart run flutter_launcher_icons
```

This will automatically generate:
- Android icons (all densities: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- Android adaptive icons (foreground + background)
- iOS icons (all required sizes)
- Web icons (if configured)

## Verify the icons:

After running the command, check:
- `android/app/src/main/res/mipmap-*/` for Android icons
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` for iOS icons

Then rebuild your app:
```bash
flutter clean
flutter build apk --release
```

Your APK will now have the new SplitSmart logo!
