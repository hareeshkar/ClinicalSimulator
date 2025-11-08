import Foundation
import SwiftData

// THIS IS THE ONE AND ONLY DEFINITION OF THIS STRUCT.
// It is Hashable (for NavigationStack) and Identifiable (for .sheet).
struct EvaluationNavigationContext: Hashable, Identifiable {
    let patientCase: PatientCase
    let session: StudentSession
    
    // The 'id' for Identifiable is the session's unique UUID.
    var id: UUID { session.sessionId }
}

@MainActor
class EvaluationViewModel: ObservableObject, Hashable {
    
    // MARK: - Nested State Enum
    enum EvaluationState {
        case idle
        case evaluating
        case success(ProfessionalEvaluationResult)
        case error(String)
    }
    
    // MARK: - Published State
    @Published private(set) var state: EvaluationState
    
    // MARK: - Private Properties
    private let patientCase: PatientCase
    private let session: StudentSession
    private let modelContext: ModelContext
    private let geminiService = GeminiService()
    private let userRole: String

    // MARK: - Main Initializer (Used by app)
    init(patientCase: PatientCase, session: StudentSession, modelContext: ModelContext, userRole: String) {
        self.patientCase = patientCase
        self.session = session
        self.modelContext = modelContext
        self.userRole = userRole
        
        // ✅ UPDATE TO DECODE THE NEW STRUCT
        if let evalJSON = session.evaluationJSON, let data = evalJSON.data(using: .utf8),
           let savedResult = try? JSONDecoder().decode(ProfessionalEvaluationResult.self, from: data) {
            self.state = .success(savedResult)
        } else {
            self.state = .idle
        }
    }
    
    // MARK: - Preview / Testing Initializer
    init(patientCase: PatientCase, session: StudentSession, modelContext: ModelContext, initialState: EvaluationState, userRole: String) {
        self.patientCase = patientCase
        self.session = session
        self.modelContext = modelContext
        self.userRole = userRole
        self.state = initialState
    }
    
    // MARK: - Main Evaluation Function
    func evaluatePerformance() async {
        guard case .idle = state else { return }
        state = .evaluating
        
        let data = Data(patientCase.fullCaseJSON.utf8)
        guard let caseDetail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) else {
            state = .error("Failed to parse the case file for evaluation.")
            return
        }
        
        do {
            // ✅ Use the stored userRole
            let result = try await geminiService.generateEvaluation(
                caseDetail: caseDetail,
                session: session,
                userRole: userRole
            )
            
            // ✅ SAVES THE NEW RESULT
            session.score = Double(result.overallScore)
            if let resultData = try? JSONEncoder().encode(result) {
                session.evaluationJSON = String(data: resultData, encoding: .utf8)
            }
            try? modelContext.save()
            
            state = .success(result)
        } catch {
            print("Evaluation error: \(error.localizedDescription)")
            state = .error("An error occurred while generating your report.")
        }
    }
    
    // --- HASHABLE CONFORMANCE ---
    static func == (lhs: EvaluationViewModel, rhs: EvaluationViewModel) -> Bool {
        lhs.session.sessionId == rhs.session.sessionId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(session.sessionId)
    }
}

// MARK: - Equatable Conformance for EvaluationState
extension EvaluationViewModel.EvaluationState: Equatable {
    static func == (lhs: EvaluationViewModel.EvaluationState, rhs: EvaluationViewModel.EvaluationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.evaluating, .evaluating): return true
        case (.success(let a), .success(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
