import Foundation
import SwiftData

class DataManager {
    
    // A static function can be called without creating an instance of the class.
    static func loadSampleData(modelContext: ModelContext) {
        guard let url = Bundle.main.url(forResource: "SampleCases", withExtension: "json") else {
            fatalError("Failed to find SampleCases.json")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Failed to load SampleCases.json")
        }
        
        do {
            // Decode the entire array of enhanced cases
            let casesFromJSON = try JSONDecoder().decode([EnhancedCaseDetail].self, from: data)
            
            // Loop through and create our SwiftData objects
            for caseDetail in casesFromJSON {
                // We need to re-encode the individual case object to store as a string.
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let caseData = try encoder.encode(caseDetail)
                let jsonString = String(data: caseData, encoding: .utf8)!
                
                // This is the line we are updating.
                let newCase = PatientCase(
                    caseId: caseDetail.metadata.caseId,
                    title: caseDetail.metadata.title, // Keep the real title as ground truth.
                    specialty: caseDetail.metadata.specialty,
                    difficulty: caseDetail.metadata.difficulty,
                    chiefComplaint: caseDetail.initialPresentation.chiefComplaint, // <-- THE CRUCIAL ADDITION
                    fullCaseJSON: jsonString
                )
                // ✅ NEW: prefer recommendedForLevels from the JSON metadata when present,
                // otherwise keep the auto-inferred levels based on difficulty.
                if let recommended = caseDetail.metadata.recommendedForLevels, !recommended.isEmpty {
                    newCase.recommendedForLevels = recommended
                }
                modelContext.insert(newCase)
            }
            print("Enhanced sample data loaded with chief complaints.")
        } catch {
            fatalError("Failed to decode or process enhanced JSON: \(error)")
        }
    }
    // ADD THIS FUNCTION to DataManager.swift

    static func findOrCreateActiveSession(for caseId: String, user: User, modelContext: ModelContext) -> StudentSession {
        // 1. Update the predicate to also filter by the user.
        let userId = user.id // SwiftData needs the ID for the predicate
        let predicate = #Predicate<StudentSession> { 
            $0.caseId == caseId && 
            $0.isCompleted == false &&
            $0.user?.id == userId // <-- THE CRUCIAL ADDITION
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        do {
            if let existingSession = try modelContext.fetch(descriptor).first {
                print("Found existing session for case: \(caseId) for user: \(user.fullName)")
                return existingSession
            }
        } catch {
            fatalError("Failed to fetch sessions: \(error)")
        }
        
        print("No active session found. Creating a new one for case: \(caseId) for user: \(user.fullName)")
        // 3. Pass the user to the new session's initializer.
        let newSession = StudentSession(caseId: caseId, user: user)
        modelContext.insert(newSession)
        return newSession
    }
    // ✅ FIX: Update this function to also require a user.
    static func findActiveSession(for caseId: String, user: User, modelContext: ModelContext) -> StudentSession? {
        let userId = user.id
        let predicate = #Predicate<StudentSession> {
            $0.caseId == caseId &&
            $0.isCompleted == false &&
            $0.user?.id == userId // <-- THE FIX
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}
