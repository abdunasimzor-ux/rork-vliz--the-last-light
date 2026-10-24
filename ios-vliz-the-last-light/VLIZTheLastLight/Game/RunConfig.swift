import Foundation

/// Snapshot of mission progress. Taken at each checkpoint so "Retry" rebuilds the level
/// exactly as it was when the checkpoint was reached.
struct RunConfig {
    var checkpointID: String? = nil
    var collectedPickupIDs: Set<Int> = []
    var defeatedSpawnIDs: Set<String> = []
    var completedObjectives: Set<String> = []
    var clearedEncounters: Set<String> = []
    var firedTriggers: Set<String> = []
    var hasArcBlade: Bool
    var equipped: WeaponID = .pulseBlaster
    /// Fragment value not yet banked into the wallet (fractional remainder carries).
    var unbankedValue: Double = 0
    /// Total fragments earned this run (HUD + results).
    var runFragmentValue: Double = 0
    var enemiesDefeated = 0
    var shardsCollected = 0

    static func fresh(loadout: PlayerLoadout) -> RunConfig {
        RunConfig(hasArcBlade: loadout.hasArcBlade)
    }
}
