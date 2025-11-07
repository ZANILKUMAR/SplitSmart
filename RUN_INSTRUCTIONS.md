# SplitSmart - How to Run

## Problem with `flutter run`
The command `flutter run` has an auto-upgrade issue that breaks the build.gradle.kts file.

## Solution: Use the Custom Run Scripts

### Option 1: Use the Batch Script (Windows)
```cmd
run_app.bat
```

### Option 2: Use the PowerShell Script
```powershell
.\run_app.ps1
```

### Option 3: Use the Manual Command
```powershell
cd android; $env:JAVA_HOME = "C:\Program Files\Java\jdk-17"; .\gradlew.bat assembleDebug; cd ..; C:\Android\platform-tools\adb.exe -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk; C:\Android\platform-tools\adb.exe -s emulator-5554 shell am start -n com.example.smartsplit/.MainActivity
```

## If build.gradle.kts Gets Corrupted Again

If you see this error:
```
minSdkVersion flutter.minSdkVersion
            ^ Expecting an element
```

Fix it by changing this line in `android/app/build.gradle.kts`:
```kotlin
minSdkVersion flutter.minSdkVersion  // ❌ Wrong (Flutter auto-upgrade adds this)
```

To:
```kotlin
minSdk = 23  // ✅ Correct
```

## Firebase Configuration
The app is configured with Firebase Authentication using:
- Project ID: `smartsplit-zanil`
- API Key: Configured in `lib/firebase_options.dart`
- google-services.json: Located in `android/app/`

## Login Credentials
- Test account: `test@test.com` / `password`
- Your account: `ak@ak.com` / (your Firebase password)

If `ak@ak.com` doesn't work, register a new account in the app first.
