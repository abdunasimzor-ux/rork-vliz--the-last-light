import Foundation

struct ObjectiveDefinition: Identifiable, Hashable {
    let id: String
    let text: String
}

struct MissionDefinition: Identifiable {
    let id: String
    let code: String
    let chapter: Int
    let title: String
    let synopsis: String
    let objectives: [ObjectiveDefinition]
    let firstClearBonus: Int
    let replayBonus: Int
    let rewardWeapon: WeaponID?
    let isPlayable: Bool
    let makeLevel: () -> LevelDefinition
}

struct ChapterDefinition: Identifiable {
    let id: Int
    let numeral: String
    let title: String
    let plannedMissions: Int
    let teaser: String
}

/// The long-term campaign skeleton. Only Mission 001 is playable; new missions are
/// added by appending a `MissionDefinition` with its own level data.
enum Campaign {
    static let chapters: [ChapterDefinition] = [
        ChapterDefinition(id: 1, numeral: "I", title: "The Fall of Vliz", plannedMissions: 60, teaser: "Survive the invasion."),
        ChapterDefinition(id: 2, numeral: "II", title: "The Shattered Resistance", plannedMissions: 60, teaser: "Find who is left."),
        ChapterDefinition(id: 3, numeral: "III", title: "The Corsair Empire", plannedMissions: 60, teaser: "Take the war to them."),
        ChapterDefinition(id: 4, numeral: "IV", title: "The Truth Beneath the Light", plannedMissions: 60, teaser: "What sleeps below?"),
        ChapterDefinition(id: 5, numeral: "V", title: "The Last Light", plannedMissions: 60, teaser: "Decide two fates.")
    ]

    static let mission001 = MissionDefinition(
        id: "M001",
        code: "001",
        chapter: 1,
        title: "Ashes of Vliz",
        synopsis: "The Void Corsairs have burned your settlement. Fight through the ruins and the crystal caverns to the old energy station, where something ancient is calling.",
        objectives: [
            ObjectiveDefinition(id: ObjectiveID.escape, text: "Escape the ruined settlement"),
            ObjectiveDefinition(id: ObjectiveID.station, text: "Reach the abandoned energy station"),
            ObjectiveDefinition(id: ObjectiveID.corsairs, text: "Defeat the Corsair forces"),
            ObjectiveDefinition(id: ObjectiveID.arcBlade, text: "Acquire the Arc Blade"),
            ObjectiveDefinition(id: ObjectiveID.rhex, text: "Defeat Commander Rhex"),
            ObjectiveDefinition(id: ObjectiveID.signal, text: "Discover the signal beneath Vliz")
        ],
        firstClearBonus: 150,
        replayBonus: 40,
        rewardWeapon: .arcBlade,
        isPlayable: true,
        makeLevel: { Mission001Level.make() }
    )

    static let missions: [MissionDefinition] = [mission001]

    static func mission(_ id: String) -> MissionDefinition? {
        missions.first { $0.id == id }
    }
}

enum ObjectiveID {
    static let escape = "escape"
    static let station = "station"
    static let corsairs = "corsairs"
    static let arcBlade = "arcblade"
    static let rhex = "rhex"
    static let signal = "signal"
}
