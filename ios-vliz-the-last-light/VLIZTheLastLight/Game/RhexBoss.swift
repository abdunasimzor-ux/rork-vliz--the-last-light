import SpriteKit

/// Commander Rhex. Two phases; every attack is telegraphed and followed by a recovery window.
@MainActor
final class RhexBoss {
    enum Attack: CaseIterable { case volley, beam, hop, rockets, charge }
    enum State {
        case intro, idle, volleyAim, volleyFire, beamWindup, beamFire, hop
        case recover, transition, rocketsWindup, chargeWindup, charging, stunned, dying, dead
    }

    let node = SKNode()
    let sprite: SKSpriteNode
    private let aura = SKSpriteNode(texture: ArtFactory.glow)
    private let cannonGlow = SKSpriteNode(texture: ArtFactory.glow)
    private let aimLine = SKSpriteNode(texture: ArtFactory.band)
    private let stunRing = SKSpriteNode(texture: ArtFactory.ring)
    var body: Body
    var health = BossTuning.maxHealth
    var phase = 1
    var facing: CGFloat = -1
    private(set) var state: State = .intro
    private var stateTime: TimeInterval = 0
    private var lastAttack: Attack?
    private var shotsLeft = 0
    private var aimPoint: CGPoint = .zero
    private var beamHigh = false
    private var hopFrom: CGFloat = 0
    private var hopTo: CGFloat = 0
    private var debrisTimer: TimeInterval = 4
    private var chargeDir: CGFloat = -1
    private var squash: CGFloat = 1
    private let baseScale: CGFloat
    private let arena: BossArenaSpec
    private var chargeTelegraph: SKSpriteNode?
    private var pendingZones: [TimedZone] = []
    private var landed = false
    unowned let scene: GameScene

    var alive: Bool { state != .dying && state != .dead }
    var invulnerable: Bool { state == .intro || state == .transition || !alive }
    var isStunned: Bool { state == .stunned }
    var contactDamage: Int { state == .charging ? BossTuning.chargeDamage : BossTuning.contactDamage }
    var fraction: Double { Double(max(0, health)) / Double(BossTuning.maxHealth) }
    var vulnerableWindow: Bool { state == .recover || state == .stunned }

    var hitRect: CGRect {
        var r = body.rect
        if state == .charging || state == .chargeWindup { r.size.height = 90 }
        return r
    }

    init(arena: BossArenaSpec, scene: GameScene) {
        self.arena = arena
        self.scene = scene
        body = Body(pos: CGPoint(x: arena.bossSpawn.x, y: arena.bossSpawn.y + 420), size: BossTuning.hitbox)
        let tex = ArtFactory.character(BossTuning.textureName, fallbackColor: SKTheme.magenta)
        sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        baseScale = BossTuning.spriteHeight / max(tex.size().height, 1)
        sprite.setScale(baseScale)
        sprite.zPosition = 2

        aura.color = SKTheme.magenta
        aura.colorBlendFactor = 1
        aura.blendMode = .add
        aura.size = CGSize(width: 260, height: 260)
        aura.position = CGPoint(x: 0, y: 80)
        aura.alpha = 0.3
        aura.zPosition = 1

        cannonGlow.color = SKTheme.magenta
        cannonGlow.colorBlendFactor = 1
        cannonGlow.blendMode = .add
        cannonGlow.size = CGSize(width: 70, height: 70)
        cannonGlow.alpha = 0
        cannonGlow.zPosition = 3

        stunRing.color = SKTheme.softViolet
        stunRing.colorBlendFactor = 1
        stunRing.blendMode = .add
        stunRing.size = CGSize(width: 70, height: 22)
        stunRing.position = CGPoint(x: 0, y: 168)
        stunRing.alpha = 0
        stunRing.zPosition = 4

        aimLine.color = SKTheme.magenta
        aimLine.colorBlendFactor = 1
        aimLine.blendMode = .add
        aimLine.anchorPoint = CGPoint(x: 0, y: 0.5)
        aimLine.alpha = 0
        aimLine.zPosition = 25

        node.addChild(aura)
        node.addChild(sprite)
        node.addChild(cannonGlow)
        node.addChild(stunRing)
        node.zPosition = 12
        node.position = body.pos
        scene.world.addChild(aimLine)
    }

