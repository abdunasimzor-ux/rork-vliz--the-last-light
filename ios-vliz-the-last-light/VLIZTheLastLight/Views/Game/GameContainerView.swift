import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @ObservedObject var session: GameSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: session.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .id(session.sceneID)
                .ignoresSafeArea()

            HurtVignette(pulse: session.hurtPulse, health: session.health, maxHealth: session.maxHealth)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if session.phase == .playing && !session.controlsHidden {
                TouchControlsView(input: session.input, weapon: session.weapon, hasArcBlade: session.hasArcBlade)
                    .transition(.opacity)
            }

            HUDView(session: session)

            if session.phase == .paused {
                PauseOverlay(session: session)
                    .transition(.opacity)
            }
            if session.phase == .defeated {
                DefeatOverlay(session: session)
                    .transition(.opacity)
            }
        }
        .background(Theme.void)
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .animation(.easeInOut(duration: 0.4), value: session.controlsHidden)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pause() }
        }
        .persistentSystemOverlays(.hidden)
    }
}

/// Magenta edge flash on damage, and a soft persistent glow when health is low.
struct HurtVignette: View {
    let pulse: Int
    let health: Int
    let maxHealth: Int
    @State private var flash = 0.0

    var body: some View {
        let low = Double(health) / Double(max(maxHealth, 1)) < 0.3 && health > 0
        RadialGradient(colors: [.clear, .clear, Theme.magenta.opacity(0.55)], center: .center, startRadius: 120, endRadius: 520)
            .opacity(max(flash, low ? 0.35 : 0))
            .onChange(of: pulse) { _, _ in
                flash = 1
                withAnimation(.easeOut(duration: 0.45)) { flash = 0 }
            }
    }
}
