import SwiftUI

/// Landscape touch layout: floating joystick on the left, 2×2 action cluster on the right.
struct TouchControlsView: View {
    let input: InputState
    let weapon: WeaponID
    let hasArcBlade: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 0) {
                    JoystickZone(input: input)
                        .frame(width: geo.size.width * 0.42, height: geo.size.height * 0.72)
                    Spacer(minLength: 0)
                    actionCluster
                        .padding(.trailing, 26)
                        .padding(.bottom, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var actionCluster: some View {
        let melee = weapon == .arcBlade
        return Grid(horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
                ActionButton(title: "Jump", symbol: "chevron.up.2",
                             onPress: { input.pressJump(); Haptics.light(0.4) },
                             onRelease: { input.releaseJump() })
                ActionButton(title: "Dash", symbol: "chevron.forward.2",
                             onPress: { input.pressDash() },
                             onRelease: {})
            }
            GridRow {
                ActionButton(title: melee ? "Slash" : "Fire", symbol: melee ? "bolt.horizontal.fill" : "flame.fill",
                             accent: true,
                             onPress: { input.pressAttack() },
                             onRelease: { input.releaseAttack() })
                ActionButton(title: "Swap", symbol: hasArcBlade ? "arrow.left.arrow.right" : "lock.fill",
                             enabled: hasArcBlade,
                             onPress: { input.pressSwap() },
                             onRelease: {})
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let symbol: String
    var accent: Bool = false
    var enabled: Bool = true
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
        }
        .foregroundStyle(enabled ? Theme.textPrimary : Theme.textSecondary.opacity(0.6))
        .frame(width: 66, height: 66)
        .background(
            Circle().fill(pressed ? (accent ? Theme.cyan.opacity(0.35) : Theme.textPrimary.opacity(0.22)) : Theme.midnight.opacity(0.5))
        )
        .background(Circle().fill(.ultraThinMaterial.opacity(0.4)))
        .overlay(
            Circle().stroke(accent ? Theme.cyan.opacity(pressed ? 1 : 0.55) : Theme.textSecondary.opacity(pressed ? 0.8 : 0.35),
                            lineWidth: accent ? 1.5 : 1)
        )
        .shadow(color: accent && pressed ? Theme.cyan.opacity(0.6) : .clear, radius: 10)
        .scaleEffect(pressed ? 0.9 : 1)
        .opacity(enabled ? 1 : 0.55)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
        .contentShape(Circle().inset(by: -6))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    if enabled {
                        onPress()
                    } else {
                        Haptics.warning()
                    }
                }
                .onEnded { _ in
                    pressed = false
                    if enabled { onRelease() }
                }
        )
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onPress(); onRelease() }
    }
}

/// Touch anywhere in the zone to spawn the stick under the thumb; drag to steer.
struct JoystickZone: View {
    let input: InputState
    @State private var origin: CGPoint?
    @State private var knob: CGSize = .zero
    private let radius: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let rest = CGPoint(x: 100, y: geo.size.height - 92)
            let center = origin ?? rest
            ZStack {
                Color.clear.contentShape(Rectangle())
                ZStack {
                    Circle()
                        .fill(Theme.midnight.opacity(origin == nil ? 0.3 : 0.45))
                        .background(Circle().fill(.ultraThinMaterial.opacity(0.3)))
                        .overlay(Circle().stroke(Theme.textSecondary.opacity(0.35), lineWidth: 1))
                        .frame(width: radius * 2 + 30, height: radius * 2 + 30)
                    ForEach(0..<4, id: \.self) { i in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                            .offset(x: radius + 2)
                            .rotationEffect(.degrees(Double(i) * 90))
                    }
                    Circle()
                        .fill(LinearGradient(colors: [Theme.textPrimary.opacity(0.55), Theme.textSecondary.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                        .overlay(Circle().stroke(abs(knob.width) > radius * 0.2 ? Theme.cyan.opacity(0.8) : .clear, lineWidth: 1.5))
                        .frame(width: 52, height: 52)
                        .offset(knob)
                }
                .position(center)
                .opacity(origin == nil ? 0.75 : 1)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if origin == nil { origin = v.startLocation }
                        guard let o = origin else { return }
                        var dx = v.location.x - o.x
                        var dy = v.location.y - o.y
                        let len = hypot(dx, dy)
                        if len > radius { dx *= radius / len; dy *= radius / len }
                        knob = CGSize(width: dx, height: dy)
                        input.touchMoveX = dx / radius
                    }
                    .onEnded { _ in
                        origin = nil
                        input.touchMoveX = 0
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { knob = .zero }
                    }
            )
        }
        .accessibilityHidden(true)
    }
}
