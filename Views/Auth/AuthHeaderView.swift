import SwiftUI

struct AuthHeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image("logo")  // Reference the asset name from Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)  // Match or adjust size for consistency
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )  // Keep the gradient tint for visual appeal, or remove if logo has colors
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}
