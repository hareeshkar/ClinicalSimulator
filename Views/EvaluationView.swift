// Views/EvaluationView.swift

import SwiftUI
import SwiftData

// MARK: - UnifiedReportView (Tabbed Container for Report Review)

/// A tabbed container view that presents both the detailed evaluation and the debrief
/// for a completed simulation session.
struct UnifiedReportView: View {
    private enum ReportTab { case evaluation, debrief }

    @StateObject private var viewModel: EvaluationViewModel
    @State private var selectedTab: ReportTab = .evaluation
    let onDismiss: () -> Void

    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title

    init(context: EvaluationNavigationContext, modelContext: ModelContext, onDismiss: @escaping () -> Void) {
        // ✅ Pass userRole to the ViewModel
        let role = UserDefaults.standard.string(forKey: "userRoleTitle") ?? "Medical Student (MS3)"
        _viewModel = StateObject(wrappedValue: EvaluationViewModel(
            patientCase: context.patientCase,
            session: context.session,
            modelContext: modelContext,
            userRole: role
        ))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView { // Use NavigationView for the tabbed interface
            VStack(spacing: 0) {
                Picker("Report Section", selection: $selectedTab) {
                    Text("Evaluation").tag(ReportTab.evaluation)
                    Text("Debrief").tag(ReportTab.debrief)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)
                .background(Color(.systemGray6))

                switch viewModel.state {
                case .idle, .evaluating:
                    ProgressView("Loading Report...")
                        .frame(maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground)) // Ensure background for loading state
                
                case .success(let result):
                    // Use a TabView to switch between Evaluation and Debrief content
                    TabView(selection: $selectedTab) {
                        EvaluationContentView(result: result)
                            .tag(ReportTab.evaluation)
                        
                        DebriefView(debrief: result.debrief)
                            .tag(ReportTab.debrief)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never)) // Hide page dots
                    .background(Color(.systemGroupedBackground)) // Background for tab content

                case .error(let message):
                    ContentUnavailableView("Report Error", systemImage: "xmark.octagon.fill", description: Text(message))
                        .background(Color(.systemGroupedBackground)) // Background for error state
                }
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if case .idle = viewModel.state {
                    Task { await viewModel.evaluatePerformance() }
                }
            }
        }
    }
}

// MARK: - EvaluationContentView (Reusable Content for the Evaluation Tab)

/// Displays the core evaluation metrics and feedback.
struct EvaluationContentView: View {
    let result: ProfessionalEvaluationResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OverallScoreView(score: result.overallScore)
                ReportSectionView(title: "Case Narrative", icon: "book.text") { Text(result.caseNarrative) }
                ReportSectionView(title: "Competency Scores", icon: "chart.pie") {
                    ForEach(result.competencyScores.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        // CompetencyScoreRow expects Int, but value is Double. Cast needed.
                        CompetencyScoreRow(competency: key, score: Int(value))
                    }
                }
                ReportSectionView(title: "Differential Diagnosis Analysis", icon: "brain.head.profile") { Text(result.differentialAnalysis) }
                if let text = result.calibrationAnalysis, !text.isEmpty {
                    ReportSectionView(title: "Judgment & Self-Awareness", icon: "person.fill.questionmark") { Text(text) }
                }
                FeedbackListView(title: "Key Strengths", icon: "star.fill", color: .green, items: result.keyStrengths)
                FeedbackListView(title: "Critical Feedback", icon: "exclamationmark.triangle.fill", color: .orange, items: result.criticalFeedback)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - EvaluationView (The Original View, now for Post-Simulation Flow)

/// The initial view presented after a simulation, which evaluates performance
/// and then transitions to the full debrief.
struct EvaluationView: View {
    @StateObject var viewModel: EvaluationViewModel
    @State private var isNavigatingToDebrief = false
    let onFinish: () -> Void

    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title

    init(context: EvaluationNavigationContext, modelContext: ModelContext, onFinish: @escaping () -> Void) {
        // ✅ Pass userRole to the ViewModel
        let role = UserDefaults.standard.string(forKey: "userRoleTitle") ?? "Medical Student (MS3)"
        _viewModel = StateObject(wrappedValue: EvaluationViewModel(
            patientCase: context.patientCase,
            session: context.session,
            modelContext: modelContext,
            userRole: role
        ))
        self.onFinish = onFinish
    }
    
