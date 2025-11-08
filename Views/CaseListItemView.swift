// Views/CaseListItemView.swift

import SwiftUI

/// A visually refined, data-driven list item that presents a clinical case.
/// This version is optimized for readability, spacing, and overall polish, balancing
/// vibrant aesthetics with a clear user experience.
struct CaseListItemView: View {
    // MARK: - Properties
    
    let patientCase: PatientCase
    var session: StudentSession? = nil
    var action: ActionType? = nil
    
    enum ActionType { case start, `continue`, review }
    
    @State private var hasAppeared = false
    
    // MARK: - Private Helpers
    
    private var specialtyColor: Color {
        SpecialtyDetailsProvider.color(for: patientCase.specialty)
    }
    
    private var specialtyIconName: String {
        SpecialtyDetailsProvider.details(for: patientCase.specialty).iconName
    }
    
    // MARK: - Main Body
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [specialtyColor.opacity(0.5), specialtyColor.opacity(0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // ✅ FIX: Switched to .regularMaterial for MUCH better readability and contrast.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)

            VStack(alignment: .leading, spacing: 0) {
                headerSection
                
                Spacer(minLength: 12)
                
                footerSection
                    .animation(.easeInOut(duration: 0.3), value: action)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // ✅ POLISH: Softer, more subtle shadow for a cleaner look.
        .shadow(color: specialtyColor.opacity(0.2), radius: 8, x: 0, y: 4)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    hasAppeared = true
                }
            }
        }
    }
    
    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: specialtyIconName)
                .font(.title.weight(.semibold))
                .foregroundStyle(specialtyColor)
                .frame(width: 32)
                .padding(.top, 2)
            
            // ✅ FIX: Reworked layout for better spacing and visual grouping.
            VStack(alignment: .leading, spacing: 6) {
                // The Title and Difficulty tag are now grouped in their own HStack.
                HStack(alignment: .top) {
                    Text(patientCase.chiefComplaint)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .layoutPriority(1) // Ensures text gets space first
                    
                    Spacer(minLength: 8) // Provides flexible space
                    
                    DifficultyTagView(difficulty: patientCase.difficulty)
                }

                Text(patientCase.specialty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var footerSection: some View {
        if let actionType = action {
            footerContent(for: actionType)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private func footerContent(for actionType: ActionType) -> some View {
        switch actionType {
        case .start:
            StartActionView(color: specialtyColor)
        case .continue:
            // Pass specialty color into the enhanced ContinueStatusView
            ContinueStatusView(color: specialtyColor)
        case .review:
            if let score = session?.score {
                ScoreStatusView(score: score, color: specialtyColor, animate: hasAppeared)
            }
        }
    }
}

// MARK: - Status Subviews

struct StartActionView: View {
    let color: Color

    var body: some View {
        HStack {
            Label("Start New Case", systemImage: "play.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            
            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .overlay(Divider(), alignment: .top)
    }
}

struct ContinueStatusView: View {
    let color: Color

    var body: some View {
        HStack {
            // Green dot placed in front of "In Progress"
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .padding(.top, 1)

                Text("In Progress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // "Resume" CTA with play icon next to it
            HStack(spacing: 8) {
                Text("Resume")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)

                Image(systemName: "play.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
        .overlay(Divider(), alignment: .top)
    }
}

struct ScoreStatusView: View {
    let score: Double
    let color: Color
    let animate: Bool
    
    @State private var progress: Double = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Completed Score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(score))%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
            }
            
            ProgressView(value: progress, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .clipShape(Capsule())
        }
        .padding(.top, 12)
        .overlay(Divider(), alignment: .top)
        .onChange(of: animate) { oldValue, newValue in
            if newValue {
                // ✅ POLISH: Tuned spring animation for a snappier feel.
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    progress = score
                }
            }
        }
    }
}


// MARK: - Difficulty Tag
struct DifficultyTagView: View {
    let difficulty: String
    
    var body: some View {
        Text(difficulty.uppercased())
            .font(.caption)
            .fontWeight(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficultyColor.opacity(0.15))
            .foregroundStyle(difficultyColor)
            .cornerRadius(6)
            // Ensures the tag doesn't wrap unnecessarily
            .fixedSize(horizontal: true, vertical: false)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case "Beginner": return .green
        case "Intermediate": return .orange
        case "Advanced": return .red
        default: return .gray
        }
    }
}


// MARK: - Preview (Unchanged, but will render the new design)
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            let mockCaseStart = PatientCase(
                caseId: "PREVIEW-02", title: "Community-Acquired Pneumonia", specialty: "Internal Medicine", difficulty: "Beginner",
                chiefComplaint: "An 82-year-old nursing home resident with a 3-day history of productive cough, fever, malaise, and new-onset confusion.",
                fullCaseJSON: "{}"
            )
            
            let mockCaseContinue = PatientCase(
                caseId: "PREVIEW-03", title: "Asthma Exacerbation", specialty: "Pediatrics", difficulty: "Intermediate",
                chiefComplaint: "A 7-year-old with a known history of severe asthma presents with audible wheezing and shortness of breath unresponsive to home inhaler.",
                fullCaseJSON: "{}"
            )

            let mockCaseReview = PatientCase(
                caseId: "PREVIEW-01", title: "Acute Myocardial Infarction", specialty: "Cardiology", difficulty: "Advanced",
                chiefComplaint: "Crushing, substernal chest pain radiating to the left arm and jaw, associated with diaphoresis and nausea.",
                fullCaseJSON: "{}"
            )
            
            // ✅ FIX: Create a mock user just for the preview.
            let mockUser = User(fullName: "Preview User", email: "preview@example.com", password: "password")

            let mockSessionContinue = StudentSession(caseId: "PREVIEW-03", user: mockUser) // ✅ PASS USER
            let mockSessionReview: StudentSession = {
                let session = StudentSession(caseId: "PREVIEW-01", user: mockUser) // ✅ PASS USER
                session.score = 68
                return session
            }()
            
            Text("Start a New Case").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
            CaseListItemView(patientCase: mockCaseStart, action: .start)
            
            Text("Continue Where You Left Off").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
            CaseListItemView(patientCase: mockCaseContinue, session: mockSessionContinue, action: .continue)

            Text("Review Completed Cases").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
            CaseListItemView(patientCase: mockCaseReview, session: mockSessionReview, action: .review)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
