# 💾 User Progress Sync - Implementation Guide

## 🎯 Overview

This document explains the **"Save Game Architecture"** for cloud synchronization of student simulation sessions. The system enables seamless multi-device support (start on iPhone, finish on iPad) while staying **100% free tier compatible**.

## 🏗️ Architecture

### Core Components

1. **UserProgressService.swift** - Cloud sync orchestrator
2. **ChatViewModel** - Auto-syncs on every message/action
3. **ClinicalSimulatorApp** - Emergency sync on app close
4. **DashboardView** - Restores progress on app launch

### Data Flow

```
┌─────────────────┐
│  User Action    │
│ (Send Message)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ChatViewModel  │ ──► Local Save (SwiftData)
│   saveSession() │ ──► Cloud Sync (Background Task)
└─────────────────┘
         │
         ▼
┌─────────────────┐
│UserProgressSvc  │ ──► Pack to JSON Blob
│  uploadSession()│ ──► Upload to Firestore
└─────────────────┘
         │
         ▼
┌─────────────────┐
│   Firestore     │
│ /users/{uid}/   │
│  sessions/{id}  │
└─────────────────┘
```

## 📦 "Save Game" Blob Structure

Each session is stored as a single JSON string in the `historyBlob` field:

```json
{
  "sessionId": "uuid-string",
  "caseId": "tumor_lysis_syndrome",
  "score": 85,
  "isCompleted": true,
  "evaluationStatus": "completed",
  "lastUpdated": "2025-12-29T12:00:00Z",
  "messageCount": 15,
  "historyBlob": "{\"messages\":[...],\"actions\":[...],\"notes\":\"...\",\"differential\":[...],\"evaluation\":\"...\"}"
}
```

### Why Blob Storage?

- **Cost Efficiency**: 1 document = 1 read/write (not 20+ for messages)
- **Atomicity**: Entire session syncs or doesn't (no partial states)
- **Simplicity**: No complex subcollection management
- **Free Tier Friendly**: Drastically reduces Firestore operations

## 🔄 Sync Scenarios

### Scenario 1: Hari Starts on iPhone

1. **Login**: Firebase Auth authenticates Hari
2. **Dashboard**: Downloads 50 cases from Firestore
3. **Start Case**: Opens "Tumor Lysis Syndrome"
4. **Chat**: Sends message → `ChatViewModel.saveSession()` triggered
   - ✅ Saved to local SwiftData instantly
   - ☁️ Uploaded to Firestore in background
5. **Close App**: `ClinicalSimulatorApp.performBackgroundSync()` runs
   - Emergency sync ensures latest state saved

### Scenario 2: Hari Opens iPad Later

1. **Login**: Same Firebase account
2. **Dashboard Sync**: `DashboardView.performBackgroundSync()` runs
   - Downloads case library
   - **NEW**: Calls `UserProgressService.restoreUserProgress()`
     - Finds "Tumor Lysis" session in cloud
     - Creates local `StudentSession` in SwiftData
     - Unpacks `historyBlob` → restores messages, notes, actions
3. **Dashboard UI**: Shows "Tumor Lysis" under "Active Rounds"
4. **Resume**: Taps case → chat history fully restored ✨

### Scenario 3: Hari Completes on iPad

1. **Diagnosis**: Submits final answer → gets 85% score
2. **Auto-Sync**: `ChatViewModel.saveSession()` uploads completion
3. **Back to iPhone**: Next launch pulls updated session
   - Sees "Completed" badge
   - Shows 85% score in history

## 🛡️ Security Rules (Firestore)

```javascript
match /users/{userId}/sessions/{sessionId} {
  // Users can only access their own sessions
  allow read, write: if request.auth != null && request.auth.uid == userId;

  // Validation: Required fields
  allow create: if request.resource.data.keys().hasAll(['sessionId', 'caseId', 'historyBlob']);
}
```

## 💰 Free Tier Optimization

### Firestore Limits (Spark Plan)

- **Reads**: 50,000/day
- **Writes**: 20,000/day
- **Storage**: 1 GB

### Our Usage (Per User)

