import SpriteKit

/// Shared enemy body, health, hit reactions and helpers. Behaviour lives in subclasses.
@MainActor
class Enemy {
    let spawn: EnemySpawn
    let def: EnemyDefinition
    let node = SKNode()
    let sprite: SKSpriteNode
    let eyeGlow: SKSpriteNode
    var body: Body
    var health: Int
    var facing: CGFloat = -1
    var alive = true
    var stateTime: TimeInterval = 0
    var attackCooldown: TimeInterval = 0
    let homeX: CGFloat
    var patrolDir: CGFloat = -1
    var knockTimer: TimeInterval = 0
    let baseScale: CGFloat
    var squash: CGFloat = 1
    unowned let scene: GameScene

    /// Damage multiplier while in a vulnerable state (e.g. Ironbound recovery).
    var vulnerability: CGFloat { 1 }
    var knockbackResistance: CGFloat { 0 }
    /// True while this enemy deals its attack damage on contact (e.g. lunging).
    var attackingContact: Bool { false }

    init(spawn: EnemySpawn, scene: GameScene) {
        self.spawn = spawn
        self.scene = scene
        def = EnemyCatalog.definition(spawn.kind)
        health = def.maxHealth
        homeX = spawn.x
        body = Body(pos: CGPoint(x: spawn.x, y: spawn.y), size: def.hitbox)
        let tex = ArtFactory.character(def.textureName, fallbackColor: SKTheme.magenta)
        sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        baseScale = def.spriteHeight / max(tex.size().height, 1)
        sprite.setScale(baseScale)
        sprite.zPosition = 2

        eyeGlow = SKSpriteNode(texture: ArtFactory.glow)
        eyeGlow.color = SKTheme.magenta
        eyeGlow.colorBlendFactor = 1
        eyeGlow.blendMode = .add
        eyeGlow.alpha = 0.25
        eyeGlow.size = CGSize(width: def.spriteHeight * 1.3, height: def.spriteHeight * 1.1)
        eyeGlow.position = CGPoint(x: 0, y: def.spriteHeight * 0.5)
        eyeGlow.zPosition = 1

        node.addChild(eyeGlow)
        node.addChild(sprite)
        node.position = body.pos
        node.zPosition = 10
    }

    var player: Player { scene.player }
    var distanceToPlayer: CGFloat { abs(player.body.pos.x - body.pos.x) }
    var dirToPlayer: CGFloat { player.body.pos.x >= body.pos.x ? 1 : -1 }
    var playerVerticalGap: CGFloat { abs(player.body.pos.y - body.pos.y) }

    func update(dt: TimeInterval) {
        guard alive else { return }
        stateTime += dt
        attackCooldown -= dt
        knockTimer -= dt
        if knockTimer <= 0 {
            think(dt: dt)
        } else {
            body.vel.dx = approach(body.vel.dx, 0, 900 * CGFloat(dt))
        }
        body.vel.dy = max(-900, body.vel.dy - 2000 * CGFloat(dt))
        scene.physics.move(&body, dt: CGFloat(dt))
        if body.pos.y < -80 { fellOut() }
        render(dt: dt)
    }

    func think(dt: TimeInterval) {}

    func render(dt: TimeInterval) {
        node.position = body.pos
        squash = approach(squash, 1, CGFloat(dt) * 3)
        sprite.xScale = baseScale * (facing < 0 ? 1 : -1) * (2 - squash)
        sprite.yScale = baseScale * squash
    }

    func fellOut() {
        alive = false
        node.removeFromParent()
        scene.enemyRemoved(self, rewarded: false)
    }

    /// Ground-aware horizontal step. Returns false if blocked by a ledge or wall.
    @discardableResult
    func walk(_ dir: CGFloat, speed: CGFloat, dt: TimeInterval) -> Bool {
        let probeX = body.pos.x + dir * (body.size.width / 2 + 8)
        let groundAhead = scene.physics.hasGround(at: CGPoint(x: probeX, y: body.pos.y))
        let wallAhead = scene.physics.isBlocked(at: CGPoint(x: probeX, y: body.pos.y + 10))
        if body.onGround && (!groundAhead || wallAhead) {
            body.vel.dx = approach(body.vel.dx, 0, 2000 * CGFloat(dt))
            return false
        }
        body.vel.dx = approach(body.vel.dx, dir * speed, 1400 * CGFloat(dt))
        if dir != 0 { facing = dir }
        return true
    }

