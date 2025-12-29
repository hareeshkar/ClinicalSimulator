# 🔄 Migration Guide: Local to Cloud User Profiles

## What Changed

### Before (SwiftData Only)

```
User signs up → Creates local User in SwiftData
User logs in → Checks SwiftData for credentials
App deleted → All user data lost forever
```

### After (Firebase + SwiftData) ✅

```
User signs up → Creates Firebase Auth account + Firestore profile + Local cache
User logs in → Authenticates with Firebase → Fetches from Firestore → Caches locally
App deleted → Cloud data preserved → User must re-login → Profile restored
```

---

## 🚀 Migration Steps for Production

### Step 1: Update Firestore Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the contents of `firestore.rules` from your project
5. Click **Publish**

**Verify**: Click "Rules Playground" and test:

- ✅ User can read their own profile
- ❌ User cannot read another user's profile
- ✅ User can read cases
- ❌ User cannot write cases

### Step 2: Test User Profile Creation

1. **Delete the app** from your simulator/device
2. **Rebuild and run** the app
3. **Sign up** with a new account
4. Check Firebase Console → Firestore Database
5. You should see a new document in `users` collection

**Expected Firestore Document:**

```
Collection: users
Document ID: [Firebase Auth UID]
Fields:
  - uid: "abc123..."
  - email: "test@example.com"
  - fullName: "Test User"
  - roleTitle: "Medical Student (MS3)"
  - nativeLanguage: "English"
  - createdAt: [Timestamp]
  - lastUpdated: [Timestamp]
```

### Step 3: Test Cross-Device Sync

1. **Login on Device 1** (simulator)
2. **Update profile** (change name, role, etc.)
3. Check Firestore Console → Verify changes saved
4. **Login on Device 2** (different simulator or real device)
5. **Verify profile data matches** Device 1

### Step 4: Test Offline Behavior

1. **Login to app**
2. **Enable Airplane Mode** on device
3. **Edit profile** (change name)
4. **Disable Airplane Mode**
5. **Verify changes sync** to Firestore automatically

**Expected Console Logs:**

```
🔄 Syncing local user to Firestore...
☁️ Updating Firestore profile for uid: abc123
✅ Firestore profile updated
```

### Step 5: Test Profile Image Handling

1. **Upload profile image** in app
2. **Check Firestore** → Verify NO image field (correct!)
3. **Check local storage** → Image saved as `{userID}.jpg`
4. **Delete app**
5. **Reinstall and login**
6. **Expected**: Profile data restored, image gone (must re-upload)

---

## 🔧 Code Changes Summary

### New Files Created

1. **`UserProfileService.swift`** - Firestore profile CRUD operations
2. **`FIREBASE_USER_PROFILES.md`** - Documentation
3. **`firestore.rules`** - Security rules

### Files Modified

#### 1. `AuthService.swift`

- ✅ Added `loadUserProfile()` to fetch from Firestore
- ✅ Updated `signUp()` to create Firestore profile
- ✅ Updated `login()` to fetch from Firestore
- ✅ Added `updateUserProfile()` for profile sync
- ❌ Removed auto-login from local storage

#### 2. `SignUpView.swift`

- ✅ Added Firestore sync after profile completion
- ✅ Profile details now saved to cloud

#### 3. `ProfileView.swift`

- ✅ Added Firestore sync on profile edit

---

## 🔍 Testing Checklist

### Authentication Flow

- [ ] ✅ Sign up creates Firestore profile
- [ ] ✅ Login fetches profile from Firestore
- [ ] ✅ Logout clears local user (but keeps cloud profile)
- [ ] ✅ App deletion requires re-login

### Profile Management

- [ ] ✅ Edit profile syncs to Firestore
- [ ] ✅ Profile changes persist across app restarts
- [ ] ✅ Profile syncs across multiple devices
- [ ] ✅ Offline edits sync when back online

### Security

- [ ] ✅ Users cannot access other users' profiles
- [ ] ✅ Unauthenticated users cannot read anything
- [ ] ✅ Email cannot be changed after signup
- [ ] ✅ Cases are read-only

### Profile Images

- [ ] ✅ Images save locally (not in Firestore)
- [ ] ✅ Images persist across app restarts
- [ ] ⚠️ Images lost on app deletion (expected)

---

## 🐛 Common Issues & Solutions

### Issue 1: "Permission Denied" on Firestore

