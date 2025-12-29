// Services/CaseSynchronizationService.swift

import Foundation
import SwiftData
import FirebaseFirestore
import os.log

private let syncLogger = Logger(subsystem: "com.hareeshkar.ClinicalSimulator", category: "CaseSynchronizationService")

// Actors are perfect for background work. They ensure thread safety.
actor CaseSynchronizationService {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        syncLogger.log("🔄 CaseSynchronizationService initialized")
    }
    
    /// ☁️ NEW: Sync from Firebase Firestore (2025 Cloud-First Architecture)
    func syncWithCloud() async throws {
        syncLogger.log("☁️ Starting Cloud Sync from Firestore...")
        
        let backgroundContext = ModelContext(modelContainer)
        let db = Firestore.firestore()
        
        do {
            // 1. Fetch ALL documents from Firestore (metadata is small - ~1KB per doc)
            syncLogger.log("📡 Fetching cases from Firestore collection 'cases'...")
            let snapshot = try await db.collection("cases").getDocuments()
            syncLogger.log("✅ Retrieved \(snapshot.documents.count) documents from Firestore")
            
            // 2. Get local IDs for comparison (optimized fetch)
            syncLogger.log("🔍 Fetching existing case IDs from local database...")
            let existingCases = try backgroundContext.fetch(FetchDescriptor<PatientCase>())
            let existingMap = Dictionary(uniqueKeysWithValues: existingCases.map { ($0.caseId, $0) })
            syncLogger.log("📊 Found \(existingMap.count) existing cases in local database")
            
            var updates = 0
            var inserts = 0
            
            // 3. Process each Firestore document
            for (index, document) in snapshot.documents.enumerated() {
                let data = document.data()
                let caseId = data["caseId"] as? String ?? ""
                
                // Log progress every 10 cases
                if (index + 1) % 10 == 0 {
                    syncLogger.log("📈 Processed \(index + 1)/\(snapshot.documents.count) cases")
                }
                
                guard !caseId.isEmpty else {
                    syncLogger.warning("⚠️ Skipping document with missing caseId: \(document.documentID)")
                    continue
                }
                
                // Extract metadata
                let title = data["title"] as? String ?? "Untitled Case"
                let specialty = data["specialty"] as? String ?? "General"
                let difficulty = data["difficulty"] as? String ?? "Intermediate"
                let chiefComplaint = data["chiefComplaint"] as? String ?? ""
                let fullJSON = data["fullCaseJSON"] as? String ?? "{}"
                let levels = data["recommendedForLevels"] as? [String] ?? []
                
                if let existingCase = existingMap[caseId] {
                    // Update existing case if data changed
                    // Compare JSON to detect changes (you could also use a version field)
                    if existingCase.fullCaseJSON != fullJSON {
                        syncLogger.log("🔄 Updating case: \(caseId)")
                        existingCase.title = title
                        existingCase.specialty = specialty
                        existingCase.difficulty = difficulty
                        existingCase.chiefComplaint = chiefComplaint
                        existingCase.fullCaseJSON = fullJSON
                        existingCase.recommendedForLevels = levels
                        updates += 1
                    }
                } else {
                    // Insert new case
                    syncLogger.log("➕ Inserting new case: \(caseId) - \(title)")
                    let newCase = PatientCase(
                        caseId: caseId,
                        title: title,
                        specialty: specialty,
                        difficulty: difficulty,
                        chiefComplaint: chiefComplaint,
                        fullCaseJSON: fullJSON
                    )
                    newCase.recommendedForLevels = levels
                    backgroundContext.insert(newCase)
                    inserts += 1
                }
            }
            
            // 4. Save if there were changes
            if updates > 0 || inserts > 0 {
                syncLogger.log("💾 Saving changes to local database...")
                try backgroundContext.save()
                syncLogger.log("✅ Cloud Sync Complete: \(inserts) inserted, \(updates) updated")
            } else {
                syncLogger.log("✅ Cloud Sync Complete: Database is already up to date")
            }
            
        } catch let error as NSError {
            syncLogger.error("❌ Cloud Sync Failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 📦 LEGACY: Local sync from SampleCases.json (kept for offline fallback)
    func syncLocalData() async throws {
        syncLogger.log("🚀 Starting local sync from SampleCases.json (fallback mode)")
        
        // Create a background context (OFF the main thread)
        let backgroundContext = ModelContext(modelContainer)
        syncLogger.log("📝 Created background ModelContext")
        
        // Load the file
        guard let url = Bundle.main.url(forResource: "SampleCases", withExtension: "json") else {
            syncLogger.error("❌ SampleCases.json not found in bundle")
            throw NSError(domain: "CaseSynchronizationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "SampleCases.json not found in bundle"])
        }
        syncLogger.log("📁 Found SampleCases.json at: \(url.path, privacy: .public)")
        
        let data = try Data(contentsOf: url)
        let dataSizeMB = Double(data.count) / (1024 * 1024)
        syncLogger.log("💾 Loaded \(String(format: "%.2f", dataSizeMB), privacy: .public) MB of JSON data")
        
        // Decode the massive array
        syncLogger.log("🔍 Starting JSON decoding...")
        let casesFromJSON = try JSONDecoder().decode([EnhancedCaseDetail].self, from: data)
        syncLogger.log("✅ Successfully decoded \(casesFromJSON.count, privacy: .public) cases from JSON")
        
        // Fetch existing IDs to avoid duplicates
        syncLogger.log("🔍 Fetching existing case IDs from database...")
        let existingIds = try fetchExistingCaseIDs(context: backgroundContext)
        syncLogger.log("📊 Found \(existingIds.count, privacy: .public) existing cases in database")
        
        var newCount = 0
        var skippedCount = 0
        
        // Process each case
        syncLogger.log("⚙️ Processing \(casesFromJSON.count, privacy: .public) cases...")
        for (index, caseDetail) in casesFromJSON.enumerated() {
            let id = caseDetail.metadata.caseId
            
            // Log progress every 10 cases
            if (index + 1) % 10 == 0 {
                syncLogger.log("📈 Processed \(index + 1, privacy: .public)/\(casesFromJSON.count, privacy: .public) cases")
            }
            
            // Re-encode individual case for the blob
            let rawData = try JSONEncoder().encode(caseDetail)
            let jsonString = String(data: rawData, encoding: .utf8) ?? "{}"
            
            if existingIds.contains(id) {
                syncLogger.log("⏭️ Skipping existing case: \(id, privacy: .public)")
                skippedCount += 1
                continue
            } else {
                // Insert New
                syncLogger.log("➕ Inserting new case: \(id, privacy: .public) - \(caseDetail.metadata.title, privacy: .public)")
                let newCase = PatientCase(
                    caseId: id,
                    title: caseDetail.metadata.title,
                    specialty: caseDetail.metadata.specialty,
                    difficulty: caseDetail.metadata.difficulty,
                    chiefComplaint: caseDetail.initialPresentation.chiefComplaint,
                    fullCaseJSON: jsonString
                )
                
                if let levels = caseDetail.metadata.recommendedForLevels {
                    newCase.recommendedForLevels = levels
                    syncLogger.log("🏷️ Set recommended levels for \(id, privacy: .public): \(levels.joined(separator: ", "), privacy: .public)")
                }
                
                backgroundContext.insert(newCase)
                newCount += 1
            }
        }
        
        // Save once at the end (Batch Insert)
        if newCount > 0 {
            syncLogger.log("💾 Saving \(newCount, privacy: .public) new cases to database...")
            try backgroundContext.save()
            syncLogger.log("✅ Local Sync: Successfully inserted \(newCount, privacy: .public) new cases")
        } else {
            syncLogger.log("✅ Local Sync: Database is up to date (\(skippedCount, privacy: .public) cases skipped)")
        }
        
        syncLogger.log("🎉 Local sync completed successfully")
    }
    
    private func fetchExistingCaseIDs(context: ModelContext) throws -> Set<String> {
        syncLogger.log("🔍 Fetching existing case IDs with optimized query...")
        
        // Fetch ONLY the IDs, not the heavy objects
        var descriptor = FetchDescriptor<PatientCase>(sortBy: [SortDescriptor(\.caseId)])
        descriptor.propertiesToFetch = [\.caseId]
        
        let results = try context.fetch(descriptor)
        let ids = Set(results.map { $0.caseId })
        
        syncLogger.log("📋 Retrieved \(ids.count, privacy: .public) existing case IDs")
        return ids
    }
}