    private var player: Player { scene.player }
    private var cannon: CGPoint { CGPoint(x: body.pos.x + facing * 40, y: body.pos.y + 78) }
    private var arenaMid: CGFloat { (arena.minX + arena.maxX) / 2 }

    // MARK: Update

    func update(dt: TimeInterval) {
        stateTime += dt
        let fdt = CGFloat(dt)

        switch state {
        case .intro:
            body.vel.dy = max(-900, body.vel.dy - 2000 * fdt)
            scene.physics.move(&body, dt: fdt)
            if body.onGround && !landed {
                landed = true
                squash = 0.8
                scene.shake(14)
                scene.playSFX(.slam)
                scene.dust(at: body.pos, dir: 0, count: 20)
                Haptics.heavy()
            }
            facing = player.body.pos.x > body.pos.x ? 1 : -1
            if stateTime > 3.6 { enter(.idle) }

        case .idle:
            faceplayer()
            body.vel.dx = 0
            if stateTime > (phase == 1 ? 0.75 : 0.5) { chooseAttack() }

        case .volleyAim:
            faceplayer()
            let p = CGFloat(stateTime / 0.7)
            cannonGlow.alpha = 0.3 + p * 0.7
            aimPoint = CGPoint(x: player.body.pos.x, y: player.body.pos.y + 30)
            showAim(alpha: 0.2 + 0.5 * p)
            if stateTime >= 0.7 {
                aimLine.alpha = 0
                shotsLeft = phase == 1 ? 3 : 1
                enter(.volleyFire)
                fireVolley()
            }

        case .volleyFire:
            if shotsLeft > 0 && stateTime > 0.2 {
                stateTime = 0
                fireVolley()
            }
            if shotsLeft == 0 && stateTime > 0.3 {
                cannonGlow.alpha = 0
                enter(.recover)
            }

        case .beamWindup:
            faceplayer()
            cannonGlow.alpha = 0.4 + CGFloat(stateTime / 0.9) * 0.6
            if stateTime >= 0.9 {
                enter(.beamFire)
                scene.shake(6)
                scene.playSFX(.explosion, volume: 0.5)
            }

        case .beamFire:
            if stateTime > 0.5 {
                cannonGlow.alpha = 0
                enter(.recover)
            }

        case .hop:
            let duration: TimeInterval = 0.85
            let t = min(1, CGFloat(stateTime / duration))
            body.pos.x = hopFrom + (hopTo - hopFrom) * t
            body.pos.y = arena.bossSpawn.y + sin(t * .pi) * 230
            if t >= 1 {
                body.pos.y = arena.bossSpawn.y
                body.vel = .zero
                squash = 0.8
                scene.shake(10)
                scene.playSFX(.slam, volume: 0.8)
                scene.dust(at: body.pos, dir: 0, count: 16)
                faceplayer()
                enter(.recover)
                stateTime = 0.35
            }

        case .rocketsWindup:
            cannonGlow.alpha = 0.6 + 0.4 * sin(CGFloat(stateTime) * 30)
            if stateTime > 1.1 {
                cannonGlow.alpha = 0
                enter(.recover)
            }

        case .chargeWindup:
            body.vel.dx = 0
            let p = CGFloat(stateTime / 0.8)
            squash = 1 - p * 0.12
            aura.alpha = 0.3 + p * 0.6
            sprite.position.x = sin(CGFloat(stateTime) * 70) * 2 * p
            chargeTelegraph?.alpha = 0.2 + 0.5 * (Int(stateTime * 16) % 2 == 0 ? p : p * 0.5)
            if stateTime >= 0.8 {
                sprite.position.x = 0
                chargeTelegraph?.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
                chargeTelegraph = nil
                enter(.charging)
                scene.playSFX(.dash)
                scene.shake(5)
            }

        case .charging:
            body.vel.dx = chargeDir * 760
            body.vel.dy = 0
            scene.physics.move(&body, dt: fdt)
            if Int(stateTime * 40) % 2 == 0 { scene.afterimage(of: sprite, at: node.position, color: SKTheme.magenta) }
            let atWall = (chargeDir > 0 && body.pos.x >= arena.maxX - body.size.width / 2 - 4)
                || (chargeDir < 0 && body.pos.x <= arena.minX + 22 + body.size.width / 2 + 4)
                || body.hitWall != 0
            if atWall || stateTime > 2 {
                body.vel.dx = 0
                enter(.stunned)
                scene.shake(16)
                scene.playSFX(.explosion)
                Haptics.heavy()
                scene.burst(at: CGPoint(x: body.pos.x + chargeDir * 30, y: body.pos.y + 70), color: SKTheme.ember, count: 20, speed: 300)
                scene.showFloatingText("STUNNED", at: CGPoint(x: body.pos.x, y: body.pos.y + 190), color: SKTheme.softViolet)
            }

        case .stunned:
            aura.alpha = 0.15
            stunRing.alpha = 0.8
            stunRing.zRotation += fdt * 4
            sprite.zRotation = -facing * 0.1
            if stateTime > 1.6 {
                stunRing.alpha = 0
                sprite.zRotation = 0
                enter(.idle)
            }

        case .recover:
            body.vel.dx = 0
            aura.alpha = 0.18
            if stateTime > (phase == 1 ? 0.95 : 0.8) { enter(.idle) }

        case .transition:
            body.vel.dx = 0
            aura.alpha = 0.5 + 0.4 * sin(CGFloat(stateTime) * 20)
            sprite.position.x = sin(CGFloat(stateTime) * 60) * 2
            if stateTime > 2.4 {
                sprite.position.x = 0
                enter(.idle)
            }

        case .dying:
            sprite.position.x = sin(CGFloat(stateTime) * 50) * 3
            if Int(stateTime * 6) != Int((stateTime - dt) * 6) {
                let p = CGPoint(x: body.pos.x + CGFloat.random(in: -40...40), y: body.pos.y + CGFloat.random(in: 20...140))
                scene.burst(at: p, color: Bool.random() ? SKTheme.magenta : SKTheme.ember, count: 12, speed: 220)
                scene.playSFX(.explosion, volume: 0.6)
                scene.shake(6)
            }
            if stateTime > 2.6 {
                state = .dead
                sprite.position.x = 0
                node.run(.sequence([
                    .group([.rotate(toAngle: facing * 0.25, duration: 0.6), .fadeAlpha(to: 0.0, duration: 1.2), .moveBy(x: 0, y: -10, duration: 1.2)]),
                    .removeFromParent()
                ]))
                aimLine.removeFromParent()
                scene.bossFinished()
            }

        case .dead:
            break
        }

        // Phase-two debris rain
        if phase == 2 && alive && state != .transition {
            debrisTimer -= dt
            if debrisTimer <= 0 {
                debrisTimer = 3.4
                dropDebris()
            }
        }

        // Gravity when grounded states
        if [.idle, .recover, .volleyAim, .volleyFire, .beamWindup, .beamFire, .rocketsWindup, .stunned, .transition, .chargeWindup].contains(state) {
            body.vel.dy = max(-900, body.vel.dy - 2000 * fdt)
            scene.physics.move(&body, dt: fdt)
        }

        render(dt: dt)
    }

