import Combine
import SwiftUI
import SpriteKit

struct BossHUD: Equatable {
    var name: String
    var fraction: Double
    var phase: Int
    var vulnerable: Bool
}

struct Banner: Equatable, Identifiable {
    enum Style { case info, reward, danger }
    let id = UUID()
    let title: String
    let subtitle: String?
    let style: Style
}

/// Bridges the SpriteKit scene and the SwiftUI HUD/overlays. Publishes only on change.
@MainActor
final class GameSession: ObservableObject {
    enum Phase: Equatable { case playing, paused, defeated, ending }

    @Published var phase: Phase = .playing
    @Published private(set) var health = 100
    @Published private(set) var maxHealth = 100
    @Published private(set) var runFragments = 0
    @Published private(set) var weapon: WeaponID = .pulseBlaster
    @Published private(set) var hasArcBlade = false
    @Published private(set) var objective: ObjectiveDefinition?
    @Published private(set) var completedCount = 0
    @Published private(set) var dialogue: DialogueLine?
    @Published private(set) var banner: Banner?
    @Published private(set) var boss: BossHUD?
    @Published private(set) var sceneID = UUID()
    @Published private(set) var controlsHidden = false
    @Published private(set) var hurtPulse = 0

    let input = InputState()
    let mission: MissionDefinition
    private(set) var scene: GameScene
    private var checkpointSnapshot: RunConfig?
    private var bannerTask: Task<Void, Never>?

    var onVictory: ((MissionResult) -> Void)?
    var onQuit: (() -> Void)?

    init(mission: MissionDefinition) {
        self.mission = mission
        let loadout = ProgressionManager.shared.loadout
        let config = RunConfig.fresh(loadout: loadout)
        scene = GameScene(mission: mission, config: config, loadout: loadout)
        scene.session = self
    }

    // MARK: Flow

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        scene.isPaused = true
        input.reset()
        AudioManager.shared.duckMusic(true)
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        scene.isPaused = false
        scene.resetFrameClock()
        AudioManager.shared.duckMusic(false)
    }

    func restart(fromCheckpoint: Bool) {
        let loadout = ProgressionManager.shared.loadout
        var config: RunConfig
        if fromCheckpoint, let snap = checkpointSnapshot {
            config = snap
            if loadout.hasArcBlade { config.hasArcBlade = true }
        } else {
            config = RunConfig.fresh(loadout: loadout)
            checkpointSnapshot = nil
        }
        input.reset()
        bannerTask?.cancel()
        banner = nil
        dialogue = nil
        boss = nil
        controlsHidden = false
        scene.teardown()
        scene = GameScene(mission: mission, config: config, loadout: loadout)
        scene.session = self
        sceneID = UUID()
        phase = .playing
        AudioManager.shared.duckMusic(false)
        AudioManager.shared.playMusic(.gameplay, fade: 0.6)
    }

    var hasCheckpoint: Bool { checkpointSnapshot != nil }

    func quit() {
        scene.teardown()
        scene.isPaused = true
        AudioManager.shared.duckMusic(false)
        onQuit?()
    }

    // MARK: Scene callbacks

    func storeCheckpoint(_ config: RunConfig) { checkpointSnapshot = config }

    func playerDied() {
        guard phase == .playing else { return }
        phase = .defeated
        input.reset()
        AudioManager.shared.duckMusic(true)
    }

    func finishMission(config: RunConfig) {
        let shardsTotal = scene.level.shardCount
        let unbanked = Int(config.unbankedValue.rounded(.down))
        let result = ProgressionManager.shared.completeMission(
            mission,
            unbankedFragments: unbanked,
            enemies: config.enemiesDefeated,
            shards: config.shardsCollected,
            shardsTotal: shardsTotal,
            runFragmentsTotal: Int(config.runFragmentValue.rounded(.down))
        )
        scene.teardown()
        onVictory?(result)
    }

    // MARK: HUD setters (publish only on change)

    func setHealth(_ value: Int, max: Int) {
        if value < health { hurtPulse &+= 1 }
        if health != value { health = value }
        if maxHealth != max { maxHealth = max }
    }

    func setFragments(_ value: Int) { if runFragments != value { runFragments = value } }

    func setWeapon(_ id: WeaponID, hasArcBlade owned: Bool) {
        if weapon != id { weapon = id }
        if hasArcBlade != owned { hasArcBlade = owned }
    }

    func setObjective(_ obj: ObjectiveDefinition?, completed: Int) {
        if objective != obj { objective = obj }
        if completedCount != completed { completedCount = completed }
    }

    func setDialogue(_ line: DialogueLine?) { if dialogue != line { dialogue = line } }

    func setBoss(_ hud: BossHUD?) { if boss != hud { boss = hud } }

    func setControlsHidden(_ hidden: Bool) { if controlsHidden != hidden { controlsHidden = hidden } }

    func setEnding() { phase = .ending; input.reset() }

    func showBanner(_ title: String, subtitle: String? = nil, style: Banner.Style = .info, duration: TimeInterval = 2.4) {
        let b = Banner(title: title, subtitle: subtitle, style: style)
        banner = b
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self, self.banner?.id == b.id else { return }
            self.banner = nil
        }
    }
}
