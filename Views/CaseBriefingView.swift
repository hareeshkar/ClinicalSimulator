import SwiftUI
import UIKit
import os.log

// MARK: - 🎨 CHART DESIGN TOKENS
private enum ChartTheme {
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let accent = Color.blue // Standard medical blue
    static let critical = Color.red
    static let vitalsBg = Color(.systemGray6) // Adaptive background for vitals monitor
    static let vitalsText = Color.primary
}

// ✅ LOGGING
private let logger = Logger(subsystem: "com.hareeshkar.ClinicalSimulator", category: "CaseBriefingView")

struct CaseBriefingView: View {
    // MARK: - Properties
    let patientCase: PatientCase
    let onBegin: (() -> Void)?
    var isReferenceMode: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    private let caseIdentifier: String
    
    // Loading State
    private enum LoadingState: Equatable {
        case loading
        case success(EnhancedCaseDetail)
        case error
        
        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.error, .error): return true
            case (.success(let a), .success(let b)): return a.metadata.caseId == b.metadata.caseId
            default: return false
            }
        }
    }
    
    @State private var state: LoadingState = .loading
    @State private var selectedTab: HistorySection = .presentIllness
    @State private var monitorExpanded: Bool = true
    @State private var showContent: Bool = false
    @State private var initializationId: UUID = UUID()

    enum HistorySection: String, CaseIterable, Identifiable {
        case presentIllness = "Story"
        case pastHistory = "History"
        case physicalExam = "Exam"
        
        var id: String { self.rawValue }
        
        var fullName: String {
            switch self {
            case .presentIllness: return "Patient Story (HPI)"
            case .pastHistory: return "Medical History"
            case .physicalExam: return "Physical Exam"
            }
        }
    }

    init(patientCase: PatientCase, onBegin: (() -> Void)? = nil, isReferenceMode: Bool = false) {
        self.patientCase = patientCase
        self.onBegin = onBegin
        self.isReferenceMode = isReferenceMode
        self.caseIdentifier = patientCase.caseId
    }
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                
                if !isReferenceMode, case .success = state {
                    startCaseButton
                }
            }
            .background(ChartTheme.background.ignoresSafeArea())
            .navigationTitle("Patient Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear(perform: handleOnAppear)
            .id(initializationId)
        }
    }
    
    // MARK: - ViewBuilder Content
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch state {
                case .loading:
                    ChartSkeletonLoader()
                        .transition(.opacity)
                case .success(let detail):
                    // 1. Patient Header
                    PatientHeaderCard(detail: detail)
                        .padding(.top, 16)
                    
                    // 2. Clinical Monitor Widget - Full immersive experience with haptics & ECG
                    ClinicalMonitorWidget(
                        patientProfile: detail.patientProfile,
                        vitals: detail.initialPresentation.vitals,
                        isExpanded: $monitorExpanded,
                        onChartAction: nil,
                        showChartButton: false
                    )
                    
                    // 3. Clinical History (Restored Tab Interface)
                    ClinicalHistorySection(detail: detail, selectedTab: $selectedTab)
                    
                    // Padding for FAB
                    if !isReferenceMode {
                        Spacer().frame(height: 80)
                    }
                case .error:
                    ChartErrorView()
                }
            }
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: state)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder
    private var startCaseButton: some View {
        VStack {
            Spacer()
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                onBegin?()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Start Case")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(ChartTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: ChartTheme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            VStack {
                Spacer()
                LinearGradient(colors: [ChartTheme.background.opacity(0), ChartTheme.background], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
            }
            .ignoresSafeArea()
        )
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Close") { dismiss() }
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Lifecycle
    
    private func handleOnAppear() {
        guard case .loading = state else { return }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await parseCaseDetails()
        }
    }
    
    @MainActor
    private func parseCaseDetails() async {
        guard let data = patientCase.fullCaseJSON.data(using: .utf8) else {
            self.state = .error
            return
        }
        
        do {
            let detail = try JSONDecoder().decode(EnhancedCaseDetail.self, from: data)
            withAnimation {
                self.state = .success(detail)
                self.showContent = true
            }
        } catch {
            self.state = .error
        }
    }
}

// MARK: - 🏥 COMPONENT: PATIENT HEADER
struct PatientHeaderCard: View {
    let detail: EnhancedCaseDetail
    
