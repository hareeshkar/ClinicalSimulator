import Foundation
import SwiftData
import CryptoKit

// ✅ NEW: Inclusive gender options for 2025
enum Gender: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-Binary"
    case preferNotToSay = "Prefer Not to Say"
    
    var id: String { rawValue }
}

@Model
class User {
    // This is a unique, stable ID provided by SwiftData. Great for relationships.
    @Attribute(.unique)
    var id: UUID = UUID()
    
    // ✅ NEW: Email is now the unique login identifier.
    @Attribute(.unique)
    var email: String
    
    // ✅ NEW: Full name is for display purposes (e.g., "Welcome, Dr. Jane Doe").
    var fullName: String
    
    var hashedPassword: String
    var createdAt: Date
    
    // A user can have many sessions. When a user is deleted, all their sessions are also deleted.
    @Relationship(deleteRule: .cascade, inverse: \StudentSession.user)
    var sessions: [StudentSession] = []
    
    // This will store the unique filename based on the user's UUID
    var profileImageFilename: String?
    
    // ✅ NEW: Store the user's role/title (e.g., "MS3 Student", "Resident", etc.)
    var roleTitle: String?
    
    // ✅ NEW: Inclusive gender options for 2025
    var gender: Gender? // Made optional to fix SwiftData casting issues
    var dateOfBirth: Date? // Optional for privacy
    
    // ✅ UPDATE the initializer
    init(fullName: String, email: String, password: String) {
        self.fullName = fullName
        self.email = email.lowercased() // Store emails in a consistent format
        self.hashedPassword = User.hashPassword(password)
        self.createdAt = Date()
        self.profileImageFilename = nil
        self.roleTitle = "Medical Student (MS3)"
        // ✅ NEW: Initialize new properties
        self.gender = .preferNotToSay
        self.dateOfBirth = nil
    }
    
    /// Verifies if the provided password matches the user's stored hashed password.
    func verifyPassword(_ password: String) -> Bool {
        return self.hashedPassword == User.hashPassword(password)
    }
    
    /// Hashes a plain-text password using SHA256 for secure storage.
    static func hashPassword(_ password: String) -> String {
        guard let data = password.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
