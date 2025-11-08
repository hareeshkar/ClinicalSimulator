// Views/DifferentialInputView.swift

import SwiftUI

struct DifferentialInputView: View {
    @ObservedObject var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    // A local copy for safe, transactional editing.
    @State private var items: [DifferentialItem] = []
    
    // Haptic feedback engine.
    private let hapticGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    instructionsHeader
                    
                    // The animation is now smoother with a refined spring.
                    ForEach($items) { $item in
                        diagnosisEditorCard(for: $item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity))
                            )
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: items)
                    
                    if items.count < 3 {
                        addDiagnosisButton
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Manage Hypotheses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                leadingToolbarItem
                trailingToolbarItem
            }
            .onAppear(perform: setupInitialState)
        }
    }
    
    // MARK: - ViewBuilder Sub-components
    
    /// A concise header to guide the user.
    @ViewBuilder
    private var instructionsHeader: some View {
        Text("Rank up to three potential diagnoses and set your confidence level for each.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    // ✅ --- THE FULLY REDESIGNED EDITOR CARD ---
    @ViewBuilder
    private func diagnosisEditorCard(for item: Binding<DifferentialItem>) -> some View {
        VStack(spacing: 0) { // Use spacing: 0 and control with padding/dividers
            
            // --- Diagnosis Text Field ---
            HStack {
                TextField("Diagnosis (e.g., Acute Appendicitis)", text: item.diagnosis)
                    .font(.headline.weight(.semibold)) // Bolder font for emphasis
                
                Button(role: .destructive, action: {
                    withAnimation(.spring()) {
                        items.removeAll { $0.id == item.id }
                    }
                }) {
                    // More standard 'trash' icon
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            // --- Confidence Slider ---
            VStack(alignment: .leading, spacing: 4) {
                Text("Confidence: \(Int(item.confidence.wrappedValue * 100))%")
                    .font(.subheadline) // Consistent label font
                    .foregroundStyle(.secondary)
                
                Slider(value: item.confidence, in: 0...1, step: 0.05)
                    .onChange(of: item.confidence.wrappedValue) { _, _ in
                        hapticGenerator.selectionChanged()
                    }
            }
            
            // --- Divider for Visual Separation ---
            Divider()
                .padding(.vertical, 12)

            // --- Rationale TextEditor ---
            VStack(alignment: .leading, spacing: 8) {
                Text("Justification")
                    .font(.subheadline) // Consistent label font
                    .foregroundStyle(.secondary)
                
                TextEditor(text: item.rationale)
                    .font(.callout)
                    .frame(height: 70)
                    .padding(8)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    .overlay(
                        item.rationale.wrappedValue.isEmpty ?
                        Text("Why this diagnosis? Note key findings.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(14)
                            .allowsHitTesting(false)
                        : nil
                    )
            }
        }
        .padding(16) // Consistent padding
        .background(.background)
        .cornerRadius(16)
        // Softer shadow for a more refined look
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    @ViewBuilder
    private var addDiagnosisButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                items.append(DifferentialItem(diagnosis: "", confidence: 0.5, rationale: ""))
            }
        }) {
            Label("Add Diagnosis", systemImage: "plus")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
    
    // MARK: - Toolbar Items
    
    private var leadingToolbarItem: ToolbarItem<(), some View> {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: { dismiss() })
        }
    }
    
    private var trailingToolbarItem: ToolbarItem<(), some View> {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: saveChanges)
                .fontWeight(.semibold)
                .disabled(items.allSatisfy { $0.diagnosis.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }
    
    // MARK: - Logic & Handlers
    
    private func setupInitialState() {
        hapticGenerator.prepare()
        self.items = viewModel.differentialDiagnosis
    }
    
    private func saveChanges() {
        viewModel.differentialDiagnosis = items.filter { !$0.diagnosis.trimmingCharacters(in: .whitespaces).isEmpty }
        viewModel.save()
        dismiss()
    }
}
