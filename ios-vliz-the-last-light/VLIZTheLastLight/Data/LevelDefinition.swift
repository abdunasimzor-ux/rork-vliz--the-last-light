import Foundation
import CoreGraphics

enum ZoneStyle {
    case settlement
    case caverns
    case station
    case arena

    var backdrop: String {
        switch self {
        case .settlement: return "burning_alien_skyline"
        case .caverns: return "crystal_cavern_ring_tower"
        case .station: return "alien_energy_station_bg"
        case .arena: return "alien_reactor_core_chamber"
        }
    }
}

struct ZoneSpan {
    let style: ZoneStyle
    let startX: CGFloat
    let endX: CGFloat
}

struct SolidSpec {
    let rect: CGRect
    var oneWay: Bool = false
    /// Gates are solids toggled by encounters; nil for permanent geometry.
    var gateID: String? = nil
}

enum HazardKind {
    case spikes
    /// Flame vent: idle for `period - active` seconds, then burns for `active` seconds.
    case fireVent(period: TimeInterval, active: TimeInterval, offset: TimeInterval)
}

struct HazardSpec {
    let rect: CGRect
    let kind: HazardKind
    let damage: Int
}

struct EnemySpawn {
    let id: String
    let kind: EnemyKind
    let x: CGFloat
    let y: CGFloat
    var patrol: CGFloat = 120
    /// Wave-tagged spawns only appear when their encounter starts the wave.
    var encounterID: String? = nil
    var wave: Int = 0
}

enum PickupKind {
    case shard
    case health(Int)
    case weapon(WeaponID)
}

struct PickupSpec {
    let id: Int
    let kind: PickupKind
    let position: CGPoint
}

struct CheckpointSpec {
    let id: String
    let x: CGFloat
    let y: CGFloat
}

enum TriggerAction {
    case completeObjective(String)
    case dialogue([DialogueLine])
    case startEncounter(String)
    case startBoss
}

struct TriggerSpec {
    let id: String
    let x: CGFloat
    let actions: [TriggerAction]
}

struct EncounterSpec {
    let id: String
    let gateIDs: [String]
    let waves: Int
    let objectiveOnClear: String?
}

struct BossArenaSpec {
    let minX: CGFloat
    let maxX: CGFloat
    let gateID: String
    let bossSpawn: CGPoint
    let platformY: CGFloat
    let beaconPosition: CGPoint
}

struct DecorSpec {
    enum Kind {
        case crystal(cyan: Bool)
        case memorial
        case ruinDome
        case lamp
        case pipe
        case pedestal
    }
    let kind: Kind
    let position: CGPoint
    var scale: CGFloat = 1
}

/// Complete, data-only description of a level. The `LevelManager` and `LevelBuilder`
/// turn this into geometry, actors and scripted beats.
struct LevelDefinition {
    let width: CGFloat
    let groundTop: CGFloat
    let playerStart: CGPoint
    let zones: [ZoneSpan]
    let solids: [SolidSpec]
    let hazards: [HazardSpec]
    let spawns: [EnemySpawn]
    let pickups: [PickupSpec]
    let checkpoints: [CheckpointSpec]
    let triggers: [TriggerSpec]
    let encounters: [EncounterSpec]
    let bossArena: BossArenaSpec
    let decor: [DecorSpec]

    func zone(at x: CGFloat) -> ZoneSpan {
        zones.first { x >= $0.startX && x < $0.endX } ?? zones.last!
    }

    var shardCount: Int {
        pickups.filter { if case .shard = $0.kind { return true } else { return false } }.count
    }
}
