import SwiftUI
import SwiftData

@MainActor
class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    
    let modelContext: ModelContext
    
    // ✅ We'll now store the user's email to remember them.
    @AppStorage("loggedInUserEmail") private var loggedInUserEmail: String?
    @AppStorage("shouldRememberUser") private var shouldRememberUser: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // ✅ Look up the user by email on app launch if remember is enabled.
        if shouldRememberUser, let userEmail = loggedInUserEmail {
            let predicate = #Predicate<User> { $0.email == userEmail }
            let descriptor = FetchDescriptor(predicate: predicate)
            if let user = try? modelContext.fetch(descriptor).first {
                self.currentUser = user
            }
        }
    }
    
    // ✅ UPDATE the function signature and logic
    func signUp(fullName: String, email: String, password: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fullName.isEmpty, !normalizedEmail.isEmpty, !password.isEmpty else {
            throw AuthError.invalidInput
        }
        
        let predicate = #Predicate<User> { $0.email == normalizedEmail }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existingUser = try modelContext.fetch(descriptor).first {
            print("Email '\(existingUser.email)' is already taken.")
            throw AuthError.emailTaken
        }
        
        let newUser = User(fullName: fullName, email: normalizedEmail, password: password)
        modelContext.insert(newUser)
        try modelContext.save()
        
        self.currentUser = newUser
        self.loggedInUserEmail = newUser.email
        print("User \(newUser.fullName) signed up and logged in successfully.")
    }
    
    // ✅ UPDATE the function signature and logic
    func login(email: String, password: String, rememberMe: Bool = false) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let predicate = #Predicate<User> { $0.email == normalizedEmail }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard let user = try modelContext.fetch(descriptor).first else {
            throw AuthError.userNotFound
        }
        
        guard user.verifyPassword(password) else {
            throw AuthError.incorrectPassword
        }
        
        self.currentUser = user
        if rememberMe {
            self.loggedInUserEmail = user.email
            self.shouldRememberUser = true
        } else {
            self.loggedInUserEmail = nil
            self.shouldRememberUser = false
        }
        print("User \(user.fullName) logged in successfully.")
    }
    
    func logout() {
        self.currentUser = nil
        self.loggedInUserEmail = nil
        self.shouldRememberUser = false
        print("User logged out.")
    }
    
    // MARK: - Password Recovery
    func verifyEmailExists(_ email: String) async throws -> Bool {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = #Predicate<User> { $0.email == normalizedEmail }
        let descriptor = FetchDescriptor(predicate: predicate)
        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }
    
    func resetPassword(email: String, newPassword: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = #Predicate<User> { $0.email == normalizedEmail }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard let user = try modelContext.fetch(descriptor).first else {
            throw AuthError.userNotFound
        }
        
        user.hashedPassword = User.hashPassword(newPassword)
        try modelContext.save()
        print("Password reset successful for \(normalizedEmail)")
    }
}

// ✅ UPDATE the error enum
enum AuthError: Error, LocalizedError {
    case invalidInput
    case emailTaken
    case userNotFound
    case incorrectPassword
    
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "All fields must be filled out."
        case .emailTaken: return "An account with this email already exists."
        case .userNotFound: return "No account found with that email address."
        case .incorrectPassword: return "The password you entered is incorrect."
        }
    }
}
