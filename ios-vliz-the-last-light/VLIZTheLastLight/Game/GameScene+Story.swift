import SpriteKit

extension GameScene {

    // MARK: Triggers & checkpoints

    func updateTriggers() {
        guard let player, player.alive else { return }
        let x = player.body.pos.x

        for cp in level.checkpoints where !activatedCheckpoints.contains(cp.id) && x >= cp.x - 8 {
            activateCheckpoint(cp)
        }

        for t in level.triggers where !config.firedTriggers.contains(t.id) && x >= t.x {
            config.firedTriggers.insert(t.id)
            for action in t.actions { execute(action) }
        }
    }

    private func execute(_ action: TriggerAction) {
        switch action {
        case .completeObjective(let id): completeObjective(id)
        case .dialogue(let lines): enqueueDialogue(lines)
        case .startEncounter(let id): startEncounter(id)
        case .startBoss: startBoss()
        }
    }

    private func activateCheckpoint(_ cp: CheckpointSpec) {
        activatedCheckpoints.insert(cp.id)
        lightCheckpoint(cp.id, animated: true)
        config.checkpointID = cp.id
        // Bank whole fragments now so progress survives quitting.
        let whole = Int(config.unbankedValue.rounded(.down))
        if whole > 0 {
            ProgressionManager.shared.bank(fragments: whole)
            config.unbankedValue -= Double(whole)
        }
        player.health = min(player.maxHealth, max(player.health, Int(Double(player.maxHealth) * 0.6)))
        session?.storeCheckpoint(config)
        playSFX(.checkpoint)
        Haptics.light(0.8)
        burst(at: CGPoint(x: cp.x, y: cp.y + 62), color: SKTheme.cyan, count: 14, speed: 150)
        showFloatingText("CHECKPOINT", at: CGPoint(x: cp.x, y: cp.y + 110), color: SKTheme.cyan, small: true)
    }

    // MARK: Objectives

    func completeObjective(_ id: String) {
        guard !config.completedObjectives.contains(id) else { return }
        config.completedObjectives.insert(id)
        if let p = player {
            showFloatingText("OBJECTIVE COMPLETE", at: CGPoint(x: p.body.pos.x, y: p.body.pos.y + 120), color: SKTheme.text, small: true)
        }
        refreshObjective(announce: true)
    }

    func refreshObjective(announce: Bool) {
        let next = mission.objectives.first { !config.completedObjectives.contains($0.id) }
        let done = mission.objectives.filter { config.completedObjectives.contains($0.id) }.count
        session?.setObjective(next, completed: done)
        lastObjectiveID = next?.id
    }

    // MARK: Dialogue

    func enqueueDialogue(_ lines: [DialogueLine]) {
        dialogueQueue.append(contentsOf: lines)
    }

    func updateDialogue(dt: TimeInterval) {
        if currentLine != nil {
            dialogueTimer -= dt
            if dialogueTimer <= 0 {
                currentLine = nil
                session?.setDialogue(nil)
                dialogueTimer = -0.25   // short gap between lines
            }
            return
        }
        if dialogueTimer < 0 { dialogueTimer += dt; return }
        guard !dialogueQueue.isEmpty, player?.alive ?? false else { return }
        let line = dialogueQueue.removeFirst()
        currentLine = line
        dialogueTimer = line.duration
        session?.setDialogue(line)
    }

    // MARK: Encounters

    private func startEncounter(_ id: String) {
        guard activeEncounter == nil, !config.clearedEncounters.contains(id),
              let spec = level.encounters.first(where: { $0.id == id }) else { return }
        activeEncounter = spec
        encounterWave = 0
        encounterWaveDelay = 0.9
        encounterEnemies = []
        for g in spec.gateIDs { setGate(g, closed: true) }
        playSFX(.bossWarn, volume: 0.7)
        Haptics.warning()
        shake(4)
        session?.showBanner("LOCKDOWN", subtitle: "Defeat the Corsair forces", style: .danger, duration: 2.4)
    }

