import SwiftUI

/// Opening cinematic: layered Ken Burns scenes, lighting effects, letterbox and subtitles.
struct CinematicView: View {
    let onFinish: () -> Void

    @State private var start = Date()
    @State private var finished = false

    private let scenes = StoryData.openingCinematic
    private var total: TimeInterval { scenes.reduce(0) { $0 + $1.duration } }
    private let fade: TimeInterval = 1.0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                let (index, local) = locate(t)
                ZStack {
                    Color.black
                    if index > 0 && local < fade {
                        sceneLayer(scenes[index - 1], local: scenes[index - 1].duration + local, size: geo.size)
                    }
                    sceneLayer(scenes[index], local: local, size: geo.size)
                        .opacity(index == 0 ? min(1, local / 1.4) : min(1, local / fade))

                    effectLayer(scenes[index].effect, local: local, time: t)

                    // Letterbox
                    VStack {
                        Color.black.frame(height: geo.size.height * 0.1)
                        Spacer()
                        Color.black.frame(height: geo.size.height * 0.1)
                    }
                    .ignoresSafeArea()

                    subtitle(scenes[index], local: local)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, geo.size.height * 0.1 + 14)

                    // Fade out at the very end
                    Color.black.opacity(max(0, min(1, (t - (total - 1.2)) / 1.2)))
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
                .onChange(of: t >= total) { _, done in
                    if done { finish() }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Haptics.tap()
                AudioManager.shared.play(.uiTap)
                finish()
            } label: {
                HStack(spacing: 6) {
                    Text("SKIP").tracking(3)
                    Image(systemName: "forward.end.fill")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Capsule().fill(Theme.midnight.opacity(0.7)))
                .overlay(Capsule().stroke(Theme.textSecondary.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(VlizPressStyle())
            .padding(.top, 20)
            .padding(.trailing, 28)
        }
        .background(Color.black)
        .onAppear {
            start = Date()
            AudioManager.shared.playMusic(.menu, fade: 0.5)
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }

    private func locate(_ t: TimeInterval) -> (Int, TimeInterval) {
        var acc: TimeInterval = 0
        for (i, s) in scenes.enumerated() {
            if t < acc + s.duration || i == scenes.count - 1 {
                return (i, max(0, t - acc))
            }
            acc += s.duration
        }
        return (0, 0)
    }

    private func sceneLayer(_ s: CinematicScene, local: TimeInterval, size: CGSize) -> some View {
        let p = CGFloat(min(1, max(0, local / s.duration)))
        let eased = p * p * (3 - 2 * p)
        let zoom = s.zoom.0 + (s.zoom.1 - s.zoom.0) * eased
        return Image(s.imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(zoom)
            .offset(x: size.width * s.drift * (eased - 0.5) * 2)
            .clipped()
    }

    @ViewBuilder
    private func effectLayer(_ effect: CinematicEffect, local: TimeInterval, time: TimeInterval) -> some View {
        switch effect {
        case .calm:
            ZStack {
                LinearGradient(colors: [Theme.midnight.opacity(0.4), .clear, Theme.void.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                MotesView(color: Theme.cyan, count: 24, intensity: 0.7)
            }
        case .fleet:
            // Ominous magenta pulses as the fleet arrives
            Theme.magenta
                .opacity(0.12 + 0.1 * sin(local * 2.2))
                .blendMode(.plusLighter)
        case .invasion:
            ZStack {
                Color(hex: 0xFF7A3D).opacity(0.1 + 0.08 * abs(sin(local * 7.3) * sin(local * 3.1)))
                    .blendMode(.plusLighter)
                // Occasional flash of distant explosions
                Color.white.opacity(flash(local, every: 2.6) * 0.35)
                MotesView(color: Color(hex: 0xFF7A3D), count: 30, intensity: 0.9)
            }
        case .settlement:
            ZStack {
                Theme.void.opacity(0.25)
                MotesView(color: Theme.textSecondary, count: 28, intensity: 0.6)
            }
        case .awakening:
            RadialGradient(colors: [Theme.cyan.opacity(0.1 + 0.25 * min(1, local / 6)), .clear],
                           center: .center, startRadius: 10, endRadius: 420)
                .blendMode(.plusLighter)
        }
    }

    private func flash(_ t: TimeInterval, every: TimeInterval) -> Double {
        let phase = t.truncatingRemainder(dividingBy: every)
        return phase < 0.15 ? 1 - phase / 0.15 : 0
    }

    @ViewBuilder
    private func subtitle(_ s: CinematicScene, local: TimeInterval) -> some View {
        let active = activeLine(s, local: local)
        ZStack {
            if let active {
                let line = active.0
                let alpha = active.1
                VStack(spacing: 4) {
                    if let speaker = line.speaker {
                        Text(speaker)
                            .trackedHeading(10, tracking: 3, color: Theme.cyan)
                    }
                    Text(line.text)
                        .font(.system(size: 16, weight: .medium))
                        .italic(line.speaker == nil)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black, radius: 6)
                }
                .opacity(alpha)
                .padding(.horizontal, 80)
            }
        }
    }

    private func activeLine(_ s: CinematicScene, local: TimeInterval) -> (DialogueLine, Double)? {
        var acc: TimeInterval = 0.4
        for line in s.lines {
            if local >= acc && local < acc + line.duration {
                let l = local - acc
                let alpha = min(1, l / 0.35, (line.duration - l) / 0.35)
                return (line, max(0, alpha))
            }
            acc += line.duration
        }
        return nil
    }
}
