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
    
    // ✅ ADD: Progress sync service for cloud synchronization
    private let progressService: UserProgressService
    
    // ✅ NOTIFICATION: Observer for cloud updates
    private var notificationObserver: NSObjectProtocol?
    
    // MARK: - Main Initializer (Used by app)
    init(patientCase: PatientCase, session: StudentSession, modelContext: ModelContext, userRole: String) {
        self.patientCase = patientCase
        self.session = session
        self.modelContext = modelContext
        self.userRole = userRole
        
        // ✅ INITIALIZE: Progress service with model container
        self.progressService = UserProgressService(modelContainer: modelContext.container)
        
        // ✅ UPDATE TO DECODE THE NEW STRUCT
        if let evalJSON = session.evaluationJSON, let data = evalJSON.data(using: .utf8),
           let savedResult = try? JSONDecoder().decode(ProfessionalEvaluationResult.self, from: data) {
            state = .success(savedResult)
        } else {
            state = .idle
        }
        
        // ✅ NOTIFY: Listen for session updates from cloud
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .sessionUpdatedFromCloud,
            object: session.sessionId,
            queue: .main
        ) { [weak self] _ in
            self?.reloadState()
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // ✅ RELOAD: Update state from session after cloud update
    private func reloadState() {
        if let evalJSON = session.evaluationJSON, let data = evalJSON.data(using: .utf8),
           let savedResult = try? JSONDecoder().decode(ProfessionalEvaluationResult.self, from: data) {
            state = .success(savedResult)
        } else {
            state = .idle
        }
    }

    // MARK: - Preview / Testing Initializer
    init(patientCase: PatientCase, session: StudentSession, modelContext: ModelContext, initialState: EvaluationState, userRole: String) {
        self.patientCase = patientCase
        self.session = session
        self.modelContext = modelContext
        self.userRole = userRole
        
        // ✅ INITIALIZE: Progress service (even in preview mode)
        self.progressService = UserProgressService(modelContainer: modelContext.container)
        
        self.state = initialState
        
        // ✅ NOTIFY: Listen for session updates from cloud (even in preview)
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .sessionUpdatedFromCloud,
            object: session.sessionId,
            queue: .main
        ) { [weak self] _ in
            self?.reloadState()
        }
    }
    
    // MARK: - Main Evaluation Function
    func evaluatePerformance() async {
        guard case .idle = state else { return }
        state = .evaluating
        session.evaluationStatus = EvaluationStatus.evaluating.rawValue
        session.evaluationAttempts += 1
        
        let data = Data(patientCase.fullCaseJSON.utf8)
        guard let caseDetail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) else {
            let errorMsg = "Failed to parse the case file for evaluation."
            state = .error(errorMsg)
            session.evaluationStatus = EvaluationStatus.failed.rawValue
            session.evaluationErrorMessage = errorMsg
            try? modelContext.save()
            return
        }
        
        do {
            // ✅ UPDATED: Pass native language for native-language feedback
            let result = try await geminiService.generateEvaluation(
                caseDetail: caseDetail,
                session: session,
                userRole: userRole,
                nativeLanguage: session.user?.nativeLanguage ?? .english  // ✅ PASS LANGUAGE
            )
            
            // ✅ SAVES THE NEW RESULT
            session.score = Double(result.overallScore)
            if let resultData = try? JSONEncoder().encode(result) {
                session.evaluationJSON = String(data: resultData, encoding: .utf8)
            }
            session.evaluationStatus = EvaluationStatus.completed.rawValue
            session.evaluationErrorMessage = nil
            session.isCompleted = true  // ✅ Mark session as completed
            try? modelContext.save()
            
            // ✅ SYNC TO CLOUD: Upload completed session with evaluation
            let sessionToSync = self.session
            Task.detached(priority: .userInitiated) {
                await self.progressService.uploadSession(sessionToSync)
                print("✅ Evaluation synced to cloud: Score \(result.overallScore)")
            }
            
            state = .success(result)
        } catch {
            print("Evaluation error: \(error.localizedDescription)")
            
            // ✅ ENHANCED: Better error classification
            let (errorMessage, isRetryable) = classifyError(error)
            
            session.evaluationStatus = isRetryable ? EvaluationStatus.retryNeeded.rawValue : EvaluationStatus.failed.rawValue
            session.evaluationErrorMessage = errorMessage
            try? modelContext.save()
            
            state = .error(errorMessage)
        }
    }
    
    // ✅ NEW: Classify errors for better UX
    private func classifyError(_ error: Error) -> (message: String, isRetryable: Bool) {
        let nsError = error as NSError
        
        // Network errors (retryable)
        if nsError.domain == NSURLErrorDomain {
            let retryableNetworkErrors = [
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorServerCertificateUntrusted,
                NSURLErrorServerCertificateHasUnknownRoot
            ]
            
            if retryableNetworkErrors.contains(nsError.code) {
                return ("Network connection issue. Please check your internet and try again.", true)
            }
        }
        
        // Timeout errors (retryable)
        if nsError.code == NSURLErrorTimedOut || nsError.localizedDescription.lowercased().contains("timeout") {
            return ("Request timed out. Please try again.", true)
        }
        
        // API rate limiting or temporary errors (retryable)
        if nsError.code == 429 || nsError.localizedDescription.lowercased().contains("rate limit") {
            return ("API rate limited. Please wait a moment and try again.", true)
        }
        
        // Server errors 5xx (retryable)
        if nsError.localizedDescription.lowercased().contains("500") || 
           nsError.localizedDescription.lowercased().contains("502") ||
           nsError.localizedDescription.lowercased().contains("503") {
            return ("Server temporarily unavailable. Please try again.", true)
        }
        
        // Gemini API specific errors
        if nsError.domain == "GeminiService" {
            let desc = nsError.localizedDescription.lowercased()
            if desc.contains("no text") || desc.contains("malformed") {
                return ("AI service returned invalid response. Please try again.", true)
            }
            if desc.contains("authentication") || desc.contains("unauthorized") {
                return ("Authentication error. Please contact support.", false)
            }
            if desc.contains("quota") {
                return ("API quota exceeded. Please try again later.", true)
            }
        }
        
        // JSON decode errors (might be temporary)
        if error is DecodingError {
            return ("Failed to process response. Please try again.", true)
        }
        
        // Generic fallback
        let fallbackMessage = "An error occurred while evaluating your performance. Please try again."
        return (fallbackMessage, true)
    }
    
    // ✅ NEW: Retry evaluation after failure
    func retryEvaluation() async {
        // Reset to idle to allow evaluation to run again
        if case .error = state {
            state = .idle
            await evaluatePerformance()
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