    private func render(dt: TimeInterval) {
        node.position = body.pos
        squash = approach(squash, 1, CGFloat(dt) * 2.5)
        sprite.xScale = baseScale * (facing < 0 ? 1 : -1) * (2 - squash)
        sprite.yScale = baseScale * squash
        cannonGlow.position = CGPoint(x: facing * 40, y: 78)
        if state == .idle || state == .volleyAim {
            aura.alpha = 0.25 + 0.06 * sin(CGFloat(stateTime) * 4)
        }
    }

    private func faceplayer() {
        facing = player.body.pos.x > body.pos.x ? 1 : -1
    }

    private func enter(_ s: State) { state = s; stateTime = 0 }

    // MARK: Attacks

    private func chooseAttack() {
        var options: [Attack] = phase == 1 ? [.volley, .beam, .hop] : [.volley, .beam, .rockets, .charge, .hop]
        if let last = lastAttack, options.count > 1 { options.removeAll { $0 == last } }
        // Hop more often when the player is crowding.
        let pick: Attack
        if abs(player.body.pos.x - body.pos.x) < 110 && options.contains(.hop) && Bool.random() {
            pick = .hop
        } else {
            pick = options.randomElement() ?? .volley
        }
        lastAttack = pick
        switch pick {
        case .volley:
            enter(.volleyAim)
            scene.playSFX(.bossWarn, volume: 0.6)
        case .beam:
            startBeam()
        case .hop:
            hopFrom = body.pos.x
            hopTo = body.pos.x > arenaMid ? arena.minX + 150 : arena.maxX - 150
            facing = hopTo > hopFrom ? 1 : -1
            enter(.hop)
            squash = 1.15
            scene.playSFX(.jump)
        case .rockets:
            startRockets()
        case .charge:
            startCharge()
        }
    }

