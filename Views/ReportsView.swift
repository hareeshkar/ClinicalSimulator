import SwiftUI
import SwiftData
import UIKit // ✅ ADDED for haptics

// MARK: - ReportsView (Main Entry)

struct ReportsView: View {
    @Query private var allCases: [PatientCase]
    @Query(
        filter: #Predicate<StudentSession> { $0.isCompleted },
        sort: \.sessionId,
        order: .reverse
    )
    private var completedSessions: [StudentSession]

    // ✅ ADDED ENVIRONMENT OBJECT
    @EnvironmentObject private var navigationManager: NavigationManager

    private var completedCases: [PatientCase] {
        let ids = Set(completedSessions.map { $0.caseId })
        return allCases
            .filter { ids.contains($0.caseId) }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        // ✅ BIND THE NAVIGATION STACK TO THE MANAGER'S PATH
        NavigationStack(path: $navigationManager.reportsPath) {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if completedCases.isEmpty {
                    ContentUnavailableView(
                        "No Reports Yet",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Complete a simulation to see your performance reports here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(completedCases) { patientCase in
                                // ✅ The NavigationLink now uses .value to push the case onto the path
                                NavigationLink(value: patientCase) {
                                    if let session = mostRecentSession(for: patientCase.caseId) {
                                        CaseListItemView(
                                            patientCase: patientCase,
                                            session: session,
                                            action: .review
                                        )
                                    }
                                }
                                .buttonStyle(EnhancedCardButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("All Reports")
            // ✅ DEFINE THE DESTINATION FOR A PATIENTCASE
            .navigationDestination(for: PatientCase.self) { patientCase in
                CaseHistoryView(patientCase: patientCase)
            }
        }
    }

    private func mostRecentSession(for caseId: String) -> StudentSession? {
        completedSessions.first { $0.caseId == caseId }
    }
}

// MARK: - Case History View (Now with Sheet Logic)

struct CaseHistoryView: View {
    let patientCase: PatientCase

    @Query private var sessions: [StudentSession]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager // ✅ ADDED
    
    @State private var selectedSessionForReport: StudentSession?

    init(patientCase: PatientCase) {
        self.patientCase = patientCase

        let caseId = patientCase.caseId
        self._sessions = Query(
            filter: #Predicate<StudentSession> { session in
                session.caseId == caseId && session.isCompleted
            },
            sort: \.sessionId,
            order: .reverse
        )
    }

    // ✅ NEW: Computed property for average score across sessions
    private var averageScore: Double {
        let scores = sessions.compactMap { $0.score }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }
    
    // ✅ NEW: Best score for display
    private var bestScore: Double {
        sessions.compactMap { $0.score }.max() ?? 0
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    caseHeader
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: sessions.count) // ✅ ADDED: Animation for header
                    
                    ForEach(sessions) { session in
                        // ✅ RESTORED: Wrap row in a Button so tapping opens the report sheet directly
                        Button(action: {
                            selectedSessionForReport = session
                        }) {
                            AttemptRowView(session: session)
                        }
                        .buttonStyle(EnhancedCardButtonStyle())
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(patientCase.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSessionForReport) { session in
            let context = EvaluationNavigationContext(patientCase: patientCase, session: session)
            UnifiedReportView(
                context: context,
                modelContext: modelContext,
                onDismiss: { selectedSessionForReport = nil }
            )
        }
        // ✅ ADDED ONAPPEAR LOGIC
        .onAppear(perform: presentReportIfNeeded)
    }
    
    // ✅ NEW FUNCTION TO CHECK IF A REPORT SHOULD BE PRESENTED
    private func presentReportIfNeeded() {
        // Check if the manager has a requested report
        guard let context = navigationManager.requestedReportContext else { return }
        
        // Check if that report is for THIS specific case
        guard context.patientCase.caseId == self.patientCase.caseId else { return }
        
        // If so, present the sheet with the correct session
        self.selectedSessionForReport = context.session
        
        // CRITICAL: Clear the request in the manager so it doesn't happen again
        navigationManager.requestedReportContext = nil
    }

    @ViewBuilder
    private var caseHeader: some View {
        // ✅ IMPROVED: Use adaptive material background with specialty color tint for better light/dark mode visibility
        let specialtyColor = SpecialtyDetailsProvider.color(for: patientCase.specialty)
        let specialtyIcon = SpecialtyDetailsProvider.details(for: patientCase.specialty).iconName
        
        VStack(alignment: .leading, spacing: 16) { // ✅ INCREASED SPACING
            HStack(spacing: 16) {
                Image(systemName: specialtyIcon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(specialtyColor)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(patientCase.specialty)
                        .font(.headline)
                        .foregroundStyle(.primary) // adaptive
                    
                    Text(patientCase.chiefComplaint)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary) // adaptive
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                .regularMaterial, in: RoundedRectangle(cornerRadius: 20) // material for adaptability
            )
            .background(
                specialtyColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 20) // tint overlay
            )
            .cornerRadius(20)
            .shadow(color: specialtyColor.opacity(0.3), radius: 10, y: 5)
            
            // ✅ NEW: Average score progress bar + Best score badge
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Average Score: \(Int(averageScore))%")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Best: \(Int(bestScore))%")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }
                ProgressView(value: averageScore, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: specialtyColor))
                    .clipShape(Capsule())
                    .frame(height: 8)
            }
            .padding(.horizontal)
            
            Divider()
            
            if sessions.count == 0 {
                Text("No attempts yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You have \(sessions.count) completed attempt\(sessions.count == 1 ? "" : "s") for this case.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

}

// MARK: - Attempt Row View

struct AttemptRowView: View {
    let session: StudentSession

    private var scoreColor: Color {
        guard let score = session.score else { return .secondary }
        return score > 80 ? .green : score > 60 ? .orange : .red
    }

    private var completionDate: Date? {
        let lastActionDate = session.performedActions.map { $0.timestamp }.max()
        let lastMessageDate = session.messages.map { $0.timestamp }.max()
        return lastActionDate ?? lastMessageDate
    }
    
    // Simple formatted date string helper
    private var formattedCompletionDate: String {
        guard let date = completionDate else { return "Date Unavailable" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Text("\(Int(session.score ?? 0))")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(scoreColor)
                Text("SCORE")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)
            .padding(.vertical, 12)
            .background(scoreColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Attempt from")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(formattedCompletionDate)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(completionDate != nil ? .primary : .secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
