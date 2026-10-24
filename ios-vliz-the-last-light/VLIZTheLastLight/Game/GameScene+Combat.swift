import SpriteKit
import UIKit

extension GameScene {

    // MARK: Player attacks

    func performAttack() {
        let def = WeaponCatalog.definition(player.weapon)
        player.attackCooldown = def.cooldown
        switch def.kind {
        case .projectile:
            let m = player.muzzle
            let speed = def.projectileSpeed
            spawnProjectile(at: m, vel: CGVector(dx: player.facing * speed, dy: 0),
                            damage: loadout.blasterDamage, friendly: true, style: .playerBolt,
                            life: Double(def.range / speed), knockback: def.knockback)
            muzzleFlash(at: m, color: SKTheme.cyan)
            player.recoilKick()
            playSFX(.blaster, volume: 0.55)
        case .melee:
            slash(def)
        }
    }

    private func slash(_ def: WeaponDefinition) {
        let f = player.facing
        let p = player.body.pos
        let reach = def.range
        let rect = CGRect(x: f > 0 ? p.x - 12 : p.x - reach, y: p.y - 8, width: reach + 12, height: 84)
        playSFX(.blade, volume: 0.8)
        Haptics.light(0.7)
        if player.body.onGround { player.body.vel.dx += f * 90 }

        // Visual crescent
        let arc = SKSpriteNode(texture: ArtFactory.slash)
        arc.color = SKTheme.cyan
        arc.colorBlendFactor = 0.55
        arc.blendMode = .add
        arc.size = CGSize(width: 96, height: 96)
        arc.position = CGPoint(x: p.x + f * 6, y: p.y + 36)
        arc.xScale = f
        arc.zPosition = 35
        world.addChild(arc)
        arc.run(.sequence([
            .group([.scaleX(to: f * 1.25, duration: 0.14), .scaleY(to: 1.15, duration: 0.14), .fadeOut(withDuration: 0.16)]),
            .removeFromParent()
        ]))

        var hitSomething = false
        for e in enemies where e.alive && e.body.rect.intersects(rect) {
            let dealt = e.takeHit(def.baseDamage, piercing: true, knockback: def.knockback, dir: f)
            damageNumber(dealt, at: CGPoint(x: e.body.pos.x, y: e.body.pos.y + e.body.size.height + 6), color: SKTheme.cyan, big: true)
            sparkAt(CGPoint(x: e.body.pos.x - f * e.body.size.width / 3, y: e.body.pos.y + e.body.size.height * 0.55), color: SKTheme.cyan)
            hitSomething = true
        }
        if let boss, boss.alive, boss.hitRect.intersects(rect) {
            let dealt = boss.takeHit(def.baseDamage, piercing: true)
            if dealt > 0 {
                damageNumber(dealt, at: CGPoint(x: boss.body.pos.x, y: boss.body.pos.y + 150), color: SKTheme.cyan, big: true)
            }
            sparkAt(CGPoint(x: boss.body.pos.x - f * 20, y: boss.body.pos.y + 70), color: SKTheme.cyan)
            hitSomething = true
        }
        // The blade cuts enemy bolts out of the air.
        for proj in projectiles where !proj.friendly && !proj.dead && proj.rect.intersects(rect.insetBy(dx: -8, dy: -8)) {
            proj.dead = true
            sparkAt(proj.pos, color: SKTheme.cyan)
            hitSomething = true
        }
        if hitSomething {
            playSFX(.enemyHit)
            hitstop(0.055)
            shake(3)
        }
    }

    // MARK: Projectiles

    @discardableResult
    func spawnProjectile(at pos: CGPoint, vel: CGVector, damage: Int, friendly: Bool, style: Projectile.Style, life: TimeInterval, knockback: CGFloat) -> Projectile {
        let p = Projectile(pos: pos, vel: vel, damage: damage, friendly: friendly, style: style, life: life, knockback: knockback)
        world.addChild(p.node)
        projectiles.append(p)
        return p
    }

