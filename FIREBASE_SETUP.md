# 🔥 Firebase Firestore Cloud Sync Setup Guide

## Overview

The ClinicalSimulator now uses Firebase Firestore as its cloud database for patient cases. This provides:

- ✅ **Zero-cost** cloud storage (50K reads/day free)
- ✅ **Offline-first** architecture with local SwiftData cache
- ✅ **Real-time sync** across devices
- ✅ **Scalable** to unlimited cases

---

## 📋 Prerequisites

1. **Firebase Project Created** at [console.firebase.google.com](https://console.firebase.google.com)
2. **Authentication Enabled**: Email/Password provider turned on
3. **Firestore Database Created**: Start in production mode
4. **GoogleService-Info.plist** downloaded and added to Xcode project

---

## 🚀 Initial Setup (ONE-TIME)

### Step 1: Enable Firestore in Firebase Console

1. Go to Firebase Console → Your Project
2. Navigate to **Firestore Database**
3. Click **Create Database**
4. Choose **Start in production mode**
5. Select your preferred region (closest to your users)

### Step 2: Configure Firestore Security Rules

In Firebase Console → Firestore Database → Rules, add:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Cases collection: Read-only for all authenticated users
    match /cases/{caseId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admin can write via console or upload function
    }
  }
}
```

**Note**: For initial setup, you can temporarily allow writes:

```javascript
allow write: if request.auth != null; // Remove after initial upload
```

### Step 3: Upload Cases to Firestore

1. **Build and run** the app in **DEBUG mode** on simulator
2. Navigate to **Profile** tab
3. Scroll down to **🔧 Admin Tools** section (only visible in DEBUG)
4. Tap **☁️ Upload Cases to Firestore**
5. Confirm the upload alert
6. Wait for the success message (usually 10-30 seconds for 50+ cases)

**Expected Output:**

```
✅ Upload Complete: 50 cases uploaded
```

### Step 4: Verify Upload in Firebase Console

1. Go to Firebase Console → Firestore Database
2. You should see a `cases` collection with 50+ documents
3. Each document should have:
   - `caseId`
   - `title`
   - `specialty`
   - `difficulty`
   - `chiefComplaint`
   - `recommendedForLevels`
   - `fullCaseJSON` (the complete case data)
   - `lastUpdated` (server timestamp)

### Step 5: Test Cloud Sync

1. **Delete the app** from the simulator
2. **Reinstall** and run again
3. Watch the console logs:
   ```
   ☁️ Starting Cloud Sync from Firestore...
   ✅ Retrieved 50 documents from Firestore
   ✅ Cloud Sync Complete: 50 inserted, 0 updated
   ```
4. Cases should load from Firestore automatically

---

## 🔄 How Cloud Sync Works

### Architecture

```
┌─────────────────────┐
│  Firebase Firestore │  ← Cloud Database (50+ cases)
└──────────┬──────────┘
           │ syncWithCloud()
           ↓
┌─────────────────────┐
│ CaseSynchronization │  ← Background Actor
│      Service        │
└──────────┬──────────┘
           │ Upsert Logic
           ↓
