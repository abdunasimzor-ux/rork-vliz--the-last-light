import CoreGraphics

/// Kinematic AABB body. `pos` is the bottom-center (feet).
struct Body {
    var pos: CGPoint
    var vel: CGVector = .zero
    var size: CGSize
    var onGround = false
    var hitWall: CGFloat = 0   // -1 left, +1 right, 0 none (this frame)
    var hitCeiling = false

    var rect: CGRect {
        CGRect(x: pos.x - size.width / 2, y: pos.y, width: size.width, height: size.height)
    }

    var center: CGPoint { CGPoint(x: pos.x, y: pos.y + size.height / 2) }
}

/// Deterministic tile-free collision against axis-aligned solids. Resolves X, then Y.
final class PhysicsWorld {
    struct Solid {
        let rect: CGRect
        let oneWay: Bool
        let gateID: String?
        var active: Bool
    }

    private(set) var solids: [Solid] = []

    init(specs: [SolidSpec]) {
        solids = specs.map { Solid(rect: $0.rect, oneWay: $0.oneWay, gateID: $0.gateID, active: $0.gateID == nil) }
    }

    func setGate(_ id: String, active: Bool) {
        for i in solids.indices where solids[i].gateID == id {
            solids[i].active = active
        }
    }

    func move(_ b: inout Body, dt: CGFloat, dropThrough: Bool = false) {
        b.hitWall = 0
        b.hitCeiling = false
        let w = b.size.width, h = b.size.height

        // X axis (swept against solid sides)
        let oldX = b.pos.x
        var newX = oldX + b.vel.dx * dt
        if b.vel.dx != 0 {
            for s in solids where s.active && !s.oneWay {
                let r = s.rect
                guard b.pos.y < r.maxY - 0.5, b.pos.y + h > r.minY + 0.5 else { continue }
                if b.vel.dx > 0 {
                    let oldRight = oldX + w / 2, newRight = newX + w / 2
                    if oldRight <= r.minX + 1, newRight > r.minX {
                        newX = r.minX - w / 2
                        b.hitWall = 1
                    }
                } else {
                    let oldLeft = oldX - w / 2, newLeft = newX - w / 2
                    if oldLeft >= r.maxX - 1, newLeft < r.maxX {
                        newX = r.maxX + w / 2
                        b.hitWall = -1
                    }
                }
            }
            if b.hitWall != 0 { b.vel.dx = 0 }
        }
        b.pos.x = newX

        // Y axis
        let oldY = b.pos.y
        var newY = oldY + b.vel.dy * dt
        b.onGround = false
        let minX = b.pos.x - w / 2 + 0.5, maxX = b.pos.x + w / 2 - 0.5
        if b.vel.dy <= 0 {
            var landing: CGFloat = -.greatestFiniteMagnitude
            for s in solids where s.active {
                let r = s.rect
                guard maxX > r.minX, minX < r.maxX else { continue }
                if s.oneWay && dropThrough { continue }
                if oldY >= r.maxY - 0.5, newY <= r.maxY {
                    landing = max(landing, r.maxY)
                }
            }
            if landing > -.greatestFiniteMagnitude {
                newY = landing
                b.vel.dy = 0
                b.onGround = true
            }
        } else {
            var ceiling: CGFloat = .greatestFiniteMagnitude
            for s in solids where s.active && !s.oneWay {
                let r = s.rect
                guard maxX > r.minX, minX < r.maxX else { continue }
                if oldY + h <= r.minY + 0.5, newY + h > r.minY {
                    ceiling = min(ceiling, r.minY)
                }
            }
            if ceiling < .greatestFiniteMagnitude {
                newY = ceiling - h
                b.vel.dy = 0
                b.hitCeiling = true
            }
        }
        b.pos.y = newY
    }

    /// True if there is walkable ground just below `point` (used for enemy edge detection).
    func hasGround(at point: CGPoint) -> Bool {
        for s in solids where s.active {
            let r = s.rect
            if point.x >= r.minX, point.x <= r.maxX, point.y >= r.maxY - 6, point.y <= r.maxY + 4 { return true }
        }
        return false
    }

    /// True if a solid wall blocks horizontal movement at this point.
    func isBlocked(at point: CGPoint) -> Bool {
        for s in solids where s.active && !s.oneWay {
            if s.rect.insetBy(dx: 0, dy: 1).contains(point) { return true }
        }
        return false
    }
}
