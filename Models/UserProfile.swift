import Foundation

// ✅ NO CHANGES NEEDED - Already flexible!
// Users can select from predefined roles OR type in a custom role
struct UserProfileRole: Codable, Hashable, Identifiable {
    var id: String { title }
    var title: String
    
    // ✅ These are just SUGGESTIONS for convenience
    // The AI will interpret ANY role dynamically
    static let studentMS3 = UserProfileRole(title: "Medical Student (MS3)")
    static let allPredefined: [UserProfileRole] = [
        UserProfileRole(title: "Medical Student (MS1)"),
        UserProfileRole(title: "Medical Student (MS2)"),
        studentMS3,
        UserProfileRole(title: "Medical Student (MS4)"),
        UserProfileRole(title: "PA Student"),
        UserProfileRole(title: "NP Student"),
        UserProfileRole(title: "Physiotherapy Student"),
        UserProfileRole(title: "Nursing Student"),
        UserProfileRole(title: "Intern (PGY-1)"),
        UserProfileRole(title: "Resident"),
        UserProfileRole(title: "Fellow"),
        UserProfileRole(title: "Attending Physician")
    ]
}
