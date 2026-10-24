import SpriteKit

@MainActor
final class Projectile {
    enum Style { case playerBolt, enemyBolt, bossBolt }

    let node: SKNode
    var pos: CGPoint
    var vel: CGVector
    let damage: Int
    let friendly: Bool
    let radius: CGFloat
    var life: TimeInterval
    let knockback: CGFloat
    var dead = false

    init(pos: CGPoint, vel: CGVector, damage: Int, friendly: Bool, style: Style, life: TimeInterval, knockback: CGFloat) {
        self.pos = pos
        self.vel = vel
        self.damage = damage
        self.friendly = friendly
        self.life = life
        self.knockback = knockback
        let color: SKColor = friendly ? SKTheme.cyan : SKTheme.magenta
        radius = style == .bossBolt ? 11 : (friendly ? 7 : 8)

        let container = SKNode()
        let halo = SKSpriteNode(texture: ArtFactory.glow)
        halo.color = color
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.size = CGSize(width: radius * 6, height: radius * 4)
        halo.alpha = 0.75
        container.addChild(halo)

        let core = SKSpriteNode(texture: ArtFactory.bolt)
        core.color = friendly ? .white : SKColor(hex: 0xFFC2D8)
        core.colorBlendFactor = 1
        core.size = CGSize(width: style == .bossBolt ? 40 : 34, height: radius * 1.5)
        core.anchorPoint = CGPoint(x: 0.8, y: 0.5)
        container.addChild(core)

        let tint = SKSpriteNode(texture: ArtFactory.bolt)
        tint.color = color
        tint.colorBlendFactor = 1
        tint.blendMode = .add
        tint.size = CGSize(width: core.size.width * 1.3, height: radius * 2.6)
        tint.anchorPoint = CGPoint(x: 0.8, y: 0.5)
        container.addChild(tint)

        container.zRotation = atan2(vel.dy, vel.dx)
        container.position = pos
        container.zPosition = 30
        node = container
    }

    var rect: CGRect { CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2) }
}

/// A telegraphed damage area: shows a warning for `telegraph` seconds, then deals damage
/// once to the player while `active`. Used for slams, beams, rockets and debris.
@MainActor
final class TimedZone {
    enum Style { case slam, beam, rocket, debris }

    let rect: CGRect
    let telegraph: TimeInterval
    let active: TimeInterval
    let damage: Int
    let style: Style
    let sourceX: CGFloat?
    var t: TimeInterval = 0
    var hasHit = false
    var activated = false
    let node = SKNode()
    var warning: SKSpriteNode?

    init(rect: CGRect, telegraph: TimeInterval, active: TimeInterval, damage: Int, style: Style, sourceX: CGFloat?) {
        self.rect = rect
        self.telegraph = telegraph
        self.active = active
        self.damage = damage
        self.style = style
        self.sourceX = sourceX
    }

    var isActive: Bool { t >= telegraph && t < telegraph + active }
    var finished: Bool { t >= telegraph + active }
}

@MainActor
final class Pickup {
    let specID: Int?
    let kind: PickupKind
    let node = SKNode()
    var body: Body
    var value: Double
    var magnetized = false
    var dynamic: Bool
    var age: TimeInterval = 0
    var dead = false
    let baseY: CGFloat

    init(specID: Int?, kind: PickupKind, position: CGPoint, value: Double, dynamic: Bool) {
        self.specID = specID
        self.kind = kind
        self.value = value
        self.dynamic = dynamic
        baseY = position.y
        body = Body(pos: position, size: CGSize(width: 14, height: 14))
        node.position = position
        node.zPosition = 6
        build()
    }

    private func build() {
        switch kind {
        case .shard:
            let halo = SKSpriteNode(texture: ArtFactory.glow)
            halo.color = SKTheme.cyan
            halo.colorBlendFactor = 1
            halo.blendMode = .add
            halo.alpha = 0.6
            halo.size = CGSize(width: 40, height: 40)
            halo.position = CGPoint(x: 0, y: 10)
            node.addChild(halo)
            let gem = SKSpriteNode(texture: ArtFactory.shard)
            gem.size = dynamic ? CGSize(width: 10, height: 15) : CGSize(width: 14, height: 21)
            gem.position = CGPoint(x: 0, y: 10)
            gem.run(.repeatForever(.sequence([.scaleX(to: 0.3, duration: 0.5), .scaleX(to: 1, duration: 0.5)])))
            node.addChild(gem)
        case .health:
            let halo = SKSpriteNode(texture: ArtFactory.glow)
            halo.color = SKTheme.heal
            halo.colorBlendFactor = 1
            halo.blendMode = .add
            halo.size = CGSize(width: 54, height: 54)
            halo.position = CGPoint(x: 0, y: 12)
            halo.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 0.9, duration: 0.6)])))
            node.addChild(halo)
            let cross = SKNode()
            let v = SKSpriteNode(color: .white, size: CGSize(width: 5, height: 15))
            let h = SKSpriteNode(color: .white, size: CGSize(width: 15, height: 5))
            cross.addChild(v); cross.addChild(h)
            cross.position = CGPoint(x: 0, y: 12)
            node.addChild(cross)
        case .weapon:
            let pillar = SKSpriteNode(texture: ArtFactory.verticalFade)
            pillar.color = SKTheme.cyan
            pillar.colorBlendFactor = 1
            pillar.blendMode = .add
            pillar.alpha = 0.35
            pillar.size = CGSize(width: 60, height: 260)
            pillar.anchorPoint = CGPoint(x: 0.5, y: 0)
            pillar.position = CGPoint(x: 0, y: -40)
            node.addChild(pillar)
            let halo = SKSpriteNode(texture: ArtFactory.glow)
            halo.color = SKTheme.cyan
            halo.colorBlendFactor = 1
            halo.blendMode = .add
            halo.size = CGSize(width: 90, height: 90)
            halo.position = CGPoint(x: 0, y: 14)
            node.addChild(halo)
            let blade = SKSpriteNode(texture: ArtFactory.slash)
            blade.color = SKTheme.cyan
            blade.colorBlendFactor = 0.6
            blade.size = CGSize(width: 46, height: 46)
            blade.position = CGPoint(x: -6, y: 14)
            blade.zRotation = .pi / 2
            node.addChild(blade)
            node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.9), .moveBy(x: 0, y: -6, duration: 0.9)])))
        }
    }
}
