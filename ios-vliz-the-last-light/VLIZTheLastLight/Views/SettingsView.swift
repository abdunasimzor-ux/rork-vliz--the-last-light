import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @ObservedObject private var progress = ProgressionManager.shared
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            MenuBackdrop(imageName: "vliz_alien_planet_night", time: AtmosphereManager.resolve(progress.settings.atmosphere), drift: false)
            Theme.void.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 14) {
                ScreenHeader(title: "Settings", onBack: onBack) { EmptyView() }
                ScrollView(showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 12) {
                            section("AUDIO") {
                                SliderRow(label: "Music", symbol: "music.note", value: Binding(
                                    get: { progress.settings.musicVolume },
                                    set: { v in progress.updateSettings { $0.musicVolume = v } }))
                                SliderRow(label: "Effects", symbol: "speaker.wave.2.fill", value: Binding(
                                    get: { progress.settings.sfxVolume },
                                    set: { v in progress.updateSettings { $0.sfxVolume = v } }),
                                    onRelease: { AudioManager.shared.play(.pickup) })
                            }
                            section("COMFORT") {
                                toggle("Screen shake", "iphone.radiowaves.left.and.right", \.screenShake)
                                toggle("Reduced effects", "sparkles", \.reducedEffects)
                                toggle("Haptics", "hand.tap.fill", \.haptics)
                            }
                        }
                        VStack(spacing: 12) {
                            section("ATMOSPHERE") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Picker("Time of day", selection: Binding(
                                        get: { progress.settings.atmosphere },
                                        set: { v in
                                            Haptics.tap()
                                            progress.updateSettings { $0.atmosphere = v }
                                        })) {
                                        ForEach(AtmosphereMode.allCases) { m in Text(m.label).tag(m) }
                                    }
                                    .pickerStyle(.segmented)
                                    Text(progress.settings.atmosphere == .auto
                                         ? "Follows your local time: now \(AtmosphereManager.resolve(.auto).label.lowercased()). Cosmetic only."
                                         : "Menu mood is fixed to \(progress.settings.atmosphere.label.lowercased()). Cosmetic only.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.vertical, 6)
                            }
                            section("PROGRESS") {
                                Button(role: .destructive) {
                                    Haptics.warning()
                                    confirmReset = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Reset progress")
                                        Spacer()
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.magenta)
                                    .frame(height: 40)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(VlizPressStyle())
                                Button {
                                    Haptics.tap()
                                    AudioManager.shared.play(.uiBack)
                                    onBack()
                                } label: {
                                    HStack {
                                        Image(systemName: "house")
                                        Text("Return to menu")
                                        Spacer()
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(height: 40)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(VlizPressStyle())
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) {
                progress.resetProgress()
                Haptics.heavy()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Fragments, upgrades, unlocked weapons and mission records will be erased. Settings are kept.")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .trackedHeading(10, tracking: 3, color: Theme.textSecondary)
                .padding(.bottom, 4)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vlizPanel(cut: 10)
    }

    private func toggle(_ label: String, _ symbol: String, _ key: WritableKeyPath<GameSettings, Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { progress.settings[keyPath: key] },
            set: { v in
                Haptics.tap()
                progress.updateSettings { $0[keyPath: key] = v }
            })) {
            Label(label, systemImage: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.cyan)
        .frame(height: 36)
    }
}

private struct SliderRow: View {
    let label: String
    let symbol: String
    @Binding var value: Double
    var onRelease: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Label(label, systemImage: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 100, alignment: .leading)
            Slider(value: $value, in: 0...1) { editing in
                if !editing { onRelease?() }
            }
            .tint(Theme.cyan)
            Text("\(Int((value * 100).rounded()))")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30, alignment: .trailing)
        }
        .frame(height: 36)
    }
}
