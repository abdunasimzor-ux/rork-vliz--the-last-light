import Foundation
import CoreGraphics

enum EnemyKind: String, CaseIterable {
    case skitter
    case gunner
    case ironbound
}

/// Tunable enemy parameters. Behaviour lives in the matching `Enemy` subclass;
/// numbers live here so balancing never requires touching AI code.
struct EnemyDefinition {
    let kind: EnemyKind
    let name: String
    let maxHealth: Int
    let contactDamage: Int
    let attackDamage: Int
    let moveSpeed: CGFloat
    let hitbox: CGSize
    let spriteHeight: CGFloat
    let textureName: String
    let aggroRange: CGFloat
    let attackRange: CGFloat
    let attackCooldown: TimeInterval
    let telegraph: TimeInterval
    /// Damage multiplier against non-piercing hits.
    let armor: CGFloat
    let fragmentDrop: Int
}

enum EnemyCatalog {
    static let skitter = EnemyDefinition(
        kind: .skitter, name: "Skitter Drone",
        maxHealth: 20, contactDamage: 10, attackDamage: 12,
        moveSpeed: 170, hitbox: CGSize(width: 40, height: 26), spriteHeight: 38,
        textureName: "skitter_drone",
        aggroRange: 420, attackRange: 150, attackCooldown: 1.4, telegraph: 0.38,
        armor: 1, fragmentDrop: 1
    )

    static let gunner = EnemyDefinition(
        kind: .gunner, name: "Corsair Gunner",
        maxHealth: 40, contactDamage: 8, attackDamage: 12,
        moveSpeed: 80, hitbox: CGSize(width: 30, height: 62), spriteHeight: 78,
        textureName: "corsair_gunner",
        aggroRange: 600, attackRange: 520, attackCooldown: 2.3, telegraph: 0.65,
        armor: 1, fragmentDrop: 2
    )

    static let ironbound = EnemyDefinition(
        kind: .ironbound, name: "Ironbound",
        maxHealth: 170, contactDamage: 14, attackDamage: 26,
        moveSpeed: 58, hitbox: CGSize(width: 56, height: 80), spriteHeight: 102,
        textureName: "ironbound_brute",
        aggroRange: 460, attackRange: 96, attackCooldown: 2.2, telegraph: 0.8,
        armor: 0.35, fragmentDrop: 4
    )

    static func definition(_ kind: EnemyKind) -> EnemyDefinition {
        switch kind {
        case .skitter: return skitter
        case .gunner: return gunner
        case .ironbound: return ironbound
        }
    }
}

/// Commander Rhex tuning.
enum BossTuning {
    static let name = "Commander Rhex"
    static let maxHealth = 1000
    static let hitbox = CGSize(width: 64, height: 132)
    static let spriteHeight: CGFloat = 156
    static let textureName = "commander_rhex"
    static let phaseTwoThreshold = 0.5
    static let shotDamage = 12
    static let beamDamage = 18
    static let rocketDamage = 16
    static let chargeDamage = 22
    static let debrisDamage = 14
    static let contactDamage = 12
    static let stunnedDamageMultiplier: CGFloat = 1.6
}
