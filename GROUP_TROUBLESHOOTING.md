# Group Creation Troubleshooting Guide

## Common Issues and Solutions

### 1. **Firestore Security Rules** (Most Common Issue)

**Problem:** Groups not being created, or "Permission Denied" error.

**Solution:** Update your Firestore security rules in Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **smartsplit-zanil**
3. Go to **Firestore Database** → **Rules**
4. Replace the rules with the content from `firestore.rules` file in your project:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Groups collection
    match /groups/{groupId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.members;
      
      allow create: if request.auth != null && 
                       request.auth.uid == request.resource.data.createdBy &&
                       request.auth.uid in request.resource.data.members;
      
      allow update: if request.auth != null && 
                       (request.auth.uid == resource.data.createdBy ||
                        request.auth.uid in resource.data.members);
      
      allow delete: if request.auth != null && 
                       request.auth.uid == resource.data.createdBy;
    }
    
    // Expenses collection
    match /expenses/{expenseId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

5. Click **Publish**

### 2. **User Not Logged In**

**Problem:** Error message "User not logged in"

**Solution:** 
- Make sure you're logged in with your Firebase account (ak@ak.com)
- Check the Home tab to verify you see "Welcome, [Your Name]"
- If not logged in, logout and login again

### 3. **Network/Internet Issues**

**Problem:** Groups not being created, no error message shown

**Solution:**
- Check if the emulator has internet access
- Try opening Chrome in the emulator to test connectivity
- Restart the emulator if needed

### 4. **Firebase Not Initialized**

**Problem:** Error about Firebase not being initialized

**Solution:**
- Check that `lib/firebase_options.dart` exists
- Verify `lib/main.dart` has Firebase initialization:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Testing Group Creation

### Step-by-step Test:

1. **Launch the app:**
   ```powershell
   .\run_app.ps1
   ```

2. **Login:**
   - Email: ak@ak.com
   - Password: [your password]

3. **Navigate to Groups Tab:**
   - Tap "Groups" in bottom navigation

4. **Create a Group:**
   - Tap the floating "+" button
   - Enter group name (e.g., "Test Group")
   - Optionally add description
   - Choose an icon
   - Select a color
   - Tap "Create Group"

5. **Check for Errors:**
   - Watch the emulator screen for error messages (red SnackBar at bottom)
   - If error appears, note the exact message

6. **View Logs (if needed):**
   ```powershell
   # In Android Studio, open Logcat
   # Or use command line (if adb is in PATH):
   adb -s emulator-5554 logcat | Select-String "flutter|error|GroupService"
   ```

## Debugging Output

The app now includes detailed logging. Look for these messages:

### Successful Creation:
```
I/flutter: Creating group with name: Test Group
I/flutter: User ID: xyz123...
I/flutter: GroupService: Creating group in Firestore...
I/flutter: GroupService: Name=Test Group, CreatedBy=xyz123...
I/flutter: GroupService: Group created with ID: abc456...
I/flutter: Group created successfully with ID: abc456...
```

### Permission Error:
```
I/flutter: GroupService: Error creating group: [cloud_firestore/permission-denied]
```
→ **Fix:** Update Firestore security rules (see above)

### Network Error:
```
I/flutter: GroupService: Error creating group: network error
```
→ **Fix:** Check internet connection

## Verify in Firebase Console

After creating a group successfully:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **smartsplit-zanil** project
3. Go to **Firestore Database**
4. You should see a **groups** collection
5. Click on it to see your created groups

Each group document should have:
- `name`: string
- `description`: string
- `createdBy`: string (user ID)
- `members`: array with one user ID
- `createdAt`: timestamp
- `imageUrl`: null

## Quick Fixes Checklist

- [ ] Firestore security rules updated
- [ ] User is logged in (check Home tab)
- [ ] Internet connection working
- [ ] Firebase initialized (check app startup)
- [ ] No error messages in logs
- [ ] Group appears in Firebase Console after creation

## Still Not Working?

If group creation still fails after checking all above:

1. **Clear app data:**
   ```powershell
   # Uninstall and reinstall
   adb -s emulator-5554 uninstall com.example.smartsplit
   .\run_app.ps1
   ```

2. **Check specific error message:**
   - The error message in the red SnackBar will tell you exactly what's wrong
   - Share the error message for specific help

3. **Verify Firebase project:**
   - Make sure you're using the correct Firebase project (smartsplit-zanil)
   - Check that Authentication and Firestore are enabled

## Contact Info

If you continue to have issues, provide:
1. The exact error message from the app
2. Screenshot of the error
3. Any console logs from `adb logcat`
