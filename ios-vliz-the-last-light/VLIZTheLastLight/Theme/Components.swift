import SwiftUI

/// Sharp sci-fi panel with two chamfered corners.
struct ChamferShape: Shape {
    var cut: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        p.closeSubpath()
        return p
    }
}

struct PanelBackground: ViewModifier {
    var highlighted: Bool = false
    var cut: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(
                ChamferShape(cut: cut)
                    .fill(Theme.midnight.opacity(highlighted ? 0.82 : 0.62))
                    .background(.ultraThinMaterial.opacity(0.25), in: ChamferShape(cut: cut))
            )
            .overlay(
                ChamferShape(cut: cut)
                    .stroke(highlighted ? Theme.cyan.opacity(0.9) : Theme.textSecondary.opacity(0.28), lineWidth: highlighted ? 1.4 : 1)
            )
            .shadow(color: highlighted ? Theme.cyan.opacity(0.35) : .clear, radius: 10)
    }
}

extension View {
    func vlizPanel(highlighted: Bool = false, cut: CGFloat = 10) -> some View {
        modifier(PanelBackground(highlighted: highlighted, cut: cut))
    }

    /// Wide-tracked uppercase heading style.
    func trackedHeading(_ size: CGFloat = 13, tracking: CGFloat = 3, color: Color = Theme.textPrimary) -> some View {
        self.font(.system(size: size, weight: .semibold))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

/// Press feedback used by every menu button: slight shrink + brightness + haptic + UI sound.
struct VlizPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? 0.12 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FragmentBadge: View {
    let amount: Int
    var label: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let label {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "diamond.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.8), radius: 4)
            Text(amount.formatted())
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.midnight.opacity(0.7)))
        .overlay(Capsule().stroke(Theme.textSecondary.opacity(0.3), lineWidth: 1))
        .animation(.snappy, value: amount)
    }
}

/// Header used on pushed menu screens (Arsenal, Upgrades, Settings).
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                AudioManager.shared.play(.uiBack)
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.midnight.opacity(0.7)))
                    .overlay(Circle().stroke(Theme.textSecondary.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(VlizPressStyle())
            .accessibilityLabel("Back")

            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            trailing
        }
    }
}

/// Thin glowing line used under titles.
struct GlowRule: View {
    var color: Color = Theme.cyan
    var body: some View {
        ZStack {
            LinearGradient(colors: [.clear, color, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1.5)
            LinearGradient(colors: [.clear, color.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 6)
                .blur(radius: 4)
        }
    }
}

/// Floating luminous motes drawn over menu backgrounds.
struct MotesView: View {
    var color: Color = Theme.cyan
    var count: Int = 40
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let seed = Double(i) * 12.9898
                    let fx = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let fy = (sin(seed * 1.7) * 23421.631).truncatingRemainder(dividingBy: 1)
                    let speed = 0.012 + abs(fx) * 0.02
                    let x = (abs(fx) * size.width + sin(t * 0.3 + seed) * 18)
                    var y = (abs(fy) - t * speed).truncatingRemainder(dividingBy: 1)
                    if y < 0 { y += 1 }
                    let py = y * size.height
                    let r = 1.0 + abs(fy) * 2.2
                    let a = (0.25 + 0.55 * abs(sin(t * 0.8 + seed))) * intensity
                    let rect = CGRect(x: x - r * 2, y: py - r * 2, width: r * 4, height: r * 4)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(a * 0.25)))
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: r * 1.4, dy: r * 1.4)), with: .color(color.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
