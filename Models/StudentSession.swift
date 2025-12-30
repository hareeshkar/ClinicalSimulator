// Models/StudentSession.swift

import Foundation
import SwiftData
import UIKit

// ✅ NEW: Enum to track evaluation lifecycle states
enum EvaluationStatus: String, CaseIterable {
    case notStarted = "not_started"
    case evaluating = "evaluating"
    case completed = "completed"
    case failed = "failed"
    case retryNeeded = "retry_needed"
}

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
    
    // ✅ NEW: Track evaluation status for error handling and retry logic
    var evaluationStatus: String = EvaluationStatus.notStarted.rawValue
    var evaluationErrorMessage: String?
    var evaluationAttempts: Int = 0

    // ✅ ADD THIS RELATIONSHIP
    // This is the "many-to-one" side: many sessions can belong to one user.
    var user: User?

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
    
    // ✅ SYNC METADATA: Track when this session was last synced
    var lastSyncedToCloud: Date?
    var cloudLastUpdated: Date?
    var deviceIdentifier: String? // Track which device made last change

    // ✅ UPDATE THE INITIALIZER
    init(sessionId: UUID = UUID(), caseId: String, isCompleted: Bool = false, user: User) {
        self.sessionId = sessionId
        self.caseId = caseId
        self.isCompleted = isCompleted
        self.user = user // Assign the user
        self.deviceIdentifier = UIDevice.current.identifierForVendor?.uuidString
    }
}
