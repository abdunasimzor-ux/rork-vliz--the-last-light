import SwiftUI

struct HUDView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    statusPanel
                    Spacer(minLength: 8)
                    Group {
                        if let boss = session.boss {
                            BossBar(hud: boss)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if let obj = session.objective, session.phase != .ending {
                            ObjectivePill(objective: obj, completed: session.completedCount)
                                .transition(.opacity)
                        }
                    }
                    Spacer(minLength: 8)
                    pauseButton
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .animation(.snappy, value: session.boss != nil)

            if let banner = session.banner {
                BannerView(banner: banner)
                    .id(banner.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 78)
                    .allowsHitTesting(false)
            }

            if let line = session.dialogue {
                DialogueView(line: line)
                    .id(line)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, session.controlsHidden ? 40 : 22)
                    .padding(.horizontal, session.controlsHidden ? 80 : 230)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.25), value: session.banner)
        .animation(.easeOut(duration: 0.25), value: session.dialogue)
    }

    private var statusPanel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HealthBar(health: session.health, maxHealth: session.maxHealth)
                HStack(spacing: 5) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.cyan)
                    Text("\(session.runFragments)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: session.runFragments)
                }
            }
            Rectangle()
                .fill(Theme.textSecondary.opacity(0.3))
                .frame(width: 1, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: session.weapon == .arcBlade ? "bolt.horizontal.fill" : "scope")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.symbolEffect(.replace))
                Text(WeaponCatalog.definition(session.weapon).name.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(minWidth: 84, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .vlizPanel(cut: 8)
        .accessibilityElement(children: .combine)
    }

    private var pauseButton: some View {
        Button {
            Haptics.tap()
            AudioManager.shared.play(.uiTap)
            session.pause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.midnight.opacity(0.7)))
                .overlay(Circle().stroke(Theme.textSecondary.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(VlizPressStyle())
        .disabled(session.phase != .playing)
        .opacity(session.phase == .playing ? 1 : 0.4)
        .accessibilityLabel("Pause")
    }
}

struct HealthBar: View {
    let health: Int
    let maxHealth: Int
    @State private var trailing: Double = 1

    var body: some View {
        let frac = Double(health) / Double(max(maxHealth, 1))
        let segments = max(5, maxHealth / 20)
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.void.opacity(0.7))
                Rectangle().fill(Theme.magenta.opacity(0.6))
                    .frame(width: 120 * trailing)
                Rectangle()
                    .fill(LinearGradient(colors: [frac < 0.3 ? Theme.magenta : Theme.cyan, frac < 0.3 ? Theme.magenta.opacity(0.8) : Color(hex: 0x8FF8FF)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 120 * frac)
                    .shadow(color: (frac < 0.3 ? Theme.magenta : Theme.cyan).opacity(0.8), radius: 4)
                // Segment ticks
                HStack(spacing: 0) {
                    ForEach(1..<segments, id: \.self) { _ in
                        Spacer()
                        Rectangle().fill(Theme.void).frame(width: 2)
                    }
                    Spacer()
                }
            }
            .frame(width: 120, height: 9)
            .clipShape(ChamferShape(cut: 3))
            Text("\(health)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(frac < 0.3 ? Theme.magenta : Theme.textSecondary)
        }
        .onAppear { trailing = frac }
        .onChange(of: health) { _, _ in
            withAnimation(.easeOut(duration: 0.6).delay(0.25)) { trailing = frac }
        }
        .accessibilityLabel("Health \(health) of \(maxHealth)")
    }
}

struct ObjectivePill: View {
    let objective: ObjectiveDefinition
    let completed: Int
    @State private var glow = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "diamond.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.cyan)
            Text(objective.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(completed)/\(Campaign.mission001.objectives.count)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .vlizPanel(highlighted: glow, cut: 8)
        .id(objective.id)
        .transition(.opacity)
        .onChange(of: objective.id) { _, _ in
            glow = true
            withAnimation(.easeOut(duration: 1.4).delay(0.6)) { glow = false }
        }
        .accessibilityLabel("Objective: \(objective.text)")
    }
}

struct BossBar: View {
    let hud: BossHUD

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(hud.name.uppercased())
                    .trackedHeading(11, tracking: 3)
                Spacer()
                if hud.vulnerable {
                    Text("OPENING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.void)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.cyan, in: Capsule())
                        .transition(.opacity)
                }
                Text(hud.phase == 1 ? "PHASE I" : "PHASE II")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(hud.phase == 1 ? Theme.textSecondary : Theme.magenta)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.void.opacity(0.8))
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.magenta, Color(hex: 0xFF6FA3)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * hud.fraction)
                        .shadow(color: Theme.magenta, radius: 5)
                        .animation(.easeOut(duration: 0.2), value: hud.fraction)
                    Rectangle()
                        .fill(Theme.textPrimary.opacity(0.7))
                        .frame(width: 2)
                        .offset(x: g.size.width * 0.5 - 1)
                }
            }
            .frame(height: 8)
            .clipShape(ChamferShape(cut: 3))
        }
        .frame(width: 320)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .vlizPanel(cut: 8)
        .animation(.easeOut(duration: 0.2), value: hud.vulnerable)
    }
}

struct BannerView: View {
    let banner: Banner

    private var accent: Color {
        switch banner.style {
        case .info: return Theme.textPrimary
        case .reward: return Theme.cyan
        case .danger: return Theme.magenta
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(banner.title.uppercased())
                .font(.system(size: 22, weight: .bold))
                .tracking(6)
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.7), radius: 10)
            GlowRule(color: accent)
                .frame(width: 260)
            if let sub = banner.subtitle {
                Text(sub)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .shadow(color: .black, radius: 4)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [.clear, Theme.void.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
        )
    }
}

struct DialogueView: View {
    let line: DialogueLine

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let speaker = line.speaker {
                Text(speaker)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(color(for: speaker))
                    .padding(.top, 2)
            }
            Text(line.text)
                .font(.system(size: 14, weight: .medium))
                .italic(line.speaker == nil)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ChamferShape(cut: 8).fill(Theme.void.opacity(0.72)))
        .overlay(ChamferShape(cut: 8).stroke(color(for: line.speaker ?? "").opacity(0.4), lineWidth: 1))
    }

    private func color(for speaker: String) -> Color {
        switch speaker {
        case "KAEL": return Theme.cyan
        case "RHEX", "CORSAIR": return Theme.magenta
        case "???": return Theme.softViolet
        default: return Theme.textSecondary
        }
    }
}
