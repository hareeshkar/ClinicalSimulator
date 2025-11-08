// Views/NotesTabView.swift

import SwiftUI

struct NotesTabView: View {
    @ObservedObject var viewModel: NotesViewModel
    @State private var isPresentingDifferentialSheet = false

    var body: some View {
        // A NavigationStack provides a title and toolbar context.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) { // Increased spacing for visual separation
                    
                    differentialDiagnosisSection
                    
                    clinicalReasoningSection
                    
                }
                .padding()
            }
            .navigationTitle("Clinical Worksheet")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $isPresentingDifferentialSheet) {
                // The sheet presentation remains the same, leveraging the existing input view.
                DifferentialInputView(viewModel: viewModel)
            }
        }
        .dismissKeyboardOnTap()
    }
    
    // MARK: - ViewBuilder Sub-components
    
    /// The primary section for managing and viewing the differential diagnosis.
    @ViewBuilder
    private var differentialDiagnosisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // A clear, actionable header.
            HStack {
                Label("Differential Diagnosis", systemImage: "brain.head.profile.fill")
                    .font(.title2.bold())
                Spacer()
                Button("Manage", systemImage: "list.bullet", action: { isPresentingDifferentialSheet = true })
                    .buttonStyle(.bordered)
                    .tint(.secondary)
            }
            
            // The view intelligently switches between the empty state and the list.
            if viewModel.differentialDiagnosis.isEmpty {
                emptyDiagnosisView
            } else {
                ForEach(viewModel.differentialDiagnosis) { item in
                    // Each diagnosis is now its own modular, detailed card.
                    DifferentialDiagnosisRowView(item: item)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.differentialDiagnosis)
            }
        }
    }
    
    /// The dedicated section for long-form clinical notes.
    @ViewBuilder
    private var clinicalReasoningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Clinical Reasoning Notes", systemImage: "pencil.and.scribble")
                .font(.title2.bold())

            // The TextEditor is now visually styled to feel like a "scratchpad".
            TextEditor(text: $viewModel.notes)
                .font(.callout)
                .frame(minHeight: 150)
                .padding(16) // This is the inset for the actual typed text.
                .background(.background)
                .cornerRadius(12)
                .overlay(
                
                viewModel.notes.isEmpty ?
                    Text("Justify your differential. What are the key findings supporting your hypotheses? What are you trying to rule out?")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        // 1. Force the placeholder to the top-left of the overlay frame.
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        // 2. Apply the *exact same padding* as the TextEditor's text.
                        .padding(22)
                        .allowsHitTesting(false)
                    : nil
                )
                .onChange(of: viewModel.notes) { viewModel.save() }
        }
    }
    /// An instructional and visually appealing empty state.
    @ViewBuilder
    private var emptyDiagnosisView: some View {
        VStack(spacing: 12) {
            Text("No Hypotheses Added")
                .font(.headline)
            Text("Tap 'Manage' to rank your potential diagnoses. This is a critical step before ordering tests.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background)
        .cornerRadius(12)
    }
}


// MARK: - Modular Sub-view for a Single DDx Item

/// A dedicated view that visualizes a single differential diagnosis item.
/// This encapsulates the logic for displaying the diagnosis, confidence, and rationale.
struct DifferentialDiagnosisRowView: View {
    let item: DifferentialItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.diagnosis)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                // Visual confidence meter
                confidenceView
            }
            
            // The rationale is now clearly displayed with its corresponding diagnosis.
            if !item.rationale.isEmpty {
                Text(item.rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var confidenceView: some View {
        HStack(spacing: 8) {
            // A dynamic progress bar provides an at-a-glance confidence level.
            ProgressView(value: item.confidence, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .frame(height: 8)
                .clipShape(Capsule())

            Text("\(Int(item.confidence * 100))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }
}


