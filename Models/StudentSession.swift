// Models/StudentSession.swift

import Foundation
import SwiftData

// ✅ NEW: A struct to hold a single, structured differential diagnosis item.
struct DifferentialItem: Codable, Hashable, Identifiable {
    var id = UUID() // For SwiftUI lists
    var diagnosis: String
    var confidence: Double // 0.0 to 1.0
    var rationale: String
}

struct PerformedAction: Codable, Hashable {
    let actionName: String
    let timestamp: Date
    var reason: String? // The student's justification for this action.
}

@Model
class StudentSession {
    @Attribute(.unique)
    var sessionId: UUID

    var caseId: String
    var isCompleted: Bool
    var score: Double?

    // ⚠️ REMOVE THE OLD, DEPRECATED DATA PROPERTY. THIS IS THE CAUSE OF THE ERROR.
    // private var orderedTestNamesData: Data = Data()
    
    // ✅ KEEP THE NEW, RICHER DATA PROPERTY.
    private var performedActionsData: Data = Data()
    
    // ✅ KEEP THE NEW COMPUTED PROPERTY.
    var performedActions: [PerformedAction] {
        get {
            (try? JSONDecoder().decode([PerformedAction].self, from: performedActionsData)) ?? []
        }
        set {
            performedActionsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    // ✅ KEEP THIS CONVENIENCE PROPERTY. With the old one gone, it is no longer ambiguous.
    var orderedTestNames: [String] {
        performedActions.map { $0.actionName }
    }
    
    // ✅ RENAME: This property now stores the student's initial hypothesis.
    private var differentialDiagnosisData: Data = Data()
    var differentialDiagnosis: [DifferentialItem] {
        get { (try? JSONDecoder().decode([DifferentialItem].self, from: differentialDiagnosisData)) ?? [] }
        set { differentialDiagnosisData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var notes: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \ConversationMessage.session)
    var messages: [ConversationMessage] = []

    var evaluationJSON: String?

    init(sessionId: UUID = UUID(), caseId: String, isCompleted: Bool = false) {
        self.sessionId = sessionId
        self.caseId = caseId
        self.isCompleted = isCompleted
    }
}