    func patrol(dt: TimeInterval, speed: CGFloat) {
        if body.pos.x < homeX - spawn.patrol { patrolDir = 1 }
        if body.pos.x > homeX + spawn.patrol { patrolDir = -1 }
        if !walk(patrolDir, speed: speed, dt: dt) { patrolDir *= -1 }
    }

    func canSeePlayer(range: CGFloat) -> Bool {
        player.alive && distanceToPlayer < range && playerVerticalGap < 180
    }

    /// Applies damage. Returns the damage actually dealt.
    @discardableResult
    func takeHit(_ amount: Int, piercing: Bool, knockback: CGFloat, dir: CGFloat) -> Int {
        guard alive else { return 0 }
        var dmg = CGFloat(amount) * vulnerability
        if !piercing { dmg *= def.armor }
        let dealt = max(1, Int(dmg.rounded()))
        health -= dealt
        let kb = knockback * (1 - knockbackResistance)
        if kb > 20 {
            body.vel.dx = dir * kb
            if kb > 120 { body.vel.dy = 160 }
            knockTimer = kb > 120 ? 0.22 : 0.06
        }
        squash = 0.82
        sprite.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.9, duration: 0),
            .wait(forDuration: 0.06),
            .colorize(withColorBlendFactor: 0, duration: 0.08)
        ]), withKey: "flash")
        onHurt()
        if health <= 0 { die() }
        return dealt
    }

    func onHurt() {}

    func die() {
        alive = false
        scene.enemyRemoved(self, rewarded: true)
        let center = CGPoint(x: body.pos.x, y: body.pos.y + body.size.height / 2)
        scene.burst(at: center, color: SKTheme.magenta, count: 18, speed: 260)
        scene.burst(at: center, color: SKTheme.ember, count: 8, speed: 160)
        node.run(.sequence([
            .group([.fadeOut(withDuration: 0.25), .scaleY(to: 0.6, duration: 0.25)]),
            .removeFromParent()
        ]))
    }

    func setGlow(_ alpha: CGFloat) {
        eyeGlow.alpha = alpha
    }
}

// MARK: - Skitter Drone: patrols, rushes, telegraphed lunge.

@MainActor
final class SkitterDrone: Enemy {
    enum State { case patrol, chase, windup, lunge, recover }
    private var state: State = .patrol
    private var lungeDir: CGFloat = 1
    private var hover: CGFloat = 0

    override var attackingContact: Bool { state == .lunge }

    override func think(dt: TimeInterval) {
        hover += CGFloat(dt) * 10
        switch state {
        case .patrol:
            patrol(dt: dt, speed: 70)
            setGlow(0.22)
            if canSeePlayer(range: def.aggroRange) { enter(.chase) }
        case .chase:
            setGlow(0.35)
            if !canSeePlayer(range: def.aggroRange * 1.3) { enter(.patrol); break }
            if distanceToPlayer < def.attackRange && attackCooldown <= 0 && playerVerticalGap < 90 && body.onGround {
                enter(.windup)
                body.vel.dx = 0
                lungeDir = dirToPlayer
                facing = lungeDir
                scene.playSFX(.bossWarn, volume: 0.25)
                break
            }
            walk(dirToPlayer, speed: def.moveSpeed, dt: dt)
        case .windup:
            body.vel.dx = 0
            setGlow(0.4 + CGFloat(stateTime / def.telegraph) * 0.6)
            squash = 0.86
            sprite.position.x = sin(CGFloat(stateTime) * 90) * 1.5
            if stateTime >= def.telegraph {
                sprite.position.x = 0
                enter(.lunge)
                body.vel = CGVector(dx: lungeDir * 430, dy: 340)
                squash = 1.12
            }
        case .lunge:
            setGlow(1)
            if stateTime > 0.12 && body.onGround { enter(.recover); body.vel.dx = 0 }
            if stateTime > 0.9 { enter(.recover) }
        case .recover:
            setGlow(0.15)
            body.vel.dx = approach(body.vel.dx, 0, 1600 * CGFloat(dt))
            if stateTime > 0.55 {
                attackCooldown = def.attackCooldown
                enter(.chase)
            }
        }
    }

