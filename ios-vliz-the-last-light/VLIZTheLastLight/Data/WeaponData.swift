import Foundation
import CoreGraphics

nonisolated enum WeaponID: String, Codable, CaseIterable, Identifiable, Sendable {
    case pulseBlaster
    case arcBlade

    var id: String { rawValue }
}

enum WeaponKind {
    case projectile
    case melee
}

/// Data-driven weapon configuration. Add new weapons by adding entries to `WeaponCatalog.all`.
struct WeaponDefinition: Identifiable {
    let id: WeaponID
    let name: String
    let role: String
    let description: String
    let kind: WeaponKind
    let baseDamage: Int
    /// Seconds between attacks.
    let cooldown: TimeInterval
    /// Projectile travel distance, or melee reach.
    let range: CGFloat
    let projectileSpeed: CGFloat
    let knockback: CGFloat
    /// Ignores enemy armor (Ironbound plating).
    let armorPiercing: Bool
    let symbol: String
    let unlockHint: String

    var attacksPerSecond: Double { 1 / cooldown }
}

enum WeaponCatalog {
    static let all: [WeaponDefinition] = [
        WeaponDefinition(
            id: .pulseBlaster,
            name: "Pulse Blaster",
            role: "Ranged",
            description: "A compact relic sidearm that fires bolts of living light. Reliable at any distance, but struggles against heavy plating.",
            kind: .projectile,
            baseDamage: 10,
            cooldown: 0.2,
            range: 560,
            projectileSpeed: 860,
            knockback: 40,
            armorPiercing: false,
            symbol: "scope",
            unlockHint: "Starting weapon"
        ),
        WeaponDefinition(
            id: .arcBlade,
            name: "Arc Blade",
            role: "Close range",
            description: "A crescent of compressed energy. Cuts through Corsair armor and staggers heavy enemies. Get close, strike, get out.",
            kind: .melee,
            baseDamage: 30,
            cooldown: 0.38,
            range: 84,
            projectileSpeed: 0,
            knockback: 260,
            armorPiercing: true,
            symbol: "bolt.horizontal.fill",
            unlockHint: "Recovered in Mission 001"
        )
    ]

    static func definition(_ id: WeaponID) -> WeaponDefinition {
        all.first { $0.id == id } ?? all[0]
    }
}
