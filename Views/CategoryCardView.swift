// This is the card in the cases tab
import SwiftUI

struct CategoryCardView: View {
    // MARK: - Properties
    let specialty: String
    let iconName: String
    let caseCount: Int
    let color: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // LAYER 1: Cinematic Backdrop (Image or Organic Texture)
            SpecialtyCinematicBackground(specialty: specialty, color: color)
            
            // LAYER 2: "Light Leak" Overlay
            // Adds a cinematic shadow gradient so text is always readable
            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            
            // LAYER 3: Architectural Icon (Watermark)
            // Subtle, large, and blending into the background like a texture
            GeometryReader { geo in
                Image(systemName: iconName)
                    .font(.system(size: 180, weight: .black)) // Massive
                    .foregroundStyle(Color.white)
                    .blur(radius: 1)
                    .opacity(0.06) // Very subtle
                    .rotationEffect(.degrees(-5))
                    .offset(x: geo.size.width * 0.55, y: -geo.size.height * 0.1)
                    .blendMode(.overlay)
            }
            
            // LAYER 4: Editorial Content
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                
                // Kicker: Clinical Series
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 2, height: 12)
                    
                    // Removed "CLINICAL SCENARIOS" as per request
                }
                
                // Headline: Specialty (Serif = Human/Journal feel)
                Text(specialty)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(.bottom, 2)
                
                // Context Data
                HStack {
                    Text("View All Cases")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                    
                    Spacer()
                    
                    // Navigate Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .overlay(
            // Case Count Badge in top right
            Text("\(caseCount)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(.white, in: Circle())
                .padding(.trailing, 12)
                .padding(.top, 12),
            alignment: .topTrailing
        )
        .aspectRatio(1.0, contentMode: .fit) // Boxy square appearance
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Physical Depth Shadow
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}


