import SwiftUI
import SwiftData
import FirebaseCore // 1. Import the FirebaseCore library

@main
struct ClinicalSimulatorApp: App {

    // 2. Add this init() method
    // This code runs once when your app starts up.
    init() {
        // This line finds your GoogleService-Info.plist and configures Firebase.
        FirebaseApp.configure()
        print("Firebase configured successfully!") // Optional: for debugging
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onTapGesture {
                    hideKeyboard()
                }
        }
        // We will replace 'Item.self' with our real models later.
        .modelContainer(for: [PatientCase.self, StudentSession.self, ConversationMessage.self])
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
