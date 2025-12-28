import SwiftUI

// MARK: - 🎨 CLINICAL DESIGN TOKENS
private enum NotesTheme {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let accent = Color.blue // Medical Blue
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let confidenceHigh = Color.green
    static let confidenceMed = Color.orange
    static let confidenceLow = Color.gray
    static let shadowColor = Color.black.opacity(0.02)
    static let activeShadowColor = Color.black.opacity(0.08)
    static let separator = Color.primary.opacity(0.06)
}

struct NotesTabView: View {
    @ObservedObject var viewModel: NotesViewModel
    @State private var isPresentingDifferentialSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // 1. Differential Diagnosis Section
                    differentialDiagnosisSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100) // Clearance for tab bar
            }
            .background(NotesTheme.background.ignoresSafeArea())
            .navigationTitle("Worksheet")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingDifferentialSheet) {
                DifferentialInputView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
        .dismissKeyboardOnTap()
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var differentialDiagnosisSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header with Action
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Differential Diagnosis", systemImage: "list.bullet.clipboard")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NotesTheme.primaryText)
                    
                    Text("Ranked by clinical likelihood")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { 
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isPresentingDifferentialSheet = true 
                }) {
                    HStack(spacing: 4) {
                        if viewModel.differentialDiagnosis.isEmpty {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(viewModel.differentialDiagnosis.isEmpty ? "Formulate" : "Refine")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(NotesTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NotesTheme.accent.opacity(0.1), in: Capsule())
                }
            }
            
            if viewModel.differentialDiagnosis.isEmpty {
                EmptyHypothesisState()
            } else {
                VStack(spacing: 12) {
                    // Sort by confidence logic helps clinical readability
                    let sortedItems = viewModel.differentialDiagnosis.sorted(by: { $0.confidence > $1.confidence })
                    ForEach(sortedItems.indices, id: \.self) { index in
                        HypothesisCard(item: sortedItems[index], rank: index + 1)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.differentialDiagnosis)
            }
        }
    }
}

// MARK: - 🧠 HEADER COMPONENT
struct ReasoningHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .bold))
                Text("Clinical Reasoning")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .foregroundStyle(NotesTheme.accent)
            
            VStack(alignment: .leading, spacing: 10) {
                bulletText("Review your prioritized differential diagnosis.")
                bulletText("Each hypothesis includes clinical likelihood and rationale.")
                bulletText("Tap 'Refine' to modify or add new hypotheses.")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotesTheme.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(NotesTheme.accent.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Helper
    @ViewBuilder
    private func bulletText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NotesTheme.accent)
            
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 📋 COMPONENT: HYPOTHESIS CARD
struct HypothesisCard: View {
    let item: DifferentialItem
    let rank: Int
    
    // Dynamic color based on confidence level
    private var confidenceColor: Color {
        if item.confidence >= 0.7 { return NotesTheme.confidenceHigh }
        if item.confidence >= 0.4 { return NotesTheme.confidenceMed }
        return NotesTheme.confidenceLow
    }
    
    private var likelihoodText: String {
        switch item.confidence {
        case 0.0..<0.2: return "Unlikely"
        case 0.2..<0.5: return "Possible"
        case 0.5..<0.8: return "Probable"
        default: return "Definitive"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Rank, Diagnosis Name & Probability
            HStack(alignment: .center, spacing: 16) {
                // Rank Badge
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(NotesTheme.accent, in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.diagnosis)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NotesTheme.primaryText)
                    
                    HStack(spacing: 8) {
                        Text(likelihoodText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(confidenceColor)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text("\(Int(item.confidence * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(confidenceColor)
                    }
                }
                
                Spacer()
            }
            
            // Probability Bar (Scientific Visual)
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(confidenceColor)
                            .frame(width: geo.size.width * item.confidence, height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("Low").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("High").font(.caption2).foregroundStyle(.secondary)
                }
            }
            
            // Rationale (Contextual Logic)
            if !item.rationale.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Rationale", systemImage: "text.bubble")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(item.rationale)
                        .font(.callout)
                        .foregroundStyle(NotesTheme.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(NotesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: NotesTheme.shadowColor, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(NotesTheme.separator, lineWidth: 1)
        )
    }
}

// MARK: - 💭 COMPONENT: EMPTY STATE
struct EmptyHypothesisState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb.min.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(NotesTheme.accent.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Working Hypotheses")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NotesTheme.primaryText)
                
                Text("Develop a prioritized differential diagnosis with clinical rationale to proceed with diagnostic workup.")
                    .font(.subheadline)
                    .foregroundStyle(NotesTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(NotesTheme.accent.opacity(0.2))
        )
        .padding(.horizontal, 20)
    }
}