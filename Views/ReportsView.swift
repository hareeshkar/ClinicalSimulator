import SwiftUI
import SwiftData
import UIKit

// MARK: - 🧠 SORTING LOGIC (Unchanged Data Model)
enum SortOption: String, CaseIterable, Identifiable {
    case latestToOld = "Most Recent"
    case oldestToLatest = "Oldest First"
    case aToZ = "A-Z"
    case zToA = "Z-A"
    case highestScore = "Highest Score"
    case lowestScore = "Lowest Score"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .latestToOld, .oldestToLatest: return "calendar"
        case .aToZ, .zToA: return "textformat.abc"
        case .highestScore, .lowestScore: return "chart.bar"
        }
    }
}

// MARK: - 🏆 LIQUID GLASS REPORTS VIEW
struct ReportsView: View {
    @Query private var allCases: [PatientCase]
    @Query(filter: #Predicate<StudentSession> { $0.isCompleted })
    private var completedSessions: [StudentSession]

    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(User.self) private var currentUser
    @Environment(\.modelContext) private var modelContext
    
    @State private var sortOption: SortOption = .latestToOld
    @State private var scrollOffset: CGFloat = 0

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
            case .latestToOld: return completionDate(for: lhs.session) > completionDate(for: rhs.session)
            case .oldestToLatest: return completionDate(for: lhs.session) < completionDate(for: rhs.session)
            case .aToZ: return lhs.patientCase.title < rhs.patientCase.title
            case .zToA: return lhs.patientCase.title > rhs.patientCase.title
            case .highestScore: return (lhs.session.score ?? 0) > (rhs.session.score ?? 0)
            case .lowestScore: return (lhs.session.score ?? 0) < (rhs.session.score ?? 0)
            }
        }
    }
    
    private func completionDate(for session: StudentSession) -> Date {
        return session.messages.map { $0.timestamp }.max() ?? session.performedActions.map { $0.timestamp }.max() ?? .distantPast
    }

    // MARK: - BODY
    var body: some View {
        NavigationStack(path: $navigationManager.reportsPath) {
            ZStack {
                // Layer 0: Clinical Fluid Background
                ClinicalAmbientBackground(score: averageScore)
                    .ignoresSafeArea()
                
                // Layer 1: Scroll Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Scroll Offset Reader
                        GeometryReader { proxy in
                            Color.clear.preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)
                        
                        // Header Cluster
                        headerView
                            .opacity(1.0 - (max(0, -scrollOffset) / 150.0)) // Fade out on scroll
                            .blur(radius: max(0, -scrollOffset) / 20.0) // Blur on scroll
                            .scaleEffect(max(0.8, 1.0 - (max(0, -scrollOffset) / 500.0))) // Shrink slightly
                        
                        // Sort & Filter Bar (Sticky Logic)
                        glassSortBar
                            .zIndex(1)
                        
                        // Content List
                        if sortedCaseSessionPairs.isEmpty {
                            emptyStateView
                        } else {
                            reportsList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20) // Initial top padding
                    .padding(.bottom, 100) // Space for tab bar
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = value
                }
            }
            .navigationTitle("Clinical Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: PatientCase.self) { patientCase in
                CaseHistoryView(patientCase: patientCase)
            }
            // If a specific report context was requested (e.g., from Simulation end), present it immediately.
            .sheet(item: $navigationManager.requestedReportContext) { context in
                UnifiedReportView(
                    context: context,
                    modelContext: modelContext,
                    onDismiss: { navigationManager.requestedReportContext = nil }
                )
            }
        }
    }

    // MARK: - VIEW COMPONENTS
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 30) {
            // "Living" Average Score Ring
            ZStack {
                // Outer Glow
                Circle()
                    .fill(scoreColor(for: averageScore).opacity(0.2))
                    .frame(width: 180, height: 180)
                    .blur(radius: 35)
                
                // Physics-based Fluid Ring
                FluidScoreRing(score: averageScore, color: scoreColor(for: averageScore))
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 4) {
                    Text("\(averageScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(for: averageScore))
                        // Liquid Glass numeric transition
                        .contentTransition(.numericText(value: Double(averageScore)))
                    
                    Text("AVERAGE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }
            }
            
            VStack(spacing: 8) {
                Text("Performance Analytics")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("Review your diagnostic reasoning and clinical efficiency across \(userCompletedSessions.count) completed simulations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var glassSortBar: some View {
        HStack {
            Text("SESSION LOG")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            Spacer()
            
            Menu {
                ForEach(SortOption.allCases) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            sortOption = option
                        }
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                    Text(sortOption.rawValue)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var reportsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(sortedCaseSessionPairs, id: \.session.sessionId) { pair in
                NavigationLink(value: pair.patientCase) {
                    GlassReportCard(patientCase: pair.patientCase, session: pair.session)
                }
            }
        }
        // Animate reordering
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sortOption)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No Clinical Data")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Complete a simulation to generate performance analytics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    
    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return .teal
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }
}

// MARK: - 🧬 COMPONENT: GLASS REPORT CARD
struct GlassReportCard: View {
    let patientCase: PatientCase
    let session: StudentSession
    
    private var scoreColor: Color {
        // Check for failed/error states first
        if session.evaluationStatus == EvaluationStatus.failed.rawValue || 
           session.evaluationStatus == EvaluationStatus.retryNeeded.rawValue {
            return .red
        }
        
        guard let score = session.score else { return .gray }
        switch score {
        case 90...100: return .teal
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }
    
    private var specialtyColor: Color {
        SpecialtyDetailsProvider.color(for: patientCase.specialty)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Score Pill (Vertical Layout)
            VStack(spacing: 2) {
                if session.evaluationStatus == EvaluationStatus.failed.rawValue || 
                   session.evaluationStatus == EvaluationStatus.retryNeeded.rawValue {
                    // Failed state: show !
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(scoreColor)
                } else if session.score != nil {
                    // Completed: show score
                    Text("\(Int(session.score ?? 0))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                    
                    Text("%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(scoreColor.opacity(0.8))
                } else {
                    // Not started: show dash
                    Text("—")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 50, height: 50)
            .background(
                scoreColor.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(scoreColor.opacity(0.2), lineWidth: 1)
            )
            
            // Case Info
            VStack(alignment: .leading, spacing: 6) {
                Text(patientCase.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(patientCase.specialty, systemImage: SpecialtyDetailsProvider.details(for: patientCase.specialty).iconName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(specialtyColor)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(patientCase.difficulty.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(16)
        .background(.ultraThinMaterial) // Liquid Glass effect
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}

// MARK: - 🎨 COMPONENT: FLUID SCORE RING (Optimized)
struct FluidScoreRing: View {
    let score: Int
    let color: Color
    
    var body: some View {
        // Optimized: Use SwiftUI shapes instead of Canvas for better performance
        ZStack {
            // Track (Background Ring)
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 12)
                .padding(8)
            
            // Progress Ring with Gradient
            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(8)
        }
    }
}

// MARK: - 🏥 COMPONENT: CLINICAL AMBIENT BACKGROUND
struct ClinicalAmbientBackground: View {
    let score: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { proxy in
            let baseColor = Color(.systemGroupedBackground)
            let accentColor = scoreColor(for: score)
            
            ZStack {
                baseColor
                
                // Subtle medical gradient orb
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: proxy.size.width * 1.2)
                    .blur(radius: 100)
                    .offset(y: -proxy.size.height * 0.4)
                
                // Bottom ambient light
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: proxy.size.width)
                    .blur(radius: 80)
                    .offset(y: proxy.size.height * 0.4)
            }
        }
    }
    
    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return .teal
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }
}

// Preference Key for Scroll Tracking
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 🏛️ CASE HISTORY VIEW (Child View)
struct CaseHistoryView: View {
    let patientCase: PatientCase
    @Query private var sessions: [StudentSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(User.self) private var currentUser
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var selectedSessionForReport: StudentSession?

    init(patientCase: PatientCase) {
        self.patientCase = patientCase
        let caseId = patientCase.caseId
        self._sessions = Query(
            filter: #Predicate<StudentSession> { session in
                session.caseId == caseId && session.isCompleted
            },
            sort: \.sessionId, order: .reverse
        )
    }

    private var userSessions: [StudentSession] {
        sessions.filter { $0.user?.id == currentUser.id }
    }

    private var sortedSessions: [StudentSession] {
        userSessions.sorted { lhs, rhs in
            let lhsDate = lhs.performedActions.map { $0.timestamp }.max() ?? lhs.messages.map { $0.timestamp }.max() ?? .distantPast
            let rhsDate = rhs.performedActions.map { $0.timestamp }.max() ?? rhs.messages.map { $0.timestamp }.max() ?? .distantPast
            return lhsDate > rhsDate
        }
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    GlassCaseHeader(patientCase: patientCase, sessionCount: userSessions.count)
                    
                    // History Timeline
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ATTEMPT HISTORY")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        
                        ForEach(sortedSessions) { session in
                            Button(action: { selectedSessionForReport = session }) {
                                GlassAttemptRow(session: session)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(patientCase.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSessionForReport) { session in
            let context = EvaluationNavigationContext(patientCase: patientCase, session: session)
            UnifiedReportView(context: context, modelContext: modelContext, onDismiss: { selectedSessionForReport = nil })
        }
    }
}

// MARK: - 🎨 COMPONENT: GLASS CASE HEADER
struct GlassCaseHeader: View {
    let patientCase: PatientCase
    let sessionCount: Int
    
    private var specialtyColor: Color {
        SpecialtyDetailsProvider.color(for: patientCase.specialty)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(patientCase.specialty.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(specialtyColor)
                        .tracking(1)
                    
                    Text(patientCase.chiefComplaint)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                Spacer()
                
                Image(systemName: SpecialtyDetailsProvider.details(for: patientCase.specialty).iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(specialtyColor.opacity(0.3))
            }
            
            Divider().overlay(Color.primary.opacity(0.1))
            
            HStack {
                Label("\(sessionCount) Attempts", systemImage: "clock.arrow.circlepath")
                Spacer()
                Text(patientCase.difficulty)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - 🎨 COMPONENT: GLASS ATTEMPT ROW
struct GlassAttemptRow: View {
    let session: StudentSession
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var showErrorDetails = false
    
    private var scoreColor: Color {
        // Check for failed/error states first
        if session.evaluationStatus == EvaluationStatus.failed.rawValue || 
           session.evaluationStatus == EvaluationStatus.retryNeeded.rawValue {
            return .red
        }
        
        guard let score = session.score else { return .secondary }
        return score > 80 ? .green : score > 60 ? .orange : .red
    }
    
    private var formattedDate: String {
        let date = session.performedActions.map { $0.timestamp }.max() ?? session.messages.map { $0.timestamp }.max() ?? Date()
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    
    private var hasError: Bool {
        session.evaluationStatus == EvaluationStatus.failed.rawValue || 
        session.evaluationStatus == EvaluationStatus.retryNeeded.rawValue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let score = session.score {
                    // Show score whenever it exists, regardless of evaluation status
                    Text("\(Int(score))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                } else if session.evaluationStatus == EvaluationStatus.completed.rawValue {
                    // Completed evaluation but score is nil - show 0
                    Text("0")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if navigationManager.evaluatingSessionIDs.contains(session.sessionId) {
                    // Session is currently being evaluated — show loader
                    ProgressView()
                        .frame(width: 22, height: 22)
                } else if hasError {
                    // Failed evaluation — show ! icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                        
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .frame(width: 32, height: 32)
                } else {
                    // No score yet (not evaluated)
                    Text("—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Completed Simulation")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                // Show error message if available
                if hasError, let errorMsg = session.evaluationErrorMessage, !errorMsg.isEmpty {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Show retry badge if needed
            if session.evaluationStatus == EvaluationStatus.retryNeeded.rawValue {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.small")
                        .font(.caption2.weight(.semibold))
                    Text("Retry")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            } else if hasError {
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .help(hasError && session.evaluationErrorMessage != nil ? session.evaluationErrorMessage! : "")
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [PatientCase.self, StudentSession.self, User.self], inMemory: true)
        .environmentObject(NavigationManager())
}