┌─────────────────────┐
│  SwiftData Local DB │  ← Offline Cache
│   (PatientCase)     │
└─────────────────────┘
```

### Sync Flow

1. **App Launch**: DashboardView triggers sync
2. **Cloud Fetch**: Download all case metadata from Firestore (~1KB/case)
3. **Compare**: Check against local SwiftData cache
4. **Upsert**: Insert new cases, update changed cases
5. **Fallback**: If cloud fails, load from local SampleCases.json

### Performance Optimization

- **External Storage**: Large `fullCaseJSON` stored separately (not loaded in RAM)
- **Batch Operations**: Firestore batch writes (400 docs/batch)
- **Smart Caching**: Only fetch cases that changed
- **Background Sync**: Non-blocking UI operations

---

## 🛠️ Admin Tools Reference

### Upload Cases to Firestore

**Purpose**: One-time upload of SampleCases.json to Firestore  
**When to use**: Initial database setup or when adding new cases  
**Safety**: Uses batch writes (atomic transactions)

### Clear Firestore Database

**Purpose**: Delete all cases from Firestore  
**When to use**: Testing, re-uploading with changes  
**⚠️ Warning**: Irreversible - use with caution

---

## 📊 Cost Analysis (Firebase Free Tier)

| Operation       | Free Tier Limit | Usage per Sync      | Daily Capacity    |
| --------------- | --------------- | ------------------- | ----------------- |
| Document Reads  | 50,000/day      | 50 cases            | 1,000 syncs/day   |
| Document Writes | 20,000/day      | 50 cases (one-time) | N/A               |
| Storage         | 1 GB            | ~5 MB (50 cases)    | 200x headroom     |
| Bandwidth       | 10 GB/month     | ~5 MB/sync          | 2,000 syncs/month |

**Conclusion**: With 50 cases, you can support **1,000+ daily active users** on the free tier.

---

## 🐛 Troubleshooting

### "Permission Denied" Error

**Cause**: Firestore security rules too restrictive  
**Fix**: Temporarily allow writes in Firestore rules (see Step 2)

### "Network Error" During Upload

**Cause**: No internet connection or Firebase config issue  
**Fix**:

1. Check internet connection
2. Verify `GoogleService-Info.plist` is in Xcode project
3. Rebuild and run

### Cases Not Syncing from Cloud

**Cause**: App falling back to local JSON  
**Check Console Logs**:

```
☁️ Calling syncWithCloud()...
❌ Cloud Sync Failed: [error message]
⚠️ Falling back to local sync...
```

**Fix**: Check Firebase configuration and internet connection

### Upload Stuck at "Uploading..."

**Cause**: Large batch taking time or network issue  
**Expected Duration**: 10-30 seconds for 50 cases  
**Fix**: Wait up to 60 seconds, then restart app if needed

---

## 🔐 Security Best Practices

1. **Never commit** `GoogleService-Info.plist` to public repos
2. **Use security rules** to protect data (read-only for clients)
3. **Validate user auth** before allowing reads
4. **Remove admin tools** from production builds (use `#if DEBUG`)
5. **Monitor usage** in Firebase Console to detect abuse

---

## 🚢 Production Deployment

### Before Release:

1. ✅ Upload cases to Firestore
2. ✅ Set proper Firestore security rules (read-only)
3. ✅ Remove or disable admin upload buttons
4. ✅ Test cloud sync on multiple devices
5. ✅ Verify offline fallback works
6. ✅ Add `.gitignore` for `GoogleService-Info.plist`

### Release Build Configuration:

```swift
// Admin tools are automatically hidden in Release builds
#if DEBUG
GlassSection(title: "🔧 Admin Tools", tint: .orange) {
    // Upload buttons only visible in DEBUG
}
#endif
```

---

## 📝 Maintenance

### Adding New Cases

1. Update `SampleCases.json` locally
2. Run admin upload in DEBUG mode
3. Cases will sync to all users on next app launch

### Updating Existing Cases

1. Modify `SampleCases.json`
2. Clear Firestore database (admin tool)
3. Upload fresh cases
4. Users will auto-sync updated cases

### Monitoring Usage

Firebase Console → Firestore → Usage tab shows:

- Document reads/writes
- Storage used
- Active users

---

## 🎯 Next Steps

- [ ] Enable Firebase Authentication (already done ✅)
- [ ] Set up Firestore indexes for complex queries
- [ ] Implement differential sync (only download changed cases)
- [ ] Add version tracking for smarter updates
- [ ] Consider Firebase Cloud Functions for server-side logic

---

## 📚 Additional Resources

- [Firebase iOS Quickstart](https://firebase.google.com/docs/ios/setup)
- [Firestore Get Started](https://firebase.google.com/docs/firestore/quickstart)
- [Security Rules Reference](https://firebase.google.com/docs/firestore/security/get-started)
- [SwiftData + Firebase Integration](https://developer.apple.com/documentation/swiftdata)

---

**Last Updated**: December 29, 2025  
**Architecture**: Cloud-First with Offline Fallback  
**Firebase SDK**: 10.x (2025 Latest)
