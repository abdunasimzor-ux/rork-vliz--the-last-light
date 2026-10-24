import SwiftUI

enum TimeOfDay: String {
    case day, evening, night

    var label: String { rawValue.capitalized }

    /// Cosmetic tint layered over the menu art.
    var tint: Color {
        switch self {
        case .day: return Color(hex: 0x3FA8C8)
        case .evening: return Color(hex: 0xC2456E)
        case .night: return Color(hex: 0x05060D)
        }
    }

    var tintOpacity: Double {
        switch self {
        case .day: return 0.16
        case .evening: return 0.2
        case .night: return 0.28
        }
    }

    var moteColor: Color {
        switch self {
        case .day: return Theme.cyan
        case .evening: return Color(hex: 0xFF9A7A)
        case .night: return Theme.softViolet
        }
    }

    var brightness: Double {
        switch self {
        case .day: return 0.06
        case .evening: return 0
        case .night: return -0.08
        }
    }
}

/// Resolves the menu atmosphere. Cosmetic only — never touches gameplay.
enum AtmosphereManager {
    static func resolve(_ mode: AtmosphereMode, date: Date = Date()) -> TimeOfDay {
        switch mode {
        case .day: return .day
        case .evening: return .evening
        case .night: return .night
        case .auto:
            let hour = Calendar.current.component(.hour, from: date)
            if (6..<17).contains(hour) { return .day }
            if (17..<21).contains(hour) { return .evening }
            return .night
        }
    }
}
