# 👤 Firebase User Profile Management (2025)

## Overview

User profiles are now stored in **Firebase Firestore** instead of local-only SwiftData. This enables:

- ✅ **Cross-device sync** - Access your profile from any device
- ✅ **Cloud backup** - Never lose your profile data
- ✅ **Real-time updates** - Profile changes sync instantly
- ✅ **Secure authentication** - Firebase handles all auth logic
- ⚠️ **Profile images remain local** - Firebase Storage costs money, so images stay on-device

---

## 🏗️ Architecture

### Data Flow

```
┌─────────────────┐
│  Firebase Auth  │  ← Handles login/signup
└────────┬────────┘
         │ uid
         ↓
┌─────────────────┐
│ Firestore Users │  ← Cloud profile storage
│   Collection    │     (name, role, gender, etc.)
└────────┬────────┘
         │ sync
         ↓
┌─────────────────┐
│ SwiftData User  │  ← Local cache for offline access
│     Model       │
└─────────────────┘
         │
         ↓
┌─────────────────┐
│ Local Storage   │  ← Profile images (FREE)
│  .documentDir   │
└─────────────────┘
```

### What's Stored Where

| Data          | Firebase Auth | Firestore | SwiftData  | Local Storage |
| ------------- | ------------- | --------- | ---------- | ------------- |
| Email         | ✅            | ✅        | ✅         | ❌            |
| Password      | ✅ (hashed)   | ❌        | ❌         | ❌            |
| Full Name     | ❌            | ✅        | ✅ (cache) | ❌            |
| Role/Title    | ❌            | ✅        | ✅ (cache) | ❌            |
| Gender        | ❌            | ✅        | ✅ (cache) | ❌            |
| Date of Birth | ❌            | ✅        | ✅ (cache) | ❌            |
| Language      | ❌            | ✅        | ✅ (cache) | ❌            |
| Profile Image | ❌            | ❌        | ❌         | ✅ (.jpg)     |
| Sessions      | ❌            | ❌        | ✅         | ❌            |

---

## 🔐 Firestore Security Rules

Update your Firestore security rules to protect user data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users collection: Users can only read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Cases collection: Read-only for all authenticated users
    match /cases/{caseId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admin can write
    }
  }
}
```

**Key Security Points:**

- Users can **only access their own profile** (uid-based)
- **No user can read** other users' profiles
- Cases remain **read-only** for all users

---

## 📝 Firestore User Document Structure

Each user has a document at `/users/{uid}` with the following fields:

```json
{
  "uid": "abc123...",
  "email": "student@med.edu",
  "fullName": "Jane Doe",
  "roleTitle": "Medical Student (MS3)",
  "gender": "Female",
  "dateOfBirth": Timestamp(1998, 5, 15),
  "nativeLanguage": "English",
  "createdAt": Timestamp(2025, 12, 29),
  "lastUpdated": ServerTimestamp()
}
```

**Field Types:**

- `uid`: String (Firebase Auth UID)
- `email`: String (lowercase)
- `fullName`: String
- `roleTitle`: String (optional)
- `gender`: String (optional, enum: "Male" | "Female" | "Non-Binary" | "Prefer Not to Say")
- `dateOfBirth`: Timestamp (optional)
- `nativeLanguage`: String (enum: "English" | "Tamil" | "Sinhala")
- `createdAt`: Timestamp
- `lastUpdated`: Timestamp (server-generated)

---

## 🔄 Sync Behavior

### Sign Up Flow

1. User enters email, password, name
2. **Firebase Auth** creates account → returns `uid`
3. **Firestore** creates profile document at `/users/{uid}`
4. **SwiftData** caches profile locally
5. User is logged in

### Login Flow

1. User enters email, password
2. **Firebase Auth** validates credentials → returns `uid`
3. **Firestore** fetches profile from `/users/{uid}`
4. **SwiftData** syncs profile to local cache
5. User sees their dashboard

### Profile Update Flow

1. User edits profile in app
2. **SwiftData** saves changes locally (instant UI update)
3. **Firestore** syncs changes to cloud (background)
4. If offline, changes queue until next sync

### Logout Flow

1. User taps "Sign Out"
2. **Firebase Auth** signs out
3. **SwiftData** local cache remains (for next login)
4. User returns to login screen

### App Deletion Flow

1. User deletes app
2. **All local data deleted** (SwiftData + profile images)
3. **Cloud data preserved** in Firestore
4. On reinstall, login fetches profile from cloud

---

## 🚫 What Changed: No Auto-Login

### Before (2024)

- App remembered last logged-in user via `@AppStorage`
- On app launch, user was auto-logged in from local SwiftData
- **Problem**: Insecure, no real authentication

### After (2025) ✅

- App **requires Firebase login** on every fresh install
- Firebase Auth handles session persistence securely
- User stays logged in **only if Firebase session is active**
- On app deletion, user **must re-authenticate**

**User Experience:**

- Install app → Must login
- Use app normally → Stays logged in
- Delete app → Session cleared
- Reinstall app → Must login again ✅

---

## 🛠️ Developer Guide

### Creating a User Profile

```swift
let profileService = UserProfileService(modelContext: modelContext)

