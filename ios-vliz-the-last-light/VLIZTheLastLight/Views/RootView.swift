import Combine
import SwiftUI

/// Top-level flow: menu → briefing → (cinematic) → game → mission complete.
@MainActor
final class AppRouter: ObservableObject {
    enum Screen: Equatable {
        case menu
        case briefing
        case cinematic(launchAfter: Bool)
        case game
        case complete(MissionResult)
    }

    @Published var screen: Screen = .menu
    @Published private(set) var session: GameSession?

    func launch(_ mission: MissionDefinition) {
        if !ProgressionManager.shared.seenIntro {
            screen = .cinematic(launchAfter: true)
        } else {
            startGame(mission)
        }
    }

    func startGame(_ mission: MissionDefinition) {
        let s = GameSession(mission: mission)
        s.onVictory = { [weak self] result in
            self?.screen = .complete(result)
            self?.session = nil
        }
        s.onQuit = { [weak self] in
            self?.session = nil
            self?.screen = .menu
            AudioManager.shared.playMusic(.menu)
        }
        session = s
        screen = .game
    }

    func finishCinematic(launchAfter: Bool) {
        ProgressionManager.shared.markIntroSeen()
        if launchAfter {
            startGame(Campaign.mission001)
        } else {
            screen = .briefing
            AudioManager.shared.playMusic(.menu)
        }
    }

    func toMenu() {
        session = nil
        screen = .menu
        AudioManager.shared.playMusic(.menu)
    }
}

struct RootView: View {
    @StateObject private var router = AppRouter()
    @ObservedObject private var progress = ProgressionManager.shared

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()
            switch router.screen {
            case .menu:
                MainMenuView(onPlay: { router.screen = .briefing })
                    .transition(.opacity)
            case .briefing:
                BriefingView(
                    onBack: { router.screen = .menu },
                    onLaunch: { router.launch(Campaign.mission001) },
                    onWatchIntro: { router.screen = .cinematic(launchAfter: false) }
                )
                .transition(.opacity)
            case .cinematic(let launchAfter):
                CinematicView { router.finishCinematic(launchAfter: launchAfter) }
                    .transition(.opacity)
            case .game:
                if let session = router.session {
                    GameContainerView(session: session)
                        .transition(.opacity)
                }
            case .complete(let result):
                MissionCompleteView(
                    result: result,
                    onContinue: { router.toMenu() },
                    onReplay: { router.startGame(Campaign.mission001) }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: router.screen)
        .onAppear { AudioManager.shared.playMusic(.menu) }
    }
}
