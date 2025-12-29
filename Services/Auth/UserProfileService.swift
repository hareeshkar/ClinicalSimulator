// Services/UserProfileService.swift
// ☁️ Firestore User Profile Management (2025)

import Foundation
import FirebaseFirestore
import SwiftData

/// Manages user profiles in Firestore with local SwiftData sync
/// Profile images are kept local-only (Firebase Storage is not free)
@MainActor
class UserProfileService {
    private let db = Firestore.firestore()
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Firestore Profile Data Structure
    
    /// User profile data stored in Firestore
    struct FirestoreUserProfile: Codable {
        let uid: String
        let email: String
        let fullName: String
        let roleTitle: String?
        let gender: String?
        let dateOfBirth: Date?
        let nativeLanguage: String
        let createdAt: Date
        let lastUpdated: Date
        
        /// Convert to dictionary for Firestore
        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "uid": uid,
                "email": email,
                "fullName": fullName,
                "nativeLanguage": nativeLanguage,
                "createdAt": Timestamp(date: createdAt),
                "lastUpdated": FieldValue.serverTimestamp()
            ]
            
            if let roleTitle = roleTitle {
                dict["roleTitle"] = roleTitle
            }
            if let gender = gender {
                dict["gender"] = gender
            }
            if let dateOfBirth = dateOfBirth {
                dict["dateOfBirth"] = Timestamp(date: dateOfBirth)
            }
            
            return dict
        }
        
        /// Create from Firestore document
        static func from(document: [String: Any], uid: String) -> FirestoreUserProfile? {
            guard let email = document["email"] as? String,
                  let fullName = document["fullName"] as? String else {
                return nil
            }
            
            let roleTitle = document["roleTitle"] as? String
            let gender = document["gender"] as? String
            let nativeLanguage = document["nativeLanguage"] as? String ?? "English"
            
            let dateOfBirth = (document["dateOfBirth"] as? Timestamp)?.dateValue()
            let createdAt = (document["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let lastUpdated = (document["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
            
            return FirestoreUserProfile(
                uid: uid,
                email: email,
                fullName: fullName,
                roleTitle: roleTitle,
                gender: gender,
                dateOfBirth: dateOfBirth,
                nativeLanguage: nativeLanguage,
                createdAt: createdAt,
                lastUpdated: lastUpdated
            )
        }
    }
    
    // MARK: - Create Profile
    
    /// Create a new user profile in Firestore
    func createProfile(
        uid: String,
        email: String,
        fullName: String,
        roleTitle: String? = nil,
        gender: Gender? = nil,
        dateOfBirth: Date? = nil,
        nativeLanguage: NativeLanguage = .english
    ) async throws {
        print("☁️ Creating Firestore profile for uid: \(uid)")
        
        let profile = FirestoreUserProfile(
            uid: uid,
            email: email.lowercased(),
            fullName: fullName,
            roleTitle: roleTitle,
            gender: gender?.rawValue,
            dateOfBirth: dateOfBirth,
            nativeLanguage: nativeLanguage.rawValue,
            createdAt: Date(),
            lastUpdated: Date()
        )
        
        try await db.collection("users").document(uid).setData(profile.toDictionary())
        print("✅ Firestore profile created for \(fullName)")
    }
    
    // MARK: - Fetch Profile
    
    /// Fetch user profile from Firestore
    func fetchProfile(uid: String) async throws -> FirestoreUserProfile? {
        print("☁️ Fetching Firestore profile for uid: \(uid)")
        
        let document = try await db.collection("users").document(uid).getDocument()
        
        guard document.exists, let data = document.data() else {
            print("⚠️ No Firestore profile found for uid: \(uid)")
            return nil
        }
        
        let profile = FirestoreUserProfile.from(document: data, uid: uid)
        if let profile = profile {
            print("✅ Fetched Firestore profile for \(profile.fullName)")
        }
        return profile
    }
    
    // MARK: - Update Profile
    
    /// Update user profile in Firestore
    func updateProfile(
        uid: String,
        fullName: String? = nil,
        roleTitle: String? = nil,
        gender: Gender? = nil,
        dateOfBirth: Date? = nil,
        nativeLanguage: NativeLanguage? = nil
    ) async throws {
        print("☁️ Updating Firestore profile for uid: \(uid)")
        
        var updates: [String: Any] = [
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        if let fullName = fullName {
            updates["fullName"] = fullName
        }
        if let roleTitle = roleTitle {
            updates["roleTitle"] = roleTitle
        }
        if let gender = gender {
            updates["gender"] = gender.rawValue
        }
        if let dateOfBirth = dateOfBirth {
            updates["dateOfBirth"] = Timestamp(date: dateOfBirth)
        }
        if let nativeLanguage = nativeLanguage {
            updates["nativeLanguage"] = nativeLanguage.rawValue
        }
        
        try await db.collection("users").document(uid).updateData(updates)
        print("✅ Firestore profile updated")
    }
    
    // MARK: - Delete Profile
    
    /// Delete user profile from Firestore
    func deleteProfile(uid: String) async throws {
        print("☁️ Deleting Firestore profile for uid: \(uid)")
        try await db.collection("users").document(uid).delete()
        print("✅ Firestore profile deleted")
    }
    
    // MARK: - Sync with Local SwiftData
    
    /// Sync Firestore profile to local SwiftData User model
    func syncToLocal(firestoreProfile: FirestoreUserProfile) -> User {
        print("🔄 Syncing Firestore profile to local SwiftData...")
        
        // Check if user already exists locally
        let targetUID = firestoreProfile.uid
        let predicate = #Predicate<User> { $0.firebaseUID == targetUID }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        let existingUser = try? modelContext.fetch(descriptor).first
        
        if let user = existingUser {
            // Update existing local user
            print("🔄 Updating existing local user")
            user.fullName = firestoreProfile.fullName
            user.email = firestoreProfile.email
            user.roleTitle = firestoreProfile.roleTitle
            user.gender = Gender(rawValue: firestoreProfile.gender ?? "")
            user.dateOfBirth = firestoreProfile.dateOfBirth
            user.nativeLanguage = NativeLanguage(rawValue: firestoreProfile.nativeLanguage) ?? .english
            
            try? modelContext.save()
            return user
        } else {
            // Create new local user
            print("➕ Creating new local user from Firestore profile")
            let newUser = User(
                fullName: firestoreProfile.fullName,
                email: firestoreProfile.email,
                password: "" // Not stored locally anymore
            )
            newUser.firebaseUID = firestoreProfile.uid
            newUser.roleTitle = firestoreProfile.roleTitle
            newUser.gender = Gender(rawValue: firestoreProfile.gender ?? "")
            newUser.dateOfBirth = firestoreProfile.dateOfBirth
            newUser.nativeLanguage = NativeLanguage(rawValue: firestoreProfile.nativeLanguage) ?? .english
            newUser.createdAt = firestoreProfile.createdAt
            
            modelContext.insert(newUser)
            try? modelContext.save()
            
            return newUser
        }
    }
    
    /// Sync local User model changes to Firestore
    func syncToFirestore(user: User) async throws {
        guard let uid = user.firebaseUID else {
            throw NSError(domain: "UserProfileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "User has no Firebase UID"])
        }
        
        print("☁️ Syncing local user to Firestore...")
        
        try await updateProfile(
            uid: uid,
            fullName: user.fullName,
            roleTitle: user.roleTitle,
            gender: user.gender,
            dateOfBirth: user.dateOfBirth,
            nativeLanguage: user.nativeLanguage
        )
    }
}