    private var specialtyColor: Color {
        SpecialtyDetailsProvider.color(for: detail.metadata.specialty)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Identity Section (Compact)
            HStack(alignment: .center, spacing: 16) {
                // Clinical Avatar (Refined Size)
                ZStack {
                    Circle()
                        .fill(specialtyColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Text(String(detail.patientProfile.name.prefix(1)))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(specialtyColor)
                }
                .overlay(
                    Circle()
                        .stroke(specialtyColor.opacity(0.15), lineWidth: 1)
                )
                
                // Patient Record Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.patientProfile.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(ChartTheme.primaryText)
                        .minimumScaleFactor(0.9)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        DemographicBadge(text: "\(detail.patientProfile.age)", color: specialtyColor)
                        DemographicBadge(text: detail.patientProfile.gender, color: specialtyColor)
                        SpecialtyCapsule(specialty: detail.metadata.specialty, color: specialtyColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            // Subtle Clinical Divider
            Rectangle()
                .fill(specialtyColor.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // 2. Clinical Presentation (Streamlined)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(specialtyColor.opacity(0.8))
                    
                    Text("PRESENTING COMPLAINT")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(specialtyColor.opacity(0.6))
                        .tracking(1.2)
                }
                
                Text(detail.initialPresentation.chiefComplaint)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(ChartTheme.primaryText.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(
            ZStack {
                ChartTheme.cardBackground
                
                // Atmospheric Medical Grid (More Subtle)
                GeometryReader { geo in
                    Path { path in
                        let step: CGFloat = 30
                        for x in stride(from: 0, to: geo.size.width, by: step) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        }
                        for y in stride(from: 0, to: geo.size.height, by: step) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                    }
                    .stroke(specialtyColor.opacity(0.02), lineWidth: 0.5)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(specialtyColor.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - 🏥 REFINED SUB-COMPONENTS
struct DemographicBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct SpecialtyCapsule: View {
    let specialty: String
    let color: Color
    
    var body: some View {
        Text(specialty.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                ZStack {
                    color.opacity(0.1)
                    Capsule().stroke(color.opacity(0.2), lineWidth: 0.5)
                }
            )
            .clipShape(Capsule())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: -  COMPONENT: CLINICAL HISTORY (TABBED)
struct ClinicalHistorySection: View {
    let detail: EnhancedCaseDetail
    @Binding var selectedTab: CaseBriefingView.HistorySection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ✅ THE RESTORED SEGMENTED PICKER
            Picker("History Section", selection: $selectedTab) {
                ForEach(CaseBriefingView.HistorySection.allCases) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.3)
            
            // Content Area
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(ChartTheme.accent)
                        .frame(width: 3, height: 14)
                    
                    Text(selectedTab.fullName)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(ChartTheme.accent)
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
                
                Group {
                    switch selectedTab {
                    case .presentIllness:
                        Text(detail.initialPresentation.history.presentIllness)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .lineSpacing(8)
                            .foregroundStyle(ChartTheme.primaryText.opacity(0.9))
                    case .pastHistory:
                        PastHistoryView(history: detail.initialPresentation.history.pastMedicalHistory)
                    case .physicalExam:
                        PhysicalExamView(findings: detail.dynamicState.states["initial"]?.physicalExamFindings ?? [:])
                    }
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ChartTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - 🧱 SUB-COMPONENTS FOR HISTORY
struct PastHistoryView: View {
    let history: StructuredPastHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InfoBlock(label: "Medical History", content: history.medicalHistory, icon: "cross.case.fill")
            InfoBlock(label: "Surgical History", content: history.surgicalHistory, icon: "scissors")
            InfoBlock(label: "Medications", content: history.medications, icon: "pill.fill")
            InfoBlock(label: "Allergies", content: history.allergies, icon: "exclamationmark.triangle.fill", isAlert: true)
            InfoBlock(label: "Social History", content: history.socialHistory, icon: "person.2.fill")
        }
    }
}

struct PhysicalExamView: View {
    let findings: [String: String]
    
    var body: some View {
        if findings.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(Color.secondary.opacity(0.5))
                Text("No specific physical exam findings recorded.")
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(Color.secondary)
            }
            .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(findings.keys.sorted(), id: \.self) { key in
                    InfoBlock(label: key, content: findings[key] ?? "", icon: "stethoscope")
                }
            }
        }
    }
}

struct InfoBlock: View {
    let label: String
    let content: String
    var icon: String? = nil
    var isAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isAlert ? Color.red : ChartTheme.accent.opacity(0.7))
                }
                
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isAlert ? Color.red : Color.secondary)
                    .tracking(1.2)
            }
            
            Text(content)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(ChartTheme.primaryText.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, icon != nil ? 18 : 0)
        }
    }
}

// MARK: - 🦴 LOADING SKELETON
struct ChartSkeletonLoader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header Skeleton
            HStack(spacing: 16) {
                Circle().fill(Color(.systemGray5)).frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 180, height: 20)
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 120, height: 14)
                }
            }
            .padding(16)
            .background(ChartTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Monitor Skeleton
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray5)).frame(height: 160)
            
            // History Skeleton
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 100, height: 12)
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(height: 200)
            }
            .padding(20)
            .background(ChartTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.top, 20)
        .shimmering()
    }
}

struct ChartErrorView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            
            VStack(spacing: 8) {
                Text("CHART ACCESS DENIED")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2)
                Text("Unable to synchronize with clinical database.")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { /* Retry logic */ }) {
                Text("RETRY CONNECTION")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// Helper modifier for shimmer effect
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -0.5
    
    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white.opacity(0.2), location: phase),
                                    .init(color: .white.opacity(0.6), location: phase + 0.1),
                                    .init(color: .white.opacity(0.2), location: phase + 0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}