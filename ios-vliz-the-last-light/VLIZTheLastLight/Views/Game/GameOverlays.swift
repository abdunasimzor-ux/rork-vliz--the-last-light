import SwiftUI

struct OverlayButton: View {
    let title: String
    let symbol: String
    var primary: Bool = false
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            AudioManager.shared.play(destructive ? .uiBack : .uiTap)
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                    .foregroundStyle(destructive ? Theme.magenta : (primary ? Theme.cyan : Theme.textSecondary))
                Text(title.uppercased())
                    .trackedHeading(13, tracking: 2.5)
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .contentShape(Rectangle())
            .vlizPanel(highlighted: primary)
        }
        .buttonStyle(VlizPressStyle())
    }
}

struct PauseOverlay: View {
    @ObservedObject var session: GameSession
    @ObservedObject private var progress = ProgressionManager.shared
    @State private var confirmQuit = false

    var body: some View {
        ZStack {
            Theme.void.opacity(0.72).ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.4))

            HStack(alignment: .center, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PAUSED")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(8)
                        .foregroundStyle(Theme.textPrimary)
                    Text("MISSION \(session.mission.code) · \(session.mission.title.uppercased())")
                        .trackedHeading(10, tracking: 2.5, color: Theme.textSecondary)
                    GlowRule().frame(width: 240)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(session.mission.objectives.enumerated()), id: \.element.id) { i, obj in
                            HStack(spacing: 8) {
                                Image(systemName: i < session.completedCount ? "checkmark.diamond.fill" : (i == session.completedCount ? "diamond.inset.filled" : "diamond"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(i <= session.completedCount ? Theme.cyan : Theme.textSecondary.opacity(0.6))
                                Text(obj.text)
                                    .font(.system(size: 12))
                                    .strikethrough(i < session.completedCount, color: Theme.textSecondary)
                                    .foregroundStyle(i < session.completedCount ? Theme.textSecondary : Theme.textPrimary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(width: 280, alignment: .leading)

                VStack(spacing: 9) {
                    OverlayButton(title: "Resume", symbol: "play.fill", primary: true) { session.resume() }
                    if session.hasCheckpoint {
                        OverlayButton(title: "Last checkpoint", symbol: "flag.fill") { session.restart(fromCheckpoint: true) }
                    }
                    OverlayButton(title: "Restart mission", symbol: "arrow.counterclockwise") { session.restart(fromCheckpoint: false) }
                    HStack(spacing: 9) {
                        ToggleChip(title: "Shake", on: progress.settings.screenShake) {
                            progress.updateSettings { $0.screenShake.toggle() }
                        }
                        ToggleChip(title: "Music", on: progress.settings.musicVolume > 0) {
                            progress.updateSettings { $0.musicVolume = $0.musicVolume > 0 ? 0 : 0.6 }
                        }
                    }
                    OverlayButton(title: "Quit to menu", symbol: "xmark", destructive: true) { confirmQuit = true }
                }
                .frame(width: 270)
            }
        }
        .confirmationDialog("Quit the mission?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Quit to menu", role: .destructive) { session.quit() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Fragments banked at checkpoints are kept. Progress since the last checkpoint is lost.")
        }
    }
}

struct ToggleChip: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            AudioManager.shared.play(.uiTap)
            action()
        } label: {
            HStack(spacing: 6) {
                Circle().fill(on ? Theme.cyan : Theme.textSecondary.opacity(0.4)).frame(width: 7, height: 7)
                Text(title.uppercased()).trackedHeading(10, tracking: 2, color: on ? Theme.textPrimary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .vlizPanel(cut: 6)
        }
        .buttonStyle(VlizPressStyle())
        .accessibilityValue(on ? "On" : "Off")
    }
}

struct DefeatOverlay: View {
    @ObservedObject var session: GameSession
    @State private var appear = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Theme.void.opacity(0.6), Theme.magenta.opacity(0.25)], center: .center, startRadius: 60, endRadius: 600)
                .background(Theme.void.opacity(0.65))
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("SIGNAL LOST")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(10)
                    .foregroundStyle(Theme.magenta)
                    .shadow(color: Theme.magenta.opacity(0.7), radius: 14)
                    .scaleEffect(appear ? 1 : 1.15)
                    .opacity(appear ? 1 : 0)
                Text("Kael has fallen. The light flickers, but it has not gone out.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                GlowRule(color: Theme.magenta).frame(width: 300)
                VStack(spacing: 9) {
                    if session.hasCheckpoint {
                        OverlayButton(title: "Retry from checkpoint", symbol: "flag.fill", primary: true) { session.restart(fromCheckpoint: true) }
                    }
                    OverlayButton(title: "Restart mission", symbol: "arrow.counterclockwise", primary: !session.hasCheckpoint) {
                        session.restart(fromCheckpoint: false)
                    }
                    OverlayButton(title: "Quit to menu", symbol: "xmark", destructive: true) { session.quit() }
                }
                .frame(width: 300)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
        }
    }
}
