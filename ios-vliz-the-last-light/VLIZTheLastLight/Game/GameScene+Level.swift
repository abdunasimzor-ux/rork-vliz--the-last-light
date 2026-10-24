import SpriteKit

extension ZoneStyle {
    var accent: SKColor {
        switch self {
        case .settlement: return SKTheme.ember
        case .caverns: return SKTheme.softViolet
        case .station: return SKColor(hex: 0x2FD6C8)
        case .arena: return SKTheme.magenta
        }
    }

    var fog: SKColor {
        switch self {
        case .settlement: return SKColor(hex: 0x3A1A2E)
        case .caverns: return SKTheme.violet
        case .station: return SKTheme.teal
        case .arena: return SKColor(hex: 0x3B0F2C)
        }
    }

    var moteColor: SKColor {
        switch self {
        case .settlement: return SKTheme.ember
        case .caverns: return SKTheme.cyan
        case .station: return SKColor(hex: 0x6FF7E8)
        case .arena: return SKTheme.magenta
        }
    }

    var title: String {
        switch self {
        case .settlement: return "RUINED SETTLEMENT"
        case .caverns: return "CRYSTAL CAVERNS"
        case .station: return "ABANDONED ENERGY STATION"
        case .arena: return "REACTOR CORE"
        }
    }
}

extension GameScene {

    // MARK: Background (camera-space parallax)

    func buildBackground() {
        for _ in 0..<2 {
            let s = SKSpriteNode()
            s.zPosition = -100
            s.alpha = 0
            s.color = SKTheme.void
            s.colorBlendFactor = 0.25
            cam.addChild(s)
            backdropNodes.append(s)
        }

        shadeNode = SKSpriteNode(color: SKTheme.void, size: CGSize(width: 10, height: 10))
        shadeNode.alpha = 0.22
        shadeNode.zPosition = -95
        cam.addChild(shadeNode)

        silhouetteLayer.zPosition = -90
        cam.addChild(silhouetteLayer)
        for _ in 0..<4 {
            let t = SKSpriteNode()
            t.anchorPoint = CGPoint(x: 0, y: 0)
            t.colorBlendFactor = 1
            silhouetteLayer.addChild(t)
            silhouetteTiles.append(t)
        }

        fogNode = SKSpriteNode(texture: ArtFactory.verticalFade)
        fogNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        fogNode.colorBlendFactor = 1
        fogNode.alpha = 0.55
        fogNode.zPosition = -85
        cam.addChild(fogNode)

        let emitter = SKEmitterNode()
        emitter.particleTexture = ArtFactory.dot
        emitter.particleBirthRate = reduced ? 3 : 9
        emitter.particleLifetime = 9
        emitter.particleLifetimeRange = 3
        emitter.particleSpeed = 18
        emitter.particleSpeedRange = 12
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.8
        emitter.particleAlpha = 0.7
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -0.08
        emitter.particleScale = 0.25
        emitter.particleScaleRange = 0.2
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.zPosition = -80
        emitter.advanceSimulationTime(8)
        cam.addChild(emitter)
        motes = emitter
    }

    func layoutBackground() {
        let vis = CGSize(width: size.width, height: size.height) // camera-space is pre-scale
        for s in backdropNodes {
            guard let tex = s.texture else { continue }
            let ts = tex.size()
            let scale = max(vis.width * 1.12 / ts.width, vis.height * 1.06 / ts.height)
            s.size = CGSize(width: ts.width * scale, height: ts.height * scale)
        }
        shadeNode.size = CGSize(width: vis.width * 1.3, height: vis.height * 1.3)
        fogNode.size = CGSize(width: vis.width * 1.3, height: vis.height * 0.5)
        fogNode.position = CGPoint(x: 0, y: -vis.height / 2 - 10)
        motes?.position = CGPoint(x: 0, y: -vis.height / 2 - 10)
        motes?.particlePositionRange = CGVector(dx: vis.width * 1.2, dy: 40)
        layoutParallax()
    }