    // Preview-specific initializer for easier testing
    init(context: EvaluationNavigationContext, modelContext: ModelContext, onFinish: @escaping () -> Void, initialState: EvaluationViewModel.EvaluationState) {
        let role = UserDefaults.standard.string(forKey: "userRoleTitle") ?? "Medical Student (MS3)"
        _viewModel = StateObject(wrappedValue: EvaluationViewModel(
            patientCase: context.patientCase,
            session: context.session,
            modelContext: modelContext,
            initialState: initialState,
            userRole: role
        ))
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Evaluation Report")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    // Only show "Continue to Debrief" button if evaluation is successful
                    if case .success = viewModel.state {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Continue to Debrief") {
                                isNavigatingToDebrief = true
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                // Navigation destination for the DebriefView
                .navigationDestination(isPresented: $isNavigatingToDebrief) {
                    if case .success(let result) = viewModel.state {
                        DebriefView(debrief: result.debrief)
                            .navigationTitle("Debrief")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Finish Simulation", action: onFinish)
                                        .fontWeight(.semibold)
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

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .idle, .evaluating:
            ProgressView("Analyzing Performance...")
                .frame(maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        case .success(let result):
            // Display the evaluation content directly
            EvaluationContentView(result: result)
        case .error(let message):
            ContentUnavailableView("Evaluation Failed", systemImage: "xmark.octagon.fill", description: Text(message))
                .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Helper Views for Professional Report

// NOTE: These helper views (OverallScoreView, ReportSectionView, etc.) are crucial
// and should be kept in this file as they are used by EvaluationContentView.

struct OverallScoreView: View {
    let score: Int
    var body: some View {
        VStack {
            Text("Overall Score")
                .font(.headline).foregroundStyle(.secondary)
            Text("\(score)%")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(score > 80 ? .green : (score > 60 ? .orange : .red))
        }
        .frame(maxWidth: .infinity).padding(.vertical)
    }
}

struct ReportSectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title2.bold())
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.background)
                .cornerRadius(12)
        }
    }
}

struct CompetencyScoreRow: View {
    let competency: String
    let score: Int // This expects Int
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(competency)
                Spacer()
                Text("\(score)%").fontWeight(.semibold)
            }
            ProgressView(value: Double(score), total: 100)
                .tint(score > 80 ? .green : (score > 60 ? .orange : .red))
        }
    }
}

struct FeedbackListView: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title2.bold()).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(color)
                            .padding(.top, 6)
                        Text(item).font(.subheadline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background)
            .cornerRadius(12)
        }
    }
}





// MARK: - Xcode Previews

#Preview("Tabbed Report") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StudentSession.self, PatientCase.self, configurations: config)
    let mockSession = StudentSession(caseId: "mock")
    let mockCase = PatientCase(caseId: "mock", title: "Mock Case", specialty: "Mock Specialty", difficulty: "Advanced", chiefComplaint: "Mock complaint", fullCaseJSON: "{}")
    
    // IMPORTANT: To make the preview work, we have to pre-populate the evaluationJSON
    // on the mock session so the view has data to display immediately.
    if let data = try? JSONEncoder().encode(ProfessionalEvaluationResult.mock) {
        mockSession.evaluationJSON = String(data: data, encoding: .utf8)
    }
    
    let context = EvaluationNavigationContext(patientCase: mockCase, session: mockSession)
    
    return UnifiedReportView(context: context, modelContext: container.mainContext, onDismiss: {})
}

#Preview("Post-Simulation Flow") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StudentSession.self, PatientCase.self, configurations: config)
    let mockSession = StudentSession(caseId: "mock")
    let mockCase = PatientCase(caseId: "mock", title: "Mock", specialty: "Mock", difficulty: "Advanced", chiefComplaint: "Mock", fullCaseJSON: "{}")
    let context = EvaluationNavigationContext(patientCase: mockCase, session: mockSession)
    
    return EvaluationView(context: context, modelContext: container.mainContext, onFinish: {})
}
