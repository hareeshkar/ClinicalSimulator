// Views/EvaluationView.swift

import SwiftUI
import SwiftData
import CoreHaptics

// MARK: - 🏥 CLINICAL DESIGN SYSTEM
private enum ClinicalTheme {
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let accent = Color.blue
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let critical = Color(red: 1.0, green: 0.23, blue: 0.19)
    static func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return success
        case 75..<90: return accent
        case 60..<75: return Color(red: 1.0, green: 0.58, blue: 0.0)
        default: return critical
        }
    }
}

// MARK: - 📐 HELPER EXTENSIONS
extension View {
    func clinicalCard(color: Color = ClinicalTheme.accent) -> some View {
        self
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - 🗂️ UNIFIED REPORT CONTAINER
struct UnifiedReportView: View {
    enum ReportTab: String, CaseIterable, Identifiable {
        case evaluation = "Performance"
        case debrief = "Clinical Debrief"
        var id: String { rawValue }
    }

    @StateObject private var viewModel: EvaluationViewModel
    @State private var selectedTab: ReportTab = .evaluation
    let onDismiss: () -> Void
    @EnvironmentObject private var navigationManager: NavigationManager
    private let sessionId: UUID

    init(context: EvaluationNavigationContext, modelContext: ModelContext, onDismiss: @escaping () -> Void) {
        let role = UserDefaults.standard.string(forKey: "userRoleTitle") ?? "Medical Student"
        _viewModel = StateObject(wrappedValue: EvaluationViewModel(
            patientCase: context.patientCase,
            session: context.session,
            modelContext: modelContext,
            userRole: role
        ))
        self.onDismiss = onDismiss
        self.sessionId = context.session.sessionId
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ClinicalTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ClinicalTabSwitcher(selectedTab: $selectedTab)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    contentForState
                }
            }
            .navigationTitle("Session Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { onDismiss() }
                        .fontWeight(.medium)
                        .foregroundStyle(ClinicalTheme.accent)
                }
            }
            .onAppear {
                if case .idle = viewModel.state {
                    // mark evaluation started and run
                    navigationManager.startEvaluation(sessionId: sessionId)
                    Task { await viewModel.evaluatePerformance() }
                }
            }
            .onChange(of: viewModel.state) { newState in
                switch newState {
                case .success:
                    navigationManager.finishEvaluation(sessionId: sessionId)
                case .error:
                    navigationManager.markEvaluationFailed(sessionId: sessionId)
                default:
                    break
                }
            }
        }
    }
    
    @ViewBuilder private var contentForState: some View {
        switch viewModel.state {
        case .idle, .evaluating:
            ClinicalLoadingView()
        case .success(let result):
            TabView(selection: $selectedTab) {
                EvaluationContentView(result: result)
                    .tag(ReportTab.evaluation)
                DebriefView(debrief: result.debrief)
                    .tag(ReportTab.debrief)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        case .error(let message):
            ClinicalErrorView(
                message: message,
                onRetry: {
                    Task { await viewModel.retryEvaluation() }
                }
            )
        }
    }
}