    func updateProjectiles(dt: TimeInterval) {
        let fdt = CGFloat(dt)
        for p in projectiles where !p.dead {
            p.pos.x += p.vel.dx * fdt
            p.pos.y += p.vel.dy * fdt
            p.life -= dt
            p.node.position = p.pos
            if p.life <= 0 { p.dead = true; continue }
            if physics.isBlocked(at: p.pos) {
                p.dead = true
                sparkAt(p.pos, color: p.friendly ? SKTheme.cyan : SKTheme.magenta, small: true)
                continue
            }
            if p.friendly {
                for e in enemies where e.alive && e.body.rect.insetBy(dx: -4, dy: -4).intersects(p.rect) {
                    let dir: CGFloat = p.vel.dx >= 0 ? 1 : -1
                    let dealt = e.takeHit(p.damage, piercing: false, knockback: p.knockback, dir: dir)
                    damageNumber(dealt, at: CGPoint(x: e.body.pos.x, y: e.body.pos.y + e.body.size.height + 4),
                                 color: e.def.armor < 1 ? SKTheme.textSecondaryUI : .white, big: false)
                    sparkAt(p.pos, color: e.def.armor < 1 ? SKTheme.softViolet : SKTheme.cyan, small: true)
                    playSFX(.enemyHit, volume: 0.6)
                    p.dead = true
                    break
                }
                if !p.dead, let boss, boss.alive, boss.hitRect.intersects(p.rect) {
                    let dealt = boss.takeHit(p.damage, piercing: false)
                    if dealt > 0 {
                        damageNumber(dealt, at: CGPoint(x: boss.body.pos.x + CGFloat.random(in: -20...20), y: boss.body.pos.y + 150), color: .white, big: false)
                        playSFX(.enemyHit, volume: 0.6)
                    }
                    sparkAt(p.pos, color: SKTheme.cyan, small: true)
                    p.dead = true
                }
            } else if player.alive && player.body.rect.insetBy(dx: -2, dy: -2).intersects(p.rect) {
                if !player.isInvulnerable {
                    damagePlayer(p.damage, from: p.pos.x - p.vel.dx)
                    p.dead = true
                    sparkAt(p.pos, color: SKTheme.magenta, small: false)
                }
            }
        }
        for p in projectiles where p.dead { p.node.removeFromParent() }
        projectiles.removeAll { $0.dead }
    }

    // MARK: Telegraphed zones

