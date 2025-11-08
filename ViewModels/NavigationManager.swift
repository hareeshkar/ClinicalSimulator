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

    // An enum to define our tabs, making the code safer and easier to read.
    enum Tab {
        case dashboard, cases, reports, profile
    }
    
    /// This is the function our SimulationView will call.
    func requestReport(for context: EvaluationNavigationContext) {
        // 1. Set the specific report we want to view.
        self.requestedReportContext = context
        
        // 2. Clear any previous navigation path and add the new case to it.
        //    This will cause the NavigationStack in ReportsView to navigate to CaseHistoryView.
        self.reportsPath = NavigationPath()
        self.reportsPath.append(context.patientCase)
        
        // 3. Immediately switch the user to the 'Reports' tab.
        self.selectedTab = .reports
    }
}
