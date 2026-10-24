import Foundation

nonisolated enum AtmosphereMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case day
    case evening
    case night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .day: return "Day"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}

nonisolated struct GameSettings: Codable, Equatable, Sendable {
    var musicVolume: Double = 0.6
    var sfxVolume: Double = 0.8
    var screenShake: Bool = true
    var reducedEffects: Bool = false
    var haptics: Bool = true
    var atmosphere: AtmosphereMode = .auto

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        musicVolume = min(max((try? c.decodeIfPresent(Double.self, forKey: .musicVolume)) ?? 0.6, 0), 1)
        sfxVolume = min(max((try? c.decodeIfPresent(Double.self, forKey: .sfxVolume)) ?? 0.8, 0), 1)
        screenShake = (try? c.decodeIfPresent(Bool.self, forKey: .screenShake)) ?? true
        reducedEffects = (try? c.decodeIfPresent(Bool.self, forKey: .reducedEffects)) ?? false
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
        atmosphere = (try? c.decodeIfPresent(AtmosphereMode.self, forKey: .atmosphere)) ?? .auto
    }
}

nonisolated struct MissionRecord: Codable, Equatable, Sendable {
    var clears: Int = 0
    var bestEnemies: Int = 0
    var bestShards: Int = 0
}

/// Everything persisted to disk. Decoding tolerates missing or malformed fields so an
/// older or partially written save never wipes the player's progress.
nonisolated struct SaveData: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int = SaveData.currentVersion
    var fragments: Int = 0
    var unlockedWeapons: [WeaponID] = [.pulseBlaster]
    var upgrades: [String: Int] = [:]
    var missionRecords: [String: MissionRecord] = [:]
    var settings = GameSettings()
    var seenIntro = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? SaveData.currentVersion
        fragments = max(0, (try? c.decodeIfPresent(Int.self, forKey: .fragments)) ?? 0)
        let rawWeapons = (try? c.decodeIfPresent([String].self, forKey: .unlockedWeapons)) ?? []
        var weapons = rawWeapons.compactMap(WeaponID.init(rawValue:))
        if !weapons.contains(.pulseBlaster) { weapons.insert(.pulseBlaster, at: 0) }
        unlockedWeapons = weapons
        let rawUpgrades = (try? c.decodeIfPresent([String: Int].self, forKey: .upgrades)) ?? [:]
        upgrades = rawUpgrades.filter { UpgradeID(rawValue: $0.key) != nil }.mapValues { max(0, $0) }
        missionRecords = (try? c.decodeIfPresent([String: MissionRecord].self, forKey: .missionRecords)) ?? [:]
        settings = (try? c.decodeIfPresent(GameSettings.self, forKey: .settings)) ?? GameSettings()
        seenIntro = (try? c.decodeIfPresent(Bool.self, forKey: .seenIntro)) ?? false
    }
}
