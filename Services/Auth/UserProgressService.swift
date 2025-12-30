// Services/UserProgressService.swift
//
// Purpose: Cloud synchronization service for student simulation sessions
// Architecture: "Save Game" pattern - pack entire session into single JSON blob
// Free Tier Optimization: Minimizes Firestore reads/writes by using blob storage

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import os.log

private let progressLogger = Logger(subsystem: "com.hareeshkar.ClinicalSimulator", category: "UserProgressService")

// ✅ NOTIFICATION: Posted when a session is updated from cloud data
extension Notification.Name {
    static let sessionUpdatedFromCloud = Notification.Name("sessionUpdatedFromCloud")
}

// MARK: - 📦 Portable Data Models (Codable)
/// Lightweight, serializable version of session data for cloud storage
struct PortableSessionData: Codable {
    let messages: [PortableMessage]
    let actions: [PerformedAction]
    let notes: String
    let differential: [DifferentialItem]
    let evaluation: String?
    
    // Metadata for versioning and conflict resolution
    let clientTimestamp: Date
    let appVersion: String
    let deviceIdentifier: String
}

struct PortableMessage: Codable {
    let sender: String
    let content: String
    let timestamp: Date
}

// MARK: - 🌐 User Progress Service Actor
/// Thread-safe service for syncing session progress between local and cloud
actor UserProgressService {
    private let modelContainer: ModelContainer
    private let maxRetries = 3
    private let retryDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        progressLogger.log("🔄 UserProgressService initialized")
    }
    
    // MARK: - 📤 Smart Upload (Local -> Cloud)
    
    /// Syncs a single session to Firestore with retry logic
    /// - Parameter session: The StudentSession to upload
    /// - Returns: Success status
    @discardableResult
    func uploadSession(_ session: StudentSession) async -> Bool {
        // 1. Pre-flight Checks
        guard let user = session.user,
              let uid = user.firebaseUID else {
            progressLogger.warning("⚠️ Skipping sync: Session not linked to Firebase user")
            return false
        }
        
        // Don't sync if session has no meaningful data yet
        guard !session.messages.isEmpty || !session.notes.isEmpty else {
            progressLogger.log("⏭️ Skipping sync: Session has no data to save")
            return false
        }
        
        let sessionID = session.sessionId.uuidString
        
        progressLogger.log("📤 Uploading session \(sessionID, privacy: .public) for user \(uid, privacy: .public)")
        
        // 2. Prepare Firestore References
        let db = Firestore.firestore()
        let sessionRef = db.collection("users")
            .document(uid)
            .collection("sessions")
            .document(sessionID)
        
        // 3. Pack Session into Portable Format
        guard let portableData = packSession(session) else {
            progressLogger.error("❌ Failed to pack session data")
            return false
        }
        
        // 4. Encode to JSON Blob
        guard let blobData = try? JSONEncoder().encode(portableData),
              let blobString = String(data: blobData, encoding: .utf8) else {
            progressLogger.error("❌ Failed to encode session blob")
            return false
        }
        
        // 5. Prepare Firestore Document
        let data: [String: Any] = [
            "sessionId": sessionID,
            "caseId": session.caseId,
            "score": session.score ?? 0,
            "isCompleted": session.isCompleted,
            "evaluationStatus": session.evaluationStatus,
            "lastUpdated": FieldValue.serverTimestamp(),
            "historyBlob": blobString,
            "blobVersion": portableData.appVersion,
            "deviceId": portableData.deviceIdentifier,
            "messageCount": session.messages.count // For quick filtering
        ]
        
        // 6. Upload with Retry Logic
        var attempt = 0
        while attempt < maxRetries {
            do {
                try await sessionRef.setData(data, merge: true)
                progressLogger.log("✅ Session \(sessionID, privacy: .public) synced to cloud (attempt \(attempt + 1))")
                return true
            } catch {
                attempt += 1
                if attempt < maxRetries {
                    progressLogger.warning("⚠️ Upload failed (attempt \(attempt)/\(self.maxRetries)): \(error.localizedDescription, privacy: .public). Retrying...")
                    try? await Task.sleep(nanoseconds: retryDelay)
                } else {
                    progressLogger.error("❌ Upload failed after \(self.maxRetries) attempts: \(error.localizedDescription, privacy: .public)")
                    return false
                }
            }
        }
        
        return false
    }
    
    /// Batch upload multiple sessions (for background sync on app close)
    /// - Parameter sessions: Array of sessions to sync
    /// - Returns: Count of successfully synced sessions
    func uploadSessions(_ sessions: [StudentSession]) async -> Int {
        progressLogger.log("📤 Batch uploading \(sessions.count) sessions...")
        
        var successCount = 0
        
        // Use TaskGroup for parallel uploads (faster but respects free tier limits)
        await withTaskGroup(of: Bool.self) { group in
            for session in sessions {
                group.addTask {
                    await self.uploadSession(session)
                }
            }
            
            for await success in group {
                if success {
                    successCount += 1
                }
            }
        }
        
        progressLogger.log("✅ Batch upload complete: \(successCount)/\(sessions.count) sessions synced")
        return successCount
    }
    
    // MARK: - 📥 Smart Download (Cloud -> Local)
    
    /// Restores user's session progress from Firestore
    func restoreUserProgress() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            progressLogger.warning("⚠️ No Firebase user logged in, skipping restore")
            return
        }
        
        progressLogger.log("☁️ Restoring progress for user \(uid, privacy: .public)...")
        
        // Create background context for thread-safe operations
        let backgroundContext = ModelContext(modelContainer)
        let db = Firestore.firestore()
        
        // 1. Fetch user's sessions from Firestore
        let snapshot = try await db.collection("users")
            .document(uid)
            .collection("sessions")
            .order(by: "lastUpdated", descending: true)
            .getDocuments()
        
        progressLogger.log("☁️ Found \(snapshot.documents.count) cloud sessions")
        
        // 2. Get local user
        let userPredicate = #Predicate<User> { $0.firebaseUID == uid }
        guard let localUser = try? backgroundContext.fetch(FetchDescriptor(predicate: userPredicate)).first else {
            progressLogger.error("❌ Restore failed: Local user not found")
            throw ProgressSyncError.userNotFound
        }
        
        var restoredCount = 0
        var updatedCount = 0
        var skippedCount = 0
        
        // 3. Process each cloud session
        for doc in snapshot.documents {
            let data = doc.data()
            let sessionIdStr = doc.documentID
            
            guard let sessionId = UUID(uuidString: sessionIdStr) else {
                progressLogger.warning("⚠️ Invalid session ID: \(sessionIdStr, privacy: .public)")
                continue
            }
            
            // 4. Check if session exists locally
            let fetchDescriptor = FetchDescriptor<StudentSession>(
                predicate: #Predicate { $0.sessionId == sessionId }
            )
            
            let existingSession = try? backgroundContext.fetch(fetchDescriptor).first
            
            if let existingSession = existingSession {
                // Session exists locally - check if cloud version is newer
                if shouldUpdateFromCloud(cloudData: data, localSession: existingSession) {
                    updateLocalSession(existingSession, from: data, context: backgroundContext)
                    updatedCount += 1
                    progressLogger.log("🔄 Updated session \(sessionIdStr, privacy: .public) from cloud")
                } else {
                    skippedCount += 1
                    progressLogger.log("⏭️ Skipped session \(sessionIdStr, privacy: .public) - no changes")
                }
            } else {
                // Session doesn't exist locally - restore it
                if let newSession = createSessionFromCloud(
                    sessionId: sessionId,
                    data: data,
                    user: localUser,
                    context: backgroundContext
                ) {
                    backgroundContext.insert(newSession)
                    restoredCount += 1
                    progressLogger.log("✨ Restored new session \(sessionIdStr, privacy: .public)")
                }
            }
        }
        
        // 5. Save all changes
        if restoredCount > 0 || updatedCount > 0 {
            try backgroundContext.save()
            progressLogger.log("✅ Restore complete: \(restoredCount) new, \(updatedCount) updated, \(skippedCount) skipped")
        } else {
            progressLogger.log("✅ Local data is current (skipped \(skippedCount) sessions)")
        }
    }
    
    /// Deletes a session from both local and cloud storage
    /// - Parameter session: The session to delete
    func deleteSession(_ session: StudentSession) async throws {
        guard let uid = session.user?.firebaseUID else {
            throw ProgressSyncError.userNotFound
        }
        
        let sessionID = session.sessionId.uuidString
        let db = Firestore.firestore()
        
        // Delete from cloud
        try await db.collection("users")
            .document(uid)
            .collection("sessions")
            .document(sessionID)
            .delete()
        
        progressLogger.log("🗑️ Deleted session \(sessionID, privacy: .public) from cloud")
    }
    
    // MARK: - 🔧 Helper Methods
    
    /// Packs a StudentSession into portable format
    private func packSession(_ session: StudentSession) -> PortableSessionData? {
        let portableMessages = session.messages.map {
            PortableMessage(sender: $0.sender, content: $0.content, timestamp: $0.timestamp)
        }
        
        return PortableSessionData(
            messages: portableMessages,
            actions: session.performedActions,
            notes: session.notes,
            differential: session.differentialDiagnosis,
            evaluation: session.evaluationJSON,
            clientTimestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
    }
    
    /// Creates a new StudentSession from cloud data
    private func createSessionFromCloud(
        sessionId: UUID,
        data: [String: Any],
        user: User,
        context: ModelContext
    ) -> StudentSession? {
        guard let caseId = data["caseId"] as? String else {
            progressLogger.error("❌ Missing caseId in cloud data")
            return nil
        }
        
        let session = StudentSession(sessionId: sessionId, caseId: caseId, user: user)
        session.score = data["score"] as? Double
        session.isCompleted = data["isCompleted"] as? Bool ?? false
        session.evaluationStatus = data["evaluationStatus"] as? String ?? "not_started"
        
        // ✅ NEW: Track sync metadata
        if let cloudTimestamp = data["lastUpdated"] as? Timestamp {
            session.cloudLastUpdated = cloudTimestamp.dateValue()
        }
        session.lastSyncedToCloud = Date()
        if let deviceId = data["deviceId"] as? String {
            session.deviceIdentifier = deviceId
        }
        
        // Unpack history blob
        if let blobString = data["historyBlob"] as? String,
           let blobData = blobString.data(using: .utf8),
           let portable = try? JSONDecoder().decode(PortableSessionData.self, from: blobData) {
            
            session.notes = portable.notes
            session.differentialDiagnosis = portable.differential
            session.performedActions = portable.actions
            session.evaluationJSON = portable.evaluation
            
            // Restore messages
            for msg in portable.messages {
                let newMessage = ConversationMessage(
                    sender: msg.sender,
                    content: msg.content,
                    timestamp: msg.timestamp
                )
                newMessage.session = session
                context.insert(newMessage)
            }
        }
        
        return session
    }
    
    /// Updates an existing local session with cloud data
    private func updateLocalSession(
        _ session: StudentSession,
        from data: [String: Any],
        context: ModelContext
    ) {
        session.score = data["score"] as? Double
        session.isCompleted = data["isCompleted"] as? Bool ?? false
        session.evaluationStatus = data["evaluationStatus"] as? String ?? "not_started"
        
        // ✅ UPDATE: Track sync metadata
        if let cloudTimestamp = data["lastUpdated"] as? Timestamp {
            session.cloudLastUpdated = cloudTimestamp.dateValue()
        }
        session.lastSyncedToCloud = Date()
        if let deviceId = data["deviceId"] as? String {
            session.deviceIdentifier = deviceId
        }
        
        // Unpack and update blob data
        if let blobString = data["historyBlob"] as? String,
           let blobData = blobString.data(using: .utf8),
           let portable = try? JSONDecoder().decode(PortableSessionData.self, from: blobData) {
            
            session.notes = portable.notes
            session.differentialDiagnosis = portable.differential
            session.performedActions = portable.actions
            session.evaluationJSON = portable.evaluation
            
            // Clear and restore messages
            for msg in session.messages {
                context.delete(msg)
            }
            
            for msg in portable.messages {
                let newMessage = ConversationMessage(
                    sender: msg.sender,
                    content: msg.content,
                    timestamp: msg.timestamp
                )
                newMessage.session = session
                context.insert(newMessage)
            }
        }
        
        // ✅ NOTIFY: Post notification that session was updated from cloud
        NotificationCenter.default.post(name: .sessionUpdatedFromCloud, object: session.sessionId)
    }
    
    /// Determines if cloud version is newer than local using server timestamp
    private func shouldUpdateFromCloud(cloudData: [String: Any], localSession: StudentSession) -> Bool {
        progressLogger.log("🔍 shouldUpdateFromCloud called for session \(localSession.sessionId)")
        
        // Parse cloud's lastUpdated server timestamp
        guard let cloudTimestamp = cloudData["lastUpdated"] as? Timestamp else {
            // No timestamp in cloud? This shouldn't happen, but keep local version
            progressLogger.warning("⚠️ Cloud session missing lastUpdated timestamp, keeping local")
            return false
        }
        
        let cloudDate = cloudTimestamp.dateValue()
        progressLogger.log("🔍 Cloud timestamp parsed: \(cloudDate)")
        
        // If we've never synced before, check if cloud is newer than local creation
        guard let localCloudTimestamp = localSession.cloudLastUpdated else {
            progressLogger.log("🔍 No local cloud timestamp - first time sync for session \(localSession.sessionId)")
            // First time seeing this session from cloud - compare message counts as fallback
            if let cloudMessageCount = cloudData["messageCount"] as? Int {
                let isNewer = cloudMessageCount > localSession.messages.count
                progressLogger.log("🔍 Message count check: cloud=\(cloudMessageCount), local=\(localSession.messages.count), isNewer=\(isNewer)")
                if isNewer {
                    progressLogger.log("📥 First sync: Cloud has more messages, updating")
                } else {
                    progressLogger.log("⏭️ First sync: Same or fewer messages, skipping")
                }
                return isNewer
            }
            progressLogger.log("⏭️ First sync: No message count available, skipping")
            return false
        }
        
        progressLogger.log("🔍 Local cloud timestamp exists: \(localCloudTimestamp)")
        
        // Compare timestamps with tolerance - only update if cloud is significantly newer
        let timeDifference = cloudDate.timeIntervalSince(localCloudTimestamp)
        let toleranceSeconds: TimeInterval = 5.0 // Allow 5 second tolerance for timestamp precision
        
        progressLogger.log("🔍 Timestamp diff: \(String(format: "%.3f", timeDifference))s (tolerance: ±\(toleranceSeconds)s)")
        
        // If timestamps are within tolerance, consider them equal
        if abs(timeDifference) <= toleranceSeconds {
            progressLogger.log("⏭️ Within tolerance, skipping update")
            return false
        }
        
        let isNewer = timeDifference > toleranceSeconds
        
        if isNewer {
            progressLogger.log("📥 Cloud is newer by \(String(format: "%.1f", timeDifference))s, updating")
        } else {
            progressLogger.log("⏭️ Local is newer or same, skipping")
        }
        
        return isNewer
    }
}

// MARK: - 🚨 Error Definitions
enum ProgressSyncError: LocalizedError {
    case userNotFound
    case encodingFailed
    case networkError(String)
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found in local database"
        case .encodingFailed:
            return "Failed to encode session data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorizedAccess:
            return "User not logged in to Firebase"
        }
    }
}
