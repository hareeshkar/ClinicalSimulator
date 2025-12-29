// Models/PatientCase.swift

import Foundation
import SwiftData

// The @Model macro tells SwiftData to create a database table for this class.
@Model
class PatientCase: Identifiable, Hashable { // ✅ ADD HASHABLE
    // @Attribute(.unique) is a constraint that prevents duplicate case IDs.
    @Attribute(.unique)
    var caseId: String
    
    var title: String // This will now be the "Ground Truth" title.
    var specialty: String
    var difficulty: String
    var chiefComplaint: String // ✅ NEW: The student-facing title.
    
    // ✅ THE MAGIC FIX: @Attribute(.externalStorage)
    // This tells SwiftData: "Save this huge string to a separate file on disk. 
    // Do not load it into RAM when I fetch the list of cases. 
    // Only load it when I specifically access 'patientCase.fullCaseJSON'."
    @Attribute(.externalStorage) 
    var fullCaseJSON: String
    
    // Versioning for future sync checks
    var dataVersion: Int = 1
    
    // ✅ NEW: Recommended training levels for this case
    var recommendedForLevels: [String] = [] // e.g., ["MS3", "MS4", "Resident"]
    
    init(caseId: String, title: String, specialty: String, difficulty: String, chiefComplaint: String, fullCaseJSON: String) {
        self.caseId = caseId
        self.title = title
        self.specialty = specialty
        self.difficulty = difficulty
        self.chiefComplaint = chiefComplaint // Assign the property.
        self.fullCaseJSON = fullCaseJSON
        
        // ✅ Auto-assign based on difficulty
        self.recommendedForLevels = PatientCase.inferRecommendedLevels(from: difficulty)
    }
    
    // ✅ Helper to map difficulty to training levels
    static func inferRecommendedLevels(from difficulty: String) -> [String] {
        switch difficulty.lowercased() {
        case "beginner":
            return ["MS1", "MS2", "MS3", "PA Student", "NP Student", "Nursing Student"]
        case "intermediate":
            return ["MS3", "MS4", "PA Student", "NP Student", "Intern", "Resident"]
        case "advanced":
            return ["MS4", "Intern", "Resident", "Fellow", "Attending"]
        default:
            return [] // Show to everyone if unknown
        }
    }

    // ✅ ADD HASHABLE CONFORMANCE
    static func == (lhs: PatientCase, rhs: PatientCase) -> Bool {
        lhs.caseId == rhs.caseId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(caseId)
    }
}
