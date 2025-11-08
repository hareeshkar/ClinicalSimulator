// Views/CategoryCardView.swift

import SwiftUI

struct CategoryCardView: View {
    // MARK: - Properties
    let specialty: String
    let iconName: String
    let caseCount: Int
    let color: Color // The specialty color is now passed in for the glow effect.
    
    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Layer 1: Background Material
            // Using a thicker material for a more pronounced depth effect.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background.secondary)

            // Layer 2: Subtle Glow
            // This adds a soft, colored light that makes the card feel more dynamic.
            glowOverlay

            // Layer 3: Content
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(color) // Icon is now colored
                
                Spacer()
                
                Text(specialty)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(caseCount) Cases")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .aspectRatio(1.0, contentMode: .fit)
        // A very subtle stroke helps define the card's edge.
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - ViewBuilder Sub-components
    
    /// A soft, colored glow that emanates from the top-left, adding depth and personality.
    @ViewBuilder
    private var glowOverlay: some View {
        Circle()
            .fill(color)
            .blur(radius: 60)
            .opacity(0.4)
            .frame(width: 120, height: 120)
            .offset(x: -60, y: -60)
            .allowsHitTesting(false) // Ensures the glow doesn't interfere with taps
    }
}
