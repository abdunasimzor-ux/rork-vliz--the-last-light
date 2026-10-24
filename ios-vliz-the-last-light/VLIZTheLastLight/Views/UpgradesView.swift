import SwiftUI

struct UpgradesView: View {
    let onBack: () -> Void
    @ObservedObject private var progress = ProgressionManager.shared

    var body: some View {
        ZStack {
            ArmoryBackdrop()
            VStack(spacing: 14) {
                ScreenHeader(title: "Upgrades", onBack: onBack) {
                    FragmentBadge(amount: progress.fragments, label: "Energy Fragments")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(UpgradeCatalog.all) { def in
                            UpgradeCard(def: def)
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                Text("Upgrades apply to all missions. Earn fragments from shards, enemies and mission rewards.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

struct ArmoryBackdrop: View {
    var body: some View {
        ZStack {
            Image("armory_bay_soldier_silhouette")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            LinearGradient(colors: [Theme.void.opacity(0.55), Theme.void.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            MotesView(color: Theme.cyan, count: 20, intensity: 0.6).ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

private struct UpgradeCard: View {
    let def: UpgradeDefinition
    @ObservedObject private var progress = ProgressionManager.shared
    @State private var bump = 0

    var body: some View {
        let level = progress.level(of: def.id)
        let maxed = level >= def.maxLevel
        let cost = def.cost(forLevel: level)
        let affordable = progress.canPurchase(def.id)

        VStack(spacing: 10) {
            Image(systemName: def.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 8)
                .symbolEffect(.bounce, value: bump)
            Text(def.name.uppercased())
                .trackedHeading(12, tracking: 1.5)
            Text("Lv \(level)/\(def.maxLevel)")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 6) {
                ForEach(0..<def.maxLevel, id: \.self) { i in
                    Circle()
                        .fill(i < level ? Theme.cyan : Theme.textSecondary.opacity(0.3))
                        .frame(width: 9, height: 9)
                        .shadow(color: i < level ? Theme.cyan.opacity(0.7) : .clear, radius: 3)
                }
            }
            Rectangle().fill(Theme.textSecondary.opacity(0.2)).frame(height: 1)
            Group {
                if maxed {
                    Text(def.format(def.value(at: level)))
                        .foregroundStyle(Theme.cyan)
                } else {
                    HStack(spacing: 6) {
                        Text(def.format(def.value(at: level))).foregroundStyle(Theme.textPrimary)
                        Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                        Text(def.format(def.value(at: level + 1))).foregroundStyle(Theme.cyan)
                    }
                }
            }
            .font(.system(size: 15, weight: .semibold).monospacedDigit())
            Text(def.summary)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(height: 44, alignment: .top)

            Button {
                if progress.purchase(def.id) {
                    bump += 1
                    Haptics.success()
                    AudioManager.shared.play(.unlock)
                } else {
                    Haptics.error()
                    AudioManager.shared.play(.uiBack)
                }
            } label: {
                HStack(spacing: 6) {
                    if maxed {
                        Text("MAXED").trackedHeading(12, tracking: 2, color: Theme.textSecondary)
                    } else {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.cyan)
                        Text("\(cost ?? 0)")
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundStyle(affordable ? Theme.textPrimary : Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Capsule().fill(affordable ? Theme.teal.opacity(0.7) : Theme.midnight.opacity(0.6)))
                .overlay(Capsule().stroke(affordable ? Theme.cyan.opacity(0.8) : Theme.textSecondary.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(VlizPressStyle())
            .disabled(maxed)
            .accessibilityLabel(maxed ? "\(def.name) maxed" : "Buy \(def.name) level \(level + 1) for \(cost ?? 0) fragments")
        }
        .padding(16)
        .frame(width: 200)
        .vlizPanel(highlighted: affordable && !maxed, cut: 14)
    }
}