    override func render(dt: TimeInterval) {
        super.render(dt: dt)
        if state == .patrol || state == .chase {
            sprite.position.y = abs(sin(hover)) * 2
        }
    }

    private func enter(_ s: State) { state = s; stateTime = 0 }
}

// MARK: - Corsair Gunner: keeps distance, telegraphed aimed shots.

@MainActor
final class CorsairGunner: Enemy {
    enum State { case patrol, engage, aim, fire }
    private var state: State = .patrol
    private var aimTarget: CGPoint = .zero
    private let laser = SKSpriteNode(texture: ArtFactory.band)
    private var shotsLeft = 0

    override init(spawn: EnemySpawn, scene: GameScene) {
        super.init(spawn: spawn, scene: scene)
        laser.color = SKTheme.magenta
        laser.colorBlendFactor = 1
        laser.blendMode = .add
        laser.anchorPoint = CGPoint(x: 0, y: 0.5)
        laser.alpha = 0
        laser.zPosition = 25
        scene.world.addChild(laser)
        attackCooldown = 0.8
    }

    var muzzle: CGPoint {
        CGPoint(x: body.pos.x + facing * def.hitbox.width * 0.75, y: body.pos.y + def.spriteHeight * 0.66)
    }

    override func think(dt: TimeInterval) {
        switch state {
        case .patrol:
            setGlow(0.22)
            patrol(dt: dt, speed: 50)
            if canSeePlayer(range: def.aggroRange) { enter(.engage) }
        case .engage:
            setGlow(0.3)
            facing = dirToPlayer
            if !canSeePlayer(range: def.aggroRange * 1.25) { enter(.patrol); break }
            let d = distanceToPlayer
            if d < 260 {
                if !walk(-dirToPlayer, speed: def.moveSpeed, dt: dt) { body.vel.dx = 0 }
                facing = dirToPlayer
            } else if d > 420 {
                walk(dirToPlayer, speed: def.moveSpeed, dt: dt)
            } else {
                body.vel.dx = approach(body.vel.dx, 0, 1200 * CGFloat(dt))
            }
            if attackCooldown <= 0 && d < def.attackRange && playerVerticalGap < 220 {
                enter(.aim)
                body.vel.dx = 0
                scene.playSFX(.bossWarn, volume: 0.3)
            }
        case .aim:
            facing = dirToPlayer
            body.vel.dx = 0
            aimTarget = CGPoint(x: player.body.pos.x, y: player.body.pos.y + 32)
            let progress = CGFloat(stateTime / def.telegraph)
            setGlow(0.4 + progress * 0.6)
            showLaser(alpha: 0.25 + 0.55 * progress * (Int(stateTime * 18) % 2 == 0 ? 1 : 0.6), width: 2 + progress * 2)
            if stateTime >= def.telegraph {
                enter(.fire)
                shotsLeft = 2
                fireShot()
            }
        case .fire:
            laser.alpha = 0
            if shotsLeft > 0 && stateTime > 0.16 {
                stateTime = 0
                fireShot()
            }
            if shotsLeft == 0 && stateTime > 0.4 {
                attackCooldown = def.attackCooldown
                enter(.engage)
            }
        }
    }

    private func fireShot() {
        shotsLeft -= 1
        let m = muzzle
        let dx = aimTarget.x - m.x, dy = aimTarget.y - m.y
        let len = max(1, hypot(dx, dy))
        let speed: CGFloat = 400
        scene.spawnProjectile(at: m, vel: CGVector(dx: dx / len * speed, dy: dy / len * speed),
                              damage: def.attackDamage / 2 + 2, friendly: false, style: .enemyBolt, life: 1.8, knockback: 0)
        scene.muzzleFlash(at: m, color: SKTheme.magenta)
        scene.playSFX(.blaster, volume: 0.45)
        squash = 0.92
    }

