import SpriteKit

/// Runtime state of a hazard placed in the level.
@MainActor
final class HazardRuntime {
    let spec: HazardSpec
    let node = SKNode()
    var flame: SKSpriteNode?
    var nozzleGlow: SKSpriteNode?
    var active = false

    init(spec: HazardSpec) { self.spec = spec }
}

@MainActor
final class GameScene: SKScene {
    enum BossStage { case none, fighting, defeated, ending, finished }

    static let visibleHeight: CGFloat = 420

    weak var session: GameSession?
    let mission: MissionDefinition
    let level: LevelDefinition
    let loadout: PlayerLoadout
    var config: RunConfig

    let world = SKNode()
    let cam = SKCameraNode()
    let physics: PhysicsWorld
    var player: Player!
    var enemies: [Enemy] = []
    var boss: RhexBoss?
    var projectiles: [Projectile] = []
    var zones: [TimedZone] = []
    var pickups: [Pickup] = []
    var hazards: [HazardRuntime] = []
    var gateNodes: [String: [SKNode]] = [:]
    var checkpointNodes: [String: SKNode] = [:]
    var activatedCheckpoints: Set<String> = []
    var beacon: SKNode?

    // Story
    var dialogueQueue: [DialogueLine] = []
    var currentLine: DialogueLine?
    var dialogueTimer: TimeInterval = 0
    var activeEncounter: EncounterSpec?
    var encounterWave = 0
    var encounterWaveDelay: TimeInterval = 0
    var encounterEnemies: [Enemy] = []
    var bossStage: BossStage = .none
    var endingTimer: TimeInterval = 0
    var lastObjectiveID: String?

    // Feel
    var shakeMagnitude: CGFloat = 0
    var hitstopTimer: TimeInterval = 0
    var lastTime: TimeInterval?
    var elapsed: TimeInterval = 0
    var deathTimer: TimeInterval = 0
    let reduced: Bool
    let shakeEnabled: Bool
    var lookahead: CGFloat = 60
    var cameraTarget: CGPoint = .zero

    // Background
    var backdropNodes: [SKSpriteNode] = []
    var activeBackdrop = 0
    var silhouetteLayer = SKNode()
    var silhouetteTiles: [SKSpriteNode] = []
    var fogNode = SKSpriteNode()
    var shadeNode = SKSpriteNode()
    var motes: SKEmitterNode?
    var currentZone: ZoneStyle?

    private var built = false

    init(mission: MissionDefinition, config: RunConfig, loadout: PlayerLoadout) {
        self.mission = mission
        self.level = mission.makeLevel()
        self.config = config
        self.loadout = loadout
        self.physics = PhysicsWorld(specs: level.solids)
        let settings = ProgressionManager.shared.settings
        reduced = settings.reducedEffects
        shakeEnabled = settings.screenShake
        super.init(size: CGSize(width: 844, height: 390))
        scaleMode = .resizeFill
        backgroundColor = SKTheme.void
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        addChild(world)
        addChild(cam)
        camera = cam
        buildBackground()
        buildLevel()
        spawnPlayer()
        spawnActors()
        let start = player.body.pos
        cam.position = CGPoint(x: start.x + 60, y: 210)
        updateCameraScale()
        clampCamera(&cam.position)
        cameraTarget = cam.position
        updateZone(force: true)
        refreshObjective(announce: false)
        syncHUD()
        AudioManager.shared.playMusic(.gameplay)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateCameraScale()
    }

    func resetFrameClock() { lastTime = nil }

    func teardown() {
        boss?.removeAll()
        removeAllActions()
        world.removeAllActions()
        isPaused = true
    }

    var cameraScale: CGFloat { GameScene.visibleHeight / max(size.height, 1) }
    var visibleSize: CGSize { CGSize(width: size.width * cameraScale, height: GameScene.visibleHeight) }

    private func updateCameraScale() {
        guard size.height > 0 else { return }
        cam.setScale(cameraScale)
        layoutBackground()
    }

    // MARK: Main loop

    override func update(_ currentTime: TimeInterval) {
        guard built, let session else { return }
        let raw = lastTime.map { currentTime - $0 } ?? (1.0 / 60.0)
        lastTime = currentTime
        let dt = min(max(raw, 0), 1.0 / 30.0)
        if session.phase == .paused { return }

        let input = session.input
        input.pollKeyboard()
        if input.consumePause() && session.phase == .playing {
            session.pause()
            return
        }
        elapsed += dt

        if hitstopTimer > 0 {
            hitstopTimer -= dt
            updateCamera(dt: dt)
            return
        }

        updatePlayer(dt: dt, input: input)
        for e in enemies { e.update(dt: dt) }
        enemies.removeAll { !$0.alive }
        boss?.update(dt: dt)
        updateProjectiles(dt: dt)
        updateZones(dt: dt)
        updatePickups(dt: dt)
        updateHazards(dt: dt)
        checkContacts()
        updateTriggers()
        updateDialogue(dt: dt)
        updateEncounter(dt: dt)
        updateBossFlow(dt: dt)
        updateCamera(dt: dt)
        updateZone(force: false)
        syncHUD()
    }

