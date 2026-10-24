import UIKit

/// Light wrapper over UIKit feedback generators. Respects the haptics setting.
enum Haptics {
    static var enabled = true

    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()
    private static let select = UISelectionFeedbackGenerator()

    static func tap() { guard enabled else { return }; select.selectionChanged() }
    static func light(_ intensity: CGFloat = 0.6) { guard enabled else { return }; lightGen.impactOccurred(intensity: intensity) }
    static func medium() { guard enabled else { return }; mediumGen.impactOccurred() }
    static func heavy() { guard enabled else { return }; heavyGen.impactOccurred() }
    static func rigid() { guard enabled else { return }; rigidGen.impactOccurred(intensity: 0.8) }
    static func success() { guard enabled else { return }; notify.notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; notify.notificationOccurred(.warning) }
    static func error() { guard enabled else { return }; notify.notificationOccurred(.error) }
}