    /// Children of the camera are in screen points (camera scale applies on top), so convert.
    func layoutParallax() {
        guard size.width > 0 else { return }
        let inv = 1 / cameraScale
        let progress = cam.position.x / max(level.width, 1) - 0.5
        for s in backdropNodes {
            s.position = CGPoint(x: -progress * size.width * 0.08, y: 0)
            s.setScale(1)
        }
        // Silhouette strip at ~35% parallax, in world units converted to screen points.
        let tileW: CGFloat = 1024 * inv * 0.8
        let tileH: CGFloat = 220 * inv * 0.8
        let offset = (cam.position.x * 0.35 * inv * 0.8).truncatingRemainder(dividingBy: tileW)
        let groundScreenY = (level.groundTop - cam.position.y) * inv
        for (i, t) in silhouetteTiles.enumerated() {
            t.size = CGSize(width: tileW + 1, height: tileH)
            t.position = CGPoint(x: -size.width / 2 - offset + CGFloat(i) * tileW - tileW * 0.25, y: groundScreenY - 6 * inv)
        }
    }

    func updateZone(force: Bool) {
        guard let player else { return }
        let style = level.zone(at: player.body.pos.x).style
        guard force || style != currentZone else { return }
        let previous = currentZone
        currentZone = style

        let next = backdropNodes[(activeBackdrop + 1) % 2]
        let current = backdropNodes[activeBackdrop]
        if let img = UIImage(named: style.backdrop) {
            next.texture = SKTexture(image: img)
        }
        next.removeAllActions()
        next.zPosition = -99
        current.zPosition = -100
        next.run(.fadeIn(withDuration: force ? 0 : 1.2))
        current.run(.sequence([.wait(forDuration: force ? 0 : 1.2), .fadeOut(withDuration: 0.2)]))
        activeBackdrop = (activeBackdrop + 1) % 2
        layoutBackground()

        let silTex = ArtFactory.silhouette(for: style)
        for t in silhouetteTiles {
            t.texture = silTex
            t.color = style.fog.withAlphaComponent(1)
            t.colorBlendFactor = 0.55
            t.alpha = 0.9
        }
        fogNode.color = style.fog
        motes?.particleColor = style.moteColor
        motes?.particleColorSequence = nil

        if previous != nil {
            session?.showBanner(style.title, subtitle: nil, style: .info, duration: 2.2)
        }
    }

    // MARK: Level geometry

    func buildLevel() {
        var rng = SplitMix(seed: 7)
        for spec in level.solids {
            let style = level.zone(at: spec.rect.midX).style
            if let gate = spec.gateID {
                let n = makeGate(rect: spec.rect)
                gateNodes[gate, default: []].append(n)
                world.addChild(n)
            } else if spec.oneWay {
                world.addChild(makePlatform(rect: spec.rect, accent: style.accent))
            } else {
                world.addChild(makeTerrain(rect: spec.rect, accent: style.accent, rng: &rng))
            }
        }
        for h in level.hazards { buildHazard(h) }
        for d in level.decor { world.addChild(makeDecor(d)) }
        for cp in level.checkpoints { buildCheckpoint(cp) }
        // Mark checkpoints reached in this snapshot.
        if let cpID = config.checkpointID, let reached = level.checkpoints.first(where: { $0.id == cpID }) {
            for cp in level.checkpoints where cp.x <= reached.x {
                activatedCheckpoints.insert(cp.id)
                lightCheckpoint(cp.id, animated: false)
            }
        }
    }

