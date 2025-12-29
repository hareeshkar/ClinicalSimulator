import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// ✅ ADD A CUSTOM APP DELEGATE
class AppDelegate: NSObject, UIApplicationDelegate {
    let modelContainer: ModelContainer
    
    override init() {
        do {
            // Initialize the container here so we can access it.
            modelContainer = try ModelContainer(for: PatientCase.self, StudentSession.self, ConversationMessage.self, User.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct ClinicalSimulatorApp: App {
    // ✅ REGISTER THE APP DELEGATE
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // ✅ FIX: Pass the modelContainer directly to ContentView's initializer.
            ContentView(modelContainer: appDelegate.modelContainer)
                .onTapGesture {
                    hideKeyboard()
                }
        }
        // ✅ USE THE CONTAINER FROM THE DELEGATE
        .modelContainer(appDelegate.modelContainer)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
