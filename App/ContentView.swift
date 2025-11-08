import SwiftUI
import SwiftData

struct ContentView: View {
    // The AuthService will be the single source of truth for auth state.
    @StateObject private var authService: AuthService
    
    // ❌ REMOVE THIS. We no longer need to access the environment for the context here.
    // @Environment(\.modelContext) private var modelContext

    // ✅ FIX: Create an initializer that accepts the ModelContainer.
    init(modelContainer: ModelContainer) {
        // Use the mainContext from the passed-in container to initialize the AuthService.
        // This is now safe, direct, and avoids the casting crash.
        let authService = AuthService(modelContext: modelContainer.mainContext)
        _authService = StateObject(wrappedValue: authService)
    }
    
    var body: some View {
        Group {
            if let user = authService.currentUser {
                // If a user is logged in, show the main app.
                MainTabView()
                    // Pass the logged-in user down for data scoping.
                    .environment(user)
            } else {
                // If no user is logged in, show the login screen.
                LoginView()
            }
        }
        // Make the AuthService available to all child views (Login, SignUp, etc.)
        .environmentObject(authService)
    }
}