    @discardableResult
    func addZone(rect: CGRect, telegraph: TimeInterval, active: TimeInterval, damage: Int, style: TimedZone.Style, sourceX: CGFloat?) -> TimedZone {
        let z = TimedZone(rect: rect, telegraph: telegraph, active: active, damage: damage, style: style, sourceX: sourceX)
        z.node.zPosition = 28
        let warn = SKSpriteNode()
        warn.blendMode = .add
        warn.color = SKTheme.magenta
        warn.colorBlendFactor = 1
        switch style {
        case .slam:
            warn.texture = ArtFactory.verticalFade
            warn.anchorPoint = CGPoint(x: 0, y: 0)
            warn.size = CGSize(width: rect.width, height: rect.height)
            warn.position = rect.origin
            warn.alpha = 0.15
            let line = SKSpriteNode(color: SKTheme.magenta, size: CGSize(width: rect.width, height: 3))
            line.anchorPoint = .zero
            line.position = rect.origin
            z.node.addChild(line)
        case .beam:
            warn.texture = ArtFactory.band
            warn.anchorPoint = CGPoint(x: 0, y: 0.5)
            warn.size = CGSize(width: rect.width, height: 10)
            warn.position = CGPoint(x: rect.minX, y: rect.midY)
            warn.alpha = 0.35
            let outline = SKShapeNode(rect: rect)
            outline.strokeColor = SKTheme.magenta.withAlphaComponent(0.45)
            outline.lineWidth = 1
            outline.fillColor = SKTheme.magenta.withAlphaComponent(0.06)
            z.node.addChild(outline)
        case .rocket:
            warn.texture = ArtFactory.ring
            warn.size = CGSize(width: rect.width, height: 20)
            warn.position = CGPoint(x: rect.midX, y: rect.minY + 4)
            warn.alpha = 0.6
            let column = SKSpriteNode(texture: ArtFactory.verticalFade)
            column.color = SKTheme.magenta
            column.colorBlendFactor = 1
            column.blendMode = .add
            column.anchorPoint = CGPoint(x: 0.5, y: 0)
            column.size = CGSize(width: rect.width * 0.7, height: rect.height)
            column.position = CGPoint(x: rect.midX, y: rect.minY)
            column.alpha = 0.18
            z.node.addChild(column)
            warn.run(.repeatForever(.sequence([.scale(to: 0.75, duration: 0.18), .scale(to: 1, duration: 0.18)])))
        case .debris:
            warn.texture = ArtFactory.glow
            warn.color = .black
            warn.blendMode = .alpha
            warn.size = CGSize(width: rect.width * 1.4, height: 18)
            warn.position = CGPoint(x: rect.midX, y: rect.minY + 2)
            warn.alpha = 0.2
            warn.setScale(0.4)
            warn.run(.group([.scale(to: 1, duration: telegraph), .fadeAlpha(to: 0.9, duration: telegraph)]))
            let ring = SKSpriteNode(texture: ArtFactory.ring)
            ring.color = SKTheme.magenta
            ring.colorBlendFactor = 1
            ring.blendMode = .add
            ring.size = CGSize(width: rect.width * 1.2, height: 16)
            ring.position = warn.position
            ring.alpha = 0.7
            z.node.addChild(ring)
            let rock = SKShapeNode(path: rockPath(radius: 22))
            rock.fillColor = SKColor(hex: 0x1A1430)
            rock.strokeColor = SKTheme.ember.withAlphaComponent(0.8)
            rock.lineWidth = 1.5
            rock.position = CGPoint(x: rect.midX, y: rect.minY + 460)
            rock.run(.sequence([
                .wait(forDuration: max(0, telegraph - 0.55)),
                .group([.moveTo(y: rect.minY + 20, duration: 0.55), .rotate(byAngle: 3, duration: 0.55)])
            ]))
            z.node.addChild(rock)
        }
        z.node.addChild(warn)
        z.warning = warn
        world.addChild(z.node)
        zones.append(z)
        return z
    }

