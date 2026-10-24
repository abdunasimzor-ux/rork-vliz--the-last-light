import SpriteKit
import UIKit

/// Procedural textures (glows, sparks, shards, terrain gradients, silhouettes) generated once
/// and cached. Character art is loaded from the asset catalog with a drawn fallback.
@MainActor
enum ArtFactory {
    private static var cache: [String: SKTexture] = [:]

    private static func cached(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(ctx.cgContext, size)
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    // MARK: Characters

    static func character(_ name: String, fallbackColor: UIColor) -> SKTexture {
        if let t = cache["img_" + name] { return t }
        if let img = UIImage(named: name) {
            let t = SKTexture(image: img)
            cache["img_" + name] = t
            return t
        }
        return cached("fallback_" + name, size: CGSize(width: 60, height: 90)) { ctx, s in
            ctx.setFillColor(UIColor(hex: 0x0B1230).cgColor)
            ctx.fillEllipse(in: CGRect(x: 15, y: 0, width: 30, height: 26))
            ctx.fill(CGRect(x: 12, y: 24, width: 36, height: 66))
            ctx.setFillColor(fallbackColor.cgColor)
            ctx.fill(CGRect(x: 30, y: 10, width: 14, height: 4))
        }
    }

    // MARK: Light & particles

    static var glow: SKTexture {
        cached("glow", size: CGSize(width: 64, height: 64)) { ctx, s in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.25, 1])!
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
    }

    static var dot: SKTexture {
        cached("dot", size: CGSize(width: 16, height: 16)) { ctx, _ in
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 12, height: 12))
        }
    }

    static var spark: SKTexture {
        cached("spark", size: CGSize(width: 24, height: 6)) { ctx, s in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 3).cgPath)
            ctx.clip()
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: s.width, y: 0), options: [])
        }
    }

    static var bolt: SKTexture {
        cached("bolt", size: CGSize(width: 44, height: 12)) { ctx, s in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.7).cgColor, UIColor.white.cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1])!
            ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 6).cgPath)
            ctx.clip()
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: s.width, y: 0), options: [])
        }
    }

    static var shard: SKTexture {
        cached("shard", size: CGSize(width: 20, height: 30)) { ctx, s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 10, y: 1))
            p.addLine(to: CGPoint(x: 19, y: 13))
            p.addLine(to: CGPoint(x: 10, y: 29))
            p.addLine(to: CGPoint(x: 1, y: 13))
            p.close()
            ctx.setFillColor(UIColor(hex: 0x3FF2FF).cgColor)
            ctx.addPath(p.cgPath)
            ctx.fillPath()
            let inner = UIBezierPath()
            inner.move(to: CGPoint(x: 10, y: 4))
            inner.addLine(to: CGPoint(x: 15, y: 13))
            inner.addLine(to: CGPoint(x: 10, y: 15))
            inner.close()
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            ctx.addPath(inner.cgPath)
            ctx.fillPath()
        }
    }

    static var slash: SKTexture {
        cached("slash", size: CGSize(width: 120, height: 120)) { ctx, s in
            let c = CGPoint(x: 20, y: 60)
            for i in 0..<14 {
                let t = CGFloat(i) / 13
                let r: CGFloat = 70 + t * 22
                let path = UIBezierPath(arcCenter: c, radius: r, startAngle: -.pi * 0.42, endAngle: .pi * 0.42, clockwise: true)
                ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.08 + t * 0.07).cgColor)
                ctx.setLineWidth(3 + (1 - abs(t - 0.6)) * 4)
                ctx.addPath(path.cgPath)
                ctx.strokePath()
            }
            let core = UIBezierPath(arcCenter: c, radius: 86, startAngle: -.pi * 0.36, endAngle: .pi * 0.36, clockwise: true)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(5)
            ctx.setLineCap(.round)
            ctx.addPath(core.cgPath)
            ctx.strokePath()
        }
    }

    static var ring: SKTexture {
        cached("ring", size: CGSize(width: 96, height: 96)) { ctx, _ in
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(5)
            ctx.strokeEllipse(in: CGRect(x: 6, y: 6, width: 84, height: 84))
        }
    }

    /// Soft horizontal band (beams, telegraph strips). White, tint with colour.
    static var band: SKTexture {
        cached("band", size: CGSize(width: 8, height: 64)) { ctx, s in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
        }
    }

    /// Vertical fade, opaque at the bottom (image-space top), used for fog and light shafts.
    static var verticalFade: SKTexture {
        cached("vfade", size: CGSize(width: 8, height: 64)) { ctx, s in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
        }
    }

    // MARK: Terrain

    static func terrainTop(accent: UIColor) -> SKTexture {
        cached("terrainTop_\(accent.hashValue)", size: CGSize(width: 8, height: 48)) { ctx, s in
            let colors = [accent.withAlphaComponent(0.55).cgColor,
                          UIColor(hex: 0x16294A).cgColor,
                          UIColor(hex: 0x080C1C).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.12, 1])!
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
        }
    }

    /// Repeating silhouette strip for the mid parallax layer of a zone.
    static func silhouette(for style: ZoneStyle) -> SKTexture {
        cached("sil_\(style)", size: CGSize(width: 1024, height: 220)) { ctx, s in
            let seed: UInt64
            switch style {
            case .settlement: seed = 11
            case .caverns: seed = 29
            case .station: seed = 47
            case .arena: seed = 83
            }
            var rng = SplitMix(seed: seed)
            ctx.setFillColor(UIColor(hex: 0x05060D).cgColor)
            switch style {
            case .settlement:
                var x: CGFloat = 0
                while x < s.width {
                    let w = 50 + rng.next() * 110
                    let h = 50 + rng.next() * 120
                    let rect = CGRect(x: x, y: s.height - h, width: w, height: h)
                    if rng.next() > 0.5 {
                        ctx.addPath(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: w / 2, height: w / 2)).cgPath)
                        ctx.fillPath()
                    } else {
                        ctx.fill(rect)
                        ctx.fill(CGRect(x: x + w * 0.4, y: s.height - h - 30, width: 6, height: 30))
                    }
                    x += w + rng.next() * 40
                }
            case .caverns:
                var x: CGFloat = 0
                while x < s.width {
                    let w = 20 + rng.next() * 40
                    let h = 60 + rng.next() * 150
                    let p = UIBezierPath()
                    p.move(to: CGPoint(x: x, y: s.height))
                    p.addLine(to: CGPoint(x: x + w * 0.5, y: s.height - h))
                    p.addLine(to: CGPoint(x: x + w, y: s.height))
                    p.close()
                    ctx.addPath(p.cgPath)
                    ctx.fillPath()
                    x += w * 0.7 + rng.next() * 30
                }
            case .station:
                var x: CGFloat = 0
                while x < s.width {
                    let w = 80 + rng.next() * 140
                    let h = 70 + rng.next() * 110
                    ctx.fill(CGRect(x: x, y: s.height - h, width: w, height: h))
                    ctx.fill(CGRect(x: x + 10, y: s.height - h - 14, width: w * 0.3, height: 14))
                    ctx.fill(CGRect(x: x + w - 18, y: s.height - h - 60, width: 8, height: 60))
                    x += w + 20 + rng.next() * 60
                }
            case .arena:
                var x: CGFloat = 0
                while x < s.width {
                    let w = 40 + rng.next() * 60
                    let h = 120 + rng.next() * 90
                    ctx.fill(CGRect(x: x, y: s.height - h, width: w, height: h))
                    x += w + 60 + rng.next() * 80
                }
            }
        }
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return CGFloat(z % 10_000) / 10_000
    }
}
