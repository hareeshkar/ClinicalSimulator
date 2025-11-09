// Views/NotesTabView.swift

import SwiftUI

struct NotesTabView: View {
    @ObservedObject var viewModel: NotesViewModel
    @State private var isPresentingDifferentialSheet = false

    var body: some View {
        // A NavigationStack provides a title and toolbar context.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    differentialDiagnosisSection
                    
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
                Button(
                    viewModel.differentialDiagnosis.isEmpty ? "Add" : "Manage",
                    systemImage: viewModel.differentialDiagnosis.isEmpty ? "plus.circle.fill" : "list.bullet",
                    action: { isPresentingDifferentialSheet = true }
                )
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
    
    /// An instructional and visually appealing empty state.
    @ViewBuilder
    private var emptyDiagnosisView: some View {
        VStack(spacing: 12) {
            Text("No Hypotheses Added")
                .font(.headline)
            Text("Tap 'Add' to create your differential diagnosis. Each diagnosis should include your confidence level and clinical justification.")
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


