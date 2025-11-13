# Fix Google Sign-In - Step by Step Guide

## Your SHA Fingerprints

**SHA-1:** `B2:A9:48:F1:3A:7F:0C:F2:C5:16:2F:24:62:19:2D:3B:E7:64:A6:C2`

**SHA-256:** `FE:EB:5F:F5:FD:1B:AB:40:CE:F1:80:8E:94:87:3E:4B:79:E7:72:22:BA:F2:69:47:D1:76:4E:99:F6:64:C6:E3`

---

## Step 1: Add SHA Fingerprints to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **SplitSmart** project
3. Click the ⚙️ **Settings** icon → **Project settings**
4. Scroll down to **Your apps** section
5. Find your Android app (com.example.smartsplit)
6. Scroll down to **SHA certificate fingerprints**
7. Click **Add fingerprint**
8. Paste SHA-1: `B2:A9:48:F1:3A:7F:0C:F2:C5:16:2F:24:62:19:2D:3B:E7:64:A6:C2`
9. Click **Add fingerprint** again
10. Paste SHA-256: `FE:EB:5F:F5:FD:1B:AB:40:CE:F1:80:8E:94:87:3E:4B:79:E7:72:22:BA:F2:69:47:D1:76:4E:99:F6:64:C6:E3`
11. Click **Save** or the save icon

---

## Step 2: Enable Google Sign-In in Firebase

1. In Firebase Console, go to **Authentication** (left sidebar)
2. Click **Sign-in method** tab
3. Find **Google** in the list of providers
4. Click on **Google**
5. Toggle **Enable** switch to ON
6. Enter **Support email** (your email address)
7. Click **Save**

---

## Step 3: Download Updated google-services.json

1. Go back to **Project Settings** → **Your apps**
2. Find your Android app
3. Click **Download google-services.json** button
4. **Replace** the file at: `android/app/google-services.json`
   - **Important:** Make sure to replace the existing file

---

## Step 4: Clean and Rebuild

Run these commands in order:

```powershell
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# Run on Android emulator
flutter run -d emulator-5554
```

---

## Step 5: Test Google Sign-In

1. Launch the app on Android emulator
2. Go to **Login** or **Register** screen
3. Click **"Continue with Google"** button
4. Select a Google account
5. Should successfully sign in and navigate to dashboard

---

## Common Errors and Solutions

### Error: "PlatformException(sign_in_failed)"
**Cause:** SHA fingerprints not added or incorrect in Firebase Console  
**Solution:** Double-check SHA-1 and SHA-256 are correctly added to Firebase

### Error: "ERROR_INVALID_CREDENTIAL"
**Cause:** google-services.json not updated after adding SHA fingerprints  
**Solution:** Download fresh google-services.json and replace the old one

### Error: "account-exists-with-different-credential"
**Cause:** Email already registered with email/password  
**Solution:** User should log in with email/password or reset password

### Error: "A network error has occurred"
**Cause:** Emulator doesn't have internet or Google Play Services not configured  
**Solution:** 
- Check emulator has internet connection
- Make sure emulator has Google Play Services (use emulator with Play Store)

### Google Sign-In button does nothing
**Cause:** google-services.json not updated or app not rebuilt after adding SHA fingerprints  
**Solution:** 
1. Download fresh google-services.json
2. Run `flutter clean`
3. Run `flutter pub get`
4. Rebuild and run the app

---

## Verify Configuration Checklist

✅ **Firebase Console:**
- [ ] Google provider enabled in Authentication
- [ ] Support email added
- [ ] SHA-1 fingerprint added: `B2:A9:48:F1:3A:7F:0C:F2:C5:16:2F:24:62:19:2D:3B:E7:64:A6:C2`
- [ ] SHA-256 fingerprint added: `FE:EB:5F:F5:FD:1B:AB:40:CE:F1:80:8E:94:87:3E:4B:79:E7:72:22:BA:F2:69:47:D1:76:4E:99:F6:64:C6:E3`
- [ ] google-services.json downloaded and replaced

✅ **Local Setup:**
- [ ] `flutter clean` executed
- [ ] `flutter pub get` executed
- [ ] App rebuilt and running

✅ **Testing:**
- [ ] "Continue with Google" button visible on login screen
- [ ] Clicking button opens Google account picker
- [ ] Selecting account signs in successfully
- [ ] User navigated to dashboard
- [ ] User document created in Firestore

---

## Need Help?

If you're still facing issues:

1. Check Flutter console logs for specific error messages
2. Verify emulator has Google Play Services installed
3. Try on a physical Android device
4. Restart the emulator after configuration changes
5. Check Firebase Console → Authentication → Users to see if authentication succeeded

---

## Quick Command Reference

```powershell
# Get SHA fingerprints (already done)
cd android; .\gradlew.bat signingReport

# Clean and rebuild
flutter clean
flutter pub get

# Run on emulator
flutter run -d emulator-5554

# Run with verbose logging
flutter run -d emulator-5554 -v

# List available devices
flutter devices
```