    private func updatePlayer(dt: TimeInterval, input: InputState) {
        guard let player else { return }
        if !player.alive {
            deathTimer -= dt
            if deathTimer <= 0 && deathTimer > -10 {
                deathTimer = -100
                session?.playerDied()
            }
            return
        }
        player.update(dt: dt, input: input, scene: self)

        if input.consumeSwap() && !player.locked {
            if config.hasArcBlade {
                player.weapon = player.weapon == .pulseBlaster ? .arcBlade : .pulseBlaster
                config.equipped = player.weapon
                playSFX(.uiTap)
                Haptics.tap()
                showFloatingText(WeaponCatalog.definition(player.weapon).name.uppercased(),
                                 at: CGPoint(x: player.body.pos.x, y: player.body.pos.y + 96), color: SKTheme.cyan, small: true)
            }
        }

        let pressed = input.consumeAttack()
        if (pressed || input.attackHeld) && player.attackCooldown <= 0 && !player.locked && !player.isDashing {
            performAttack()
        }

        // Kill plane
        if player.body.pos.y < -60 {
            let p = player.lastSafePosition
            damagePlayer(15, from: nil, force: true)
            if player.alive {
                player.body.pos = p
                player.body.vel = .zero
                player.invulnerable = 1.2
                burst(at: CGPoint(x: p.x, y: p.y + 30), color: SKTheme.cyan, count: 14, speed: 160)
            }
        }
    }

    // MARK: Camera

    func clampCamera(_ p: inout CGPoint) {
        let vis = visibleSize
        var minX = vis.width / 2
        var maxX = level.width - vis.width / 2
        if bossStage == .fighting || bossStage == .defeated || bossStage == .ending {
            let a = level.bossArena
            let aMin = a.minX - 30 + vis.width / 2
            let aMax = a.maxX + 30 - vis.width / 2
            if aMin > aMax {
                minX = (a.minX + a.maxX) / 2; maxX = minX
            } else {
                minX = max(minX, aMin); maxX = min(maxX, aMax)
            }
        }
        if minX > maxX { p.x = (minX + maxX) / 2 } else { p.x = min(max(p.x, minX), maxX) }
        p.y = max(p.y, vis.height / 2 - 4)
    }

    private func updateCamera(dt: TimeInterval) {
        guard let player else { return }
        let fdt = CGFloat(dt)
        lookahead = approach(lookahead, player.facing * 70, 220 * fdt)
        var target = CGPoint(x: player.body.pos.x + lookahead,
                             y: 210 + max(0, player.body.pos.y - 150) * 0.8)
        clampCamera(&target)
        cameraTarget.x += (target.x - cameraTarget.x) * min(1, 7 * fdt)
        cameraTarget.y += (target.y - cameraTarget.y) * min(1, 4.5 * fdt)
        var pos = cameraTarget
        if shakeMagnitude > 0.1 {
            if shakeEnabled {
                pos.x += CGFloat.random(in: -1...1) * shakeMagnitude
                pos.y += CGFloat.random(in: -1...1) * shakeMagnitude
            }
            shakeMagnitude = max(0, shakeMagnitude - fdt * 45)
        }
        cam.position = pos
        layoutParallax()
    }

    func shake(_ amount: CGFloat) {
        shakeMagnitude = min(18, max(shakeMagnitude, amount * (reduced ? 0.6 : 1)))
    }

    func hitstop(_ duration: TimeInterval) {
        hitstopTimer = max(hitstopTimer, duration)
    }

    // MARK: HUD

    func syncHUD() {
        guard let session, let player else { return }
        session.setHealth(player.health, max: player.maxHealth)
        session.setFragments(Int(config.runFragmentValue.rounded(.down)))
        session.setWeapon(player.weapon, hasArcBlade: config.hasArcBlade)
        if let boss, bossStage == .fighting {
            session.setBoss(BossHUD(name: BossTuning.name, fraction: (boss.fraction * 100).rounded() / 100,
                                    phase: boss.phase, vulnerable: boss.vulnerableWindow))
        } else {
            session.setBoss(nil)
        }
    }

    func playSFX(_ sfx: SFX, volume: Float = 1) {
        AudioManager.shared.play(sfx, volume: volume)
    }
}