    private func rockPath(radius r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let pts = 7
        for i in 0..<pts {
            let a = CGFloat(i) / CGFloat(pts) * .pi * 2
            let rr = r * (0.75 + CGFloat((i * 37) % 10) / 40)
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    func cancelZone(_ z: TimedZone) {
        z.t = z.telegraph + z.active + 1
        z.activated = true
        z.node.removeAllActions()
        z.node.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
    }

    func updateZones(dt: TimeInterval) {
        for z in zones {
            let wasActivated = z.activated
            z.t += dt
            if !z.activated {
                // Telegraph blink speeds up toward activation.
                let p = min(1, z.t / z.telegraph)
                let blink = Int(z.t * (6 + p * 16)) % 2 == 0
                switch z.style {
                case .slam: z.warning?.alpha = (blink ? 0.55 : 0.3) * CGFloat(0.4 + p)
                case .beam: z.warning?.alpha = blink ? 0.9 : 0.4; z.warning?.size.height = 6 + CGFloat(p) * 10
                case .rocket: z.warning?.alpha = blink ? 1 : 0.45
                case .debris: break
                }
                if z.t >= z.telegraph {
                    z.activated = true
                    activateZoneVisual(z)
                }
            }
            if z.isActive && !z.hasHit && player.alive && player.body.rect.intersects(z.rect) {
                if !player.isInvulnerable {
                    z.hasHit = true
                    damagePlayer(z.damage, from: z.sourceX)
                }
            }
            if z.finished && wasActivated && z.node.parent != nil && z.node.action(forKey: "end") == nil {
                z.node.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]), withKey: "end")
            }
        }
        zones.removeAll { $0.finished && $0.t > $0.telegraph + $0.active + 0.3 }
    }

    private func activateZoneVisual(_ z: TimedZone) {
        z.warning?.removeAllActions()
        let r = z.rect
        switch z.style {
        case .slam:
            z.warning?.alpha = 0.9
            let wave = SKSpriteNode(texture: ArtFactory.band)
            wave.color = SKTheme.magenta
            wave.colorBlendFactor = 1
            wave.blendMode = .add
            wave.size = CGSize(width: r.width, height: 40)
            wave.position = CGPoint(x: r.midX, y: r.minY + 8)
            z.node.addChild(wave)
            wave.run(.group([.scaleX(to: 1.3, duration: 0.2), .fadeOut(withDuration: 0.25)]))
            dust(at: CGPoint(x: r.midX, y: r.minY), dir: 0, count: 10)
        case .beam:
            z.warning?.alpha = 0
            let beam = SKSpriteNode(texture: ArtFactory.band)
            beam.color = SKTheme.magenta
            beam.colorBlendFactor = 1
            beam.blendMode = .add
            beam.anchorPoint = CGPoint(x: 0, y: 0.5)
            beam.size = CGSize(width: r.width, height: r.height * 1.9)
            beam.position = CGPoint(x: r.minX, y: r.midY)
            z.node.addChild(beam)
            let core = SKSpriteNode(texture: ArtFactory.band)
            core.color = .white
            core.colorBlendFactor = 1
            core.blendMode = .add
            core.anchorPoint = CGPoint(x: 0, y: 0.5)
            core.size = CGSize(width: r.width, height: r.height * 0.6)
            core.position = beam.position
            z.node.addChild(core)
            for n in [beam, core] {
                n.yScale = 0.2
                n.run(.sequence([.scaleY(to: 1, duration: 0.06), .wait(forDuration: z.active - 0.1), .scaleY(to: 0.1, duration: 0.12)]))
            }
            Haptics.medium()
        case .rocket:
            z.warning?.alpha = 0
            burst(at: CGPoint(x: r.midX, y: r.minY + 20), color: SKTheme.ember, count: 16, speed: 280)
            burst(at: CGPoint(x: r.midX, y: r.minY + 60), color: SKTheme.magenta, count: 10, speed: 200)
            let column = SKSpriteNode(texture: ArtFactory.verticalFade)
            column.color = SKTheme.ember
            column.colorBlendFactor = 1
            column.blendMode = .add
            column.anchorPoint = CGPoint(x: 0.5, y: 0)
            column.size = CGSize(width: r.width, height: r.height * 1.2)
            column.position = CGPoint(x: r.midX, y: r.minY)
            z.node.addChild(column)
            column.run(.fadeOut(withDuration: 0.35))
            let flash = SKSpriteNode(texture: ArtFactory.glow)
            flash.color = SKTheme.ember
            flash.colorBlendFactor = 1
            flash.blendMode = .add
            flash.size = CGSize(width: 160, height: 160)
            flash.position = CGPoint(x: r.midX, y: r.minY + 30)
            z.node.addChild(flash)
            flash.run(.group([.scale(to: 1.4, duration: 0.3), .fadeOut(withDuration: 0.3)]))
            shake(6)
            playSFX(.explosion, volume: 0.7)
        case .debris:
            z.warning?.alpha = 0
            dust(at: CGPoint(x: r.midX, y: r.minY), dir: 0, count: 12)
            burst(at: CGPoint(x: r.midX, y: r.minY + 16), color: SKTheme.ember, count: 8, speed: 160)
            shake(5)
            playSFX(.slam, volume: 0.6)
        }
    }

    // MARK: Pickups

    func updatePickups(dt: TimeInterval) {
        guard player.alive else { return }
        let fdt = CGFloat(dt)
        let pc = CGPoint(x: player.body.pos.x, y: player.body.pos.y + 30)
        for p in pickups where !p.dead {
            p.age += dt
            if p.dynamic && !p.magnetized {
                p.body.vel.dy = max(-700, p.body.vel.dy - 1400 * fdt)
                p.body.vel.dx = approach(p.body.vel.dx, 0, 200 * fdt)
                physics.move(&p.body, dt: fdt)
                if p.body.pos.y < -60 { p.dead = true; continue }
            }
            let target = CGPoint(x: p.body.pos.x, y: p.body.pos.y + 10)
            let dist = hypot(pc.x - target.x, pc.y - target.y)
            switch p.kind {
            case .shard:
                let radius = loadout.magnetRadius * (p.dynamic ? 1.6 : 1)
                if dist < radius && (!p.dynamic || p.age > 0.35) { p.magnetized = true }
                if p.magnetized {
                    let speed: CGFloat = 260 + CGFloat(p.age) * 300
                    let step = min(dist, speed * fdt + 4)
                    p.body.pos.x += (pc.x - target.x) / max(dist, 1) * step
                    p.body.pos.y += (pc.y - target.y) / max(dist, 1) * step
                }
                if dist < 26 { collect(p) }
            case .health(let amount):
                if dist < 34 {
                    player.health = min(player.maxHealth, player.health + amount)
                    playSFX(.heal)
                    Haptics.success()
                    showFloatingText("+\(amount)", at: CGPoint(x: pc.x, y: pc.y + 50), color: SKTheme.heal)
                    burst(at: target, color: SKTheme.heal, count: 12, speed: 140)
                    markCollected(p)
                }
            case .weapon(let id):
                if dist < 40 {
                    markCollected(p)
                    acquireWeapon(id)
                }
            }
            if !p.dead {
                if p.dynamic || p.magnetized {
                    p.node.position = p.body.pos
                } else {
                    p.node.position = CGPoint(x: p.body.pos.x, y: p.baseY + sin(CGFloat(elapsed) * 3 + p.body.pos.x * 0.05) * 4)
                }
            }
        }
        pickups.removeAll { $0.dead }
    }

    private func collect(_ p: Pickup) {
        config.unbankedValue += p.value
        config.runFragmentValue += p.value
        if p.specID != nil { config.shardsCollected += 1 }
        playSFX(.pickup, volume: 0.45)
        if !reduced { burst(at: p.node.position, color: SKTheme.cyan, count: 5, speed: 90) }
        markCollected(p)
    }

    private func markCollected(_ p: Pickup) {
        p.dead = true
        if let id = p.specID { config.collectedPickupIDs.insert(id) }
        p.node.removeAllActions()
        p.node.run(.sequence([.group([.scale(to: 1.6, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
    }

    func dropFragments(at pos: CGPoint, count: Int) {
        for _ in 0..<count {
            let p = Pickup(specID: nil, kind: .shard, position: CGPoint(x: pos.x, y: pos.y + 20),
                           value: 1 * loadout.fragmentMultiplier, dynamic: true)
            p.body.vel = CGVector(dx: CGFloat.random(in: -160...160), dy: CGFloat.random(in: 260...460))
            world.addChild(p.node)
            pickups.append(p)
        }
    }

    // MARK: Hazards

    func updateHazards(dt: TimeInterval) {
        for h in hazards {
            if case let .fireVent(period, active, offset) = h.spec.kind {
                let phase = (elapsed + offset).truncatingRemainder(dividingBy: period)
                let activeStart = period - active
                let isActive = phase >= activeStart
                let warning = !isActive && phase >= activeStart - 0.6
                if isActive != h.active {
                    h.active = isActive
                    h.flame?.removeAllActions()
                    if isActive {
                        h.flame?.run(.group([.scaleY(to: 1, duration: 0.08), .fadeAlpha(to: 0.95, duration: 0.08)]))
                        h.flame?.run(.repeatForever(.sequence([.scaleX(to: 0.85, duration: 0.07), .scaleX(to: 1.05, duration: 0.07)])), withKey: "flicker")
                    } else {
                        h.flame?.run(.group([.scaleY(to: 0.01, duration: 0.15), .fadeOut(withDuration: 0.15)]))
                    }
                }
                h.nozzleGlow?.alpha = isActive ? 1 : (warning ? (Int(elapsed * 14) % 2 == 0 ? 0.9 : 0.3) : 0.3)
            }
            guard h.active, player.alive, player.body.rect.intersects(h.spec.rect) else { continue }
            if case .spikes = h.spec.kind {
                player.body.vel.dy = 620
                player.body.vel.dx = player.body.vel.dx * 0.5
            }
            if !player.isInvulnerable {
                damagePlayer(h.spec.damage, from: h.spec.rect.midX)
                if case .spikes = h.spec.kind { player.body.vel.dy = 640 }
            }
        }
    }

    func isOverHazard(_ rect: CGRect) -> Bool {
        let probe = rect.insetBy(dx: -40, dy: -10)
        return hazards.contains { probe.intersects($0.spec.rect) }
    }

    // MARK: Contacts & damage

    func checkContacts() {
        guard player.alive, !player.isInvulnerable else { return }
        let pr = player.body.rect.insetBy(dx: 3, dy: 3)
        for e in enemies where e.alive && e.body.rect.insetBy(dx: 4, dy: 2).intersects(pr) {
            damagePlayer(e.attackingContact ? e.def.attackDamage : e.def.contactDamage, from: e.body.pos.x)
            return
        }
        if let boss, boss.alive, bossStage == .fighting, boss.hitRect.insetBy(dx: 8, dy: 4).intersects(pr) {
            damagePlayer(boss.contactDamage, from: boss.body.pos.x)
        }
    }

    func damagePlayer(_ amount: Int, from sourceX: CGFloat?, force: Bool = false) {
        guard player.hurt(amount, from: sourceX, scene: self, force: force) else { return }
        playSFX(.playerHurt)
        Haptics.rigid()
        shake(7)
        hitstop(0.06)
        damageNumber(amount, at: CGPoint(x: player.body.pos.x, y: player.body.pos.y + 76), color: SKTheme.magenta, big: false)
        burst(at: CGPoint(x: player.body.pos.x, y: player.body.pos.y + 34), color: SKTheme.magenta, count: 8, speed: 160)
        if player.health <= 0 { killPlayer() }
    }

    private func killPlayer() {
        player.alive = false
        player.body.vel = .zero
        deathTimer = 1.4
        playSFX(.defeat)
        Haptics.error()
        shake(12)
        let center = CGPoint(x: player.body.pos.x, y: player.body.pos.y + 34)
        burst(at: center, color: SKTheme.cyan, count: 30, speed: 260)
        player.sprite.run(.group([.fadeOut(withDuration: 0.6), .scaleY(to: player.sprite.yScale * 0.3, duration: 0.6)]))
        dialogueQueue.removeAll()
        currentLine = nil
        session?.setDialogue(nil)
    }

    // MARK: Enemy bookkeeping

    func enemyRemoved(_ e: Enemy, rewarded: Bool) {
        config.defeatedSpawnIDs.insert(e.spawn.id)
        guard rewarded else { return }
        config.enemiesDefeated += 1
        dropFragments(at: e.body.pos, count: e.def.fragmentDrop)
        playSFX(.enemyDie, volume: 0.8)
        hitstop(e.def.kind == .ironbound ? 0.1 : 0.05)
        shake(e.def.kind == .ironbound ? 8 : 4)
        if e.def.kind == .ironbound { Haptics.medium() }
    }

    // MARK: Effects

    func burst(at pos: CGPoint, color: SKColor, count: Int, speed: CGFloat) {
        let n = reduced ? max(2, count / 3) : count
        for _ in 0..<n {
            let s = SKSpriteNode(texture: ArtFactory.spark)
            s.color = color
            s.colorBlendFactor = 1
            s.blendMode = .add
            let a = CGFloat.random(in: 0...(.pi * 2))
            let v = speed * CGFloat.random(in: 0.4...1)
            s.size = CGSize(width: CGFloat.random(in: 8...18), height: 3)
            s.zRotation = a
            s.position = pos
            s.zPosition = 40
            world.addChild(s)
            let life = Double.random(in: 0.25...0.5)
            s.run(.sequence([
                .group([.moveBy(x: cos(a) * v * CGFloat(life), y: sin(a) * v * CGFloat(life), duration: life),
                        .fadeOut(withDuration: life), .scaleX(to: 0.2, duration: life)]),
                .removeFromParent()
            ]))
        }
        let flash = SKSpriteNode(texture: ArtFactory.glow)
        flash.color = color
        flash.colorBlendFactor = 1
        flash.blendMode = .add
        flash.size = CGSize(width: 60, height: 60)
        flash.position = pos
        flash.zPosition = 39
        world.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.5, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    func sparkAt(_ pos: CGPoint, color: SKColor, small: Bool = false) {
        burst(at: pos, color: color, count: small ? 4 : 8, speed: small ? 140 : 220)
    }

    func muzzleFlash(at pos: CGPoint, color: SKColor) {
        let f = SKSpriteNode(texture: ArtFactory.glow)
        f.color = color
        f.colorBlendFactor = 1
        f.blendMode = .add
        f.size = CGSize(width: 36, height: 36)
        f.position = pos
        f.zPosition = 36
        world.addChild(f)
        f.run(.sequence([.group([.scale(to: 1.4, duration: 0.07), .fadeOut(withDuration: 0.08)]), .removeFromParent()]))
    }

    func dust(at pos: CGPoint, dir: CGFloat, count: Int = 6) {
        let n = reduced ? count / 2 : count
        for _ in 0..<n {
            let d = SKSpriteNode(texture: ArtFactory.glow)
            d.color = SKColor(hex: 0x6B7899)
            d.colorBlendFactor = 1
            d.alpha = 0.45
            let s = CGFloat.random(in: 8...16)
            d.size = CGSize(width: s, height: s)
            d.position = CGPoint(x: pos.x + CGFloat.random(in: -10...10), y: pos.y + 3)
            d.zPosition = 19
            world.addChild(d)
            let dx = (dir == 0 ? CGFloat.random(in: -1...1) : dir) * CGFloat.random(in: 20...50)
            d.run(.sequence([
                .group([.moveBy(x: dx, y: CGFloat.random(in: 6...20), duration: 0.4), .fadeOut(withDuration: 0.4), .scale(to: 1.8, duration: 0.4)]),
                .removeFromParent()
            ]))
        }
    }

    func afterimage(of sprite: SKSpriteNode, at pos: CGPoint, color: SKColor = SKTheme.cyan) {
        guard !reduced, let tex = sprite.texture else { return }
        let ghost = SKSpriteNode(texture: tex)
        ghost.anchorPoint = sprite.anchorPoint
        ghost.xScale = sprite.xScale
        ghost.yScale = sprite.yScale
        ghost.zRotation = sprite.zRotation
        ghost.position = CGPoint(x: pos.x + sprite.position.x, y: pos.y + sprite.position.y)
        ghost.color = color
        ghost.colorBlendFactor = 1
        ghost.blendMode = .add
        ghost.alpha = 0.45
        ghost.zPosition = 18
        world.addChild(ghost)
        ghost.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    func damageNumber(_ amount: Int, at pos: CGPoint, color: SKColor, big: Bool) {
        guard amount > 0 else { return }
        if reduced && !big { return }
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: "\(amount)", attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: big ? 17 : 13, weight: .heavy),
            .foregroundColor: color,
            .strokeColor: SKTheme.void,
            .strokeWidth: -3
        ])
        label.position = CGPoint(x: pos.x + CGFloat.random(in: -8...8), y: pos.y)
        label.zPosition = 50
        label.setScale(0.6)
        world.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.08), .moveBy(x: 0, y: 30, duration: 0.55)]),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }

    func showFloatingText(_ text: String, at pos: CGPoint, color: SKColor, small: Bool = false) {
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: small ? 10 : 15, weight: .bold),
            .foregroundColor: color,
            .kern: small ? 2 : 4,
            .strokeColor: SKTheme.void,
            .strokeWidth: -3
        ])
        label.position = pos
        label.zPosition = 52
        label.alpha = 0
        world.addChild(label)
        label.run(.sequence([
            .group([.fadeIn(withDuration: 0.12), .moveBy(x: 0, y: 14, duration: 0.5)]),
            .wait(forDuration: small ? 0.3 : 0.7),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}
