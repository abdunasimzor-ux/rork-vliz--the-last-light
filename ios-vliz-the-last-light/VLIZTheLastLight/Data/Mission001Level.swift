import Foundation
import CoreGraphics

/// Mission 001 "Ashes of Vliz" layout. Pure data: four zones, ~3-5 minutes of play.
enum Mission001Level {
    static let groundTop: CGFloat = 96

    static func make() -> LevelDefinition {
        let G = groundTop
        var solids: [SolidSpec] = []
        var shards: [CGPoint] = []

        func ground(_ from: CGFloat, _ to: CGFloat, top: CGFloat = G) {
            solids.append(SolidSpec(rect: CGRect(x: from, y: -400, width: to - from, height: top + 400)))
        }
        func block(_ from: CGFloat, _ to: CGFloat, top: CGFloat) {
            solids.append(SolidSpec(rect: CGRect(x: from, y: G - 2, width: to - from, height: top - G + 2)))
        }
        func ledge(_ centerX: CGFloat, _ top: CGFloat, _ width: CGFloat) {
            solids.append(SolidSpec(rect: CGRect(x: centerX - width / 2, y: top - 16, width: width, height: 16), oneWay: true))
        }
        func gate(_ id: String, _ x: CGFloat) {
            solids.append(SolidSpec(rect: CGRect(x: x, y: G - 2, width: 22, height: 600), oneWay: false, gateID: id))
        }
        func shardRow(_ xs: [CGFloat], _ y: CGFloat) {
            shards.append(contentsOf: xs.map { CGPoint(x: $0, y: y) })
        }

        // Boundaries
        solids.append(SolidSpec(rect: CGRect(x: -300, y: -400, width: 300, height: 2000)))
        solids.append(SolidSpec(rect: CGRect(x: 7100, y: -400, width: 300, height: 2000)))

        // ZONE 1 — Ruined settlement (0 - 2140)
        ground(0, 620)
        ground(720, 1180)
        block(960, 1030, top: 152)
        ground(1320, 2400)
        block(1500, 1720, top: 156)
        ledge(1900, 204, 130)

        shardRow([200, 240, 280], G + 34)
        shards.append(contentsOf: [CGPoint(x: 640, y: 170), CGPoint(x: 670, y: 200), CGPoint(x: 700, y: 170)])
        shardRow([995], 188)
        shardRow([1250], 210)
        shardRow([1570, 1620, 1670], 192)
        shardRow([1870, 1900, 1930], 240)

        // ZONE 2 — Crystal caverns (2140 - 4330)
        ground(2400, 2900, top: 40)
        ledge(2480, 170, 110)
        ledge(2650, 232, 110)
        ledge(2820, 170, 110)
        ground(2900, 3350)
        block(3350, 3600, top: 182)
        ledge(3690, 172, 84)
        ground(3780, 7100)

        shardRow([2480], 205)
        shardRow([2650], 268)
        shardRow([2820], 205)
        shardRow([3100, 3140, 3180], G + 34)
        shardRow([3430, 3470], 218)
        shardRow([3690], 208)
        shardRow([4000, 4040], G + 34)

        // ZONE 3 — Abandoned energy station (4330 - 6200)
        gate("gateA", 4700)
        gate("gateB", 5380)
        ledge(4900, 200, 150)
        ledge(5160, 200, 150)

        shardRow([4480, 4520, 4560], G + 34)
        shardRow([4900], 236)
        shardRow([5160], 236)
        shardRow([5700, 5740, 5780], G + 34)

        // ZONE 4 — Reactor arena (6200 - 7100)
        gate("gateBoss", 6180)
        ledge(6440, 214, 130)
        ledge(6860, 214, 130)

        var pickups: [PickupSpec] = shards.enumerated().map { PickupSpec(id: $0.offset, kind: .shard, position: $0.element) }
        let base = pickups.count
        pickups.append(PickupSpec(id: base + 1, kind: .health(25), position: CGPoint(x: 1995, y: G + 26)))
        pickups.append(PickupSpec(id: base + 2, kind: .health(25), position: CGPoint(x: 3560, y: 208)))
        pickups.append(PickupSpec(id: base + 3, kind: .health(35), position: CGPoint(x: 6060, y: G + 26)))
        pickups.append(PickupSpec(id: base + 4, kind: .weapon(.arcBlade), position: CGPoint(x: 5560, y: G + 40)))

        let spawns: [EnemySpawn] = [
            EnemySpawn(id: "s1", kind: .skitter, x: 520, y: G, patrol: 80),
            EnemySpawn(id: "s2", kind: .skitter, x: 1090, y: G, patrol: 60),
            EnemySpawn(id: "s3", kind: .skitter, x: 1400, y: G, patrol: 70),
            EnemySpawn(id: "g1", kind: .gunner, x: 1660, y: 156, patrol: 40),
            EnemySpawn(id: "s4", kind: .skitter, x: 1840, y: G, patrol: 80),
            EnemySpawn(id: "s5", kind: .skitter, x: 2060, y: G, patrol: 90),
            EnemySpawn(id: "s6", kind: .skitter, x: 2980, y: G, patrol: 60),
            EnemySpawn(id: "g2", kind: .gunner, x: 3250, y: G, patrol: 60),
            EnemySpawn(id: "g3", kind: .gunner, x: 3530, y: 182, patrol: 30),
            EnemySpawn(id: "s7", kind: .skitter, x: 3900, y: G, patrol: 80),
            EnemySpawn(id: "i1", kind: .ironbound, x: 4150, y: G, patrol: 90),
            // Station lockdown waves
            EnemySpawn(id: "w1a", kind: .skitter, x: 5100, y: G, patrol: 80, encounterID: "lockdown", wave: 0),
            EnemySpawn(id: "w1b", kind: .skitter, x: 5280, y: G, patrol: 80, encounterID: "lockdown", wave: 0),
            EnemySpawn(id: "w1c", kind: .gunner, x: 5160, y: 200, patrol: 30, encounterID: "lockdown", wave: 0),
            EnemySpawn(id: "w2a", kind: .ironbound, x: 5220, y: G, patrol: 80, encounterID: "lockdown", wave: 1),
            EnemySpawn(id: "w2b", kind: .gunner, x: 4900, y: 200, patrol: 30, encounterID: "lockdown", wave: 1),
            EnemySpawn(id: "w2c", kind: .skitter, x: 5320, y: G, patrol: 60, encounterID: "lockdown", wave: 1),
            // Arc Blade proving ground
            EnemySpawn(id: "i2", kind: .ironbound, x: 5920, y: G, patrol: 80),
            EnemySpawn(id: "s8", kind: .skitter, x: 6040, y: G, patrol: 60)
        ]

        let hazards: [HazardSpec] = [
            HazardSpec(rect: CGRect(x: 860, y: G, width: 40, height: 70), kind: .fireVent(period: 2.6, active: 1.0, offset: 0), damage: 14),
            HazardSpec(rect: CGRect(x: 1420, y: G, width: 40, height: 70), kind: .fireVent(period: 2.6, active: 1.0, offset: 1.3), damage: 14),
            HazardSpec(rect: CGRect(x: 2400, y: 40, width: 500, height: 22), kind: .spikes, damage: 15)
        ]

        let checkpoints: [CheckpointSpec] = [
            CheckpointSpec(id: "cp1", x: 2190, y: G),
            CheckpointSpec(id: "cp2", x: 4380, y: G),
            CheckpointSpec(id: "cp3", x: 6110, y: G)
        ]

        let triggers: [TriggerSpec] = [
            TriggerSpec(id: "t_start", x: 0, actions: [.dialogue(StoryData.levelStart)]),
            TriggerSpec(id: "t_memorial", x: 300, actions: [.dialogue(StoryData.familyMemorial)]),
            TriggerSpec(id: "t_escape", x: 2120, actions: [.completeObjective(ObjectiveID.escape)]),
            TriggerSpec(id: "t_caverns", x: 2300, actions: [.dialogue(StoryData.caverns)]),
            TriggerSpec(id: "t_iron", x: 3920, actions: [.dialogue(StoryData.ironboundHint)]),
            TriggerSpec(id: "t_station", x: 4330, actions: [.completeObjective(ObjectiveID.station)]),
            TriggerSpec(id: "t_lockdown", x: 4800, actions: [.dialogue(StoryData.station), .startEncounter("lockdown")]),
            TriggerSpec(id: "t_boss", x: 6330, actions: [.startBoss])
        ]

        let encounters = [
            EncounterSpec(id: "lockdown", gateIDs: ["gateA", "gateB"], waves: 2, objectiveOnClear: ObjectiveID.corsairs)
        ]

        let arena = BossArenaSpec(
            minX: 6200, maxX: 7100, gateID: "gateBoss",
            bossSpawn: CGPoint(x: 6920, y: G), platformY: 214,
            beaconPosition: CGPoint(x: 6960, y: G)
        )

        let decor: [DecorSpec] = [
            DecorSpec(kind: .ruinDome, position: CGPoint(x: 120, y: G), scale: 1.1),
            DecorSpec(kind: .memorial, position: CGPoint(x: 330, y: G)),
            DecorSpec(kind: .lamp, position: CGPoint(x: 560, y: G)),
            DecorSpec(kind: .ruinDome, position: CGPoint(x: 820, y: G), scale: 0.8),
            DecorSpec(kind: .lamp, position: CGPoint(x: 1120, y: G)),
            DecorSpec(kind: .ruinDome, position: CGPoint(x: 1380, y: G), scale: 1.2),
            DecorSpec(kind: .lamp, position: CGPoint(x: 1780, y: G)),
            DecorSpec(kind: .ruinDome, position: CGPoint(x: 2020, y: G), scale: 0.9),
            DecorSpec(kind: .crystal(cyan: false), position: CGPoint(x: 2260, y: G), scale: 1.3),
            DecorSpec(kind: .crystal(cyan: true), position: CGPoint(x: 2330, y: G), scale: 0.8),
            DecorSpec(kind: .crystal(cyan: false), position: CGPoint(x: 2950, y: G), scale: 1.0),
            DecorSpec(kind: .crystal(cyan: true), position: CGPoint(x: 3200, y: G), scale: 1.4),
            DecorSpec(kind: .crystal(cyan: false), position: CGPoint(x: 3380, y: 182), scale: 0.9),
            DecorSpec(kind: .crystal(cyan: true), position: CGPoint(x: 3850, y: G), scale: 1.1),
            DecorSpec(kind: .crystal(cyan: false), position: CGPoint(x: 4200, y: G), scale: 1.5),
            DecorSpec(kind: .pipe, position: CGPoint(x: 4450, y: G)),
            DecorSpec(kind: .pipe, position: CGPoint(x: 4650, y: G)),
            DecorSpec(kind: .pipe, position: CGPoint(x: 5050, y: G)),
            DecorSpec(kind: .pedestal, position: CGPoint(x: 5560, y: G)),
            DecorSpec(kind: .pipe, position: CGPoint(x: 5850, y: G)),
            DecorSpec(kind: .crystal(cyan: true), position: CGPoint(x: 6250, y: G), scale: 1.2),
            DecorSpec(kind: .crystal(cyan: true), position: CGPoint(x: 7060, y: G), scale: 1.4)
        ]

        return LevelDefinition(
            width: 7100,
            groundTop: G,
            playerStart: CGPoint(x: 110, y: G),
            zones: [
                ZoneSpan(style: .settlement, startX: -400, endX: 2140),
                ZoneSpan(style: .caverns, startX: 2140, endX: 4330),
                ZoneSpan(style: .station, startX: 4330, endX: 6200),
                ZoneSpan(style: .arena, startX: 6200, endX: 8000)
            ],
            solids: solids,
            hazards: hazards,
            spawns: spawns,
            pickups: pickups,
            checkpoints: checkpoints,
            triggers: triggers,
            encounters: encounters,
            bossArena: arena,
            decor: decor
        )
    }
}
