import SpriteKit

/// Movement tuning for Kael. Kept in one place for fast iteration.
enum PlayerTuning {
    static let runSpeed: CGFloat = 236
    static let groundAccel: CGFloat = 2400
    static let groundDecel: CGFloat = 3000
    static let airAccel: CGFloat = 1500
    static let gravity: CGFloat = 2000
    static let lowJumpGravity: CGFloat = 2600   // extra gravity while rising with jump released
    static let maxFall: CGFloat = -900
    static let jumpVelocity: CGFloat = 760
    static let coyoteTime: TimeInterval = 0.1
    static let jumpBuffer: TimeInterval = 0.12
    static let dashSpeed: CGFloat = 640
    static let dashTime: TimeInterval = 0.17
    static let dashCooldown: TimeInterval = 0.6
    static let hitbox = CGSize(width: 26, height: 60)
    static let spriteHeight: CGFloat = 80
    static let hurtInvulnerability: TimeInterval = 0.9
}

@MainActor
final class Player {
    let node = SKNode()
    let sprite: SKSpriteNode
    private let aura: SKSpriteNode
    private let shadow: SKSpriteNode
    var body: Body

    var facing: CGFloat = 1
    var health: Int
    var maxHealth: Int
    var weapon: WeaponID
    var alive = true
    var locked = false

    private(set) var dashTimer: TimeInterval = 0
    private var dashDir: CGFloat = 1
    private var dashCooldown: TimeInterval = 0
    private var airDashUsed = false
    private var coyote: TimeInterval = 0
    private var jumpBuffer: TimeInterval = 0
    var invulnerable: TimeInterval = 0
    var attackCooldown: TimeInterval = 0
    private var recoil: TimeInterval = 0
    private var landSquash: TimeInterval = 0
    private var runPhase: CGFloat = 0
    private var afterimageTimer: TimeInterval = 0
    private var wasOnGround = true
    private let baseScale: CGFloat
    var lastSafePosition: CGPoint

    var isDashing: Bool { dashTimer > 0 }
    var isInvulnerable: Bool { invulnerable > 0 || isDashing }

    var muzzle: CGPoint {
        CGPoint(x: body.pos.x + 26 * facing, y: body.pos.y + 40)
    }

    init(at position: CGPoint, loadout: PlayerLoadout, weapon: WeaponID) {
        body = Body(pos: position, size: PlayerTuning.hitbox)
        health = loadout.maxHealth
        maxHealth = loadout.maxHealth
        self.weapon = weapon
        lastSafePosition = position

        let tex = ArtFactory.character("kael_survivor_sprite", fallbackColor: SKTheme.cyan)
        sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        baseScale = PlayerTuning.spriteHeight / max(tex.size().height, 1)
        sprite.setScale(baseScale)
        sprite.colorBlendFactor = 0
        sprite.zPosition = 2

        aura = SKSpriteNode(texture: ArtFactory.glow)
        aura.color = SKTheme.cyan
        aura.colorBlendFactor = 1
        aura.alpha = 0.22
        aura.size = CGSize(width: 110, height: 120)
        aura.position = CGPoint(x: 0, y: 44)
        aura.blendMode = .add
        aura.zPosition = 1

        shadow = SKSpriteNode(texture: ArtFactory.glow)
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = 0.6
        shadow.size = CGSize(width: 54, height: 10)
        shadow.zPosition = 0

        node.addChild(shadow)
        node.addChild(aura)
        node.addChild(sprite)
        node.zPosition = 20
        node.position = position
    }

    // MARK: Update

