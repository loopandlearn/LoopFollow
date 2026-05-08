// LoopFollow
// CelebrationOverlay.swift

import SwiftUI

/// Randomly triggered celebration animations on successful remote commands.
/// Appears roughly every 5–15 successful sends as a "surprise and delight" Easter egg.
/// Uses the full watch display for maximum visual impact.
struct CelebrationOverlay: View {
    @Binding var isActive: Bool
    @State private var animationType: CelebrationType = .confetti
    @State private var particles: [Particle] = []
    @State private var phase: Bool = false
    @State private var phase2: Bool = false

    enum CelebrationType: CaseIterable {
        case confetti, fireworks, sparkleRain, rainbowPulse, partyEmoji
    }

    var body: some View {
        if isActive {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    switch animationType {
                    case .confetti:
                        confettiView(width: w, height: h)
                    case .fireworks:
                        fireworksView(width: w, height: h)
                    case .sparkleRain:
                        sparkleRainView(width: w, height: h)
                    case .rainbowPulse:
                        rainbowPulseView(width: w, height: h)
                    case .partyEmoji:
                        partyEmojiView(width: w, height: h)
                    }
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                animationType = CelebrationType.allCases.randomElement() ?? .confetti
                phase = false
                phase2 = false
                generateParticles()
                // First wave
                withAnimation(.easeOut(duration: 3.5)) {
                    phase = true
                }
                // Second wave for some animations
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 3.0)) {
                        phase2 = true
                    }
                }
            }
        }
    }

    // MARK: - Randomization

    /// Returns true roughly every 5–15 sends (≈10% chance per send).
    static func shouldCelebrate() -> Bool {
        return Int.random(in: 1 ... 10) == 1
    }

    /// How long to show the celebration before dismissing (longer than normal 3s).
    static let displayDuration: TimeInterval = 5.0

    // MARK: - Particle Generation

    private struct Particle: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let targetX: Double
        let targetY: Double
        let size: Double
        let rotation: Double
        let delay: Double
        let color: Color
        let emoji: String
        let wave: Int // 1 or 2
    }

    private func generateParticles() {
        switch animationType {
        case .confetti:
            // Two waves of confetti covering the full screen
            let wave1: [Particle] = (0 ..< 40).map { _ in
                Particle(
                    x: 0, y: -20,
                    targetX: Double.random(in: -120 ... 120),
                    targetY: Double.random(in: 60 ... 220),
                    size: Double.random(in: 5 ... 10),
                    rotation: Double.random(in: 360 ... 1080),
                    delay: Double.random(in: 0 ... 0.5),
                    color: [.red, .blue, .green, .yellow, .orange, .pink, .purple, .mint, .cyan].randomElement()!,
                    emoji: "", wave: 1
                )
            }
            let wave2: [Particle] = (0 ..< 25).map { _ in
                Particle(
                    x: Double.random(in: -60 ... 60), y: -40,
                    targetX: Double.random(in: -120 ... 120),
                    targetY: Double.random(in: 40 ... 200),
                    size: Double.random(in: 6 ... 12),
                    rotation: Double.random(in: 360 ... 1080),
                    delay: Double.random(in: 0 ... 0.4),
                    color: [.red, .blue, .green, .yellow, .orange, .pink, .purple, .mint, .cyan].randomElement()!,
                    emoji: "", wave: 2
                )
            }
            particles = wave1 + wave2

        case .fireworks:
            // Multiple burst points across the screen
            var all: [Particle] = []
            let bursts: [(Double, Double, Double)] = [
                (0, -30, 0), (-40, -50, 0.3), (35, -20, 0.7),
                (-20, 10, 1.5), (30, -45, 1.8), (0, 0, 2.2),
            ]
            for (bx, by, baseDelay) in bursts {
                for _ in 0 ..< 12 {
                    let angle = Double.random(in: 0 ... (2 * .pi))
                    let dist = Double.random(in: 30 ... 90)
                    all.append(Particle(
                        x: bx, y: by,
                        targetX: bx + cos(angle) * dist,
                        targetY: by + sin(angle) * dist,
                        size: Double.random(in: 4 ... 8),
                        rotation: 0,
                        delay: baseDelay + Double.random(in: 0 ... 0.15),
                        color: [.red, .orange, .yellow, .cyan, .white, .pink, .green].randomElement()!,
                        emoji: "", wave: baseDelay < 1.0 ? 1 : 2
                    ))
                }
            }
            particles = all

        case .sparkleRain:
            // Dense sparkles falling across the full width, two waves
            particles = (0 ..< 30).map { i in
                let wave = i < 18 ? 1 : 2
                return Particle(
                    x: Double.random(in: -100 ... 100),
                    y: -120,
                    targetX: Double.random(in: -100 ... 100),
                    targetY: 160,
                    size: Double.random(in: 12 ... 22),
                    rotation: Double.random(in: -360 ... 360),
                    delay: Double.random(in: 0 ... (wave == 1 ? 1.5 : 0.8)),
                    color: [.yellow, .white, .orange, .cyan, .mint].randomElement()!,
                    emoji: "", wave: wave
                )
            }

        case .rainbowPulse:
            // Big rings that fill the entire display, two waves
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
            let wave1 = colors.enumerated().map { i, color in
                Particle(
                    x: 0, y: 0, targetX: 0, targetY: 0,
                    size: 300,
                    rotation: 0,
                    delay: Double(i) * 0.15,
                    color: color, emoji: "", wave: 1
                )
            }
            let wave2 = colors.reversed().enumerated().map { i, color in
                Particle(
                    x: 0, y: 0, targetX: 0, targetY: 0,
                    size: 300,
                    rotation: 0,
                    delay: Double(i) * 0.15,
                    color: color, emoji: "", wave: 2
                )
            }
            particles = wave1 + wave2

        case .partyEmoji:
            // Huge emoji bouncing in from all edges, two waves
            let emojis = ["🎉", "🥳", "🎊", "🪩", "✨", "💫", "⭐️", "🌟", "🎆", "🎇", "🍾", "🥂"]
            let wave1: [Particle] = (0 ..< 6).map { _ in
                let edge = Int.random(in: 0 ... 3)
                let startX: Double
                let startY: Double
                switch edge {
                case 0: startX = Double.random(in: -100 ... 100); startY = -140
                case 1: startX = Double.random(in: -100 ... 100); startY = 140
                case 2: startX = -140; startY = Double.random(in: -80 ... 80)
                default: startX = 140; startY = Double.random(in: -80 ... 80)
                }
                return Particle(
                    x: startX, y: startY,
                    targetX: Double.random(in: -50 ... 50),
                    targetY: Double.random(in: -50 ... 50),
                    size: Double.random(in: 40 ... 56),
                    rotation: Double.random(in: -30 ... 30),
                    delay: Double.random(in: 0 ... 0.6),
                    color: .white,
                    emoji: emojis.randomElement()!,
                    wave: 1
                )
            }
            let wave2: [Particle] = (0 ..< 5).map { _ in
                let edge = Int.random(in: 0 ... 3)
                let startX: Double
                let startY: Double
                switch edge {
                case 0: startX = Double.random(in: -100 ... 100); startY = -140
                case 1: startX = Double.random(in: -100 ... 100); startY = 140
                case 2: startX = -140; startY = Double.random(in: -80 ... 80)
                default: startX = 140; startY = Double.random(in: -80 ... 80)
                }
                return Particle(
                    x: startX, y: startY,
                    targetX: Double.random(in: -50 ... 50),
                    targetY: Double.random(in: -50 ... 50),
                    size: Double.random(in: 44 ... 60),
                    rotation: Double.random(in: -30 ... 30),
                    delay: Double.random(in: 0 ... 0.5),
                    color: .white,
                    emoji: emojis.randomElement()!,
                    wave: 2
                )
            }
            particles = wave1 + wave2
        }
    }

    // MARK: - Animation Views

    @ViewBuilder
    private func confettiView(width: Double, height: Double) -> some View {
        ForEach(particles) { p in
            let active = p.wave == 1 ? phase : phase2
            RoundedRectangle(cornerRadius: 2)
                .fill(p.color)
                .frame(width: p.size, height: p.size * 2)
                .rotationEffect(.degrees(active ? p.rotation : 0))
                .position(
                    x: width / 2 + (active ? p.targetX : p.x),
                    y: height / 2 + (active ? p.targetY : p.y)
                )
                .opacity(active ? 0 : 1)
                .animation(
                    .easeOut(duration: 3.0).delay(p.delay),
                    value: active
                )
        }
    }

    @ViewBuilder
    private func fireworksView(width: Double, height: Double) -> some View {
        ForEach(particles) { p in
            let active = p.wave == 1 ? phase : phase2
            Circle()
                .fill(p.color)
                .frame(width: active ? p.size : p.size * 3, height: active ? p.size : p.size * 3)
                .shadow(color: p.color, radius: 4)
                .position(
                    x: width / 2 + (active ? p.targetX : p.x),
                    y: height / 2 + (active ? p.targetY : p.y)
                )
                .opacity(active ? 0 : 1)
                .animation(
                    .easeOut(duration: 1.8).delay(p.delay),
                    value: active
                )
        }
    }

    @ViewBuilder
    private func sparkleRainView(width: Double, height: Double) -> some View {
        ForEach(particles) { p in
            let active = p.wave == 1 ? phase : phase2
            Image(systemName: "sparkle")
                .font(.system(size: p.size, weight: .bold))
                .foregroundColor(p.color)
                .shadow(color: p.color, radius: 6)
                .rotationEffect(.degrees(active ? p.rotation : 0))
                .position(
                    x: width / 2 + (active ? p.targetX : p.x),
                    y: height / 2 + (active ? p.targetY : p.y)
                )
                .opacity(active ? 0 : 0.95)
                .animation(
                    .easeIn(duration: 2.5).delay(p.delay),
                    value: active
                )
        }
    }

    @ViewBuilder
    private func rainbowPulseView(width: Double, height: Double) -> some View {
        ForEach(particles) { p in
            let active = p.wave == 1 ? phase : phase2
            Circle()
                .stroke(p.color, lineWidth: 6)
                .frame(width: active ? p.size : 0, height: active ? p.size : 0)
                .position(x: width / 2, y: height / 2)
                .opacity(active ? 0 : 0.9)
                .animation(
                    .easeOut(duration: 2.5).delay(p.delay),
                    value: active
                )
        }
    }

    @ViewBuilder
    private func partyEmojiView(width: Double, height: Double) -> some View {
        ForEach(particles) { p in
            let active = p.wave == 1 ? phase : phase2
            Text(p.emoji)
                .font(.system(size: p.size))
                .rotationEffect(.degrees(active ? p.rotation : 0))
                .position(
                    x: width / 2 + (active ? p.targetX : p.x),
                    y: height / 2 + (active ? p.targetY : p.y)
                )
                .scaleEffect(active ? 1.2 : 0.1)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.55).delay(p.delay),
                    value: active
                )
        }
    }
}