**Symptoms**: Console shows:

```
❌ Error loading user profile: Permission denied
```

**Solution**:

1. Check Firestore Rules are published
2. Verify user is authenticated (check `Auth.auth().currentUser`)
3. Ensure `userId` in path matches `auth.uid`

### Issue 2: Profile not syncing to Firestore

**Symptoms**: Profile edits don't appear in Firestore Console

**Solution**:

1. Check network connection
2. Look for console errors
3. Verify `authService.updateUserProfile()` is called
4. Check Firestore write limit (20K/day on free tier)

### Issue 3: User auto-logged out

**Symptoms**: User needs to login every time app opens

**Expected Behavior**: Firebase maintains session  
**If unexpected**:

1. Check Firebase Auth persistence is enabled
2. Verify `GoogleService-Info.plist` is in project
3. Check for auth errors in console

### Issue 4: Duplicate users created

**Symptoms**: Multiple Firestore documents for same user

**Solution**:

1. This shouldn't happen - each signup creates ONE document
2. Check if `signUp()` is called multiple times
3. Verify `userId` is the Firebase UID, not SwiftData UUID

---

## 📊 Database Migration (For Existing Users)

If you have existing users in SwiftData who need to be migrated to Firestore:

### Option 1: Manual Migration Script

```swift
// Add this to ProfileView or a debug menu
func migrateLocalUsersToFirestore() async {
    let context = modelContext
    let users = try? context.fetch(FetchDescriptor<User>())

    for user in users ?? [] {
        guard let uid = user.firebaseUID else { continue }

        let profileService = UserProfileService(modelContext: context)

        // Check if already exists in Firestore
        if let _ = try? await profileService.fetchProfile(uid: uid) {
            print("⏭️ User \(user.fullName) already in Firestore")
            continue
        }

        // Create Firestore profile
        try? await profileService.createProfile(
            uid: uid,
            email: user.email,
            fullName: user.fullName,
            roleTitle: user.roleTitle,
            gender: user.gender,
            dateOfBirth: user.dateOfBirth,
            nativeLanguage: user.nativeLanguage
        )

        print("✅ Migrated user: \(user.fullName)")
    }
}
```

### Option 2: Fresh Start (Recommended)

Since this is a development app:

1. **Delete old SwiftData database**
2. **Users re-signup** with Firebase Auth
3. **Profiles auto-create** in Firestore

---

## 🎯 Success Criteria

Your migration is successful when:

1. ✅ **Sign up** creates user in Firebase Auth + Firestore
2. ✅ **Login** authenticates and fetches profile from cloud
3. ✅ **Profile edits** sync to Firestore automatically
4. ✅ **App deletion** preserves cloud data
5. ✅ **Re-install** requires login but restores profile
6. ✅ **Security rules** prevent unauthorized access
7. ✅ **Profile images** remain local (not in Firestore)

---

## 📈 Monitoring & Analytics

### Firebase Console Dashboards

**Authentication** → Shows:

- Total users
- Sign-ups per day
- Active sessions

**Firestore Database** → Shows:

- Document count (should match user count)
- Read/write operations
- Storage used

**Usage & Billing** → Shows:

- Free tier usage (%)
- Estimated costs (should be $0)

### Console Logs to Monitor

```
✅ Firebase Auth: Created account with uid: abc123
✅ Firestore: Profile created
✅ Local: Profile synced for Jane Doe
```

```
✅ Firebase Auth: Logged in with uid: abc123
☁️ Fetching Firestore profile for uid: abc123
✅ Fetched Firestore profile for Jane Doe
✅ User profile loaded: Jane Doe
```

```
☁️ Syncing local user to Firestore...
☁️ Updating Firestore profile for uid: abc123
✅ Firestore profile updated
```

---

## 🚀 Next Steps

After successful migration:

1. **Monitor Firestore usage** for first week
2. **Add error tracking** (e.g., Firebase Crashlytics)
3. **Implement retry logic** for failed syncs
4. **Add offline indicators** in UI
5. **Consider adding**:
   - Profile completeness score
   - Achievement badges (stored in Firestore)
   - Study history sync across devices
   - Leaderboards (optional)

---

**Migration Status**: ✅ Complete  
**Breaking Changes**: Users must re-login after app deletion  
**User Impact**: Positive - profiles now cloud-backed  
**Cost**: $0 (within Firebase free tier)
