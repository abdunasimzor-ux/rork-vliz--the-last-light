import Combine
import SwiftUI

/// Result of a completed mission, shown on the Mission Complete screen.
struct MissionResult: Equatable {
    let missionID: String
    let missionTitle: String
    let missionCode: String
    let enemiesDefeated: Int
    let shardsCollected: Int
    let shardsTotal: Int
    let bossDefeated: Bool
    let fragmentsEarned: Int
    let bonusFragments: Int
    let firstClear: Bool
    let unlockedWeapon: WeaponID?
}

/// Owns the player's persistent progress: currency, upgrades, unlocks, mission records
/// and settings. Every mutation is written to disk immediately.
@MainActor
final class ProgressionManager: ObservableObject {
    static let shared = ProgressionManager()

    @Published private(set) var data: SaveData

    private init() {
        data = SaveManager.load()
    }

    // MARK: Currency

    var fragments: Int { data.fragments }

    func bank(fragments amount: Int) {
        guard amount > 0 else { return }
        data.fragments += amount
        persist()
    }

    // MARK: Upgrades

    func level(of id: UpgradeID) -> Int {
        let def = UpgradeCatalog.definition(id)
        return min(data.upgrades[id.rawValue] ?? 0, def.maxLevel)
    }

    func canPurchase(_ id: UpgradeID) -> Bool {
        let def = UpgradeCatalog.definition(id)
        guard let cost = def.cost(forLevel: level(of: id)) else { return false }
        return data.fragments >= cost
    }

    @discardableResult
    func purchase(_ id: UpgradeID) -> Bool {
        let def = UpgradeCatalog.definition(id)
        let current = level(of: id)
        guard let cost = def.cost(forLevel: current), data.fragments >= cost else { return false }
        data.fragments -= cost
        data.upgrades[id.rawValue] = current + 1
        persist()
        return true
    }

    // MARK: Weapons

    func isUnlocked(_ weapon: WeaponID) -> Bool {
        data.unlockedWeapons.contains(weapon)
    }

    func unlock(_ weapon: WeaponID) {
        guard !data.unlockedWeapons.contains(weapon) else { return }
        data.unlockedWeapons.append(weapon)
        persist()
    }

    var loadout: PlayerLoadout {
        let magnet = UpgradeCatalog.definition(.fragmentMagnet).value(at: level(of: .fragmentMagnet))
        return PlayerLoadout(
            maxHealth: Int(UpgradeCatalog.definition(.maxHealth).value(at: level(of: .maxHealth))),
            blasterDamage: Int(UpgradeCatalog.definition(.blasterDamage).value(at: level(of: .blasterDamage))),
            fragmentMultiplier: magnet,
            magnetRadius: CGFloat(70 + (magnet - 1) * 110),
            hasArcBlade: isUnlocked(.arcBlade)
        )
    }

    // MARK: Missions

    func record(for missionID: String) -> MissionRecord? {
        data.missionRecords[missionID]
    }

    func isCompleted(_ missionID: String) -> Bool {
        (data.missionRecords[missionID]?.clears ?? 0) > 0
    }

    /// Awards the end-of-mission bonus, records stats and saves. Run fragments still
    /// unbanked are passed in and banked here as well.
    func completeMission(_ mission: MissionDefinition, unbankedFragments: Int, enemies: Int, shards: Int, shardsTotal: Int, runFragmentsTotal: Int) -> MissionResult {
        let firstClear = !isCompleted(mission.id)
        let bonus = firstClear ? mission.firstClearBonus : mission.replayBonus
        var record = data.missionRecords[mission.id] ?? MissionRecord()
        record.clears += 1
        record.bestEnemies = max(record.bestEnemies, enemies)
        record.bestShards = max(record.bestShards, shards)
        data.missionRecords[mission.id] = record
        data.fragments += max(0, unbankedFragments) + bonus
        var unlocked: WeaponID? = nil
        if let reward = mission.rewardWeapon {
            if firstClear { unlocked = reward }
            if !data.unlockedWeapons.contains(reward) { data.unlockedWeapons.append(reward) }
        }
        persist()
        return MissionResult(
            missionID: mission.id,
            missionTitle: mission.title,
            missionCode: mission.code,
            enemiesDefeated: enemies,
            shardsCollected: shards,
            shardsTotal: shardsTotal,
            bossDefeated: true,
            fragmentsEarned: runFragmentsTotal,
            bonusFragments: bonus,
            firstClear: firstClear,
            unlockedWeapon: unlocked
        )
    }

    // MARK: Intro & settings

    var seenIntro: Bool { data.seenIntro }

    func markIntroSeen() {
        guard !data.seenIntro else { return }
        data.seenIntro = true
        persist()
    }

    var settings: GameSettings { data.settings }

    func updateSettings(_ change: (inout GameSettings) -> Void) {
        var s = data.settings
        change(&s)
        guard s != data.settings else { return }
        data.settings = s
        AudioManager.shared.apply(settings: s)
        persist()
    }

    func resetProgress() {
        let settings = data.settings
        data = SaveData()
        data.settings = settings
        persist()
    }

    private func persist() {
        SaveManager.save(data)
    }
}