    func update(dt: TimeInterval, input: InputState, scene: GameScene) {
        let fdt = CGFloat(dt)
        dashCooldown -= dt
        invulnerable -= dt
        attackCooldown -= dt
        recoil -= dt
        landSquash -= dt
        jumpBuffer -= dt

        var move: CGFloat = 0
        var jumpPressed = false
        var dashPressed = false
        if !locked && alive {
            let raw = input.moveX
            move = abs(raw) < 0.2 ? 0 : (raw > 0 ? 1 : -1) * min(1, (abs(raw) - 0.2) / 0.5 + 0.35)
            jumpPressed = input.consumeJump()
            dashPressed = input.consumeDash()
        } else {
            _ = input.consumeJump(); _ = input.consumeDash()
        }

        if jumpPressed { jumpBuffer = PlayerTuning.jumpBuffer }
        if body.onGround {
            coyote = PlayerTuning.coyoteTime
            airDashUsed = false
        } else {
            coyote -= dt
        }

        // Dash start
        if dashPressed && dashCooldown <= 0 && (body.onGround || !airDashUsed) {
            dashDir = move != 0 ? (move > 0 ? 1 : -1) : facing
            facing = dashDir
            dashTimer = PlayerTuning.dashTime
            dashCooldown = PlayerTuning.dashCooldown
            if !body.onGround { airDashUsed = true }
            scene.playSFX(.dash)
            Haptics.light(0.5)
            scene.dust(at: body.pos, dir: -dashDir)
        }

        if dashTimer > 0 {
            dashTimer -= dt
            body.vel = CGVector(dx: dashDir * PlayerTuning.dashSpeed, dy: 0)
            afterimageTimer -= dt
            if afterimageTimer <= 0 {
                afterimageTimer = 0.03
                scene.afterimage(of: sprite, at: node.position)
            }
            if dashTimer <= 0 {
                body.vel.dx = dashDir * PlayerTuning.runSpeed * 0.8
            }
        } else {
            let target = move * PlayerTuning.runSpeed
            let accel: CGFloat
            if body.onGround {
                accel = (target == 0 || (target > 0) != (body.vel.dx > 0)) ? PlayerTuning.groundDecel : PlayerTuning.groundAccel
            } else {
                accel = PlayerTuning.airAccel
            }
            body.vel.dx = approach(body.vel.dx, target, accel * fdt)
            var g = PlayerTuning.gravity
            if body.vel.dy > 0 && !input.jumpHeld { g += PlayerTuning.lowJumpGravity }
            body.vel.dy = max(PlayerTuning.maxFall, body.vel.dy - g * fdt)
            if move != 0 { facing = move > 0 ? 1 : -1 }
        }

        // Jump (also cancels a dash for momentum tech)
        if jumpBuffer > 0 && coyote > 0 && !locked && alive {
            jumpBuffer = 0
            coyote = 0
            dashTimer = 0
            body.vel.dy = PlayerTuning.jumpVelocity
            scene.playSFX(.jump, volume: 0.8)
            scene.dust(at: body.pos, dir: 0)
        }

        scene.physics.move(&body, dt: fdt)

        if body.onGround && !wasOnGround {
            landSquash = 0.12
            scene.dust(at: body.pos, dir: 0)
        }
        wasOnGround = body.onGround

        if body.onGround,
           scene.physics.hasGround(at: CGPoint(x: body.pos.x - 34, y: body.pos.y)),
           scene.physics.hasGround(at: CGPoint(x: body.pos.x + 34, y: body.pos.y)),
           !scene.isOverHazard(body.rect) {
            lastSafePosition = body.pos
        }

        animate(dt: dt)
    }

    func recoilKick() { recoil = 0.08 }

    // MARK: Damage

    /// Returns true if damage was applied.
    @discardableResult
    func hurt(_ amount: Int, from sourceX: CGFloat?, scene: GameScene, force: Bool = false) -> Bool {
        guard alive, force || !isInvulnerable else { return false }
        health = max(0, health - amount)
        invulnerable = PlayerTuning.hurtInvulnerability
        if let sx = sourceX {
            let dir: CGFloat = body.pos.x >= sx ? 1 : -1
            body.vel = CGVector(dx: dir * 300, dy: 380)
        }
        sprite.run(.sequence([
            .colorize(with: SKTheme.magenta, colorBlendFactor: 0.85, duration: 0.02),
            .wait(forDuration: 0.12),
            .colorize(withColorBlendFactor: 0, duration: 0.1)
        ]))
        return true
    }

    // MARK: Animation

    private func animate(dt: TimeInterval) {
        node.position = body.pos
        let speedFrac = min(1, abs(body.vel.dx) / PlayerTuning.runSpeed)
        var sx: CGFloat = 1, sy: CGFloat = 1
        var yOff: CGFloat = 0
        var rot: CGFloat = 0

        if isDashing {
            sx = 1.18; sy = 0.9
            rot = -0.12 * facing
        } else if !body.onGround {
            if body.vel.dy > 120 { sx = 0.93; sy = 1.08 } else if body.vel.dy < -200 { sx = 0.96; sy = 1.05 }
            rot = -0.05 * (body.vel.dx / PlayerTuning.runSpeed)
        } else {
            if speedFrac > 0.1 {
                runPhase += CGFloat(dt) * 15 * speedFrac
                yOff = abs(sin(runPhase)) * 3.5
                rot = -0.07 * (body.vel.dx / PlayerTuning.runSpeed)
                sy = 1 + sin(runPhase * 2) * 0.02
            } else {
                runPhase = 0
                sy = 1 + sin(CGFloat(CACurrentMediaTime()) * 2.4) * 0.012
            }
        }
        if landSquash > 0 { sx *= 1.1; sy *= 0.88 }
        let recoilOffset: CGFloat = recoil > 0 ? -4 * facing : 0

        sprite.xScale = baseScale * sx * facing
        sprite.yScale = baseScale * sy
        sprite.position = CGPoint(x: recoilOffset, y: yOff)
        sprite.zRotation = rot

        // Blink while invulnerable after a hit
        if invulnerable > 0 && !isDashing && alive {
            sprite.alpha = Int(invulnerable * 20) % 2 == 0 ? 0.35 : 1
        } else {
            sprite.alpha = alive ? 1 : sprite.alpha
        }
        aura.alpha = isDashing ? 0.55 : 0.2 + 0.04 * sin(CGFloat(CACurrentMediaTime()) * 3)
        shadow.alpha = body.onGround ? 0.55 : 0.25
    }
}

func approach(_ value: CGFloat, _ target: CGFloat, _ delta: CGFloat) -> CGFloat {
    if value < target { return min(value + delta, target) }
    return max(value - delta, target)
}