// MARK: - 📊 EVALUATION CONTENT
struct EvaluationContentView: View {
    let result: ProfessionalEvaluationResult
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroSection
                narrativeSection
                competencyMatrix
                clinicalAnalysis
                observationsSections
                Spacer().frame(height: 40)
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            isVisible = true
        }
    }
    
    private var heroSection: some View {
        HStack(alignment: .top, spacing: 20) {
            ClinicalScoreGauge(score: result.overallScore, isVisible: isVisible)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Clinical Summary")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(ClinicalTheme.accent)
                    .fontWeight(.bold)
                
                Text(result.caseNarrative)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(4)
                    .foregroundStyle(ClinicalTheme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isVisible)
    }
    
    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Case Overview")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(ClinicalTheme.textSecondary)
                .fontWeight(.bold)
            
            Text(result.caseNarrative)
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
                .foregroundStyle(ClinicalTheme.textPrimary)
        }
        .clinicalCard()
        .padding(.horizontal)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isVisible)
    }
    
    private var competencyMatrix: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Competency Matrix")
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(result.competencyScores.sorted(by: { $0.key < $1.key }).enumerated()), id: \.element.key) { index, item in
                    CompetencyMetricCard(title: item.key, score: Int(item.value))
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.08), value: isVisible)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var clinicalAnalysis: some View {
        VStack(alignment: .leading, spacing: 20) {
            EditorialCard(
                title: "Reasoning & Differential Analysis",
                content: result.differentialAnalysis,
                icon: "brain.head.profile",
                accentColor: .indigo
            )
            
            if let insight = result.calibrationAnalysis, !insight.isEmpty {
                EditorialCard(
                    title: "Judgment & Self-Awareness",
                    content: insight,
                    icon: "eye.fill",
                    accentColor: .blue
                )
            }
        }
        
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: isVisible)
    }
    
    private var observationsSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            ObservationSection(
                title: "Clinical Strengths",
                items: result.keyStrengths,
                icon: "checkmark.seal.fill",
                color: .teal
            )
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: isVisible)
            
            ObservationSection(
                title: "Areas for Refinement",
                items: result.criticalFeedback,
                icon: "exclamationmark.circle.fill",
                color: .orange
            )
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: isVisible)
        }
        .padding(.horizontal)
    }
}

// MARK: - 🎨 COMPONENTS

struct ClinicalTabSwitcher: View {
    @Binding var selectedTab: UnifiedReportView.ReportTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(UnifiedReportView.ReportTab.allCases) { tab in
                let isSelected = selectedTab == tab
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? ClinicalTheme.textPrimary : ClinicalTheme.textSecondary)
                        
                        Rectangle()
                            .fill(isSelected ? ClinicalTheme.accent : Color.clear)
                            .frame(height: 2)
                            .frame(maxWidth: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

struct ClinicalScoreGauge: View {
    let score: Int
    let isVisible: Bool
    
    @State private var animatedScore: Double = 0
    @State private var hapticTriggered = false
    
    var body: some View {
        ZStack {
            // Track (background ring)
            Circle()
                .stroke(Color.secondary.opacity(0.1), lineWidth: 12)
            
            // Liquid Progress Ring with Gradient
            Circle()
                .trim(from: 0, to: isVisible ? Double(score) / 100.0 : 0)
                .stroke(
                    AngularGradient(
                        colors: [
                            scoreColor.opacity(0.7),
                            scoreColor
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * (Double(score) / 100))
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.interpolatingSpring(stiffness: 50, damping: 10).delay(0.15), value: isVisible)
            
            // Score Text with Numeric Transition
            VStack(spacing: -4) {
                Text("\(Int(animatedScore))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundStyle(scoreColor)
                
                Text("%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ClinicalTheme.textSecondary)
                    .tracking(0.5)
            }
        }
        .frame(width: 110, height: 110)
        .onAppear {
            if isVisible {
                triggerScoreAnimation()
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                triggerScoreAnimation()
            }
        }
    }
    
    private var scoreColor: Color {
        ClinicalTheme.scoreColor(for: score)
    }
    
    private func triggerScoreAnimation() {
        withAnimation(.easeOut(duration: 1.5)) {
            animatedScore = Double(score)
        }
        
        // Trigger haptic feedback with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !hapticTriggered {
                hapticTriggered = true
                triggerHapticFeedback()
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct CompetencyMetricCard: View {
    let title: String
    let score: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ClinicalTheme.textSecondary)
                .lineLimit(1)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("/ 100")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.05))
                    Capsule()
                        .fill(ClinicalTheme.scoreColor(for: score))
                        .frame(width: geo.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(ClinicalTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

struct EditorialCard: View {
    let title: String
    let content: String
    let icon: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.system(.headline, design: .rounded))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
            }
            
            Text(content)
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
                .foregroundStyle(ClinicalTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clinicalCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct ObservationSection: View {
    let title: String
    let items: [String]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            
            if items.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(color.opacity(0.6))
            Text("No \(title.lowercased()) recorded")
                .font(.subheadline)
                .foregroundStyle(ClinicalTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .multilineTextAlignment(.center)
        .clinicalCard(color: color)
    }
    
    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(color.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(item)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(ClinicalTheme.textPrimary)
                        .lineSpacing(2)
                }
            }
        }
        .clinicalCard(color: color)
    }
}

// MARK: - 💤 STATE VIEWS

struct ClinicalLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ClinicalTheme.accent)
                .scaleEffect(1.5)
            Text("Synthesizing Clinical Data...")
                .font(.system(.subheadline))
                .foregroundStyle(ClinicalTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClinicalErrorView: View {
    let message: String
    let onRetry: () -> Void
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon with animation
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                        .scaleEffect(isRetrying ? 1.05 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isRetrying)
                }
                
                Text("Analysis Interrupted")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            
            // Error message
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)
            }
            
            // Try Again button
            Button(action: {
                isRetrying = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                Task {
                    onRetry()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isRetrying = false
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(.body, design: .rounded))
                    }
                    Text("Try Again")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.blue.opacity(0.4), radius: 8, y: 4)
            }
            .disabled(isRetrying)
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - 🔄 LEGACY COMPATIBILITY
struct EvaluationView: View {
    @StateObject var viewModel: EvaluationViewModel
    @State private var isNavigatingToDebrief = false
    let onFinish: () -> Void