    private func showAim(alpha: CGFloat) {
        let m = cannon
        let dx = aimPoint.x - m.x, dy = aimPoint.y - m.y
        aimLine.position = m
        aimLine.zRotation = atan2(dy, dx)
        aimLine.size = CGSize(width: min(900, hypot(dx, dy) + 200), height: 8)
        aimLine.alpha = alpha
    }

    private func fireVolley() {
        shotsLeft -= 1
        let m = cannon
        let base = atan2(aimPoint.y - m.y, aimPoint.x - m.x)
        let angles: [CGFloat] = phase == 1 ? [base] : [-0.32, -0.16, 0, 0.16, 0.32].map { base + $0 }
        let speed: CGFloat = phase == 1 ? 430 : 360
        for a in angles {
            scene.spawnProjectile(at: m, vel: CGVector(dx: cos(a) * speed, dy: sin(a) * speed),
                                  damage: BossTuning.shotDamage, friendly: false, style: .bossBolt, life: 2.6, knockback: 0)
        }
        scene.muzzleFlash(at: m, color: SKTheme.magenta)
        scene.playSFX(.blaster, volume: 0.7)
        squash = 0.94
    }

    private func startBeam() {
        faceplayer()
        enter(.beamWindup)
        let groundY = arena.bossSpawn.y
        // Phase 1: always low (jump it). Phase 2: alternates low / high (stay grounded).
        let high = phase == 2 ? beamHigh : false
        if phase == 2 { beamHigh.toggle() }
        let y = high ? groundY + 66 : groundY
        let h: CGFloat = high ? 80 : 36
        let startX = facing > 0 ? body.pos.x + 30 : arena.minX
        let endX = facing > 0 ? arena.maxX : body.pos.x - 30
        let z = scene.addZone(rect: CGRect(x: startX, y: y, width: endX - startX, height: h),
                              telegraph: 0.9, active: 0.5, damage: BossTuning.beamDamage, style: .beam, sourceX: body.pos.x)
        pendingZones.append(z)
        scene.playSFX(.bossCharge, volume: 0.7)
        scene.showFloatingText(high ? "STAY LOW" : "JUMP", at: CGPoint(x: arenaMid, y: groundY + 250), color: SKTheme.magenta)
    }

    private func startRockets() {
        faceplayer()
        enter(.rocketsWindup)
        scene.playSFX(.bossWarn, volume: 0.8)
        var xs: [CGFloat] = [player.body.pos.x]
        let count = 4
        var attempts = 0
        while xs.count < count && attempts < 40 {
            attempts += 1
            let x = CGFloat.random(in: (arena.minX + 70)...(arena.maxX - 70))
            if xs.allSatisfy({ abs($0 - x) > 120 }) { xs.append(x) }
        }
        for (i, x) in xs.enumerated() {
            let z = scene.addZone(rect: CGRect(x: x - 38, y: arena.bossSpawn.y, width: 76, height: 170),
                                  telegraph: 1.0 + Double(i) * 0.12, active: 0.2, damage: BossTuning.rocketDamage,
                                  style: .rocket, sourceX: x)
            pendingZones.append(z)
        }
        for i in 0..<3 {
            scene.run(.sequence([.wait(forDuration: Double(i) * 0.15), .run { [weak self] in
                guard let self else { return }
                self.scene.muzzleFlash(at: CGPoint(x: self.body.pos.x - self.facing * 10, y: self.body.pos.y + 140), color: SKTheme.ember)
            }]))
        }
    }