    private func makeTerrain(rect: CGRect, accent: SKColor, rng: inout SplitMix) -> SKNode {
        let n = SKNode()
        let bodySprite = SKSpriteNode(color: SKTheme.rock, size: rect.size)
        bodySprite.anchorPoint = .zero
        bodySprite.position = rect.origin
        n.addChild(bodySprite)

        let bandH = min(48, rect.height)
        let band = SKSpriteNode(texture: ArtFactory.terrainTop(accent: accent))
        band.anchorPoint = CGPoint(x: 0, y: 1)
        band.size = CGSize(width: rect.width, height: bandH)
        band.position = CGPoint(x: rect.minX, y: rect.maxY)
        n.addChild(band)

        let edge = SKSpriteNode(color: accent, size: CGSize(width: rect.width, height: 2))
        edge.anchorPoint = CGPoint(x: 0, y: 1)
        edge.position = CGPoint(x: rect.minX, y: rect.maxY)
        edge.alpha = 0.55
        n.addChild(edge)

        // Sparse luminous tufts along the top edge
        if rect.width > 90 && rect.maxY > 0 && rect.maxY < 400 {
            var x = rect.minX + 30
            while x < rect.maxX - 20 {
                let tuft = SKSpriteNode(texture: ArtFactory.glow)
                let cyan = rng.next() > 0.55
                tuft.color = cyan ? SKTheme.cyan : accent
                tuft.colorBlendFactor = 1
                tuft.blendMode = .add
                let s = 10 + rng.next() * 16
                tuft.size = CGSize(width: s, height: s)
                tuft.alpha = 0.3 + rng.next() * 0.35
                tuft.position = CGPoint(x: x, y: rect.maxY + 2)
                n.addChild(tuft)
                let stem = SKSpriteNode(color: cyan ? SKTheme.cyan : accent, size: CGSize(width: 2, height: 4 + rng.next() * 8))
                stem.anchorPoint = CGPoint(x: 0.5, y: 0)
                stem.alpha = 0.6
                stem.position = CGPoint(x: x, y: rect.maxY)
                n.addChild(stem)
                x += 60 + rng.next() * 110
            }
        }
        n.zPosition = 0
        return n
    }

    private func makePlatform(rect: CGRect, accent: SKColor) -> SKNode {
        let n = SKNode()
        let slab = SKSpriteNode(color: SKTheme.rockEdge, size: rect.size)
        slab.anchorPoint = .zero
        slab.position = rect.origin
        n.addChild(slab)
        let under = SKSpriteNode(color: SKTheme.rock, size: CGSize(width: rect.width - 10, height: 8))
        under.anchorPoint = CGPoint(x: 0, y: 1)
        under.position = CGPoint(x: rect.minX + 5, y: rect.minY)
        n.addChild(under)
        let edge = SKSpriteNode(color: accent, size: CGSize(width: rect.width, height: 2))
        edge.anchorPoint = CGPoint(x: 0, y: 1)
        edge.position = CGPoint(x: rect.minX, y: rect.maxY)
        n.addChild(edge)
        let glow = SKSpriteNode(texture: ArtFactory.glow)
        glow.color = accent
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.35
        glow.size = CGSize(width: rect.width * 1.1, height: 26)
        glow.position = CGPoint(x: rect.midX, y: rect.maxY)
        n.addChild(glow)
        n.zPosition = 1
        return n
    }

    private func makeGate(rect: CGRect) -> SKNode {
        let n = SKNode()
        let field = SKSpriteNode(color: SKTheme.magenta, size: CGSize(width: rect.width, height: 260))
        field.anchorPoint = CGPoint(x: 0, y: 0)
        field.position = CGPoint(x: rect.minX, y: rect.minY)
        field.alpha = 0.22
        field.blendMode = .add
        n.addChild(field)
        for x in [rect.minX, rect.maxX - 3] {
            let bar = SKSpriteNode(color: SKTheme.magenta, size: CGSize(width: 3, height: 260))
            bar.anchorPoint = .zero
            bar.position = CGPoint(x: x, y: rect.minY)
            n.addChild(bar)
        }
        let glow = SKSpriteNode(texture: ArtFactory.glow)
        glow.color = SKTheme.magenta
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.size = CGSize(width: 90, height: 300)
        glow.position = CGPoint(x: rect.midX, y: rect.minY + 130)
        glow.alpha = 0.5
        n.addChild(glow)
        n.alpha = 0
        n.zPosition = 15
        return n
    }

    func setGate(_ id: String, closed: Bool) {
        physics.setGate(id, active: closed)
        for n in gateNodes[id] ?? [] {
            n.removeAllActions()
            if closed {
                n.run(.sequence([
                    .fadeIn(withDuration: 0.25),
                    .repeatForever(.sequence([.fadeAlpha(to: 0.7, duration: 0.4), .fadeAlpha(to: 1, duration: 0.4)]))
                ]))
            } else {
                n.run(.fadeOut(withDuration: 0.4))
            }
        }
    }