- **Dashboard Load**: ~50 reads (case library) + ~5 reads (sessions)
- **Each Message**: 1 write (session update)
- **App Close**: 1 write per active session

### Optimization Strategies

1. **Blob Storage**: Reduces 20+ writes to 1 per session
2. **Skip Empty Sessions**: Don't sync sessions with no messages
3. **Skip Synced Sessions**: Don't re-download unchanged sessions
4. **Batch Background Sync**: Only sync incomplete sessions on close
5. **Smart Conflict Resolution**: Prefer local version if user is actively working

### Example: Daily Usage for 100 Active Users

```
Case Library Downloads: 100 users × 50 cases = 5,000 reads
Session Restores: 100 users × 3 active sessions × 1 read = 300 reads
Message Syncs: 100 users × 20 messages/day × 1 write = 2,000 writes
Background Syncs: 100 users × 3 sessions × 1 write = 300 writes

Total: 5,300 reads, 2,300 writes ✅ Well within free tier
```

## 🧪 Testing Checklist

### Single Device

- [ ] Start new case → send message → verify local save
- [ ] Close app → reopen → verify session persists locally
- [ ] Complete case → verify score saved
- [ ] Check Firestore console → verify session document exists

### Multi-Device

- [ ] Start case on Device A → send 3 messages
- [ ] Close app on Device A
- [ ] Open app on Device B → verify session appears in "Active Rounds"
- [ ] Open restored session → verify all 3 messages present
- [ ] Send 2 more messages on Device B
- [ ] Return to Device A → verify 5 messages total

### Edge Cases

- [ ] Start case offline → verify local-only mode works
- [ ] Go online later → verify background sync catches up
- [ ] Rapid message sending → verify no duplicate syncs
- [ ] Force quit app mid-session → verify emergency sync ran
- [ ] Delete session → verify removed from cloud

## 🔧 Troubleshooting

### "Session not syncing to cloud"

1. Check Firebase Auth status: `Auth.auth().currentUser`
2. Verify `user.firebaseUID` is set
3. Check Firestore rules in console
4. Check network connectivity

### "Old session not restoring on new device"

1. Verify `isDatabaseInitialized` reset on fresh install
2. Check `performBackgroundSync()` is called in DashboardView
3. Verify Firestore console shows session document
4. Check logs for `UserProgressService` errors

### "Duplicate sessions appearing"

1. Verify `sessionId` is unique (UUID)
2. Check `shouldUpdateFromCloud()` logic
3. Clear local SwiftData: Delete app and reinstall

## 📈 Future Enhancements

1. **Timestamp Conflict Resolution**: Compare `lastUpdated` to choose newest version
2. **Delta Sync**: Only sync new messages (requires more complex logic)
3. **Compression**: GZIP the historyBlob for larger sessions
4. **Selective Restore**: Let users choose which sessions to restore
5. **Analytics**: Track sync success rates and performance

## 🎓 How It Works: The "Hari Login" Scenario

**Morning - iPhone**

```
1. Login → Firebase Auth
2. Dashboard loads → 50 cases synced
3. Start "Tumor Lysis" → New StudentSession created locally
4. Send 5 messages → Each triggers background upload
5. Close app → Emergency sync ensures cloud is current
```

**Evening - iPad**

```
1. Login → Same Firebase account
2. Dashboard loads → restoreUserProgress() called
3. Cloud check: "Does Hari have sessions?"
   → YES: "tumor_lysis_syndrome" found
4. Download blob → Unpack JSON
5. Create local StudentSession with all 5 messages
6. Dashboard shows "Continue: Tumor Lysis Syndrome"
7. Tap to open → Seamless resume ✨
```

**Result**: Netflix-like "Continue Watching" experience

## 🚀 Deployment Steps

1. **Update Firestore Rules**: Copy rules from `firestore.rules` to Firebase Console
2. **Test Locally**: Run app on simulator, verify logs show sync events
3. **Test Multi-Device**: Use 2 simulators or physical device + simulator
4. **Monitor**: Check Firestore usage in Firebase Console
5. **Ship**: Deploy to TestFlight/App Store

---

**Built with ❤️ for medical students worldwide**