    private func showLaser(alpha: CGFloat, width: CGFloat) {
        let m = muzzle
        let dx = aimTarget.x - m.x, dy = aimTarget.y - m.y
        laser.position = m
        laser.zRotation = atan2(dy, dx)
        laser.size = CGSize(width: min(hypot(dx, dy), 640), height: width * 3)
        laser.alpha = alpha
    }

    override func die() {
        laser.removeFromParent()
        super.die()
    }

    override func fellOut() {
        laser.removeFromParent()
        super.fellOut()
    }

    override func onHurt() {
        if state == .patrol { enter(.engage) }
    }

    private func enter(_ s: State) { state = s; stateTime = 0 }
}

// MARK: - Ironbound: armoured, telegraphed slam, vulnerable recovery.

@MainActor
final class Ironbound: Enemy {
    enum State { case patrol, chase, windup, slam, recover }
    private var state: State = .patrol
    private let vulnGlow = SKSpriteNode(texture: ArtFactory.glow)
    private var pendingZone: TimedZone?

    override var vulnerability: CGFloat { state == .recover ? 1.5 : 1 }
    override var knockbackResistance: CGFloat { state == .recover ? 0.4 : 0.85 }

    override init(spawn: EnemySpawn, scene: GameScene) {
        super.init(spawn: spawn, scene: scene)
        vulnGlow.color = SKTheme.softViolet
        vulnGlow.colorBlendFactor = 1
        vulnGlow.blendMode = .add
        vulnGlow.size = CGSize(width: 90, height: 90)
        vulnGlow.position = CGPoint(x: 0, y: 58)
        vulnGlow.alpha = 0
        vulnGlow.zPosition = 3
        node.addChild(vulnGlow)
    }

    override func think(dt: TimeInterval) {
        switch state {
        case .patrol:
            setGlow(0.2)
            patrol(dt: dt, speed: 40)
            if canSeePlayer(range: def.aggroRange) { enter(.chase) }
        case .chase:
            setGlow(0.3)
            if !canSeePlayer(range: def.aggroRange * 1.3) { enter(.patrol); break }
            if distanceToPlayer < def.attackRange + 30 && attackCooldown <= 0 && playerVerticalGap < 120 {
                facing = dirToPlayer
                body.vel.dx = 0
                enter(.windup)
                let width: CGFloat = 170
                let x = facing > 0 ? body.pos.x - 30 : body.pos.x - width + 30
                pendingZone = scene.addZone(rect: CGRect(x: x, y: body.pos.y, width: width, height: 56),
                              telegraph: def.telegraph, active: 0.14, damage: def.attackDamage,
                              style: .slam, sourceX: body.pos.x)
                scene.playSFX(.bossCharge, volume: 0.5)
                break
            }
            walk(dirToPlayer, speed: def.moveSpeed, dt: dt)
        case .windup:
            body.vel.dx = 0
            let p = CGFloat(stateTime / def.telegraph)
            setGlow(0.4 + p * 0.7)
            squash = 1 + p * 0.1
            sprite.zRotation = facing * p * 0.12
            if stateTime >= def.telegraph {
                enter(.slam)
                squash = 0.8
                sprite.zRotation = -facing * 0.08
                scene.shake(9)
                scene.playSFX(.slam)
                Haptics.medium()
                scene.dust(at: CGPoint(x: body.pos.x + facing * 60, y: body.pos.y), dir: 0, count: 14)
            }
        case .slam:
            if stateTime > 0.18 {
                enter(.recover)
                sprite.zRotation = 0
            }
        case .recover:
            setGlow(0.08)
            vulnGlow.alpha = 0.35 + 0.25 * sin(CGFloat(stateTime) * 14)
            body.vel.dx = 0
            if stateTime > 1.3 {
                vulnGlow.alpha = 0
                attackCooldown = def.attackCooldown
                enter(.chase)
            }
        }
    }

    override func onHurt() {
        if state == .patrol { enter(.chase) }
    }

    override func die() {
        if let z = pendingZone, state == .windup { scene.cancelZone(z) }
        super.die()
    }

    private func enter(_ s: State) { state = s; stateTime = 0 }
}