    private func buildHazard(_ spec: HazardSpec) {
        let h = HazardRuntime(spec: spec)
        let r = spec.rect
        switch spec.kind {
        case .spikes:
            let path = CGMutablePath()
            let count = Int(r.width / 18)
            for i in 0..<count {
                let x = r.minX + CGFloat(i) * 18
                path.move(to: CGPoint(x: x, y: r.minY))
                path.addLine(to: CGPoint(x: x + 9, y: r.maxY))
                path.addLine(to: CGPoint(x: x + 18, y: r.minY))
                path.closeSubpath()
            }
            let shape = SKShapeNode(path: path)
            shape.fillColor = SKColor(hex: 0x3B1640)
            shape.strokeColor = SKTheme.magenta.withAlphaComponent(0.8)
            shape.lineWidth = 1.2
            h.node.addChild(shape)
            let glow = SKSpriteNode(texture: ArtFactory.band)
            glow.color = SKTheme.magenta
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.35
            glow.size = CGSize(width: r.width, height: 50)
            glow.position = CGPoint(x: r.midX, y: r.minY + 10)
            h.node.addChild(glow)
            h.active = true
        case .fireVent:
            let base = SKSpriteNode(color: SKTheme.rockEdge, size: CGSize(width: r.width + 14, height: 10))
            base.anchorPoint = CGPoint(x: 0.5, y: 0)
            base.position = CGPoint(x: r.midX, y: r.minY)
            h.node.addChild(base)
            let nozzle = SKSpriteNode(texture: ArtFactory.glow)
            nozzle.color = SKTheme.ember
            nozzle.colorBlendFactor = 1
            nozzle.blendMode = .add
            nozzle.size = CGSize(width: r.width * 1.6, height: 24)
            nozzle.position = CGPoint(x: r.midX, y: r.minY + 10)
            nozzle.alpha = 0.4
            h.node.addChild(nozzle)
            h.nozzleGlow = nozzle
            let flame = SKSpriteNode(texture: ArtFactory.verticalFade)
            flame.color = SKTheme.ember
            flame.colorBlendFactor = 1
            flame.blendMode = .add
            flame.anchorPoint = CGPoint(x: 0.5, y: 0)
            flame.size = CGSize(width: r.width * 1.2, height: r.height + 20)
            flame.position = CGPoint(x: r.midX, y: r.minY + 6)
            flame.yScale = 0.01
            flame.alpha = 0
            h.node.addChild(flame)
            h.flame = flame
        }
        h.node.zPosition = 4
        world.addChild(h.node)
        hazards.append(h)
    }

    private func buildCheckpoint(_ cp: CheckpointSpec) {
        let n = SKNode()
        n.position = CGPoint(x: cp.x, y: cp.y)
        let post = SKSpriteNode(color: SKTheme.rockEdge, size: CGSize(width: 8, height: 54))
        post.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.addChild(post)
        let cap = SKSpriteNode(color: SKTheme.textSecondaryUI, size: CGSize(width: 18, height: 4))
        cap.position = CGPoint(x: 0, y: 56)
        n.addChild(cap)
        let lamp = SKSpriteNode(texture: ArtFactory.glow)
        lamp.name = "lamp"
        lamp.color = SKTheme.softViolet
        lamp.colorBlendFactor = 1
        lamp.blendMode = .add
        lamp.size = CGSize(width: 34, height: 34)
        lamp.alpha = 0.45
        lamp.position = CGPoint(x: 0, y: 62)
        n.addChild(lamp)
        let pillar = SKSpriteNode(texture: ArtFactory.verticalFade)
        pillar.name = "pillar"
        pillar.color = SKTheme.cyan
        pillar.colorBlendFactor = 1
        pillar.blendMode = .add
        pillar.anchorPoint = CGPoint(x: 0.5, y: 0)
        pillar.size = CGSize(width: 26, height: 220)
        pillar.alpha = 0
        n.addChild(pillar)
        n.zPosition = 3
        world.addChild(n)
        checkpointNodes[cp.id] = n
    }