try await profileService.createProfile(
    uid: "firebase-uid-123",
    email: "student@med.edu",
    fullName: "Jane Doe",
    roleTitle: "Medical Student (MS3)",
    gender: .female,
    dateOfBirth: Date(),
    nativeLanguage: .english
)
```

### Fetching a User Profile

```swift
let profileService = UserProfileService(modelContext: modelContext)

if let profile = try await profileService.fetchProfile(uid: "firebase-uid-123") {
    print("Loaded: \(profile.fullName)")
}
```

### Updating a User Profile

```swift
let profileService = UserProfileService(modelContext: modelContext)

try await profileService.updateProfile(
    uid: "firebase-uid-123",
    fullName: "Dr. Jane Doe",
    roleTitle: "Resident"
)
```

### Syncing Local to Firestore

```swift
// In ProfileView or AuthService
try await authService.updateUserProfile()
```

---

## 📊 Cost Analysis

### Firestore Free Tier (User Profiles)

| Operation       | Free Tier Limit | Typical Usage            | Capacity           |
| --------------- | --------------- | ------------------------ | ------------------ |
| Document Reads  | 50,000/day      | 1 read/login             | 50,000 logins/day  |
| Document Writes | 20,000/day      | 1 write/signup + updates | 20,000 signups/day |
| Storage         | 1 GB            | ~1 KB/user               | 1,000,000 users    |

**Calculation for 1000 daily active users:**

- Logins: 1000 reads/day (98% under limit)
- Profile updates: ~100 writes/day (0.5% of limit)
- Storage: 1000 users × 1 KB = 1 MB (0.1% of limit)

**Conclusion**: User profiles are **essentially free** for apps with <10,000 daily users.

---

## 🐛 Troubleshooting

### "Permission Denied" when accessing Firestore

**Cause**: Security rules not set up correctly  
**Fix**: Update Firestore rules to allow uid-based access:

```javascript
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### Profile not syncing after signup

**Check Console Logs**:

```
✅ Firebase Auth: Created account with uid: abc123
✅ Firestore: Profile created
✅ Local: Profile synced for Jane Doe
```

**If missing "Firestore: Profile created":**

1. Check Firestore is enabled in Firebase Console
2. Verify security rules allow writes
3. Check internet connection

### User logged out after app restart

**Expected Behavior**: Firebase maintains session across restarts  
**If logging out unexpectedly:**

1. Check Firebase Auth persistence is enabled (default in iOS)
2. Verify `GoogleService-Info.plist` is in project
3. Check console for auth state listener errors

### Profile image disappeared

**Cause**: Profile images are stored locally, not in cloud  
**Expected**: After app deletion, images are lost  
**Solution**: User must re-upload profile image after reinstalling

---

## 🔒 Privacy & Security

### Data Handling

1. **Passwords**: Only stored in Firebase Auth (hashed with bcrypt)
2. **Email**: Stored in plaintext (normalized to lowercase)
3. **Profile data**: Accessible only by the owning user
4. **Profile images**: Stored locally in app's Documents directory

### GDPR Compliance

To delete a user completely:

```swift
// 1. Delete Firestore profile
let profileService = UserProfileService(modelContext: modelContext)
try await profileService.deleteProfile(uid: user.firebaseUID)

// 2. Delete Firebase Auth account
try await Auth.auth().currentUser?.delete()

// 3. Delete local data (automatic on logout)
```

---

## 🚀 Production Checklist

Before releasing to App Store:

- [ ] ✅ Firestore security rules configured
- [ ] ✅ Firebase Auth email/password enabled
- [ ] ✅ Test profile sync on multiple devices
- [ ] ✅ Test offline profile editing
- [ ] ✅ Verify app requires login after deletion
- [ ] ✅ Test profile image persistence (local only)
- [ ] ✅ Add error handling for network failures
- [ ] ✅ Implement retry logic for failed syncs

---

## 📚 Additional Resources

- [Firebase Auth iOS Guide](https://firebase.google.com/docs/auth/ios/start)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/rules-structure)
- [SwiftData + Cloud Sync](https://developer.apple.com/documentation/swiftdata)
- [Firebase Pricing](https://firebase.google.com/pricing)

---

**Last Updated**: December 29, 2025  
**Architecture**: Cloud-First User Profiles  
**Firebase SDK**: 10.x (2025 Latest)  
**iOS**: 17.0+
