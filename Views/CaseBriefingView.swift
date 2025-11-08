// Views/CaseBriefingView.swift

import SwiftUI
import UIKit

struct CaseBriefingView: View {
    // MARK: - Properties (Backend-driven)
    let patientCase: PatientCase
    let onBegin: (() -> Void)?
    var isReferenceMode: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    private enum LoadingState {
        case loading, success(EnhancedCaseDetail), error
    }
    
    @State private var state: LoadingState = .loading
    @State private var selectedHistorySection: HistorySection = .presentIllness
    @State private var showContent: Bool = false

    enum HistorySection: String, CaseIterable, Identifiable {
        case presentIllness = "Present Illness", pastHistory = "Past History", physicalExam = "Physical Exam"
        var id: String { self.rawValue }
    }

    init(patientCase: PatientCase, onBegin: (() -> Void)? = nil, isReferenceMode: Bool = false) {
        self.patientCase = patientCase
        self.onBegin = onBegin
        self.isReferenceMode = isReferenceMode
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
            .onAppear(perform: parseCaseDetails)
        }
    }
    
    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            switch state {
            case .loading:
                SkeletonLoadingView()
            case .success(let detail):
                VStack(alignment: .leading, spacing: 20) {
                    patientHeader(for: detail).animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: showContent)
                    vitalsSection(for: detail.initialPresentation.vitals).animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showContent)
                    historySection(for: detail).animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: showContent)
                }
                .opacity(showContent ? 1 : 0)
                .padding()
            case .error:
                ContentUnavailableView("Unable to Load Chart", systemImage: "xmark.octagon.fill", description: Text("The patient chart could not be loaded. Please try again."))
                    .padding(.top, 100)
            }
        }
        .safeAreaPadding(.bottom, 80)
    }
    
    @ViewBuilder
    private func patientHeader(for detail: EnhancedCaseDetail) -> some View {
        let specialtyColor = SpecialtyDetailsProvider.color(for: detail.metadata.specialty)
        
        VStack(alignment: .leading, spacing: 10) {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Initial Vitals").font(.headline.weight(.semibold))
            VitalsGridView(vitals: vitals)
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
    }
    
    // ✅ --- REWORKED HISTORY SECTION FOR ADAPTIVE HEIGHT ---
    @ViewBuilder
    private func historySection(for detail: EnhancedCaseDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Clinical History").font(.headline.weight(.semibold))

            Picker("History Section", selection: $selectedHistorySection) {
                ForEach(HistorySection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // This VStack now smoothly animates its height changes.
            VStack(alignment: .leading, spacing: 14) {
                // Use a switch statement to ensure only one view is in the
                // layout tree at a time, allowing the parent to resize.
                switch selectedHistorySection {
                case .presentIllness:
                    Text(detail.initialPresentation.history.presentIllness)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        // Add a transition for the content itself.
                        .transition(.opacity)
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
                case .physicalExam:
                    VStack(alignment: .leading, spacing: 14) {
                        let findings = detail.dynamicState.states["initial"]?.physicalExamFindings?.sorted(by: <) ?? []
                        if findings.isEmpty {
                            Text("No specific physical exam findings noted in the initial presentation.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(findings, id: \.key) { InfoRowView(label: $0.key, content: $0.value) }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background)
            .cornerRadius(12)
        }
        // ✅ KEY: This modifier animates any changes to animatable properties
        // within the VStack, including its frame (height).
        .animation(.easeInOut(duration: 0.3), value: selectedHistorySection)
    }
    
    @ViewBuilder
    private var beginButton: some View {
        Button(action: {
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
            Button("Done") { dismiss() }
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Data Loading (Unchanged)
    @MainActor
    private func parseCaseDetails() {
        let fullCaseJSON = patientCase.fullCaseJSON
        Task {
            do {
                let result = try await parsePatientData(fullCaseJSON: fullCaseJSON)
                await MainActor.run {
                    self.state = .success(result)
                    withAnimation { self.showContent = true }
                }
            } catch {
                await MainActor.run {
                    self.state = .error
                    print("CRITICAL: Failed to load/process CaseBriefingView: \(error)")
                }
            }
        }
    }
    
    private func parsePatientData(fullCaseJSON: String) async throws -> EnhancedCaseDetail {
        guard let fullCaseData = fullCaseJSON.data(using: .utf8) else { throw URLError(.badServerResponse) }
        let groundTruth = try JSONDecoder().decode(EnhancedCaseDetail.self, from: fullCaseData)
        let studentJSON = groundTruth.studentFacingJSON()
        guard let studentSafeData = studentJSON.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return try JSONDecoder().decode(EnhancedCaseDetail.self, from: studentSafeData)
    }
}

// MARK: - Helper Views (Unchanged)

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
