# How to Update the SplitSmart Logo

## Current Status
- The app is already configured to use `assets/logo.png`
- The logo widget in `lib/widgets/app_logo.dart` is ready to display the image
- You just need to replace the placeholder image with the actual logo

## Steps to Update:

1. **Save the logo image** that was shared (the blue SplitSmart logo with the split wallet icon)

2. **Replace the file:**
   - Navigate to: `F:\ANIL KUMAR\TEST WORKS\SplitSmart\assets\`
   - Replace the existing `logo.png` file with your new logo image
   - Make sure the file name is exactly: `logo.png`

3. **Recommended specifications:**
   - Format: PNG with transparency
   - Size: 512x512 pixels or larger (will be scaled down as needed)
   - Background: Transparent or white

4. **After updating:**
   - Run: `flutter pub get` (to ensure assets are recognized)
   - Hot reload or restart the app to see the new logo

## Where the logo appears:
- Login screen (large, with app name)
- Dashboard (in app bar if used)
- Any screen using the `AppLogo` or `AppLogoIcon` widgets

## Note:
The logo file at `assets/logo.png` currently exists but contains placeholder content.
Just replace it with the actual blue SplitSmart logo image you have.
