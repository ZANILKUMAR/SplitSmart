# Group Creation Feature

## Overview
The group creation feature allows users to create and manage expense-sharing groups in the SplitSmart app.

## Files Created

### Models
- **`lib/models/GroupModel.dart`**: Data model for groups with fields for id, name, description, members, etc.

### Services
- **`lib/services/group_service.dart`**: Firebase service for CRUD operations on groups
  - Create group
  - Get user's groups
  - Update group
  - Add/remove members
  - Delete group

### Screens
- **`lib/screens/groups/create_group_screen.dart`**: Screen for creating new groups with:
  - Group name (required, min 3 characters)
  - Description (optional)
  - Icon selection (12 different icons)
  - Color selection (8 different colors)
  - Visual preview of the group icon
  - Form validation

- **`lib/screens/groups/groups_screen.dart`**: Screen to display all user's groups
  - Real-time updates via Firebase streams
  - Group cards showing name, member count, description
  - Empty state with create group prompt
  - Navigation to create group screen

### Integration
- **`lib/screens/dashboard/dashboard_screen.dart`**: Updated to include groups tab
  - Groups tab now shows GroupsScreen
  - FAB appears on Groups tab to create new groups

## Features

### Create Group Screen
- ✅ Group name validation (min 3 characters)
- ✅ Optional description
- ✅ Visual icon picker (12 icons)
- ✅ Color customization (8 colors)
- ✅ Live preview of group appearance
- ✅ Form validation with error messages
- ✅ Loading states during creation
- ✅ Success/error feedback
- ✅ Creator automatically added as first member

### Groups List Screen
- ✅ Real-time group updates from Firebase
- ✅ Display group name, member count, description
- ✅ Relative date formatting (e.g., "2 days ago")
- ✅ Empty state with call-to-action
- ✅ Pull-to-refresh capability
- ✅ Loading and error states
- ✅ Floating action button to create new group

## Firebase Structure

### Groups Collection
```
groups/
  {groupId}/
    - id: string
    - name: string
    - description: string
    - createdBy: string (userId)
    - members: array of userIds
    - createdAt: timestamp
    - imageUrl: string (optional)
```

## Usage

### To Create a Group:
1. Navigate to the "Groups" tab in the dashboard
2. Tap the floating "+" button
3. Enter group name (required)
4. Optionally add a description
5. Choose an icon from the grid
6. Select a color theme
7. Tap "Create Group"

### To View Groups:
1. Navigate to the "Groups" tab
2. All groups where user is a member are displayed
3. Tap on a group card to view details (TODO: implement details screen)

## Next Steps (TODO)

1. **Group Details Screen**: View full group information, members list, expenses
2. **Add Members**: Search and invite users to groups
3. **Edit Group**: Allow group creator to modify group settings
4. **Leave/Delete Group**: Allow members to leave, creator to delete
5. **Group Expenses**: Add expenses within a group
6. **Group Statistics**: Show spending patterns and balances
7. **Member Avatars**: Display user profile pictures
8. **Group Images**: Allow custom group photos
9. **Permissions**: Implement admin/member roles

## Testing

To test the feature:
```powershell
# Build and run the app
cd android
.\gradlew.bat assembleDebug
# Or use: .\run_app.ps1
```

Then:
1. Login with Firebase credentials (ak@ak.com)
2. Navigate to Groups tab
3. Create a test group
4. Verify it appears in the list
5. Check Firebase console to see the data

## Dependencies
No additional packages required. Uses existing:
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
