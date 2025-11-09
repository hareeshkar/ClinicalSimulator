// Views/CaseBriefingView.swift

import SwiftUI
import UIKit
import os.log

// ✅ LOGGING: Create a dedicated logger for CaseBriefingView
private let logger = Logger(subsystem: "com.hareeshkar.ClinicalSimulator", category: "CaseBriefingView")

struct CaseBriefingView: View {
    // MARK: - Properties (Backend-driven)
    let patientCase: PatientCase
    let onBegin: (() -> Void)?
    var isReferenceMode: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    // ✅ CRITICAL FIX: Store the case ID to track when the sheet is reinitializing
    private let caseIdentifier: String
    
    // ✅ FIX: Make LoadingState conform to Equatable
    private enum LoadingState: Equatable {
        case loading
        case success(EnhancedCaseDetail)
        case error
        
        // ✅ CUSTOM EQUATABLE IMPLEMENTATION to handle comparison
        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                logger.log("🔍 Comparing: loading == loading → true")
                return true
            case (.error, .error):
                logger.log("🔍 Comparing: error == error → true")
                return true
            case (.success(let lhsDetail), .success(let rhsDetail)):
                let result = lhsDetail.metadata.caseId == rhsDetail.metadata.caseId
                logger.log("🔍 Comparing: success(\(lhsDetail.metadata.caseId, privacy: .public)) == success(\(rhsDetail.metadata.caseId, privacy: .public)) → \(result)")
                return result
            default:
                logger.log("🔍 Comparing: different states → false")
                return false
            }
        }
    }
    
    @State private var state: LoadingState = .loading
    // ✅ CRITICAL FIX: Explicitly name this state and add logging
    @State private var selectedHistorySection: HistorySection = .presentIllness
    @State private var showContent: Bool = false
    
    // ✅ NEW: Track initialization for debugging
    @State private var initializationId: UUID = UUID()
    
    // ✅ NEW: Track view lifecycle events
    @State private var appearCount: Int = 0
    @State private var disappearCount: Int = 0

    enum HistorySection: String, CaseIterable, Identifiable {
        case presentIllness = "Present Illness"
        case pastHistory = "Past History"
        case physicalExam = "Physical Exam"
        
        var id: String { self.rawValue }
    }

    init(patientCase: PatientCase, onBegin: (() -> Void)? = nil, isReferenceMode: Bool = false) {
        self.patientCase = patientCase
        self.onBegin = onBegin
        self.isReferenceMode = isReferenceMode
        self.caseIdentifier = patientCase.caseId
        
        logger.log("🟢 [INIT] CaseBriefingView.init() called for case: \(patientCase.caseId, privacy: .public), isReferenceMode: \(isReferenceMode)")
    }
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                
                if !isReferenceMode, case .success = state {
                    beginButton
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Patient Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear(perform: handleOnAppear)
            // ✅ NEW: Track when the sheet appears to detect re-initialization
            .onDisappear(perform: handleOnDisappear)
            // ✅ NEW: Monitor state changes for debugging
            .onChange(of: selectedHistorySection) { oldValue, newValue in
                logger.log("📊 [STATE-CHANGE] selectedHistorySection: \(oldValue.rawValue, privacy: .public) → \(newValue.rawValue, privacy: .public)")
            }
            .onChange(of: state) { _, newState in
                logger.log("📊 [STATE-CHANGE] LoadingState changed:")
                switch newState {
                case .loading:
                    logger.log("  ⏳ New State: LOADING")
                case .success(let detail):
                    logger.log("  ✅ New State: SUCCESS (Case: \(detail.metadata.caseId, privacy: .public))")
                case .error:
                    logger.log("  ❌ New State: ERROR")
                }
            }
        }
        // ✅ CRITICAL FIX: Add id() to prevent sheet reinitialization when parent updates
        .id(initializationId)
        .onReceive(Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()) { _ in
            logger.log("⏱️ [HEARTBEAT] CaseBriefingView - Appear: \(self.appearCount), Disappear: \(self.disappearCount), State: \(self.stateDescription)")
        }
    }
    
    private var stateDescription: String {
        switch state {
        case .loading:
            return "loading"
        case .success:
            return "success"
        case .error:
            return "error"
        }
    }
    
    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            switch state {
            case .loading:
                SkeletonLoadingView()
                    .onAppear {
                        logger.log("🎨 [RENDERING] Showing SkeletonLoadingView")
                    }
            case .success(let detail):
                VStack(alignment: .leading, spacing: 20) {
                    patientHeader(for: detail)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: showContent)
                    
                    vitalsSection(for: detail.initialPresentation.vitals)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showContent)
                    
                    // ✅ CRITICAL FIX: Use explicit binding and id() for stable picker state
                    historySection(for: detail)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: showContent)
                        // Prevent re-initialization of this section
                        .id("history-\(caseIdentifier)-\(selectedHistorySection.id)")
                }
                .opacity(showContent ? 1 : 0)
                .padding()
                .onAppear {
                    logger.log("📄 [RENDERING] Showing success content - SelectedSection: \(self.selectedHistorySection.rawValue, privacy: .public), CaseID: \(detail.metadata.caseId, privacy: .public)")
                }
            case .error:
                ContentUnavailableView("Unable to Load Chart", systemImage: "xmark.octagon.fill", description: Text("The patient chart could not be loaded. Please try again."))
                    .padding(.top, 100)
                    .onAppear {
                        logger.log("⚠️ [RENDERING] Showing error state")
                    }
            }
        }
        .safeAreaPadding(.bottom, 80)
    }
    
    @ViewBuilder
    private func patientHeader(for detail: EnhancedCaseDetail) -> some View {
        let specialtyColor = SpecialtyDetailsProvider.color(for: detail.metadata.specialty)
        
        let _ = logger.log("🏥 [HEADER] Building header for: \(detail.patientProfile.name, privacy: .public), Specialty: \(detail.metadata.specialty, privacy: .public)")
        
        return VStack(alignment: .leading, spacing: 10) {
            Text(detail.patientProfile.name)
                .font(.title.bold())
                .foregroundStyle(.white)
                
            Text("\(detail.patientProfile.age) • \(detail.patientProfile.gender)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                
            Label(detail.initialPresentation.chiefComplaint, systemImage: "exclamationmark.bubble.fill")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [specialtyColor.opacity(0.8), specialtyColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: specialtyColor.opacity(0.35), radius: 8, y: 4)
    }

    @ViewBuilder
    private func vitalsSection(for vitals: Vitals) -> some View {
        let _ = logger.log("💓 [VITALS] Building vitals section - HR: \(vitals.heartRate ?? 0), RR: \(vitals.respiratoryRate ?? 0), BP: \(vitals.bloodPressure ?? "N/A", privacy: .public), O2: \(vitals.oxygenSaturation ?? 0)")
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Initial Vitals").font(.headline.weight(.semibold))
            VitalsGridView(vitals: vitals)
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
    }
    
    // ✅ CRITICAL FIX: Restructure for stable state management
    @ViewBuilder
    private func historySection(for detail: EnhancedCaseDetail) -> some View {
        let _ = logger.log("📚 [HISTORY] Building history section - Current selection: \(selectedHistorySection.rawValue, privacy: .public)")
        
        VStack(alignment: .leading, spacing: 14) {
            Text("Clinical History").font(.headline.weight(.semibold))

            // ✅ KEY FIX: Use explicit Picker with stable selection binding
            Picker("History Section", selection: $selectedHistorySection) {
                ForEach(HistorySection.allCases) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedHistorySection) { oldValue, newValue in
                logger.log("🔄 [PICKER-CHANGE] Selection changed: \(oldValue.rawValue, privacy: .public) → \(newValue.rawValue, privacy: .public)")
            }

            // ✅ FIX: Use dedicated ViewBuilder function for content
            historyContent(for: detail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.background)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.3), value: selectedHistorySection)
        }
    }
    
    @ViewBuilder
    private func historyContent(for detail: EnhancedCaseDetail) -> some View {
        switch selectedHistorySection {
        case .presentIllness:
            VStack(alignment: .leading, spacing: 8) {
                Text(detail.initialPresentation.history.presentIllness)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
            .onAppear {
                logger.log("📖 [HISTORY-SECTION] Rendered: Present Illness")
            }
            
        case .pastHistory:
            VStack(alignment: .leading, spacing: 14) {
                let past = detail.initialPresentation.history.pastMedicalHistory
                InfoRowView(label: "Medical History", content: past.medicalHistory)
                InfoRowView(label: "Surgical History", content: past.surgicalHistory)
                InfoRowView(label: "Medications", content: past.medications)
                InfoRowView(label: "Allergies", content: past.allergies, isCritical: true)
                InfoRowView(label: "Social History", content: past.socialHistory)
            }
            .transition(.opacity)
            .onAppear {
                logger.log("📖 [HISTORY-SECTION] Rendered: Past History")
            }
            
        case .physicalExam:
            VStack(alignment: .leading, spacing: 14) {
                let findings = detail.dynamicState.states["initial"]?.physicalExamFindings?.sorted(by: <) ?? []
                
                if findings.isEmpty {
                    Text("No specific physical exam findings noted in the initial presentation.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(findings, id: \.key) { key, value in
                        InfoRowView(label: key, content: value)
                    }
                }
            }
            .transition(.opacity)
            .onAppear {
                let findings = detail.dynamicState.states["initial"]?.physicalExamFindings?.sorted(by: <) ?? []
                logger.log("🔍 [PHYSICAL-EXAM] Found \(findings.count) examination findings")
                logger.log("📖 [HISTORY-SECTION] Rendered: Physical Exam")
            }
        }
    }
    
    @ViewBuilder
    private var beginButton: some View {
        Button(action: {
            logger.log("🎬 [USER-ACTION] Begin Simulation button tapped")
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            onBegin?()
        }) {
            Label("Begin Simulation", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor, in: Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 24)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                logger.log("✖️ [USER-ACTION] Done button tapped")
                dismiss()
            }
            .fontWeight(.medium)
        }
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleOnAppear() {
        appearCount += 1
        logger.log("🟢 [LIFECYCLE-APPEAR] CaseBriefingView.onAppear() #\(self.appearCount)")
        logger.log("  InitID: \(self.initializationId.uuidString, privacy: .public)")
        logger.log("  SelectedSection: \(self.selectedHistorySection.rawValue, privacy: .public)")
        logger.log("  CurrentState: \(self.stateDescription)")
        logger.log("  IsReferenceMode: \(self.isReferenceMode)")
        logger.log("  CaseID: \(self.caseIdentifier, privacy: .public)")
        
        parseCaseDetails()
    }
    
    private func handleOnDisappear() {
        disappearCount += 1
        logger.log("🔴 [LIFECYCLE-DISAPPEAR] CaseBriefingView.onDisappear() #\(self.disappearCount)")
        logger.log("  InitID: \(self.initializationId.uuidString, privacy: .public)")
        logger.log("  SelectedSection: \(self.selectedHistorySection.rawValue, privacy: .public)")
        logger.log("  CurrentState: \(self.stateDescription)")
    }
    
    // MARK: - Data Loading
    @MainActor
    private func parseCaseDetails() {
        logger.log("⏳ [DATA-LOADING] Starting to parse case details for: \(self.caseIdentifier, privacy: .public)")
        let fullCaseJSON = patientCase.fullCaseJSON
        logger.log("📦 [DATA-LOADING] JSON length: \(fullCaseJSON.count) characters")
        
        Task {
            do {
                logger.log("🔄 [DATA-DECODING] Decoding patient data...")
                let result = try await parsePatientData(fullCaseJSON: fullCaseJSON)
                
                await MainActor.run {
                    logger.log("✅ [DATA-SUCCESS] Patient data decoded successfully")
                    logger.log("  Case Title: \(result.metadata.title, privacy: .public)")
                    logger.log("  Specialty: \(result.metadata.specialty, privacy: .public)")
                    logger.log("  Difficulty: \(result.metadata.difficulty, privacy: .public)")
                    logger.log("  States Count: \(result.dynamicState.states.count)")
                    
                    self.state = .success(result)
                    withAnimation {
                        self.showContent = true
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("❌ [DATA-ERROR] CRITICAL: Failed to load CaseBriefingView")
                    logger.error("  Error: \(error.localizedDescription, privacy: .public)")
                    logger.error("  Error Type: \(type(of: error), privacy: .public)")
                    
                    self.state = .error
                }
            }
        }
    }
    
    private func parsePatientData(fullCaseJSON: String) async throws -> EnhancedCaseDetail {
        logger.log("🔍 [PARSE] Converting JSON string to Data...")
        
        guard let fullCaseData = fullCaseJSON.data(using: .utf8) else {
            logger.error("❌ [PARSE] Failed to convert JSON string to Data")
            throw URLError(.badServerResponse)
        }
        
        logger.log("✅ [PARSE] JSON converted to Data, size: \(fullCaseData.count) bytes")
        
        logger.log("🔍 [PARSE] Decoding ground truth...")
        let groundTruth = try JSONDecoder().decode(EnhancedCaseDetail.self, from: fullCaseData)
        logger.log("✅ [PARSE] Ground truth decoded - Case ID: \(groundTruth.metadata.caseId, privacy: .public)")
        
        logger.log("🔍 [PARSE] Generating student-facing JSON...")
        let studentJSON = groundTruth.studentFacingJSON()
        logger.log("✅ [PARSE] Student JSON generated, size: \(studentJSON.count) characters")
        
        logger.log("🔍 [PARSE] Converting student JSON to Data...")
        guard let studentSafeData = studentJSON.data(using: .utf8) else {
            logger.error("❌ [PARSE] Failed to convert student JSON to Data")
            throw URLError(.cannotDecodeContentData)
        }
        
        logger.log("✅ [PARSE] Student JSON converted to Data, size: \(studentSafeData.count) bytes")
        
        logger.log("🔍 [PARSE] Decoding student-safe case detail...")
        let studentDetail = try JSONDecoder().decode(EnhancedCaseDetail.self, from: studentSafeData)
        logger.log("✅ [PARSE] Student-safe case detail decoded successfully")
        
        return studentDetail
    }
}

// MARK: - Helper Views

struct InfoRowView: View {
    let label: String
    let content: String
    var isCritical: Bool = false

    private var shouldHighlight: Bool {
        isCritical && !content.localizedCaseInsensitiveContains("none")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(content)
                .font(.body)
                .foregroundStyle(shouldHighlight ? .red : .secondary)
        }
    }
}

struct SkeletonLoadingView: View {
    @State private var isShimmering: Bool = false
    private let shimmerColor = Color(.systemGray5)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 16).fill(shimmerColor).frame(height: 140)
            RoundedRectangle(cornerRadius: 12).fill(shimmerColor).frame(height: 120)
            RoundedRectangle(cornerRadius: 12).fill(shimmerColor).frame(height: 200)
        }
        .padding()
        .shimmering(isActive: isShimmering)
        .onAppear { isShimmering = true }
    }
}

extension View {
    @ViewBuilder
    func shimmering(isActive: Bool) -> some View {
        if isActive {
            self
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .white.opacity(0.4), .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(110))
                    .offset(x: -150)
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isActive)
                )
                .clipped()
        } else {
            self
        }
    }
}