    func lightCheckpoint(_ id: String, animated: Bool) {
        guard let n = checkpointNodes[id] else { return }
        if let lamp = n.childNode(withName: "lamp") as? SKSpriteNode {
            lamp.color = SKTheme.cyan
            lamp.alpha = 0.9
            lamp.size = CGSize(width: 46, height: 46)
        }
        if let pillar = n.childNode(withName: "pillar") as? SKSpriteNode {
            pillar.alpha = animated ? 0.9 : 0.25
            if animated { pillar.run(.fadeAlpha(to: 0.25, duration: 1.2)) }
        }
    }

    // MARK: Decor

    private func makeDecor(_ d: DecorSpec) -> SKNode {
        let n = SKNode()
        n.position = d.position
        n.setScale(d.scale)
        n.zPosition = -5
        switch d.kind {
        case .crystal(let cyan):
            let color = cyan ? SKTheme.cyan : SKTheme.softViolet
            let path = CGMutablePath()
            let shards: [(CGFloat, CGFloat, CGFloat)] = [(-14, 54, -0.25), (0, 78, 0.05), (14, 46, 0.3), (-26, 30, -0.5), (24, 26, 0.55)]
            for (x, h, lean) in shards {
                path.move(to: CGPoint(x: x - 6, y: 0))
                path.addLine(to: CGPoint(x: x + lean * h, y: h))
                path.addLine(to: CGPoint(x: x + 6, y: 0))
                path.closeSubpath()
            }
            let shape = SKShapeNode(path: path)
            shape.fillColor = color.withAlphaComponent(0.35)
            shape.strokeColor = color.withAlphaComponent(0.9)
            shape.lineWidth = 1
            n.addChild(shape)
            let glow = SKSpriteNode(texture: ArtFactory.glow)
            glow.color = color
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.size = CGSize(width: 130, height: 110)
            glow.position = CGPoint(x: 0, y: 34)
            glow.alpha = 0.5
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 1.6), .fadeAlpha(to: 0.55, duration: 1.6)])))
            n.addChild(glow)
        case .memorial:
            let stone = SKShapeNode(rect: CGRect(x: -16, y: 0, width: 32, height: 46), cornerRadius: 10)
            stone.fillColor = SKColor(hex: 0x111A33)
            stone.strokeColor = SKTheme.cyan.withAlphaComponent(0.35)
            n.addChild(stone)
            let line = SKSpriteNode(color: SKTheme.cyan, size: CGSize(width: 2, height: 20))
            line.position = CGPoint(x: 0, y: 26)
            line.alpha = 0.8
            n.addChild(line)
            for x in [-26, 24, 34] as [CGFloat] {
                let candle = SKSpriteNode(texture: ArtFactory.glow)
                candle.color = SKTheme.cyan
                candle.colorBlendFactor = 1
                candle.blendMode = .add
                candle.size = CGSize(width: 20, height: 20)
                candle.position = CGPoint(x: x, y: 6)
                candle.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.7), .fadeAlpha(to: 1, duration: 0.9)])))
                n.addChild(candle)
            }
        case .ruinDome:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -70, y: 0))
            path.addQuadCurve(to: CGPoint(x: 10, y: 88), control: CGPoint(x: -70, y: 90))
            path.addLine(to: CGPoint(x: 22, y: 60))
            path.addLine(to: CGPoint(x: 38, y: 72))
            path.addQuadCurve(to: CGPoint(x: 70, y: 0), control: CGPoint(x: 70, y: 50))
            path.closeSubpath()
            let dome = SKShapeNode(path: path)
            dome.fillColor = SKColor(hex: 0x0A0F22)
            dome.strokeColor = SKTheme.ember.withAlphaComponent(0.35)
            n.addChild(dome)
            let fire = SKSpriteNode(texture: ArtFactory.glow)
            fire.color = SKTheme.ember
            fire.colorBlendFactor = 1
            fire.blendMode = .add
            fire.size = CGSize(width: 90, height: 70)
            fire.position = CGPoint(x: 26, y: 62)
            fire.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.3), .fadeAlpha(to: 0.7, duration: 0.45)])))
            n.addChild(fire)
        case .lamp:
            let pole = SKSpriteNode(color: SKColor(hex: 0x111A33), size: CGSize(width: 4, height: 76))
            pole.anchorPoint = CGPoint(x: 0.5, y: 0)
            n.addChild(pole)
            let light = SKSpriteNode(texture: ArtFactory.glow)
            light.color = SKTheme.ember
            light.colorBlendFactor = 1
            light.blendMode = .add
            light.size = CGSize(width: 60, height: 60)
            light.position = CGPoint(x: 0, y: 78)
            light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 0.8, duration: 0.12), .wait(forDuration: 1.7)])))
            n.addChild(light)
        case .pipe:
            let v = SKSpriteNode(color: SKColor(hex: 0x10283A), size: CGSize(width: 14, height: 180))
            v.anchorPoint = CGPoint(x: 0.5, y: 0)
            n.addChild(v)
            let h = SKSpriteNode(color: SKColor(hex: 0x10283A), size: CGSize(width: 120, height: 12))
            h.position = CGPoint(x: 50, y: 150)
            n.addChild(h)
            for y in [40, 100, 150] as [CGFloat] {
                let ring = SKSpriteNode(color: SKColor(hex: 0x2FD6C8), size: CGSize(width: 18, height: 3))
                ring.position = CGPoint(x: 0, y: y)
                ring.alpha = 0.6
                n.addChild(ring)
            }
        case .pedestal:
            let base = SKShapeNode(rect: CGRect(x: -26, y: 0, width: 52, height: 22), cornerRadius: 3)
            base.fillColor = SKColor(hex: 0x111A33)
            base.strokeColor = SKTheme.cyan.withAlphaComponent(0.7)
            n.addChild(base)
            let rim = SKSpriteNode(texture: ArtFactory.glow)
            rim.color = SKTheme.cyan
            rim.colorBlendFactor = 1
            rim.blendMode = .add
            rim.size = CGSize(width: 90, height: 24)
            rim.position = CGPoint(x: 0, y: 22)
            n.addChild(rim)
            n.zPosition = 2
        }
        return n
    }

    // MARK: Actors

    func spawnPlayer() {
        var start = level.playerStart
        if let cpID = config.checkpointID, let cp = level.checkpoints.first(where: { $0.id == cpID }) {
            start = CGPoint(x: cp.x + 30, y: cp.y)
        }
        let weapon: WeaponID = config.hasArcBlade ? config.equipped : .pulseBlaster
        player = Player(at: start, loadout: loadout, weapon: weapon)
        world.addChild(player.node)
    }

    func spawnActors() {
        for s in level.spawns where s.encounterID == nil && !config.defeatedSpawnIDs.contains(s.id) {
            spawnEnemy(s, warp: false)
        }
        for p in level.pickups where !config.collectedPickupIDs.contains(p.id) {
            if case .weapon = p.kind, config.completedObjectives.contains(ObjectiveID.arcBlade) { continue }
            let value: Double = { if case .shard = p.kind { return 2 * loadout.fragmentMultiplier } else { return 0 } }()
            let pickup = Pickup(specID: p.id, kind: p.kind, position: p.position, value: value, dynamic: false)
            world.addChild(pickup.node)
            pickups.append(pickup)
        }
    }

    @discardableResult
    func spawnEnemy(_ s: EnemySpawn, warp: Bool) -> Enemy {
        let e: Enemy
        switch s.kind {
        case .skitter: e = SkitterDrone(spawn: s, scene: self)
        case .gunner: e = CorsairGunner(spawn: s, scene: self)
        case .ironbound: e = Ironbound(spawn: s, scene: self)
        }
        world.addChild(e.node)
        enemies.append(e)
        if warp {
            e.node.alpha = 0
            e.node.run(.fadeIn(withDuration: 0.35))
            let center = CGPoint(x: s.x, y: s.y + e.def.spriteHeight / 2)
            burst(at: center, color: SKTheme.magenta, count: 14, speed: 180)
            let ring = SKSpriteNode(texture: ArtFactory.ring)
            ring.color = SKTheme.magenta
            ring.colorBlendFactor = 1
            ring.blendMode = .add
            ring.position = center
            ring.setScale(0.2)
            ring.zPosition = 40
            world.addChild(ring)
            ring.run(.sequence([.group([.scale(to: 1.6, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
            e.attackCooldown = 1.0
        }
        return e
    }
}

extension SKTheme {
    static let textSecondaryUI = SKColor(hex: 0x7F8CA8)
}