    init(context: EvaluationNavigationContext, modelContext: ModelContext, onFinish: @escaping () -> Void) {
        let role = UserDefaults.standard.string(forKey: "userRoleTitle") ?? "Medical Student"
        _viewModel = StateObject(wrappedValue: EvaluationViewModel(
            patientCase: context.patientCase,
            session: context.session,
            modelContext: modelContext,
            userRole: role
        ))
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ClinicalTheme.background.ignoresSafeArea()
                
                contentForState
            }
            .navigationTitle("Performance Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isNavigatingToDebrief) {
                if case .success(let result) = viewModel.state {
                    DebriefView(debrief: result.debrief)
                        .navigationTitle("Debrief")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Complete Session", action: onFinish)
                                    .fontWeight(.bold)
                            }
                        }
                }
            }
            .onAppear {
                if case .idle = viewModel.state {
                    Task { await viewModel.evaluatePerformance() }
                }
            }
        }
    }
    
    @ViewBuilder private var contentForState: some View {
        switch viewModel.state {
        case .idle, .evaluating:
            ClinicalLoadingView()
        case .success(let result):
            ScrollView {
                VStack(spacing: 32) {
                    EvaluationContentView(result: result)
                    Button {
                        isNavigatingToDebrief = true
                    } label: {
                        Text("Proceed to Clinical Debrief")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ClinicalTheme.accent)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        case .error(let message):
            ClinicalErrorView(
                message: message,
                onRetry: {
                    Task { await viewModel.retryEvaluation() }
                }
            )
        }
    }
}

// MARK: - 🖼️ PREVIEWS
#Preview("Clinical Report") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StudentSession.self, PatientCase.self, User.self, configurations: config)
    let mockUser = User(fullName: "Dr. Smith", email: "smith@med.edu", password: "123")
    let mockCase = PatientCase(caseId: "c1", title: "Acute Dyspnea", specialty: "Emergency", difficulty: "Hard", chiefComplaint: "Shortness of breath", fullCaseJSON: "{}")
    let mockSession = StudentSession(caseId: "c1", user: mockUser)
    
    return UnifiedReportView(
        context: EvaluationNavigationContext(patientCase: mockCase, session: mockSession),
        modelContext: container.mainContext,
        onDismiss: {}
    )
}

