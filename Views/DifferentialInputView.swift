// Views/DifferentialInputView.swift

import SwiftUI

struct DifferentialInputView: View {
    @ObservedObject var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    // A local copy for safe, transactional editing.
    @State private var items: [DifferentialItem] = []
    
    // ✅ Track the active (editable) item
    @State private var activeItemId: UUID?
    
    // ✅ Deferred removal to avoid index issues
    @State private var itemsToDelete: Set<UUID> = []
    
    // Haptic feedback engine.
    private let hapticGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    instructionsHeader
                    
                    // The animation is now smoother with a refined spring.
                    ForEach($items) { $item in
                        let isActive = item.id == activeItemId
                        diagnosisEditorCard(for: $item, isActive: isActive)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity))
                            )
                    }
                    // This animation correctly handles items being added/removed
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
            // ✅ Process deletions outside view building
            .onChange(of: itemsToDelete) { _, newDeletes in
                for id in newDeletes {
                    items.removeAll { $0.id == id }
                    if id == activeItemId {
                        activeItemId = items.last?.id ?? nil
                    }
                }
                itemsToDelete.removeAll()
            }
        }
    }
    
    // MARK: - ViewBuilder Sub-components
    
    /// A concise header to guide the user.
    @ViewBuilder
    private var instructionsHeader: some View {
        VStack(spacing: 8) {
            Text("Rank up to three potential diagnoses and set your confidence level for each.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Tap 'Save' to confirm your changes.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private func diagnosisEditorCard(for item: Binding<DifferentialItem>, isActive: Bool) -> some View {
        VStack(spacing: 0) {
            
            // --- Diagnosis Text Field ---
            HStack {
                TextField("Diagnosis (e.g., Acute Appendicitis)", text: item.diagnosis)
                    .font(.headline.weight(.semibold))
                    .disabled(!isActive) // ✅ Disable if not active
                
                Button(role: .destructive, action: {
                    // ✅ OPTIMIZED: Logic extracted to a clean function
                    requestItemDeletion(for: item)
                }) {
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Slider(value: item.confidence, in: 0...1, step: 0.05)
                    .disabled(!isActive) // ✅ Disable if not active
                    .onChange(of: item.confidence.wrappedValue) { _, _ in
                        hapticGenerator.selectionChanged()
                    }
                    .opacity(isActive ? 1.0 : 0.5) // ✅ Grey out disabled slider
            }
            
            // --- Divider for Visual Separation ---
            Divider()
                .padding(.vertical, 12)

            // --- Rationale TextEditor ---
            VStack(alignment: .leading, spacing: 8) {
                Text("Justification")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: item.rationale)
                    .font(.callout)
                    .frame(height: 70)
                    .padding(8)
                    .disabled(!isActive) // ✅ Disable if not active
                    .opacity(isActive ? 1.0 : 0.6) // ✅ Grey out when not active
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? Color(.systemGray5) : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    // ✅ This is the correct, standard way to do a TextEditor placeholder
                    .overlay(
                        item.rationale.wrappedValue.isEmpty && isActive ?
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
        .padding(16)
        .background(isActive ? Color(.systemBackground) : Color(.systemGray6).opacity(0.5))
        .cornerRadius(16)
        .shadow(color: .black.opacity(isActive ? 0.05 : 0.02), radius: 5)
        // ✅ ADDED: Allows tapping an inactive card to make it active.
        .onTapGesture {
            if !isActive {
                // Animate the change between active/inactive states
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    activeItemId = item.id.wrappedValue
                }
                hapticGenerator.selectionChanged()
            }
        }
    }
    
    @ViewBuilder
    private var addDiagnosisButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                let newItem = DifferentialItem(diagnosis: "", confidence: 0.5, rationale: "")
                items.append(newItem)
                activeItemId = newItem.id // ✅ Set new item as active
            }
        }) {
            Label("Add Next Diagnosis", systemImage: "plus")
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
            Button("Save", action: saveAndDismiss)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Logic & Handlers
    
    private func setupInitialState() {
        hapticGenerator.prepare()
        self.items = viewModel.differentialDiagnosis
        
        // ✅ Preload one empty diagnosis if none exist
        if items.isEmpty {
            let newItem = DifferentialItem(diagnosis: "", confidence: 0.5, rationale: "")
            items.append(newItem)
            activeItemId = newItem.id
        } else {
            // If loading existing, set the last one as active
            activeItemId = items.last?.id
        }
    }
    
    /// ✅ OPTIMIZED: Extracted logic from the button for clarity.
    private func requestItemDeletion(for item: Binding<DifferentialItem>) {
        if items.count > 1 {
            // ✅ Queue for deletion if more than one item
            itemsToDelete.insert(item.id.wrappedValue)
        } else {
            // ✅ Clear fields if only one item
            item.diagnosis.wrappedValue = ""
            item.confidence.wrappedValue = 0.5
            item.rationale.wrappedValue = ""
        }
    }
    
    private func saveAndDismiss() {
        // Filter out any diagnoses that are still empty
        viewModel.differentialDiagnosis = items.filter { !$0.diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        viewModel.save()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}