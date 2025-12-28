import SwiftUI

// This is an ObservableObject, so SwiftUI views can subscribe to its changes.
@MainActor
class NavigationManager: ObservableObject {
    
    // This will hold the currently selected tab.
    @Published var selectedTab: Tab = .dashboard

    // ✅ NEW: A dedicated navigation path for the Reports tab.
    @Published var reportsPath = NavigationPath()
    
    // ✅ RENAMED: This now holds the specific report context we want to show.
    @Published var requestedReportContext: EvaluationNavigationContext? = nil
    // Track sessions currently being evaluated (in-memory only)
    @Published var evaluatingSessionIDs: Set<UUID> = []
    // ✅ NEW: Track sessions with failed evaluations (in-memory only)
    @Published var failedEvaluationSessionIDs: Set<UUID> = []

    // An enum to define our tabs, making the code safer and easier to read.
    enum Tab {
        case dashboard, cases, reports, profile
    }
    
    /// This is the function our SimulationView will call.
    func requestReport(for context: EvaluationNavigationContext) {
        // 1. Set the specific report we want to view.
        self.requestedReportContext = context
        // Mark evaluation as in-progress for UI
        self.evaluatingSessionIDs.insert(context.session.sessionId)
        // Clear from failed set if it exists
        self.failedEvaluationSessionIDs.remove(context.session.sessionId)
        
        // 2. Clear any previous navigation path and add the new case to it.
        //    This will cause the NavigationStack in ReportsView to navigate to CaseHistoryView.
        self.reportsPath = NavigationPath()
        self.reportsPath.append(context.patientCase)
        
        // 3. Immediately switch the user to the 'Reports' tab.
        self.selectedTab = .reports
    }

    func finishEvaluation(sessionId: UUID) {
        evaluatingSessionIDs.remove(sessionId)
        // also clear requested context if it matches
        if requestedReportContext?.session.sessionId == sessionId {
            requestedReportContext = nil
        }
    }
    
    func markEvaluationFailed(sessionId: UUID) {
        evaluatingSessionIDs.remove(sessionId)
        failedEvaluationSessionIDs.insert(sessionId)
    }
    
    func clearEvaluationFailure(sessionId: UUID) {
        failedEvaluationSessionIDs.remove(sessionId)
    }

    func startEvaluation(sessionId: UUID) {
        evaluatingSessionIDs.insert(sessionId)
        // Clear from failed set when retrying
        failedEvaluationSessionIDs.remove(sessionId)
    }
}
