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
    
    // ✅ ADD: Scene phase tracking for background sync
    @Environment(\.scenePhase) private var scenePhase

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
        // ✅ ADD: Background sync on app state change
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                print("📱 App going to background. Triggering emergency sync...")
                performBackgroundSync()
            } else if newPhase == .active {
                print("📱 App became active. Ready to restore progress on dashboard.")
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // ✅ ADD: Emergency sync when app goes to background
    /// Syncs active (incomplete) sessions to cloud when user closes the app
    private func performBackgroundSync() {
        let container = appDelegate.modelContainer
        
        // Detached task ensures this keeps running even if view hierarchy is paused
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let service = UserProgressService(modelContainer: container)
            
            // Fetch ONLY incomplete sessions to minimize bandwidth/cost
            let descriptor = FetchDescriptor<StudentSession>(
                predicate: #Predicate { $0.isCompleted == false }
            )
            
            do {
                let activeSessions = try context.fetch(descriptor)
                if !activeSessions.isEmpty {
                    print("🔄 Background sync: Found \(activeSessions.count) active sessions")
                    let synced = await service.uploadSessions(activeSessions)
                    print("✅ Background sync complete: \(synced)/\(activeSessions.count) sessions saved to cloud")
                } else {
                    print("✅ Background sync: No active sessions to sync")
                }
            } catch {
                print("❌ Background sync failed: \(error.localizedDescription)")
            }
        }
    }
}
