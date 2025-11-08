// Views/DebriefView.swift

import SwiftUI

struct DebriefView: View {
    let debrief: ProfessionalEvaluationResult.DebriefSection
    
    // This view is now a simple, reusable content view.
    // It has no navigation logic of its own.
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                finalDiagnosisSection
                keyLearningPointSection
                alternativeStrategySection
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - ViewBuilder Sub-components (Refined for Clarity)
    
    @ViewBuilder
    private var finalDiagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Final Diagnosis", systemImage: "stethoscope")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
            
            Text(debrief.finalDiagnosis)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background)
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var keyLearningPointSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Learning Point", systemImage: "lightbulb.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.orange)
            
            Text(debrief.mainLearningPoint)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background)
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var alternativeStrategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested Alternative Strategy", systemImage: "arrow.triangle.branch")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.green)
            
            Text(debrief.alternativeStrategy)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background)
                .cornerRadius(12)
        }
    }
}
