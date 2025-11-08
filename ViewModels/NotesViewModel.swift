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
    
    init(session: StudentSession, modelContext: ModelContext) {
        self.session = session
        self.modelContext = modelContext
        
        // Load the array of items from the session.
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
        } catch {
            print("Failed to save session: \(error)")
        }
    }
}
