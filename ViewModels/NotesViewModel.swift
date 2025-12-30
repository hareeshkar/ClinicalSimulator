// ViewModels/NotesViewModel.swift

import Foundation
import SwiftData

@MainActor
class NotesViewModel: ObservableObject {
    
    // ✅ FIX: This property now holds an array of DifferentialItem, not a String.
    @Published var differentialDiagnosis: [DifferentialItem]
    @Published var notes: String
    
    private let session: StudentSession
    private let modelContext: ModelContext
    
    // ✅ ADD: Progress sync service for cloud synchronization
    private let progressService: UserProgressService
    
    // ✅ NOTIFICATION: Observer for cloud updates
    private var notificationObserver: NSObjectProtocol?
    
    init(session: StudentSession, modelContext: ModelContext) {
        self.session = session
        self.modelContext = modelContext
        
        // ✅ INITIALIZE: Progress service with model container
        self.progressService = UserProgressService(modelContainer: modelContext.container)
        
        // Load the array of items from the session.
        self.differentialDiagnosis = session.differentialDiagnosis
        self.notes = session.notes
        
        // ✅ NOTIFY: Listen for session updates from cloud
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .sessionUpdatedFromCloud,
            object: session.sessionId,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromSession()
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // ✅ RELOAD: Update published properties from session after cloud update
    private func reloadFromSession() {
        self.differentialDiagnosis = session.differentialDiagnosis
        self.notes = session.notes
    }
    
    /// Saves all notes-related data back to the SwiftData model.
    func save() {
        // Save the array of items back to the session.
        session.differentialDiagnosis = self.differentialDiagnosis
        session.notes = self.notes
        
        do {
            try modelContext.save()
            print("Differential and notes saved successfully.")
            
            // ✅ SYNC TO CLOUD: Upload session after saving notes/differential
            let sessionToSync = self.session
            Task.detached(priority: .utility) {
                await self.progressService.uploadSession(sessionToSync)
            }
        } catch {
            print("Failed to save session: \(error)")
        }
    }
}
