# Firebase Configuration Migration Required

⚠️ **CRITICAL:** The Firebase configuration files in this project are still configured for the **legacy Kwaaijongens app** with the old package name.

## Current Status

### Android Configuration
**File:** `android/app/google-services.json`
- **Project ID:** `kwaaijongens-app-88f1d`
- **Package Name:** `com.app.kwaaijongens` ❌ (OLD)
- **Status:** ⚠️ NEEDS REPLACEMENT

### iOS Configuration
**File:** `ios/Runner/GoogleService-Info.plist`
- **Project ID:** `kwaaijongens-app-88f1d`
- **Bundle ID:** `com.app.kwaaijongens` ❌ (OLD)
- **Status:** ⚠️ NEEDS REPLACEMENT

## Impact

❌ **Push Notifications:** Will NOT work with current configuration
❌ **Firebase Cloud Messaging:** Will fail to deliver messages
❌ **Firebase Analytics:** Will track under old project
❌ **Remote Config:** Will not sync properly

## Required Actions

### Step 1: Create New Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name: `UYC - Unlock Your Cloud` (or your preferred name)
4. Complete project setup

### Step 2: Add Android App

1. In Firebase Console, click "Add app" → Android
2. **Package name:** `cloud.unlockyour.chat` ✅
3. Download new `google-services.json`
4. Replace file at: `android/app/google-services.json`

### Step 3: Add iOS App

1. In Firebase Console, click "Add app" → iOS
2. **Bundle ID:** `cloud.unlockyour.chat` ✅
3. Download new `GoogleService-Info.plist`
4. Replace file at: `ios/Runner/GoogleService-Info.plist`

### Step 4: Configure Cloud Messaging

1. Enable Firebase Cloud Messaging (FCM) in Firebase Console
2. For iOS: Upload APNs authentication key or certificate
3. Test push notifications

### Step 5: Update Backend

If you have a backend that sends push notifications:
- Update FCM server key/credentials
- Update API endpoints if using Firebase REST API
- Test notification delivery end-to-end

## Testing Push Notifications

After updating Firebase configs:

```bash
# Clean build
flutter clean
flutter pub get

# Test on Android
flutter run -d android

# Test on iOS (macOS only)
flutter run -d ios
```

Send a test notification from Firebase Console to verify:
1. App receives notification when in foreground
2. App receives notification when in background
3. Notification displays correctly
4. Tapping notification opens app

## Notes

- The old Firebase project (`kwaaijongens-app-88f1d`) can remain active for existing users of the old app
- Create a completely separate Firebase project for the new UYC app
- Do NOT try to change package names in the existing Firebase project - create a new one
- Keep both `google-services.json` files backed up during migration

---

**Last Updated:** February 16, 2026
**Migration Status:** ⏳ Pending
