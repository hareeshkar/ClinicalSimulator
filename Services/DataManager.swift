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
    
    // ✅ NEW: Smart reload - updates existing cases, adds new ones, preserves relationships
    static func reloadSampleCasesUpsert(modelContext: ModelContext) throws {
        guard let url = Bundle.main.url(forResource: "SampleCases", withExtension: "json") else {
            throw NSError(domain: "DataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to find SampleCases.json"])
        }
        guard let data = try? Data(contentsOf: url) else {
            throw NSError(domain: "DataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load SampleCases.json"])
        }
        
        do {
            // Step 1: Decode fresh cases from JSON
            let casesFromJSON = try JSONDecoder().decode([EnhancedCaseDetail].self, from: data)
            
            // Step 2: Fetch all existing cases for comparison
            let descriptor = FetchDescriptor<PatientCase>()
            let existingCases = try modelContext.fetch(descriptor)
            let existingCasesMap = Dictionary(uniqueKeysWithValues: existingCases.map { ($0.caseId, $0) })
            
            var updatedCount = 0
            var addedCount = 0
            
            // Step 3: Upsert each case from JSON
            for caseDetail in casesFromJSON {
                // Encode case as JSON string
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let caseData = try encoder.encode(caseDetail)
                let jsonString = String(data: caseData, encoding: .utf8)!
                
                let caseId = caseDetail.metadata.caseId
                
                if let existingCase = existingCasesMap[caseId] {
                    // UPDATE existing case
                    existingCase.title = caseDetail.metadata.title
                    existingCase.specialty = caseDetail.metadata.specialty
                    existingCase.difficulty = caseDetail.metadata.difficulty
                    existingCase.chiefComplaint = caseDetail.initialPresentation.chiefComplaint
                    existingCase.fullCaseJSON = jsonString
                    
                    // Update recommended levels if provided in JSON
                    if let recommended = caseDetail.metadata.recommendedForLevels, !recommended.isEmpty {
                        existingCase.recommendedForLevels = recommended
                    } else {
                        existingCase.recommendedForLevels = PatientCase.inferRecommendedLevels(from: caseDetail.metadata.difficulty)
                    }
                    
                    updatedCount += 1
                } else {
                    // INSERT new case
                    let newCase = PatientCase(
                        caseId: caseId,
                        title: caseDetail.metadata.title,
                        specialty: caseDetail.metadata.specialty,
                        difficulty: caseDetail.metadata.difficulty,
                        chiefComplaint: caseDetail.initialPresentation.chiefComplaint,
                        fullCaseJSON: jsonString
                    )
                    
                    if let recommended = caseDetail.metadata.recommendedForLevels, !recommended.isEmpty {
                        newCase.recommendedForLevels = recommended
                    }
                    
                    modelContext.insert(newCase)
                    addedCount += 1
                }
            }
            
            // Step 4: Delete cases that exist in DB but not in JSON (orphaned cases)
            let jsonCaseIds = Set(casesFromJSON.map { $0.metadata.caseId })
            for existingCase in existingCases {
                if !jsonCaseIds.contains(existingCase.caseId) {
                    modelContext.delete(existingCase)
                    print("🗑️ Deleted orphaned case: \(existingCase.caseId)")
                }
            }
            
            // Step 5: Save all changes atomically
            try modelContext.save()
            print("✅ Cases reload complete: \(updatedCount) updated, \(addedCount) added")
            
        } catch let error as NSError {
            throw error
        }
    }
}