    private func startCharge() {
        faceplayer()
        chargeDir = facing
        enter(.chargeWindup)
        scene.playSFX(.bossCharge)
        let startX = chargeDir > 0 ? body.pos.x : arena.minX + 22
        let endX = chargeDir > 0 ? arena.maxX : body.pos.x
        let strip = SKSpriteNode(texture: ArtFactory.band)
        strip.color = SKTheme.magenta
        strip.colorBlendFactor = 1
        strip.blendMode = .add
        strip.anchorPoint = CGPoint(x: 0, y: 0)
        strip.size = CGSize(width: endX - startX, height: 90)
        strip.position = CGPoint(x: startX, y: arena.bossSpawn.y)
        strip.alpha = 0.2
        strip.zPosition = 8
        scene.world.addChild(strip)
        chargeTelegraph = strip
    }

    private func dropDebris() {
        var xs: [CGFloat] = [player.body.pos.x + CGFloat.random(in: -30...30)]
        let other = CGFloat.random(in: (arena.minX + 60)...(arena.maxX - 60))
        if abs(other - xs[0]) > 100 { xs.append(other) }
        for x in xs {
            let clamped = min(max(x, arena.minX + 50), arena.maxX - 50)
            let z = scene.addZone(rect: CGRect(x: clamped - 30, y: arena.bossSpawn.y, width: 60, height: 90),
                                  telegraph: 1.05, active: 0.15, damage: BossTuning.debrisDamage, style: .debris, sourceX: clamped)
            pendingZones.append(z)
        }
    }

    // MARK: Damage

    @discardableResult
    func takeHit(_ amount: Int, piercing: Bool) -> Int {
        guard !invulnerable else {
            scene.sparkAt(CGPoint(x: body.pos.x, y: body.pos.y + 80), color: SKTheme.softViolet)
            return 0
        }
        var dmg = CGFloat(amount)
        if isStunned { dmg *= BossTuning.stunnedDamageMultiplier }
        if !piercing { dmg *= 0.85 }
        let dealt = max(1, Int(dmg.rounded()))
        health -= dealt
        sprite.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.7, duration: 0),
            .wait(forDuration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.08)
        ]), withKey: "flash")

        if phase == 1 && fraction <= BossTuning.phaseTwoThreshold {
            beginPhaseTwo()
        } else if health <= 0 {
            beginDeath()
        }
        return dealt
    }

    private func clearPending() {
        for z in pendingZones where !z.activated { scene.cancelZone(z) }
        pendingZones.removeAll()
        chargeTelegraph?.removeFromParent()
        chargeTelegraph = nil
        aimLine.alpha = 0
        cannonGlow.alpha = 0
        stunRing.alpha = 0
        sprite.zRotation = 0
        sprite.position.x = 0
    }

    private func beginPhaseTwo() {
        phase = 2
        health = max(health, Int(Double(BossTuning.maxHealth) * BossTuning.phaseTwoThreshold) - 1)
        clearPending()
        // Snap back to the floor if mid-hop.
        body.pos.y = max(body.pos.y, arena.bossSpawn.y)
        enter(.transition)
        debrisTimer = 3.5
        scene.bossPhaseTwo()
    }

    private func beginDeath() {
        health = 0
        clearPending()
        body.pos.y = arena.bossSpawn.y
        enter(.dying)
        scene.bossDying()
    }

    func removeAll() {
        aimLine.removeFromParent()
        chargeTelegraph?.removeFromParent()
    }
}
