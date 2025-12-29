import SwiftUI

// MARK: - 🎨 DESIGN TOKENS
private enum EditorTheme {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let accent = Color.blue // Medical Blue
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let destructive = Color.red
    static let shadowColor = Color.black.opacity(0.02)
    static let activeShadowColor = Color.black.opacity(0.08)
    static let inactiveIndicator = Color.gray.opacity(0.3)
    static let textEditorBackground = Color(.systemGray6)
    static let separator = Color.primary.opacity(0.06)
}

struct DifferentialInputView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Local State Buffer
    @State private var diagnoses: [DifferentialItem] = []
    @State private var activeDiagnosisId: UUID? // Which card is being edited?
    
    // Haptics
    private let feedback = UISelectionFeedbackGenerator()
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                EditorTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Guidance Header
                        GuidanceHeader()
                        
                        // 2. The List of Hypotheses
                        VStack(spacing: 16) {
                            ForEach(diagnoses.indices, id: \.self) { index in
                                DiagnosisEditorCard(
                                    diagnosis: $diagnoses[index],
                                    rank: index + 1,
                                    isActive: diagnoses[index].id == activeDiagnosisId,
                                    onActivate: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            activeDiagnosisId = diagnoses[index].id
                                        }
                                        feedback.selectionChanged()
                                    },
                                    onDelete: {
                                        deleteDiagnosis(id: diagnoses[index].id)
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                            }
                        }
                        
                        // 3. Add Button
                        if diagnoses.count < 5 && canAddNewDiagnosis { // Limit to 5 realistic differentials
                            Button(action: addNewDiagnosis) {
                                Label("Add Hypothesis", systemImage: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: EditorTheme.shadowColor, radius: 2, y: 1)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Formulate Differential")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.primary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndClose() }
                        .fontWeight(.semibold)
                        .tint(EditorTheme.accent)
                }
            }
            .onAppear(perform: initializeData)
            .dismissKeyboardOnTap()
        }
    }
    
    // MARK: - Computed Properties
    
    private var canAddNewDiagnosis: Bool {
        guard let activeId = activeDiagnosisId else { return true }
        return diagnoses.first(where: { $0.id == activeId })?.diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
    
    private func initializeData() {
        feedback.prepare()
        diagnoses = viewModel.differentialDiagnosis
        
        // Start fresh if empty
        if diagnoses.isEmpty {
            addNewDiagnosis()
        } else {
            // Activate the first one
            activeDiagnosisId = diagnoses.first?.id
        }
    }
    
    private func addNewDiagnosis() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            let new = DifferentialItem(diagnosis: "", confidence: 0.5, rationale: "")
            diagnoses.append(new)
            activeDiagnosisId = new.id
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func deleteDiagnosis(id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
            diagnoses.removeAll { $0.id == id }
            // If we deleted the active one, activate the last one
            if activeDiagnosisId == id {
                activeDiagnosisId = diagnoses.last?.id
            }
            // Ensure at least one card remains
            if diagnoses.isEmpty { addNewDiagnosis() }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    private func saveAndClose() {
        // Filter out blanks
        let validList = diagnoses.filter { !$0.diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        viewModel.differentialDiagnosis = validList
        viewModel.save()
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - 🗂️ COMPONENT: EDITOR CARD
struct DiagnosisEditorCard: View {
    @Binding var diagnosis: DifferentialItem
    let rank: Int
    let isActive: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void
    
    @FocusState private var isFieldFocused: Bool
    
    // Computed properties for optimization
    private var likelihoodText: String {
        likelihoodLabel(for: diagnosis.confidence)
    }
    
    private var confidencePercentage: Int {
        Int(diagnosis.confidence * 100)
    }
    
    private var isDiagnosisEmpty: Bool {
        diagnosis.diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Tap to activate)
            HStack(spacing: 16) {
                // Rank Badge
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .white : EditorTheme.accent)
                    .frame(width: 24, height: 24)
                    .background(isActive ? EditorTheme.accent : EditorTheme.accent.opacity(0.1), in: Circle())
                
                if isActive {
                    TextField("", text: $diagnosis.diagnosis, prompt: Text("Enter Diagnosis...").font(.system(size: 18, weight: .bold)))
                        .font(.system(size: 18, weight: .bold))
                        .focused($isFieldFocused)
                        .submitLabel(.done)
                } else {
                    Text(isDiagnosisEmpty ? "Untitled Hypothesis" : diagnosis.diagnosis)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isDiagnosisEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                if isActive {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isDiagnosisEmpty ? Color.gray.opacity(0.3) : EditorTheme.destructive.opacity(0.8))
                            .padding(8)
                            .background(isDiagnosisEmpty ? Color.gray.opacity(0.1) : EditorTheme.destructive.opacity(0.1), in: Circle())
                    }
                    .disabled(isDiagnosisEmpty)
                } else {
                    // Show compact percentage when collapsed
                    Text("\(confidencePercentage)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isActive { onActivate() }
            }
            
            // Expanded Body (Only if active)
            if isActive {
                VStack(spacing: 24) {
                    Divider().padding(.horizontal, 16)
                    
                    // 1. Likelihood Slider
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Clinical Likelihood", systemImage: "chart.bar.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Spacer()
                            
                            // Dynamic Text Label based on slider value
                            Text("\(likelihoodText) (\(confidencePercentage)%)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(EditorTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(EditorTheme.accent.opacity(0.1), in: Capsule())
                        }
                        
                        HStack(spacing: 12) {
                            Text("Low").font(.caption2).foregroundStyle(.secondary)
                            Slider(value: $diagnosis.confidence, in: 0...1)
                                .tint(EditorTheme.accent)
                            Text("High").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 2. Evidence Input
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Supporting Findings", systemImage: "list.bullet.indent")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)
                        
                        TextEditor(text: $diagnosis.rationale)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(EditorTheme.textEditorBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(EditorTheme.separator, lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            .overlay(alignment: .topLeading) {
                                if diagnosis.rationale.isEmpty {
                                    Text("List key symptoms, vitals, or labs...")
                                        .font(.body)
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 28)
                                        .padding(.top, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .background(EditorTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(
            color: isActive ? EditorTheme.activeShadowColor : EditorTheme.shadowColor,
            radius: isActive ? 8 : 2,
            y: isActive ? 4 : 1
        )
        // Focus management
        .onChange(of: isActive) { _, newValue in
            if newValue { isFieldFocused = true }
        }
    }
    
    // Helper: Translate math to medicine
    private func likelihoodLabel(for value: Double) -> String {
        switch value {
        case 0.0..<0.2: return "Unlikely"
        case 0.2..<0.5: return "Possible"
        case 0.5..<0.8: return "Probable"
        default: return "Definitive"
        }
    }
}

// MARK: - ℹ️ COMPONENT: GUIDANCE
struct GuidanceHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                Text("Clinical Reasoning Protocol")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .foregroundStyle(EditorTheme.accent)
            
            VStack(alignment: .leading, spacing: 10) {
                bulletText("Prioritize diagnoses by clinical likelihood.")
                bulletText("Complete current entry to unlock the next.")
                bulletText("Finalized list enables diagnostic orders.")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorTheme.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(EditorTheme.accent.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Helper
    @ViewBuilder
    private func bulletText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EditorTheme.accent)
            
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
