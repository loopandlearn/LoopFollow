// LoopFollow
// LoopFollowLogo.swift

import SwiftUI

/// The LoopFollow mark, rebuilt in SwiftUI as the full app-icon face — a glassy
/// rounded square with the blue "loop" ring — so it has real visual mass when
/// tilted in 3D (a bare ring collapses to a line edge-on).
///
/// Geometry and layers mirror the icon source artwork (loopfollow-icon.svg,
/// 1024×1024): all fractions below are the SVG coordinates divided by 1024.
struct LoopFollowLogo: View {
    var size: CGFloat = 120

    // Colors sampled from the app icon (loopfollow-icon.svg).
    private let lightBlue = Color(red: 0.357, green: 0.639, blue: 0.961) // #5BA3F5
    private let midBlue = Color(red: 0.290, green: 0.565, blue: 0.886) // #4A90E2
    private let darkBlue = Color(red: 0.227, green: 0.482, blue: 0.784) // #3A7BC8

    var body: some View {
        let corner = size * 0.225
        let ringDiameter = size * 0.879 // outer r = 450
        let holeDiameter = size * 0.615 // inner r = 315

        ZStack {
            // Glassy near-white card (the icon face).
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.973, green: 0.976, blue: 0.980), // #F8F9FA
                            .white,
                            Color(red: 0.941, green: 0.949, blue: 0.961), // #F0F2F5
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Soft highlight fading down the top half of the card.
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.6), location: 0),
                    .init(color: .white.opacity(0.3), location: 0.2),
                    .init(color: .clear, location: 0.5),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Curved glass reflection over the upper half.
            radialGlow(
                width: size * 1.172, height: size * 0.781,
                stops: [
                    .init(color: .white.opacity(0.5), location: 0),
                    .init(color: .white.opacity(0.2), location: 0.5),
                    .init(color: .clear, location: 1),
                ]
            )
            .offset(y: -size * 0.25)
            .opacity(0.8)

            // Blue glass disc.
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: lightBlue, location: 0),
                            .init(color: midBlue, location: 0.3),
                            .init(color: midBlue, location: 0.7),
                            .init(color: darkBlue, location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: ringDiameter, height: ringDiameter)

            // Darkening toward the disc's outer edge for depth.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .clear, location: 0.7),
                            .init(color: .black.opacity(0.15), location: 0.85),
                            .init(color: .black.opacity(0.25), location: 1),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: ringDiameter / 2
                    )
                )
                .frame(width: ringDiameter, height: ringDiameter)

            // White hole that turns the disc into the loop ring.
            Circle()
                .fill(Color.white.opacity(0.98))
                .frame(width: holeDiameter, height: holeDiameter)

            // Glass highlight on the white hole.
            radialGlow(
                width: size * 0.742, height: size * 0.391,
                stops: [
                    .init(color: .white.opacity(0.4), location: 0),
                    .init(color: .white.opacity(0.1), location: 0.6),
                    .init(color: .clear, location: 1),
                ]
            )
            .offset(y: -size * 0.129)
            .opacity(0.7)

            // Broad sheen across the top of the ring; its lower edge draws the
            // glass "cut line" just below the middle of the icon.
            Ellipse()
                .fill(Color.white.opacity(0.25))
                .frame(width: size * 0.82, height: size * 0.488)
                .offset(y: -size * 0.188)
                .blur(radius: size * 0.003)

            // Subtle shadow pooling under the ring.
            Ellipse()
                .fill(Color.black.opacity(0.05))
                .frame(width: size * 0.879, height: size * 0.195)
                .offset(y: size * 0.184)
                .blur(radius: size * 0.002)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    /// Elliptical radial glow: SwiftUI's RadialGradient is circular, so draw it
    /// in a circle and squash vertically to match the SVG's elliptical gradients.
    private func radialGlow(width: CGFloat, height: CGFloat, stops: [Gradient.Stop]) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: stops),
                    center: .center,
                    startRadius: 0,
                    endRadius: width / 2
                )
            )
            .frame(width: width, height: width)
            .scaleEffect(x: 1, y: height / width)
    }
}

/// LoopFollow logo that lands like a coin: it starts edge-on (rotated 90° about
/// the vertical axis) and springs open to face the viewer, overshooting a little
/// past flat and rocking back to rest. Respects Reduce Motion by rendering flat.
struct AnimatedLoopFollowLogo: View {
    var size: CGFloat = 140

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 90

    var body: some View {
        LoopFollowLogo(size: size)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            // Grounding shadow so the landing reads as dimensional.
            .shadow(color: .black.opacity(0.28), radius: size * 0.08, x: 0, y: size * 0.06)
            .onAppear {
                if reduceMotion {
                    angle = 0
                } else {
                    withAnimation(.spring(response: 0.85, dampingFraction: 0.5).delay(0.15)) {
                        angle = 0
                    }
                }
            }
    }
}
