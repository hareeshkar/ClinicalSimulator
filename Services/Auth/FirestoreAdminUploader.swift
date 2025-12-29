// Services/FirestoreAdminUploader.swift
// ⚠️ ONE-TIME ADMIN FUNCTION - Remove after initial database setup

import Foundation
import FirebaseFirestore

/// ☁️ Admin tool to upload local SampleCases.json to Firestore
/// Run this ONCE to populate the cloud database, then remove or disable
actor FirestoreAdminUploader {
    
    /// Upload all cases from SampleCases.json to Firestore
    /// This is a ONE-TIME operation for initial database setup
    func uploadDatabaseToCloud() async throws -> (success: Int, failed: Int) {
        print("🚀 Starting Admin Upload to Firestore...")
        
        // 1. Load Local JSON
        guard let url = Bundle.main.url(forResource: "SampleCases", withExtension: "json") else {
            print("❌ Could not find SampleCases.json in bundle")
            throw NSError(domain: "FirestoreAdminUploader", code: 404, userInfo: [NSLocalizedDescriptionKey: "SampleCases.json not found"])
        }
        
        let data = try Data(contentsOf: url)
        let cases = try JSONDecoder().decode([EnhancedCaseDetail].self, from: data)
        print("✅ Loaded \(cases.count) cases from local JSON")
        
        let db = Firestore.firestore()
        var successCount = 0
        var failedCount = 0
        
        // 2. Use batch writes for efficiency (max 500 operations per batch)
        let batchSize = 400 // Stay under 500 limit for safety
        var currentBatch = db.batch()
        var operationCount = 0
        
        for (index, caseDetail) in cases.enumerated() {
            let caseId = caseDetail.metadata.caseId
            let ref = db.collection("cases").document(caseId)
            
            // Prepare case data for Firestore
            let caseData: [String: Any] = [
                "caseId": caseId,
                "title": caseDetail.metadata.title,
                "specialty": caseDetail.metadata.specialty,
                "difficulty": caseDetail.metadata.difficulty,
                "chiefComplaint": caseDetail.initialPresentation.chiefComplaint,
                "recommendedForLevels": caseDetail.metadata.recommendedForLevels ?? [],
                "lastUpdated": FieldValue.serverTimestamp(),
                // ⚠️ CRITICAL: Store the full case JSON blob - this is the simulation engine
                "fullCaseJSON": caseDetail.toJSONString()
            ]
            
            currentBatch.setData(caseData, forDocument: ref)
            operationCount += 1
            
            // Commit batch every 400 operations or at the end
            if operationCount >= batchSize || index == cases.count - 1 {
                do {
                    try await currentBatch.commit()
                    print("✅ Batch committed: \(operationCount) cases (\(index + 1)/\(cases.count))")
                    successCount += operationCount
                    
                    // Start new batch
                    currentBatch = db.batch()
                    operationCount = 0
                    
                } catch {
                    print("❌ Batch commit failed: \(error.localizedDescription)")
                    failedCount += operationCount
                    
                    // Start new batch anyway
                    currentBatch = db.batch()
                    operationCount = 0
                }
            }
        }
        
        print("🎉 Upload Complete: \(successCount) cases uploaded, \(failedCount) failed")
        return (successCount, failedCount)
    }
    
    /// Delete all cases from Firestore (useful for re-uploading)
    func clearFirestoreDatabase() async throws -> Int {
        print("⚠️ Starting Firestore Database Clear...")
        
        let db = Firestore.firestore()
        let snapshot = try await db.collection("cases").getDocuments()
        
        var deletedCount = 0
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
            deletedCount += 1
        }
        
        try await batch.commit()
        print("✅ Cleared \(deletedCount) cases from Firestore")
        
        return deletedCount
    }
}
