import Foundation

nonisolated enum UpgradeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case maxHealth
    case blasterDamage
    case fragmentMagnet

    var id: String { rawValue }
}

/// `values[level]` is the stat at that level; `costs[level]` buys the next level.
struct UpgradeDefinition: Identifiable {
    let id: UpgradeID
    let name: String
    let summary: String
    let symbol: String
    let values: [Double]
    let costs: [Int]

    var maxLevel: Int { values.count - 1 }

    func value(at level: Int) -> Double {
        values[min(max(level, 0), maxLevel)]
    }

    func cost(forLevel level: Int) -> Int? {
        level < costs.count ? costs[level] : nil
    }

    func format(_ value: Double) -> String {
        switch id {
        case .maxHealth, .blasterDamage: return String(Int(value))
        case .fragmentMagnet: return "×" + String(format: value == value.rounded() ? "%.1f" : "%.2f", value)
        }
    }
}

enum UpgradeCatalog {
    static let all: [UpgradeDefinition] = [
        UpgradeDefinition(
            id: .maxHealth, name: "Max Health",
            summary: "Reinforced armor weave. More health for every mission.",
            symbol: "heart.fill",
            values: [100, 120, 140, 160, 180, 200],
            costs: [60, 120, 200, 300, 420]
        ),
        UpgradeDefinition(
            id: .blasterDamage, name: "Blaster Damage",
            summary: "Overcharged emitter. Each Pulse Blaster bolt hits harder.",
            symbol: "burst.fill",
            values: [10, 13, 16, 19, 22, 26],
            costs: [50, 100, 170, 260, 380]
        ),
        UpgradeDefinition(
            id: .fragmentMagnet, name: "Fragment Magnet",
            summary: "Resonance coil. Fragments are worth more and drift toward you from farther away.",
            symbol: "dot.radiowaves.left.and.right",
            values: [1.0, 1.25, 1.5, 2.0],
            costs: [80, 180, 320]
        )
    ]

    static func definition(_ id: UpgradeID) -> UpgradeDefinition {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Resolved player stats for a run, derived from purchased upgrades.
struct PlayerLoadout {
    var maxHealth: Int
    var blasterDamage: Int
    var fragmentMultiplier: Double
    var magnetRadius: CGFloat
    var hasArcBlade: Bool

    static let base = PlayerLoadout(maxHealth: 100, blasterDamage: 10, fragmentMultiplier: 1, magnetRadius: 70, hasArcBlade: false)
}
