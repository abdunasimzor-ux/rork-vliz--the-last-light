import Foundation

struct DialogueLine: Hashable {
    let speaker: String?
    let text: String
    let duration: TimeInterval

    init(_ speaker: String?, _ text: String, _ duration: TimeInterval = 3.2) {
        self.speaker = speaker
        self.text = text
        self.duration = duration
    }
}

enum CinematicEffect {
    case calm
    case fleet
    case invasion
    case settlement
    case awakening
}

struct CinematicScene: Identifiable {
    let id: Int
    let imageName: String
    let duration: TimeInterval
    let effect: CinematicEffect
    let lines: [DialogueLine]
    /// Ken Burns drift: start/end zoom and horizontal drift fraction.
    let zoom: (CGFloat, CGFloat)
    let drift: CGFloat
}

enum StoryData {
    static let openingCinematic: [CinematicScene] = [
        CinematicScene(
            id: 0, imageName: "planet_vliz_orbit", duration: 7.5, effect: .calm,
            lines: [
                DialogueLine(nil, "Vliz. For ten thousand years, its forests held the light.", 3.6),
                DialogueLine(nil, "We never asked where that light came from.", 3.4)
            ],
            zoom: (1.0, 1.12), drift: -0.03
        ),
        CinematicScene(
            id: 1, imageName: "void_corsair_fleet", duration: 7.5, effect: .fleet,
            lines: [
                DialogueLine(nil, "Then the sky tore open. The Void Corsairs.", 3.4),
                DialogueLine(nil, "They came for what sleeps beneath our soil.", 3.6)
            ],
            zoom: (1.15, 1.02), drift: 0.04
        ),
        CinematicScene(
            id: 2, imageName: "alien_city_under_attack", duration: 8.0, effect: .invasion,
            lines: [
                DialogueLine(nil, "The crystal spires fell in a single night.", 3.6),
                DialogueLine(nil, "The light network went dark. Families were scattered in the ash.", 4.0)
            ],
            zoom: (1.04, 1.16), drift: 0.02
        ),
        CinematicScene(
            id: 3, imageName: "alien_ruins_survivor", duration: 8.5, effect: .settlement,
            lines: [
                DialogueLine("KAEL", "I told them I'd be home before nightfall.", 3.8),
                DialogueLine("KAEL", "...There's no one left to come home to.", 4.2)
            ],
            zoom: (1.1, 1.0), drift: -0.04
        ),
        CinematicScene(
            id: 4, imageName: "alien_energy_pistol", duration: 8.0, effect: .awakening,
            lines: [
                DialogueLine(nil, "Beneath the old shrine, something was waiting.", 3.6),
                DialogueLine("KAEL", "It's warm... like it knows me.", 3.8)
            ],
            zoom: (1.0, 1.18), drift: 0.0
        )
    ]

    static let levelStart: [DialogueLine] = [
        DialogueLine("KAEL", "Corsair patrols everywhere. I have to get out of the settlement.", 3.6),
        DialogueLine("KAEL", "The old energy station... if anything still works, it's there.", 3.6)
    ]

    static let familyMemorial: [DialogueLine] = [
        DialogueLine("KAEL", "Mira. Tobin. I'll find out why they did this. I promise.", 3.8)
    ]

    static let caverns: [DialogueLine] = [
        DialogueLine("KAEL", "The crystals are dimming. The whole network is dying.", 3.4)
    ]

    static let station: [DialogueLine] = [
        DialogueLine("CORSAIR", "Survivor in the station! Seal the doors!", 3.0)
    ]

    static let arcBlade: [DialogueLine] = [
        DialogueLine("KAEL", "Another relic. It's responding to the blaster.", 3.2),
        DialogueLine(nil, "Tap SWAP to switch weapons. The Arc Blade cuts through armor.", 4.0)
    ]

    static let ironboundHint: [DialogueLine] = [
        DialogueLine(nil, "Ironbound armor shrugs off blaster fire. Strike after its slam.", 4.0)
    ]

    static let bossIntro: [DialogueLine] = [
        DialogueLine("RHEX", "So the planet sends a child to guard its heart.", 3.2),
        DialogueLine("RHEX", "Step aside. My people have no time left for mercy.", 3.4)
    ]

    static let bossPhaseTwo: [DialogueLine] = [
        DialogueLine("RHEX", "Enough! You don't know what is hunting us!", 3.0)
    ]

    static let bossDefeated: [DialogueLine] = [
        DialogueLine("RHEX", "Varkhane... will not stop. He cannot.", 3.4)
    ]

    static let ending: [DialogueLine] = [
        DialogueLine("KAEL", "The light... it's answering me.", 3.0),
        DialogueLine("???", "...Kael.", 2.4),
        DialogueLine("???", "We have been waiting beneath the light for a very long time.", 3.8),
        DialogueLine("KAEL", "Who's there? Who are you?", 2.8)
    ]
}
