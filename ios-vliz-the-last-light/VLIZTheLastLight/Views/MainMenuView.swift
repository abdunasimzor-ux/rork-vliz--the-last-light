import SwiftUI

enum MenuRoute: Hashable {
    case arsenal, upgrades, settings
}

struct MainMenuView: View {
    let onPlay: () -> Void
    @ObservedObject private var progress = ProgressionManager.shared
    @State private var path: [MenuRoute] = []
    @State private var appeared = false

    var body: some View {
        NavigationStack(path: $path) {
            menu
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MenuRoute.self) { route in
                    Group {
                        switch route {
                        case .arsenal: ArsenalView { path.removeLast() }
                        case .upgrades: UpgradesView { path.removeLast() }
                        case .settings: SettingsView { path.removeLast() }
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
    }

    private var timeOfDay: TimeOfDay { AtmosphereManager.resolve(progress.settings.atmosphere) }

    private var menu: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                MenuBackdrop(imageName: "vliz_alien_planet_night", time: timeOfDay, drift: true)

                // Left legibility gradient
                LinearGradient(colors: [Theme.void.opacity(0.85), Theme.void.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.6)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Wordmark()
                            .padding(.bottom, max(14, geo.size.height * 0.06))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -10)

                        VStack(spacing: 10) {
                            MenuButton(title: "Play", symbol: "play.fill", primary: true, action: onPlay)
                            MenuButton(title: "Arsenal", symbol: "scope") { path.append(.arsenal) }
                            MenuButton(title: "Upgrades", symbol: "chevron.up.2") { path.append(.upgrades) }
                            MenuButton(title: "Settings", symbol: "gearshape.fill") { path.append(.settings) }
                        }
                        .frame(width: min(300, geo.size.width * 0.36))
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -20)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 28)
                .frame(maxHeight: .infinity)

                VStack {
                    HStack {
                        Spacer()
                        FragmentBadge(amount: progress.fragments)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Chapter I · The Fall of Vliz")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
        }
        .background(Theme.void)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { appeared = true }
        }
    }
}

/// Full-bleed art with slow drift, a cosmetic time-of-day tint, fog and floating motes.
struct MenuBackdrop: View {
    let imageName: String
    var time: TimeOfDay
    var drift: Bool = true
    @State private var zoom = false

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .scaleEffect(zoom ? 1.08 : 1.0)
                .brightness(time.brightness)
                .ignoresSafeArea()
            time.tint.opacity(time.tintOpacity)
                .blendMode(.softLight)
                .ignoresSafeArea()
            time.tint.opacity(time.tintOpacity * 0.5)
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, Theme.void.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
            MotesView(color: time.moteColor, count: 36, intensity: 0.9)
                .ignoresSafeArea()
        }
        .clipped()
        .animation(.easeInOut(duration: 0.8), value: time)
        .onAppear {
            guard drift, !ProgressionManager.shared.settings.reducedEffects else { return }
            withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) { zoom = true }
        }
        .allowsHitTesting(false)
    }
}

struct Wordmark: View {
    var size: CGFloat = 54
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Text("VLIZ")
                    .font(Theme.wordmark(size))
                    .tracking(size * 0.32)
                    .foregroundStyle(Theme.textPrimary)
                    .shadow(color: Theme.cyan.opacity(pulse ? 0.7 : 0.35), radius: pulse ? 14 : 8)
                // Light-beam through the "I"
                Capsule()
                    .fill(LinearGradient(colors: [.clear, Theme.cyan, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: size * 1.4)
                    .offset(x: size * 0.36)
                    .opacity(pulse ? 1 : 0.6)
                    .blendMode(.plusLighter)
            }
            GlowRule()
                .frame(width: size * 4.6)
            Text("THE LAST LIGHT")
                .font(.system(size: 12, weight: .medium))
                .tracking(7)
                .foregroundStyle(Theme.textSecondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("VLIZ: The Last Light")
    }
}

struct MenuButton: View {
    let title: String
    let symbol: String
    var primary: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            AudioManager.shared.play(.uiTap)
            action()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                    .foregroundStyle(primary ? Theme.textPrimary : Theme.textSecondary)
                Text(title.uppercased())
                    .trackedHeading(14, tracking: 3)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 46)
            .contentShape(Rectangle())
            .vlizPanel(highlighted: primary)
        }
        .buttonStyle(VlizPressStyle())
    }
}
