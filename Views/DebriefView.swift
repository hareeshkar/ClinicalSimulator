import SwiftUI
import CoreHaptics

// MARK: - 🏥 CLINICAL DEBRIEF THEME
private enum DebriefTheme {
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let accent = Color.blue // Consistent with evaluation view
    static let secondaryAccent = Color.teal // Insightful
    static let tertiaryAccent = Color.orange // Action-oriented
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

// MARK: - 📐 HELPER EXTENSIONS
private extension View {
    func debriefCard(color: Color = DebriefTheme.accent) -> some View {
        self
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            )
    }
}

struct DebriefView: View {
    let debrief: ProfessionalEvaluationResult.DebriefSection
    @State private var isVisible = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 1. The "Big Reveal" Header
                DiagnosisRevealCard(diagnosis: debrief.finalDiagnosis)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
                
                // 2. Clinical Pearl (The "Why")
                InsightCard(
                    title: "Clinical Pearl",
                    content: debrief.mainLearningPoint,
                    icon: "lightbulb.max.fill",
                    accent: DebriefTheme.secondaryAccent
                )
                .opacity(isVisible ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isVisible)
                
                // 3. Strategy Correction (The "How")
                InsightCard(
                    title: "Refined Strategy",
                    content: debrief.alternativeStrategy,
                    icon: "arrow.branch",
                    accent: DebriefTheme.tertiaryAccent
                )
                .opacity(isVisible ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: isVisible)
                
                Spacer(minLength: 60)
            }
            .padding(20)
        }
        .background(DebriefTheme.background.ignoresSafeArea())
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - 🏥 COMPONENT: DIAGNOSIS REVEAL
struct DiagnosisRevealCard: View {
    let diagnosis: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("FINAL CLINICAL DIAGNOSIS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(DebriefTheme.textSecondary)
            
            Text(diagnosis)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(DebriefTheme.textPrimary)
                .padding(.horizontal)
            
            Capsule()
                .fill(DebriefTheme.accent.opacity(0.3))
                .frame(width: 60, height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(DebriefTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: DebriefTheme.accent.opacity(0.05), radius: 15, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DebriefTheme.accent.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - 💡 COMPONENT: INSIGHT CARD
struct InsightCard: View {
    let title: String
    let content: String
    let icon: String
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                }
                
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(accent)
            }
            
            Text(content)
                .font(.system(.body, design: .serif))
                .foregroundStyle(DebriefTheme.textPrimary)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .debriefCard(color: accent)
    }
}