# Google Sign-In Setup Guide

Google Sign-In has been implemented in the app. To enable it, you need to configure Google authentication in Firebase Console.

## What's Already Done ✓

1. **Package Added**: `google_sign_in: ^6.2.1` in `pubspec.yaml`
2. **Backend Implementation**: `signInWithGoogle()` method in `auth_service.dart`
3. **UI Implementation**: "Continue with Google" button added to login and register screens
4. **Sign Out**: Google sign-out integrated with Firebase sign-out

## Firebase Console Configuration Required

### 1. Enable Google Sign-In Provider

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **SplitSmart**
3. Navigate to **Authentication** → **Sign-in method**
4. Find **Google** in the providers list
5. Click on Google and toggle **Enable**
6. Enter a **Support Email** (your email address)
7. Click **Save**

### 2. Android Configuration

For Android, you need to add SHA-1 and SHA-256 fingerprints:

#### Get Debug Fingerprints:
```powershell
cd android
./gradlew signingReport
```

Look for the **SHA-1** and **SHA-256** under `Variant: debug`

#### Add Fingerprints to Firebase:
1. Go to **Project Settings** (gear icon)
2. Under **Your apps**, select your Android app
3. Scroll down to **SHA certificate fingerprints**
4. Click **Add fingerprint**
5. Paste your SHA-1 fingerprint
6. Add SHA-256 fingerprint as well
7. Click **Save**

#### Download Updated google-services.json:
1. After adding fingerprints, download the updated `google-services.json`
2. Replace `android/app/google-services.json` with the new file

### 3. Web Configuration (If using web)

1. In Firebase Console → **Project Settings**
2. Under **Your apps**, select your Web app (or add one)
3. Copy the **Web Client ID**
4. No additional configuration needed for Flutter web

### 4. Run Pub Get

After configuration, run:
```powershell
flutter pub get
```

### 5. Test the Implementation

1. Run the app: `flutter run`
2. Navigate to login or register screen
3. Click "Continue with Google"
4. Select a Google account
5. The app should authenticate and navigate to the dashboard

## How It Works

1. **User clicks "Continue with Google"** → Triggers Google account picker
2. **Selects Google account** → Gets OAuth tokens (access token & ID token)
3. **Creates Firebase credential** → Uses tokens to authenticate with Firebase
4. **Checks Firestore** → Looks for existing user document
5. **Creates user if new** → Saves name, email, and phone from Google account
6. **Returns UserModel** → Navigates to dashboard

## Error Handling

The implementation handles:
- **Account exists with different credential**: If email already registered with email/password
- **Invalid credential**: If OAuth tokens are invalid
- **User disabled**: If account is disabled in Firebase Console
- **User cancellation**: Shows friendly message if user cancels sign-in
- **Network errors**: Shows appropriate error messages

## Testing Checklist

- [ ] Firebase Console: Google provider enabled
- [ ] Android: SHA-1/SHA-256 added (for Android testing)
- [ ] `flutter pub get` executed
- [ ] Test login with Google on login screen
- [ ] Test registration with Google on register screen
- [ ] Verify user document created in Firestore
- [ ] Test sign out (signs out from both Firebase and Google)
- [ ] Test with existing email (should show error)

## Troubleshooting

### Error: "PlatformException(sign_in_failed)"
- **Cause**: SHA-1/SHA-256 fingerprints not added or incorrect
- **Solution**: Follow Android Configuration steps above

### Error: "account-exists-with-different-credential"
- **Cause**: Email already registered with email/password method
- **Solution**: User should log in with email/password or use password reset

### User document not created in Firestore
- **Cause**: Firestore rules might be blocking write
- **Solution**: Check Firestore rules allow user document creation

### Google Sign-In cancelled
- **Cause**: User closed the Google account picker
- **Solution**: This is normal user behavior, no action needed

## Files Modified

- `pubspec.yaml`: Added google_sign_in package
- `lib/services/auth_service.dart`: Added signInWithGoogle() method
- `lib/screens/auth/login_screen.dart`: Added Google Sign-In button and handler
- `lib/screens/auth/register_screen.dart`: Added Google Sign-In button and handler

## Next Steps

1. Complete Firebase Console configuration (steps above)
2. Test on Android emulator/device
3. Test on web (if applicable)
4. Consider adding Google Sign-In to iOS (requires additional setup)

---

**Note**: iOS requires additional setup in Xcode and Firebase. If you need iOS support, follow the [official Flutter Google Sign-In documentation](https://pub.dev/packages/google_sign_in).
