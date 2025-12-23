import SwiftUI
import SwiftData
import UIKit

// MARK: - Sort Options Enum (Unchanged)
enum SortOption: String, CaseIterable, Identifiable {
    case latestToOld = "Most Recent" // Renamed for clarity
    case oldestToLatest = "Oldest First" // Renamed for clarity
    case aToZ = "A-Z"
    case zToA = "Z-A"
    case highestScore = "Highest Score"
    case lowestScore = "Lowest Score"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .latestToOld, .oldestToLatest:
            return "calendar"
        case .aToZ, .zToA:
            return "textformat.abc"
        case .highestScore, .lowestScore:
            return "chart.bar"
        }
    }
}

// MARK: - ReportsView (Completely Redesigned)
struct ReportsView: View {
    @Query private var allCases: [PatientCase]
    @Query(filter: #Predicate<StudentSession> { $0.isCompleted })
    private var completedSessions: [StudentSession]

    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(User.self) private var currentUser
    
    @State private var sortOption: SortOption = .latestToOld

    // MARK: - Computed Properties
    private var userCompletedSessions: [StudentSession] {
        completedSessions.filter { $0.user?.id == currentUser.id }
    }
    
    private var averageScore: Int {
        let scores = userCompletedSessions.compactMap { $0.score }
        guard !scores.isEmpty else { return 0 }
        return Int((scores.reduce(0, +) / Double(scores.count)).rounded())
    }

    private var sortedCaseSessionPairs: [(patientCase: PatientCase, session: StudentSession)] {
        let caseSessionMap = Dictionary(uniqueKeysWithValues: allCases.map { ($0.caseId, $0) })
        
        return userCompletedSessions.compactMap { session -> (PatientCase, StudentSession)? in
            guard let patientCase = caseSessionMap[session.caseId] else { return nil }
            return (patientCase, session)
        }.sorted { lhs, rhs in
            switch sortOption {
            case .latestToOld:
                return completionDate(for: lhs.session) > completionDate(for: rhs.session)
            case .oldestToLatest:
                return completionDate(for: lhs.session) < completionDate(for: rhs.session)
            case .aToZ:
                return lhs.patientCase.title < rhs.patientCase.title
            case .zToA:
                return lhs.patientCase.title > rhs.patientCase.title
            case .highestScore:
                return (lhs.session.score ?? 0) > (rhs.session.score ?? 0)
            case .lowestScore:
                return (lhs.session.score ?? 0) < (rhs.session.score ?? 0)
            }
        }
    }
    
    private func completionDate(for session: StudentSession) -> Date {
        return session.messages.map { $0.timestamp }.max() ?? session.performedActions.map { $0.timestamp }.max() ?? .distantPast
    }

    // MARK: - Main Body
    var body: some View {
        NavigationStack(path: $navigationManager.reportsPath) {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    
                    if sortedCaseSessionPairs.isEmpty {
                        ContentUnavailableView(
                            "No Reports Yet",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Complete a simulation to see your performance reports here.")
                        )
                        .padding(.top, 50)
                    } else {
                        reportsList
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Performance Reports")
            .navigationBarHidden(true) // Hide the default bar to use our custom header
            .navigationDestination(for: PatientCase.self) { patientCase in
                CaseHistoryView(patientCase: patientCase)
            }
        }
    }

    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Performance Reports")
                .font(.largeTitle.bold())
                .padding(.top, 57)  // Updated to add 5x pt top padding to push down

            Text("Review detailed analytics from your completed simulations to track your progress and identify areas for improvement.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                AverageScoreCardView(score: averageScore)
                
                Spacer() // Add spacer to push the menu to the right
                
                Menu {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            sortOption = option
                        } label: {
                            Label(option.rawValue, systemImage: sortOption == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOption.rawValue)
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                }
            }
            .frame(height: 120)
        }
    }
    
    @ViewBuilder
    private var reportsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(sortedCaseSessionPairs, id: \.session.sessionId) { pair in
                NavigationLink(value: pair.patientCase) {
                    CaseListItemView(
                        patientCase: pair.patientCase,
                        session: pair.session,
                        action: .review
                    )
                }
                .buttonStyle(EnhancedCardButtonStyle())
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sortOption)
    }

    private func mostRecentSession(for caseId: String) -> StudentSession? {
        userCompletedSessions.first { $0.caseId == caseId }
    }
}

// MARK: - Average Score Card View
struct AverageScoreCardView: View {
    let score: Int
    @State private var animatedProgress: Double = 0
    
    private var scoreColor: Color {
        score > 80 ? .green : score > 60 ? .orange : .red
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.15), lineWidth: 8)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack {
                Text("\(score)")
                    .font(.title.bold().monospacedDigit())
                Text("AVG")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(Circle())
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = Double(score) / 100.0
            }
        }
    }
}


// MARK: - Case History View (Unchanged but included for context)
struct CaseHistoryView: View {
    let patientCase: PatientCase

    @Query private var sessions: [StudentSession]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager // ✅ ADDED
    // ✅ ADD ENVIRONMENT USER
    @Environment(User.self) private var currentUser

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

    // ✅ ADD A FILTERED COMPUTED PROPERTY
    private var userSessions: [StudentSession] {
        sessions.filter { $0.user?.id == currentUser.id }
    }

    // ✅ UPDATE OTHER COMPUTED PROPERTIES TO USE THE FILTERED LIST
    private var averageScore: Double {
        let scores = userSessions.compactMap { $0.score }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }
    
    // ✅ NEW: Best score for display
    private var bestScore: Double {
        userSessions.compactMap { $0.score }.max() ?? 0
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    caseHeader
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: sessions.count) // ✅ ADDED: Animation for header
                    
                    ForEach(userSessions) { session in // ✅ USE THE FILTERED LIST
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
            
            if userSessions.count == 0 { // ✅ USE FILTERED COUNT
                Text("No attempts yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You have \(userSessions.count) completed attempt\(userSessions.count == 1 ? "" : "s") for this case.") // ✅ USE FILTERED COUNT
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
