import SwiftUI

struct AnimatedAvatarView: View {
    let isBirthday: Bool
    let size: CGFloat // Customizable size (e.g., 72 for Dashboard, 100 for Profile)

    @State private var gradientRotation: Double = 0

    // Computed properties for proportional elements
    private var borderSize: CGFloat { size + 3 } // Border slightly larger than avatar
    private var crownOffsetX: CGFloat { size * 0.45 } // Proportional horizontal offset
    private var crownOffsetY: CGFloat { -size * 0.45 } // Proportional vertical offset
    private var crownFontSize: Font { size > 80 ? .title : .title3 } // Larger crown for bigger avatars

    var body: some View {
        ZStack {
            ProfileAvatarView()
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())

            if isBirthday {
                // Optimized: Use TimelineView instead of Timer for better performance
                TimelineView(.animation(minimumInterval: 0.03, paused: false)) { context in
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]),
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: borderSize, height: borderSize)
                        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 60))
                }

                // The crown icon (size and offset adjusted proportionally)
                Image(systemName: "crown.fill")
                    .font(crownFontSize)
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .rotationEffect(.degrees(32))
                    .offset(x: crownOffsetX, y: crownOffsetY)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
