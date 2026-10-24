import Foundation

/// All sound effects are synthesized at launch into small PCM sample arrays.
nonisolated enum SFX: String, CaseIterable, Sendable {
    case jump, dash, blaster, blade, hit, enemyHit, enemyDie, playerHurt, pickup
    case bossWarn, bossCharge, explosion, victory, defeat, uiTap, uiBack, checkpoint, unlock, slam, heal
}

nonisolated enum SynthBank {
    static let sampleRate: Double = 44100

    private struct Rng {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF) * 2 - 1
        }
    }

    /// Returns mono float samples for an effect.
    static func samples(for sfx: SFX) -> [Float] {
        switch sfx {
        case .jump:
            return tone(duration: 0.14, from: 300, to: 620, wave: .square, volume: 0.18, attack: 0.005)
        case .dash:
            return noise(duration: 0.2, volume: 0.35, lowpassFrom: 0.6, to: 0.05)
                .mix(tone(duration: 0.2, from: 500, to: 120, wave: .sine, volume: 0.2))
        case .blaster:
            return tone(duration: 0.12, from: 1300, to: 260, wave: .saw, volume: 0.16, attack: 0.002)
                .mix(tone(duration: 0.08, from: 2400, to: 900, wave: .sine, volume: 0.08))
        case .blade:
            return noise(duration: 0.18, volume: 0.32, lowpassFrom: 0.15, to: 0.8)
                .mix(tone(duration: 0.18, from: 220, to: 880, wave: .sine, volume: 0.14))
        case .hit:
            return noise(duration: 0.08, volume: 0.35, lowpassFrom: 0.5, to: 0.1)
        case .enemyHit:
            return tone(duration: 0.07, from: 520, to: 260, wave: .square, volume: 0.13)
                .mix(noise(duration: 0.06, volume: 0.18, lowpassFrom: 0.6, to: 0.2))
        case .enemyDie:
            return noise(duration: 0.35, volume: 0.4, lowpassFrom: 0.5, to: 0.02)
                .mix(tone(duration: 0.3, from: 400, to: 60, wave: .square, volume: 0.14))
        case .playerHurt:
            return tone(duration: 0.22, from: 240, to: 90, wave: .saw, volume: 0.24)
                .mix(noise(duration: 0.12, volume: 0.2, lowpassFrom: 0.4, to: 0.1))
        case .pickup:
            return tone(duration: 0.07, from: 1200, to: 1200, wave: .sine, volume: 0.16)
                .append(tone(duration: 0.1, from: 1800, to: 1800, wave: .sine, volume: 0.14))
        case .heal:
            return tone(duration: 0.1, from: 600, to: 900, wave: .sine, volume: 0.16)
                .append(tone(duration: 0.18, from: 900, to: 1400, wave: .sine, volume: 0.16))
        case .bossWarn:
            return tone(duration: 0.5, from: 180, to: 180, wave: .square, volume: 0.13, vibrato: 14)
        case .bossCharge:
            return tone(duration: 0.6, from: 80, to: 420, wave: .saw, volume: 0.18)
        case .explosion:
            return noise(duration: 0.7, volume: 0.6, lowpassFrom: 0.35, to: 0.01)
                .mix(tone(duration: 0.5, from: 120, to: 30, wave: .sine, volume: 0.4))
        case .slam:
            return tone(duration: 0.4, from: 90, to: 28, wave: .sine, volume: 0.55)
                .mix(noise(duration: 0.3, volume: 0.35, lowpassFrom: 0.2, to: 0.01))
        case .victory:
            return [523.0, 659.0, 784.0, 1046.0].reduce([Float]()) { acc, f in
                acc.append(tone(duration: 0.16, from: f, to: f, wave: .triangle, volume: 0.2))
            }
            .append(tone(duration: 0.6, from: 1046, to: 1046, wave: .triangle, volume: 0.18, vibrato: 6))
        case .defeat:
            return tone(duration: 0.3, from: 392, to: 370, wave: .triangle, volume: 0.22)
                .append(tone(duration: 0.3, from: 311, to: 293, wave: .triangle, volume: 0.22))
                .append(tone(duration: 0.7, from: 233, to: 196, wave: .triangle, volume: 0.22))
        case .uiTap:
            return tone(duration: 0.05, from: 1400, to: 1100, wave: .sine, volume: 0.12)
        case .uiBack:
            return tone(duration: 0.06, from: 900, to: 600, wave: .sine, volume: 0.12)
        case .checkpoint:
            return tone(duration: 0.12, from: 660, to: 660, wave: .triangle, volume: 0.2)
                .append(tone(duration: 0.3, from: 990, to: 990, wave: .triangle, volume: 0.18, vibrato: 5))
        case .unlock:
            return [440.0, 554.0, 659.0, 880.0, 1108.0].reduce([Float]()) { acc, f in
                acc.append(tone(duration: 0.1, from: f, to: f * 1.01, wave: .square, volume: 0.12))
            }
            .append(tone(duration: 0.5, from: 1318, to: 1318, wave: .sine, volume: 0.18, vibrato: 7))
        }
    }

    enum Wave { case sine, square, saw, triangle }

    static func tone(duration: Double, from f0: Double, to f1: Double, wave: Wave, volume: Double,
                     attack: Double = 0.01, vibrato: Double = 0) -> [Float] {
        let n = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / Double(max(n - 1, 1))
            let f = f0 * pow(f1 / f0, t) * (1 + (vibrato > 0 ? 0.03 * sin(2 * .pi * vibrato * Double(i) / sampleRate) : 0))
            phase += f / sampleRate
            phase -= floor(phase)
            let s: Double
            switch wave {
            case .sine: s = sin(2 * .pi * phase)
            case .square: s = phase < 0.5 ? 1 : -1
            case .saw: s = 2 * phase - 1
            case .triangle: s = 4 * abs(phase - 0.5) - 1
            }
            let time = Double(i) / sampleRate
            let env = min(1, time / attack) * pow(1 - t, 1.6)
            out[i] = Float(s * env * volume)
        }
        return out
    }

    static func noise(duration: Double, volume: Double, lowpassFrom a0: Double, to a1: Double) -> [Float] {
        let n = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var rng = Rng(state: 0x9E3779B97F4A7C15)
        var y = 0.0
        for i in 0..<n {
            let t = Double(i) / Double(max(n - 1, 1))
            let a = a0 + (a1 - a0) * t
            y += a * (rng.next() - y)
            let env = min(1, Double(i) / (0.004 * sampleRate)) * pow(1 - t, 2)
            out[i] = Float(y * env * volume * 1.6)
        }
        return out
    }
}

extension Array where Element == Float {
    nonisolated func mix(_ other: [Float]) -> [Float] {
        var out = [Float](repeating: 0, count: Swift.max(count, other.count))
        for i in 0..<out.count {
            out[i] = (i < count ? self[i] : 0) + (i < other.count ? other[i] : 0)
        }
        return out
    }

    nonisolated func append(_ other: [Float]) -> [Float] {
        self + other
    }
}