    func updateEncounter(dt: TimeInterval) {
        guard let spec = activeEncounter else { return }
        if encounterWaveDelay > 0 {
            encounterWaveDelay -= dt
            if encounterWaveDelay <= 0 {
                encounterWaveDelay = -1
                for s in level.spawns where s.encounterID == spec.id && s.wave == encounterWave {
                    encounterEnemies.append(spawnEnemy(s, warp: true))
                }
                playSFX(.bossCharge, volume: 0.4)
            }
            return
        }
        guard encounterEnemies.allSatisfy({ !$0.alive }) else { return }
        encounterWave += 1
        encounterEnemies = []
        if encounterWave >= spec.waves {
            activeEncounter = nil
            config.clearedEncounters.insert(spec.id)
            for g in spec.gateIDs { setGate(g, closed: false) }
            if let obj = spec.objectiveOnClear { completeObjective(obj) }
            playSFX(.checkpoint)
            Haptics.success()
            session?.showBanner("AREA SECURED", subtitle: "The station doors are open", style: .reward, duration: 2.4)
        } else {
            encounterWaveDelay = 1.2
            session?.showBanner("WAVE \(encounterWave + 1)", subtitle: nil, style: .danger, duration: 1.4)
        }
    }

    // MARK: Weapons

    func acquireWeapon(_ id: WeaponID) {
        ProgressionManager.shared.unlock(id)
        config.hasArcBlade = true
        config.equipped = id
        player.weapon = id
        completeObjective(ObjectiveID.arcBlade)
        enqueueDialogue(StoryData.arcBlade)
        let name = WeaponCatalog.definition(id).name.uppercased()
        session?.showBanner("\(name) ACQUIRED", subtitle: "Tap SWAP to switch weapons", style: .reward, duration: 3)
        playSFX(.unlock)
        Haptics.success()
        hitstop(0.12)
        let c = CGPoint(x: player.body.pos.x, y: player.body.pos.y + 40)
        burst(at: c, color: SKTheme.cyan, count: 28, speed: 260)
        let ring = SKSpriteNode(texture: ArtFactory.ring)
        ring.color = SKTheme.cyan
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.position = c
        ring.setScale(0.2)
        ring.zPosition = 45
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 3, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    // MARK: Boss flow

    private func startBoss() {
        guard bossStage == .none, boss == nil else { return }
        bossStage = .fighting
        setGate(level.bossArena.gateID, closed: true)
        AudioManager.shared.playMusic(.boss, fade: 0.8)
        let b = RhexBoss(arena: level.bossArena, scene: self)
        world.addChild(b.node)
        boss = b
        enqueueDialogue(StoryData.bossIntro)
        session?.showBanner(BossTuning.name.uppercased(), subtitle: "Void Corsair Vanguard", style: .danger, duration: 3)
        playSFX(.bossWarn)
        Haptics.warning()
    }

    func bossPhaseTwo() {
        dialogueQueue.removeAll()
        currentLine = nil
        dialogueTimer = 0
        session?.setDialogue(nil)
        enqueueDialogue(StoryData.bossPhaseTwo)
        session?.showBanner("PHASE II", subtitle: "Watch for rockets, charges and falling debris", style: .danger, duration: 2.6)
        playSFX(.bossWarn)
        Haptics.heavy()
        hitstop(0.15)
        shake(12)
        if let b = boss {
            burst(at: CGPoint(x: b.body.pos.x, y: b.body.pos.y + 80), color: SKTheme.magenta, count: 30, speed: 300)
        }
        // Clear hostile fire so the transition is fair.
        for p in projectiles where !p.friendly { p.dead = true }
    }

    func bossDying() {
        bossStage = .defeated
        completeObjective(ObjectiveID.rhex)
        for p in projectiles where !p.friendly { p.dead = true }
        for z in zones where !z.activated { cancelZone(z) }
        dialogueQueue.removeAll()
        currentLine = nil
        dialogueTimer = 0
        session?.setDialogue(nil)
        enqueueDialogue(StoryData.bossDefeated)
        AudioManager.shared.stopMusic(fade: 2)
        hitstop(0.25)
        shake(14)
        Haptics.heavy()
    }

    func bossFinished() {
        spawnBeacon()
        session?.showBanner("RHEX DEFEATED", subtitle: "Reach the signal at the reactor core", style: .reward, duration: 3)
        playSFX(.victory, volume: 0.6)
        Haptics.success()
        dropFragments(at: boss?.body.pos ?? level.bossArena.bossSpawn, count: 12)
    }

    private func spawnBeacon() {
        guard beacon == nil else { return }
        let pos = level.bossArena.beaconPosition
        let n = SKNode()
        n.position = pos
        n.zPosition = 8
        let column = SKSpriteNode(texture: ArtFactory.verticalFade)
        column.color = SKTheme.cyan
        column.colorBlendFactor = 1
        column.blendMode = .add
        column.anchorPoint = CGPoint(x: 0.5, y: 0)
        column.size = CGSize(width: 70, height: 520)
        column.alpha = 0
        n.addChild(column)
        column.run(.sequence([.fadeAlpha(to: 0.7, duration: 1),
                              .repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.9), .fadeAlpha(to: 0.75, duration: 0.9)]))]))
        let core = SKSpriteNode(texture: ArtFactory.glow)
        core.color = SKTheme.cyan
        core.colorBlendFactor = 1
        core.blendMode = .add
        core.size = CGSize(width: 90, height: 90)
        core.position = CGPoint(x: 0, y: 40)
        n.addChild(core)
        core.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.7), .scale(to: 1, duration: 0.7)])))
        let ring = SKSpriteNode(texture: ArtFactory.ring)
        ring.color = SKTheme.cyan
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.size = CGSize(width: 110, height: 26)
        ring.position = CGPoint(x: 0, y: 4)
        n.addChild(ring)
        ring.run(.repeatForever(.sequence([.group([.scale(to: 1.6, duration: 1.2), .fadeOut(withDuration: 1.2)]),
                                           .group([.scale(to: 1, duration: 0), .fadeIn(withDuration: 0)])])))
        world.addChild(n)
        beacon = n
    }

    func updateBossFlow(dt: TimeInterval) {
        switch bossStage {
        case .defeated:
            guard let beacon, player.alive else { return }
            if abs(player.body.pos.x - beacon.position.x) < 46 && player.body.pos.y < beacon.position.y + 80 {
                beginEnding()
            }
        case .ending:
            endingTimer -= dt
            if endingTimer <= 0 {
                bossStage = .finished
                session?.finishMission(config: config)
            }
        default:
            break
        }
    }

    private func beginEnding() {
        bossStage = .ending
        session?.setEnding()
        session?.setControlsHidden(true)
        player.locked = true
        player.body.vel.dx = 0
        completeObjective(ObjectiveID.signal)
        dialogueQueue.removeAll()
        currentLine = nil
        dialogueTimer = 0
        session?.setDialogue(nil)
        enqueueDialogue(StoryData.ending)
        endingTimer = StoryData.ending.reduce(0) { $0 + $1.duration + 0.25 } + 1.0
        AudioManager.shared.playMusic(.menu, fade: 1.5)
        playSFX(.unlock)
        Haptics.success()
        if let beacon {
            let flare = SKSpriteNode(texture: ArtFactory.glow)
            flare.color = SKTheme.cyan
            flare.colorBlendFactor = 1
            flare.blendMode = .add
            flare.size = CGSize(width: 200, height: 200)
            flare.position = CGPoint(x: 0, y: 60)
            flare.alpha = 0
            beacon.addChild(flare)
            flare.run(.sequence([.fadeAlpha(to: 0.9, duration: 2), .scale(to: 3.5, duration: endingTimer)]))
        }
    }
}
