import SwiftUI
import SpriteKit

/// Shared visual tokens. Gameplay (SpriteKit) and menus (SwiftUI) read the same palette.
enum Theme {
    static let void = Color(hex: 0x05060D)
    static let midnight = Color(hex: 0x0B1230)
    static let violet = Color(hex: 0x2A1B4D)
    static let teal = Color(hex: 0x0E3B44)
    static let cyan = Color(hex: 0x3FF2FF)
    static let magenta = Color(hex: 0xFF2E7A)
    static let softViolet = Color(hex: 0x9B6BFF)
    static let textPrimary = Color(hex: 0xE8F4FF)
    static let textSecondary = Color(hex: 0x7F8CA8)
    static let panel = Color(hex: 0x0B1230).opacity(0.72)

    /// Title wordmark only. Everything else uses SF Pro.
    static func wordmark(_ size: CGFloat) -> Font {
        .custom("Futura-Medium", size: size)
    }

    static func heading(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold)
    }
}

enum SKTheme {
    static let void = SKColor(hex: 0x05060D)
    static let midnight = SKColor(hex: 0x0B1230)
    static let violet = SKColor(hex: 0x2A1B4D)
    static let teal = SKColor(hex: 0x0E3B44)
    static let cyan = SKColor(hex: 0x3FF2FF)
    static let magenta = SKColor(hex: 0xFF2E7A)
    static let softViolet = SKColor(hex: 0x9B6BFF)
    static let text = SKColor(hex: 0xE8F4FF)
    static let rock = SKColor(hex: 0x080C1C)
    static let rockEdge = SKColor(hex: 0x16294A)
    static let ember = SKColor(hex: 0xFF7A3D)
    static let heal = SKColor(hex: 0x6CFFB8)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
