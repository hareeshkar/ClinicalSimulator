import SwiftUI

struct AnimatedAvatarView: View {
    // MARK: - Configuration
    let isBirthday: Bool
    let size: CGFloat
    
    // MARK: - Constants
    private var badgeSize: CGFloat { size * 0.35 }
    private var badgeOffset: CGFloat { size * 0.35 }
    
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            
            ZStack {
                // Layer 2: The Halo Ring (Metallic Physics) - Reduced size to minimize diffusion
                if isBirthday {
                    GoldenHaloLayer(size: size, time: time)
                } else {
                    ClinicalStatusRing(size: size, time: time)
                }
                
                // Layer 3: The Avatar Container
                // High-fidelity glass masking
                ProfileAvatarView()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                .linearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    // Subtle organic hover effect
                    .scaleEffect(1.0 + (sin(time * 1.5) * 0.005))
                
                // Layer 4: The Jewelry Badge (Enamel Pin)
                if isBirthday {
                    EnamelBadgeView(icon: "star.fill", size: badgeSize)
                        .offset(x: badgeOffset, y: -badgeOffset)
                        .transition(.scale.combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.6)))
                }
            }
        }
    }
}

// MARK: - 🏆 COMPONENT: GOLDEN HALO (Prestige Mode)
/// Renders a shimmering, rotating metallic ring using interference patterns.
struct GoldenHaloLayer: View {
    let size: CGFloat
    let time: TimeInterval
    
    // Warm metallic gradient: Gold -> Amber -> White Gold -> Gold
    private let goldGradient = AngularGradient(
        stops: [
            .init(color: Color(red: 0.85, green: 0.65, blue: 0.13), location: 0.0), // Deep Gold
            .init(color: Color(red: 1.0, green: 0.9, blue: 0.6), location: 0.2),    // Specular Highlight
            .init(color: Color(red: 0.85, green: 0.65, blue: 0.13), location: 0.4), // Deep Gold
            .init(color: Color(red: 0.6, green: 0.4, blue: 0.0), location: 0.5),    // Dark Amber (Shadow)
            .init(color: Color(red: 0.85, green: 0.65, blue: 0.13), location: 0.6), // Deep Gold
            .init(color: Color(red: 1.0, green: 0.95, blue: 0.8), location: 0.8),   // White Gold
            .init(color: Color(red: 0.85, green: 0.65, blue: 0.13), location: 1.0)  // Loop
        ],
        center: .center
    )
    
    var body: some View {
        ZStack {
            // Ring 1: Main Structure (Slow Rotate)
            Circle()
                .stroke(goldGradient, lineWidth: 3)
                .rotationEffect(.degrees(time * 20))
            
            // Ring 2: Interference Layer (Fast Rotate + Blend)
            // This creates the "shimmering light" effect as it passes over Ring 1
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.6), .white.opacity(0.0)],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .rotationEffect(.degrees(time * -45)) // Counter-rotation
                .blendMode(.overlay)
                .scaleEffect(1.05) // Slightly offset for depth
        }
        .frame(width: size + 4, height: size + 4)
        // Physics-based breathing of the halo itself
        .scaleEffect(1.0 + (sin(time * 3) * 0.02))
        // Slight blur for gas-like diffusion
        .blur(radius: 0.8)
    }
}

// MARK: - ⚕️ COMPONENT: CLINICAL STATUS RING (Standard Mode)
/// A subtle, professional indicator of system status.
struct ClinicalStatusRing: View {
    let size: CGFloat
    let time: TimeInterval
    
    var body: some View {
        ZStack {
            // The "Breathing" Glow - Diffusion layer
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.blue.opacity(0.15),
                            Color.blue.opacity(0.05),
                            Color.blue.opacity(0.15)
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .rotationEffect(.degrees(time * 15))
                .blur(radius: 1.5) // Slight blur for gas-like diffusion
            
            // The "Idle" Pulse - Main ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.blue,  // Medical blue
                            Color.blue.opacity(0.8),   // Bright medical blue
                            Color.blue   // Medical blue
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .rotationEffect(.degrees(time * 15))
        }
        .frame(width: size + 4, height: size + 4)
        // Physics-based breathing scale
        .scaleEffect(1.0 + (sin(time * 2) * 0.03))
    }
}

// MARK: - 🎖️ COMPONENT: ENAMEL BADGE (Jewelry Rendering)
/// Renders an icon as a physical, floating pin with glass and metal properties.
struct EnamelBadgeView: View {
    let icon: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 1. Drop Shadow (Physicality)
            Circle()
                .fill(.black.opacity(0.3))
                .blur(radius: 2)
                .offset(y: 2)
            
            // 2. Metallic Rim (Gold Container)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.9, blue: 0.6), // Light Gold
                            Color(red: 0.7, green: 0.5, blue: 0.1)  // Dark Gold
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 3. Enamel Face (The "Paint")
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(2) // Inset to show the rim
            
            // 4. The Icon (Engraved)
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .black))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 0, x: 0, y: 1) // Inner shadow simulation
            
            // 5. Specular Highlight (Glass Cap)
            // This is the "Gloss" that makes it look like a pin.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(2)
                .mask(
                    Circle() // Mask to top half only
                        .padding(2)
                        .offset(y: -size * 0.25)
                )
        }
        .frame(width: size, height: size)
        // Floating Physics
        .rotationEffect(.degrees(15)) // Tilted slightly like a pinned badge
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 40) {
            AnimatedAvatarView(isBirthday: true, size: 80)
            AnimatedAvatarView(isBirthday: false, size: 80)
        }
    }
}