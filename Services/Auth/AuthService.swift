import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticating: Bool = false
    
    let modelContext: ModelContext
    
    // Firebase Auth state listener
    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // ✅ Prevent auto-login on fresh app install
        // Firebase Auth persists sessions across installs, but we want no auto-login
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            try? Auth.auth().signOut()
        }
        
        // ✅ 2025: Listen to Firebase Auth state changes
        // Note: We do NOT auto-restore user from local storage anymore
        // User must be logged into Firebase to access the app
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let firebaseUser = firebaseUser {
                    // User is signed in Firebase - fetch profile from Firestore
                    await self.loadUserProfile(firebaseUID: firebaseUser.uid, email: firebaseUser.email)
                } else {
                    // User is signed out
                    self.currentUser = nil
                }
            }
        }
    }
    
    deinit {
        // Remove the auth state listener when AuthService is deallocated
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    // MARK: - Firebase Authentication Methods
    
    /// Sign up a new user with Firebase Auth and create Firestore profile
    func signUp(fullName: String, email: String, password: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fullName.isEmpty, !normalizedEmail.isEmpty, !password.isEmpty else {
            throw AuthError.invalidInput
        }
        
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            // 1. Create Firebase Auth account
            let authResult = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            let uid = authResult.user.uid
            print("✅ Firebase Auth: Created account with uid: \(uid)")
            
            // 2. Create Firestore profile
            let profileService = UserProfileService(modelContext: modelContext)
            try await profileService.createProfile(
                uid: uid,
                email: normalizedEmail,
                fullName: fullName,
                roleTitle: "Medical Student (MS3)",
                gender: .preferNotToSay,
                dateOfBirth: nil,
                nativeLanguage: .english
            )
            print("✅ Firestore: Profile created")
            
            // 3. Fetch and sync to local
            if let firestoreProfile = try await profileService.fetchProfile(uid: uid) {
                let localUser = profileService.syncToLocal(firestoreProfile: firestoreProfile)
                self.currentUser = localUser
                print("✅ Local: Profile synced for \(localUser.fullName)")
            }
            
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    /// Login an existing user with Firebase Auth and fetch Firestore profile
    func login(email: String, password: String, rememberMe: Bool = false) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            throw AuthError.invalidInput
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            // 1. Sign in with Firebase Auth
            let authResult = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
            let uid = authResult.user.uid
            print("✅ Firebase Auth: Logged in with uid: \(uid)")
            
            // 2. Fetch Firestore profile and sync to local
            await loadUserProfile(firebaseUID: uid, email: authResult.user.email)
            
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    /// Logout the current user
    func logout() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            print("✅ User signed out from Firebase")
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Password Recovery (Firebase)
    
    /// Send password reset email via Firebase
    func sendPasswordResetEmail(to email: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedEmail.isEmpty else {
            throw AuthError.invalidInput
        }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
            print("✅ Password reset email sent to \(normalizedEmail)")
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    /// Verify if email exists (for UI feedback before sending reset email)
    func verifyEmailExists(_ email: String) async throws -> Bool {
        // Note: Firebase doesn't expose a direct "check if email exists" API for security reasons.
        // We'll attempt to send a reset email - if user doesn't exist, Firebase will error.
        // For better UX, we just return true and let sendPasswordResetEmail handle the validation.
        return true
    }
    
    /// Legacy method - kept for compatibility but now uses Firebase
    func resetPassword(email: String, newPassword: String) async throws {
        // Firebase handles password reset via email link, not direct password change
        // This method now just sends the reset email
        try await sendPasswordResetEmail(to: email)
    }
    
    // MARK: - Helper Methods
    
    /// Load user profile from Firestore and sync to local SwiftData
    private func loadUserProfile(firebaseUID: String, email: String?) async {
        print("🔄 Loading user profile from Firestore...")
        
        let profileService = UserProfileService(modelContext: modelContext)
        
        do {
            // Fetch from Firestore
            if let firestoreProfile = try await profileService.fetchProfile(uid: firebaseUID) {
                // Sync to local
                let localUser = profileService.syncToLocal(firestoreProfile: firestoreProfile)
                self.currentUser = localUser
                print("✅ User profile loaded: \(localUser.fullName)")
            } else {
                // Profile doesn't exist in Firestore - this shouldn't happen normally
                // Create a basic profile
                print("⚠️ No Firestore profile found, creating one...")
                try await profileService.createProfile(
                    uid: firebaseUID,
                    email: email?.lowercased() ?? "unknown@example.com",
                    fullName: email ?? "User",
                    roleTitle: "Medical Student (MS3)"
                )
                
                // Fetch again
                if let firestoreProfile = try await profileService.fetchProfile(uid: firebaseUID) {
                    let localUser = profileService.syncToLocal(firestoreProfile: firestoreProfile)
                    self.currentUser = localUser
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error.localizedDescription)")
            // Fallback: create minimal local user
            let fallbackUser = User(fullName: email ?? "User", email: email ?? "unknown@example.com", password: "")
            fallbackUser.firebaseUID = firebaseUID
            modelContext.insert(fallbackUser)
            try? modelContext.save()
            self.currentUser = fallbackUser
        }
    }
    
    /// Update current user's profile in Firestore
    func updateUserProfile() async throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }
        
        let profileService = UserProfileService(modelContext: modelContext)
        try await profileService.syncToFirestore(user: user)
    }
    
    /// Fetch local User by Firebase UID (for offline access)
    private func fetchLocalUser(byFirebaseUID uid: String) -> User? {
        let predicate = #Predicate<User> { $0.firebaseUID == uid }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Fetch local User by email (fallback)
    private func fetchLocalUser(byEmail email: String) -> User? {
        let normalizedEmail = email.lowercased()
        let predicate = #Predicate<User> { $0.email == normalizedEmail }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Map Firebase Auth errors to user-friendly AuthError
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }
        
        switch errorCode {
        case .emailAlreadyInUse:
            return .emailTaken
        case .invalidEmail:
            return .invalidEmail
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .incorrectPassword
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError
        case .tooManyRequests:
            return .tooManyRequests
        case .invalidCredential:
            return .incorrectPassword
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// ✅ Enhanced error enum with Firebase-specific errors
enum AuthError: Error, LocalizedError {
    case invalidInput
    case emailTaken
    case userNotFound
    case incorrectPassword
    case invalidEmail
    case weakPassword
    case networkError
    case tooManyRequests
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "All fields must be filled out."
        case .emailTaken:
            return "An account with this email already exists."
        case .userNotFound:
            return "No account found with that email address."
        case .incorrectPassword:
            return "The email or password you entered is incorrect."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .unknown(let message):
            return message
        }
    }
}
